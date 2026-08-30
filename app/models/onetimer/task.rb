# frozen_string_literal: true

module Onetimer
  class Task < ApplicationRecord
    self.table_name = "onetimer_tasks"

    validates :name, presence: true, uniqueness: true
    validates :status, inclusion: { in: %w[running completed] }
  end
end
