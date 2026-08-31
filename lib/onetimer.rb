# frozen_string_literal: true

require "onetimer/version"
require "onetimer/engine"
require "onetimer/runner"

module Onetimer
  class Error < StandardError; end

  class << self
    attr_accessor :tasks_dir, :record_failures
  end
end
