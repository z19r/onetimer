# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"

load Rails.root.join("db/schema.rb")

require "minitest/autorun"
