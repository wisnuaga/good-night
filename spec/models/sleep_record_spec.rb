require 'rails_helper'

RSpec.describe SleepRecord, type: :model do
  let(:user) { User.create!(name: "Alice") }

  it "is valid with a clock_in and user" do
    sleep_record = SleepRecord.new(user: user, clock_in: Time.current)
    expect(sleep_record).to be_valid
  end

  it "is invalid without a clock_in" do
    sleep_record = SleepRecord.new(user: user, clock_in: nil)
    expect(sleep_record).not_to be_valid
    expect(sleep_record.errors[:clock_in]).to include("can't be blank")
  end

  it "allows clock_out to be nil (still sleeping)" do
    sleep_record = SleepRecord.new(user: user, clock_in: Time.current, clock_out: nil)
    expect(sleep_record).to be_valid
  end

  context "when user already has an active sleep session (clock_out is nil)" do
    before do
      SleepRecord.create!(user: user, clock_in: 2.hours.ago, clock_out: nil)
    end

    it "does not allow creating a new active sleep session" do
      new_sleep = SleepRecord.new(user: user, clock_in: Time.current)
      expect(new_sleep).not_to be_valid
      expect(new_sleep.errors[:base]).to include("You already have an active sleep session")
    end
  end

  context "when user has no active sleep sessions" do
    before do
      SleepRecord.create!(user: user, clock_in: 4.hours.ago, clock_out: 2.hours.ago)
    end

    it "allows creating a new sleep session" do
      new_sleep = SleepRecord.new(user: user, clock_in: Time.current)
      expect(new_sleep).to be_valid
    end
  end
end
