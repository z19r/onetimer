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
