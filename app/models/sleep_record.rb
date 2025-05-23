class SleepRecord < ApplicationRecord
  belongs_to :user

  # Validate presence of clock_in (clock_out can be nil when still sleeping)
  validates :clock_in, presence: true
end
