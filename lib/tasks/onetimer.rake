# frozen_string_literal: true

namespace :onetimer do
  desc "Run any pending one-off tasks (idempotent, safe to run repeatedly)"
  task run: :environment do
    Onetimer::Runner.run_pending!
  end

  desc "List one-off tasks that would run on the next onetimer:run"
  task pending: :environment do
    names = Onetimer::Runner.pending_task_names
    if names.empty?
      puts "No pending tasks."
    else
      names.each { |name| puts name }
    end
  end

  desc "Generate a new one-off task, e.g. rake onetimer:new NAME=backfill_x"
  task new: :environment do
    name = ENV.fetch("NAME") { abort "Usage: rake onetimer:new NAME=backfill_x" }
    path = Onetimer::Runner.generate!(name)
    puts "Created #{path}"
  end
end
