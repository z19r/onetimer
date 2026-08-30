# frozen_string_literal: true

require "rails/generators"
require "rails/generators/migration"

module Onetimer
  module Generators
    class InstallGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      source_root File.expand_path("templates", __dir__)

      def self.next_migration_number(dirname)
        ActiveRecord::Generators::Base.next_migration_number(dirname)
      end

      def create_migration_file
        migration_template(
          "create_onetimer_tasks.rb.erb",
          "db/migrate/create_onetimer_tasks.rb"
        )
      end

      def create_tasks_directory
        empty_directory "lib/one_timers"
        create_file "lib/one_timers/.keep"
      end

      private

      def migration_version
        "[#{ActiveRecord::VERSION::MAJOR}.#{ActiveRecord::VERSION::MINOR}]"
      end
    end
  end
end
