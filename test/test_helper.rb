# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
ENV["RAILS_ENV"] ||= "test"

require_relative "dummy/config/environment"
load Rails.root.join("db/schema.rb")

require "minitest/autorun"

unless Object.method_defined?(:stub)
  # rubocop:disable Metrics/MethodLength
  class Object
    def stub(name, val_or_callable, *block_args, **block_kwargs)
      new_name = "__minitest_stub__#{name}"
      metaclass = class << self; self; end

      metaclass.send(:alias_method, new_name, name)
      metaclass.send(:define_method, name) do |*args, &blk|
        if val_or_callable.respond_to?(:call)
          val_or_callable.call(*args, **block_kwargs, &blk)
        else
          blk&.call(*block_args, **block_kwargs)
          val_or_callable
        end
      end

      yield self
    ensure
      metaclass.send(:undef_method, name)
      metaclass.send(:alias_method, name, new_name)
      metaclass.send(:undef_method, new_name)
    end
  end
  # rubocop:enable Metrics/MethodLength
end
