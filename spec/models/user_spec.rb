require 'rails_helper'

RSpec.describe User, type: :model do
  it "is valid with a name" do
    user = User.new(name: "Alice")
    expect(user).to be_valid
  end

  it "is invalid without a name" do
    user = User.new(name: nil)
    expect(user).not_to be_valid
  end
end
