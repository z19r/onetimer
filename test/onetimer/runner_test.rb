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
