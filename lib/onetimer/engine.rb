# frozen_string_literal: true

module Onetimer
  class Engine < ::Rails::Engine
    isolate_namespace Onetimer

    config.onetimer = ActiveSupport::OrderedOptions.new
    config.onetimer.tasks_dir = nil # set per-host-app; defaults to Rails.root/lib/one_timers
    config.onetimer.record_failures = nil # set per-host-app; defaults to false (destroy failed rows)

    initializer "onetimer.tasks_dir" do |app|
      Onetimer.tasks_dir = app.config.onetimer.tasks_dir || Rails.root.join("lib/one_timers")
    end

    initializer "onetimer.record_failures" do |app|
      Onetimer.record_failures = app.config.onetimer.record_failures
    end

    rake_tasks do
      load File.expand_path("../tasks/onetimer.rake", __dir__)
    end
  end
end
