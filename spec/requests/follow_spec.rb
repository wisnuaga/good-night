require "rails_helper"

RSpec.describe FollowsController, type: :request do
  let(:current_user) { User.create!(name: "John") }
  let(:headers) { { "X-User-Id" => current_user.id.to_s } }
  let(:followee_id) { current_user.id + 1 }

  describe "POST /users/:id/following" do
    context "when user tries to follow themselves" do
      it "returns bad request" do
        post "/users/#{current_user.id}/following", headers: headers
        expect(response).to have_http_status(:bad_request)
        expect(response.parsed_body["error"]).to eq("Cannot follow yourself")
      end
    end

    context "when following another user" do
      before do
        allow_any_instance_of(FollowUsecase::Follow).to receive(:call).and_return(
          OpenStruct.new(success?: true, data: { message: "Followed successfully" })
        )
      end

      it "returns created" do
        post "/users/#{followee_id}/following", headers: headers
        expect(response).to have_http_status(:created)
        expect(response.parsed_body).to eq({ "message" => "Followed successfully" })
      end
    end
  end

  describe "DELETE /users/:id/following" do
    before do
      allow_any_instance_of(FollowUsecase::Unfollow).to receive(:call).and_return(
        OpenStruct.new(success?: true, data: { message: "Unfollowed successfully" })
      )
    end

    it "returns ok after unfollowing" do
      delete "/users/#{followee_id}/following", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ "message" => "Unfollowed successfully" })
    end
  end
end
