# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
ENV["RAILS_ENV"] ||= "test"


load Rails.root.join("db/schema.rb")

require "minitest/mock"
require "minitest/autorun"

require "minitest/autorun"
