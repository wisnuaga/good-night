class SleepRecord < ApplicationRecord
  belongs_to :user

  # Validate presence of clock_in (clock_out can be nil when still sleeping)
  validates :clock_in, presence: true

  # Custom validation to prevent overlapping active sleep records per user
  validate :no_overlapping_active_sessions, on: :create

  private

  def no_overlapping_active_sessions
    if SleepRecord.where(user_id: user_id, clock_out: nil).exists?
      errors.add(:base, "You already have an active sleep session")
    end
  end
end
