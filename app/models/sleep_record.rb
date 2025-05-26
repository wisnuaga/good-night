class SleepRecord < ApplicationRecord
  belongs_to :user

  # Validate presence of clock_in (clock_out can be nil when still sleeping)
  validates :clock_in, presence: true

  # Custom validation to prevent overlapping active sleep records per user
  validate :no_overlapping_active_sessions, on: :create

  # Calculate sleep_time before saving record
  before_save :calculate_sleep_time

  private

  def no_overlapping_active_sessions
    if SleepRecord.where(user_id: user_id, clock_out: nil).exists?
      errors.add(:base, "You already have an active sleep session")
    end
  end

  def calculate_sleep_time
    if clock_out.present? && clock_in.present? && clock_out > clock_in
      self.sleep_time = clock_out - clock_in  # duration in seconds
    else
      self.sleep_time = nil
    end
  end
end
