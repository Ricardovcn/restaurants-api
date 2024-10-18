require 'rails_helper'

RSpec.describe Api::V1::Restaurants::ImportFilesController, type: :controller do
  let(:valid_file) { fixture_file_upload('spec/fixtures/files/restaurant_data.json', 'application/json') }
  let(:invalid_format_file) { fixture_file_upload('spec/fixtures/files/invalid_format_file.txt', 'text/plain') }
  let(:invalid_json_file) { fixture_file_upload('spec/fixtures/files/invalid_json_file.json', 'application/json') }

  describe "POST /import_json" do
    context "a required params is missing" do
      it 'returns a 400 code and a error message' do
        post :import_json, params: { }

        expect(response).to have_http_status :bad_request
        expect(JSON.parse(response.body)["message"]).to include("No file provided")
      end
    end

    context "gets a invalid json file" do
      it 'returns a 422 code and an error message' do
        post :import_json, params: { file: invalid_format_file }

        expect(response).to have_http_status :unprocessable_entity
        expect(JSON.parse(response.body)["message"]).to include("Invalid file extension")
      end
    end

    context "gets a invalid json file" do
      it 'returns a 422 code and an error message' do
        post :import_json, params: { file: invalid_json_file }

        expect(response).to have_http_status :unprocessable_entity
        expect(JSON.parse(response.body)["message"]).to include("Invalid JSON file")
      end
    end

    context "gets a invalid json file" do
      it 'returns a 422 code and an error message' do
        mock_service = instance_double(::Restaurants::ImportService)
        allow(::Restaurants::ImportService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:serialize_and_persist).and_return({ error: "Error message" })

        post :import_json, params: { file: valid_file }

        expect(response).to have_http_status :unprocessable_entity
        expect(JSON.parse(response.body)["message"]).to include("Failed to import file.")
      end
    end

    context "gets a invalid json file" do
      it 'returns a 204 code' do
        mock_service = instance_double(::Restaurants::ImportService)
        allow(::Restaurants::ImportService).to receive(:new).and_return(mock_service)
        allow(mock_service).to receive(:serialize_and_persist).and_return({})

        post :import_json, params: { file: valid_file }

        expect(response).to have_http_status :no_content
      end
    end
  end
end