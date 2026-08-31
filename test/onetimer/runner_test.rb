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
