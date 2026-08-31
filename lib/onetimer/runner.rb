# frozen_string_literal: true

module Onetimer
  # Runs one-off data tasks exactly once, the way db:migrate runs schema
  # migrations exactly once. Task files live in Onetimer.tasks_dir (default
  # lib/one_timers/), named <timestamp>_<description>.rb, each defining
  # OneTimers::<Description> with a #run method. Generate one with
  # `rake onetimer:new NAME=...`.
  class Runner
    def self.run_pending!
      task_files.each { |file| run_task(file) }
    end

    def self.pending_task_names
      task_files.map { |file| File.basename(file, ".rb") }
                .reject { |name| Task.exists?(name: name, status: "completed") }
    end

    def self.generate!(name)
      timestamp = Time.current.strftime("%Y%m%d%H%M%S")
      class_name = name.camelize
      path = Onetimer.tasks_dir.join("#{timestamp}_#{name.underscore}.rb")

      FileUtils.mkdir_p(Onetimer.tasks_dir)
      File.write(path, <<~RUBY)
        # frozen_string_literal: true

        module OneTimers
          class #{class_name}
            def run
              # One-time task logic goes here.
            end
          end
        end
      RUBY

      path
    end

    def self.task_files
      Dir.glob(Onetimer.tasks_dir.join("*.rb")).sort
    end
    private_class_method :task_files

    def self.run_task(file)
      name = File.basename(file, ".rb")
      return if Task.exists?(name: name, status: "completed")

      task = claim(name)
      return unless task # already completed or claimed by another process

      require file
      class_for(file).new.run
      task.update!(status: "completed", finished_at: Time.current)
      Rails.logger.info "[Onetimer] completed #{name}"
    rescue StandardError => e
      handle_failure(task, e)
      Rails.logger.error "[Onetimer] failed #{name}: #{e.message}"
      raise
    end
    private_class_method :run_task

    def self.handle_failure(task, error)
      if Onetimer.record_failures && task.respond_to?(:error_message=)
        task.update!(status: "failed", error_message: error.message, finished_at: Time.current)
      else
        if Onetimer.record_failures
          Rails.logger.warn "[Onetimer] record_failures is enabled but onetimer_tasks is missing " \
                             "the error_message column — add a migration (add_column " \
                             ":onetimer_tasks, :error_message, :text). Falling back to destroying the row."
        end
        task&.destroy!
      end
    end
    private_class_method :handle_failure

    # Unique index on name makes this an atomic claim: if two processes
    # (e.g. concurrent deploy machines) race to run the same task, only
    # one succeeds in creating the row and actually runs it.
    def self.claim(name)
      Task.where(name: name, status: "failed").destroy_all if Onetimer.record_failures

      Task.create!(name: name, status: "running", started_at: Time.current)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      nil
    end
    private_class_method :claim

    def self.class_for(file)
      class_name = File.basename(file, ".rb").sub(/\A\d+_/, "").camelize
      "OneTimers::#{class_name}".constantize
    end
    private_class_method :class_for
  end
end
