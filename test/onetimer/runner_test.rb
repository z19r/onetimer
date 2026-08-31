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
