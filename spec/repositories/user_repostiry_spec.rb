require 'rails_helper'

RSpec.describe UserRepository do
  let(:repo) { UserRepository.new }
  let!(:user) { User.create!(name: "User1") }

  describe "#find_by_id" do
    it "returns user if found" do
      expect(repo.find_by_id(id: user.id)).to eq(user)
    end

    it "returns nil if user not found" do
      expect(repo.find_by_id(id: 0)).to be_nil
    end
  end
end
