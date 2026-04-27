# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Services', openapi_spec: 'v1/swagger.json', type: :request do
  let(:valid_params) do
    {
      name: "Oil Change",
      description: "Complete oil and filter change",
      base_price: 5000,
      estimated_duration_minutes: 30
    }
  end

  path '/api/v1/services' do
    get 'List services' do
      tags 'Services'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      response '200', 'returns all services' do
        schema type: :array, items: { '$ref' => '#/components/schemas/Service' }
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/services", params: valid_params, headers: { Authorization: auth_token }, as: :json
          post "/api/v1/services", params: valid_params.merge(name: "Brake Inspection"), headers: { Authorization: auth_token }, as: :json
        end
        run_test! do |response|
          expect(response.parsed_body.size).to eq(2)
        end
      end

      response '200', 'returns empty array when no services' do
        schema type: :array, items: { '$ref' => '#/components/schemas/Service' }
        let(:Authorization) { auth_token }
        run_test! do |response|
          expect(response.parsed_body).to eq([])
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end

    post 'Create service' do
      tags 'Services'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :service, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          base_price: { type: :integer, description: 'Price in cents' },
          estimated_duration_minutes: { type: :integer }
        },
        required: %w[name base_price]
      }

      response '201', 'creates a service with valid data' do
        schema '$ref' => '#/components/schemas/Service'
        let(:Authorization) { auth_token }
        let(:service) { valid_params }
        run_test! do |response|
          body = response.parsed_body
          expect(body["name"]).to eq("Oil Change")
          expect(body["description"]).to eq("Complete oil and filter change")
          expect(body["base_price"]).to eq("R$ 50.00")
          expect(body["estimated_duration_minutes"]).to eq(30)
          expect(body["active"]).to be true
        end
      end

      response '422', 'returns 422 with duplicate name' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:service) { valid_params }
        before do
          post "/api/v1/services", params: valid_params, headers: { Authorization: auth_token }, as: :json
        end
        run_test! do |response|
          body = response.parsed_body
          expect(body["error"]).to eq("Service name already registered")
        end
      end

      response '422', 'returns 422 with negative base_price' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:service) { valid_params.merge(base_price: -100) }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:service) { valid_params }
        run_test!
      end
    end
  end

  path '/api/v1/services/{id}' do
    get 'Get service by ID' do
      tags 'Services'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'returns the service' do
        schema '$ref' => '#/components/schemas/Service'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/services", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @service_id = response.parsed_body["id"]
        end
        let(:id) { @service_id }
        run_test! do |response|
          expect(response.parsed_body["name"]).to eq("Oil Change")
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end

      response '404', 'returns 404 when service not found' do
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        run_test!
      end
    end

    patch 'Update service' do
      tags 'Services'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :service, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          base_price: { type: :integer, description: 'Price in cents' },
          estimated_duration_minutes: { type: :integer }
        }
      }

      response '200', 'updates service name' do
        schema '$ref' => '#/components/schemas/Service'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/services", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @service_id = response.parsed_body["id"]
        end
        let(:id) { @service_id }
        let(:service) { { name: "Premium Oil Change" } }
        run_test! do |response|
          expect(response.parsed_body["name"]).to eq("Premium Oil Change")
        end
      end

      response '200', 'updates service base_price' do
        schema '$ref' => '#/components/schemas/Service'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/services", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @service_id = response.parsed_body["id"]
        end
        let(:id) { @service_id }
        let(:service) { { base_price: 8000 } }
        run_test! do |response|
          expect(response.parsed_body["base_price"]).to eq("R$ 80.00")
        end
      end

      response '422', 'returns 422 when service not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        let(:service) { { name: "Test" } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        let(:service) { { name: "Test" } }
        run_test!
      end
    end

    delete 'Deactivate service' do
      tags 'Services'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'deactivates the service' do
        schema '$ref' => '#/components/schemas/Service'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/services", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @service_id = response.parsed_body["id"]
        end
        let(:id) { @service_id }
        run_test! do |response|
          expect(response.parsed_body["active"]).to be false
        end
      end

      response '422', 'returns 422 when already inactive' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/services", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @service_id = response.parsed_body["id"]
          delete "/api/v1/services/#{@service_id}", headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @service_id }
        run_test! do |response|
          expect(response.parsed_body["error"]).to match(/already inactive/)
        end
      end

      response '422', 'returns 422 when service not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end
    end
  end
end
