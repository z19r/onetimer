# frozen_string_literal: true

require_relative "boot"

require "rails"
require "active_record/railtie"
require "onetimer"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("..", __dir__)
    config.load_defaults Rails::VERSION::STRING.to_f
    config.eager_load = false
    config.onetimer.tasks_dir = Rails.root.join("lib/one_timers")
  end
end
