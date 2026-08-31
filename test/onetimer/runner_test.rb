# frozen_string_literal: true

require "test_helper"

class Onetimer::RunnerTest < ActiveSupport::TestCase
  def teardown
    @task_paths&.each { |path| File.delete(path) if File.exist?(path) }
  end

  test "runs a pending task exactly once" do
    write_task("20260101000000_runner_test_ok", "Onetimer::RunnerTest.run_count += 1")

    Onetimer::Runner.run_pending!
    Onetimer::Runner.run_pending!

    assert_equal 1, self.class.run_count
    assert Onetimer::Task.exists?(
      name: "20260101000000_runner_test_ok", status: "completed"
    )
  end

  test "deletes the claim row so a failed task can retry" do
    write_task("20260101000000_runner_test_fail", 'raise "boom"')

    assert_raises(RuntimeError) { Onetimer::Runner.run_pending! }

    assert_not Onetimer::Task.exists?(name: "20260101000000_runner_test_fail")
  end

  test "with record_failures enabled, a failed task leaves a failed Task row with the error message" do
    Onetimer.record_failures = true
    write_task("20260101000000_runner_test_record_fail", 'raise "boom"')

    assert_raises(RuntimeError) { Onetimer::Runner.run_pending! }

    task = Onetimer::Task.find_by(name: "20260101000000_runner_test_record_fail")
    assert task
    assert_equal "failed", task.status
    assert_equal "boom", task.error_message
  ensure
    Onetimer.record_failures = nil
  end

  test "with record_failures enabled, retrying a fixed task after a failure succeeds" do
    Onetimer.record_failures = true
    name = "20260101000000_runner_test_record_retry"
    # The task file is only require'd once (Ruby caches by path), so simulate
    # "fix the task and redeploy" with internal state: fails on the first
    # run, succeeds on the second — same as a task that raised once and
    # whose underlying issue was then fixed.
    write_task(name, <<~RUBY)
      @@attempts ||= 0
      @@attempts += 1
      raise "boom" if @@attempts == 1
      Onetimer::RunnerTest.run_count += 1
    RUBY

    assert_raises(RuntimeError) { Onetimer::Runner.run_pending! }
    assert Onetimer::Task.exists?(name: name, status: "failed")

    Onetimer::Runner.run_pending!

    assert Onetimer::Task.exists?(name: name, status: "completed")
    assert_equal 1, self.class.run_count
  ensure
    Onetimer.record_failures = nil
  end

  test "with record_failures enabled but no error_message column, falls back to destroying the row and warns" do
    Onetimer.record_failures = true
    write_task("20260101000000_runner_test_no_column", 'raise "boom"')

    warned_messages = []
    Onetimer::Task.class_eval do
      alias_method :__original_respond_to_for_test?, :respond_to?
      define_method(:respond_to?) do |method, *args|
        method == :error_message= ? false : __original_respond_to_for_test?(method, *args)
      end
    end

    begin
      Rails.logger.stub(:warn, ->(msg) { warned_messages << msg }) do
        assert_raises(RuntimeError) { Onetimer::Runner.run_pending! }
      end
    ensure
      Onetimer::Task.class_eval do
        alias_method :respond_to?, :__original_respond_to_for_test?
        remove_method :__original_respond_to_for_test?
      end
    end

    assert_not Onetimer::Task.exists?(name: "20260101000000_runner_test_no_column")
    assert(warned_messages.any? do |msg|
      msg.include?("record_failures") && msg.include?("error_message")
    end)
  ensure
    Onetimer.record_failures = nil
  end

  test "verify_unique_index! returns true when the unique index exists" do
    result = Onetimer::Runner.verify_unique_index!
    assert_equal true, result
  end

  test "verify_unique_index! raises Onetimer::Error when the unique index is missing" do
    ActiveRecord::Base.connection.stub(:index_exists?, false) do
      error = assert_raises(Onetimer::Error) { Onetimer::Runner.verify_unique_index! }
      assert_includes error.message, "unique index"
    end
  end

  test "warns on task file missing timestamp prefix" do
    # Write a task file without a timestamp prefix
    basename = "backfill_x"
    class_name = "BackfillX"
    path = Onetimer.tasks_dir.join("#{basename}.rb")
    (@task_paths ||= []) << path

    File.write(path, <<~RUBY)
      # frozen_string_literal: true

      module OneTimers
        class #{class_name}
          def run
            # Task without timestamp prefix
          end
        end
      end
    RUBY

    # Stub Rails.logger.warn and verify it was called with the filename
    warned_messages = []
    Rails.logger.stub(:warn, ->(msg) { warned_messages << msg }) do
      Onetimer::Runner.run_pending!
    end

    assert(warned_messages.any? { |msg| msg.include?("backfill_x") && msg.include?("missing timestamp prefix") })
  end

  test "pending_task_names returns empty array when no task files exist" do
    # Clear any existing task files by not writing any
    assert_equal [], Onetimer::Runner.pending_task_names
  end

  test "pending_task_names includes a task file with no matching completed Task row" do
    write_task("20260101000000_pending_test_one", "puts 'task one'")

    names = Onetimer::Runner.pending_task_names
    assert_includes names, "20260101000000_pending_test_one"
  end

  test "pending_task_names excludes a task file with a matching completed Task row" do
    write_task("20260101000000_pending_test_two", "puts 'task two'")
    name = "20260101000000_pending_test_two"

    # Create a completed Task row
    Onetimer::Task.create!(name: name, status: "completed", started_at: Time.current, finished_at: Time.current)

    names = Onetimer::Runner.pending_task_names
    assert_not_includes names, name
  end

  class << self
    attr_accessor :run_count
  end

  private

  def write_task(basename, body)
    self.class.run_count = 0
    class_name = basename.sub(/\A\d+_/, "").camelize
    path = Onetimer.tasks_dir.join("#{basename}.rb")
    (@task_paths ||= []) << path

    File.write(path, <<~RUBY)
      # frozen_string_literal: true

      module OneTimers
        class #{class_name}
          def run
            #{body}
          end
        end
      end
    RUBY
  end
end
