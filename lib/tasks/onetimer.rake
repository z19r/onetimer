# frozen_string_literal: true

namespace :onetimer do
  desc "Run any pending one-off tasks (idempotent, safe to run repeatedly)"
  task run: :environment do
    Onetimer::Runner.run_pending!
  end

  desc "Generate a new one-off task, e.g. rake onetimer:new NAME=backfill_x"
  task new: :environment do
    name = ENV.fetch("NAME") { abort "Usage: rake onetimer:new NAME=backfill_x" }
    path = Onetimer::Runner.generate!(name)
    puts "Created #{path}"
  end

  desc "Verify the onetimer_tasks table has the required unique index on :name"
  task doctor: :environment do
    Onetimer::Runner.verify_unique_index!
    puts "onetimer_tasks: unique index on :name present. OK."
  end
end
