require "rails_helper"

RSpec.describe SleepRecordController, type: :request do
  let(:current_user) { User.create!(name: "David") }
  let(:headers) { { "X-User-Id" => current_user.id.to_s } }

  describe "POST /sleep_records/clock_in" do
    before do
      allow_any_instance_of(SleepRecordUsecase::ClockIn).to receive(:call).and_return(
        OpenStruct.new(success?: true, data: { message: "Clocked in" })
      )
    end

    it "returns created" do
      post "/sleep_records/clock_in", headers: headers
      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to eq({ "message" => "Clocked in" })
    end
  end

  describe "PUT /sleep_records/clock_out" do
    before do
      allow_any_instance_of(SleepRecordUsecase::ClockOut).to receive(:call).and_return(
        OpenStruct.new(success?: true, data: { message: "Clocked out" })
      )
    end

    it "returns ok" do
      put "/sleep_records/clock_out", headers: headers
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq({ "message" => "Clocked out" })
    end
  end

  describe "GET /sleep_records" do
    context "without followees" do
      before do
        allow_any_instance_of(SleepRecordUsecase::List).to receive(:call).and_return(
          OpenStruct.new(success?: true, data: { data: ["record1", "record2"] })
        )
      end

      it "returns records only for user" do
        get "/sleep_records", headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({ "data" => ["record1", "record2"] })
      end
    end

    context "with include_followees param" do
      before do
        allow_any_instance_of(SleepRecordUsecase::List).to receive(:call).and_return(
          OpenStruct.new(success?: true, data: { data: ["record1", "record2", "record3"] })
        )
      end

      it "returns records including followees" do
        get "/sleep_records", params: { include_followees: "true" }, headers: headers
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq({ "data" => ["record1", "record2", "record3"] })
      end
    end
  end
end
