# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Vehicles', openapi_spec: 'v1/swagger.json', type: :request do
  let(:customer_params) do
    {
      person_type: "individual",
      document: "529.982.247-25",
      name: "João Silva",
      email: "joao@example.com",
      phone: "11999990000",
      address: {
        zip_code: "01001-000",
        street: "Praça da Sé",
        number: "1",
        city: "São Paulo",
        state: "SP"
      }
    }
  end

  let(:valid_params) do
    {
      customer_id: @customer_id,
      license_plate: "ABC-1234",
      make: "Toyota",
      model: "Corolla",
      year: 2022,
      color: "Silver"
    }
  end

  path '/api/v1/vehicles' do
    get 'List vehicles' do
      tags 'Vehicles'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :customer_id, in: :query, type: :integer, required: false, description: 'Filter by customer ID'

      response '200', 'returns vehicles filtered by customer_id' do
        schema type: :array, items: { '$ref' => '#/components/schemas/Vehicle' }
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: customer_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
          post "/api/v1/vehicles", params: valid_params, headers: { Authorization: auth_token }, as: :json
          post "/api/v1/vehicles", params: valid_params.merge(license_plate: "XYZ-9876"), headers: { Authorization: auth_token }, as: :json
        end
        let(:customer_id) { @customer_id }
        run_test! do |response|
          expect(response.parsed_body.size).to eq(2)
        end
      end

      response '200', 'returns empty array when no vehicles for customer' do
        schema type: :array, items: { '$ref' => '#/components/schemas/Vehicle' }
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: customer_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
        end
        let(:customer_id) { @customer_id }
        run_test! do |response|
          expect(response.parsed_body).to eq([])
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end

    post 'Create vehicle' do
      tags 'Vehicles'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :vehicle, in: :body, schema: {
        type: :object,
        properties: {
          customer_id: { type: :integer },
          license_plate: { type: :string },
          make: { type: :string },
          model: { type: :string },
          year: { type: :integer },
          color: { type: :string }
        },
        required: %w[customer_id license_plate make model year color]
      }

      response '201', 'creates a vehicle with valid data' do
        schema '$ref' => '#/components/schemas/Vehicle'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: customer_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
        end
        let(:vehicle) { valid_params }
        run_test! do |response|
          body = response.parsed_body
          expect(body["make"]).to eq("Toyota")
          expect(body["license_plate"]).to eq("ABC-1234")
          expect(body["customer_id"]).to eq(@customer_id)
          expect(body["status"]).to eq("active")
        end
      end

      response '201', 'creates a vehicle with Mercosul plate' do
        schema '$ref' => '#/components/schemas/Vehicle'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: customer_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
        end
        let(:vehicle) { valid_params.merge(license_plate: "ABC1D23") }
        run_test! do |response|
          expect(response.parsed_body["license_plate"]).to eq("ABC1D23")
        end
      end

      response '422', 'returns 422 with invalid license plate' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: customer_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
        end
        let(:vehicle) { valid_params.merge(license_plate: "INVALID") }
        run_test! do |response|
          expect(response.parsed_body["error"]).to match(/Invalid license plate format/)
        end
      end

      response '422', 'returns 422 with duplicate license plate' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: customer_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
          post "/api/v1/vehicles", params: valid_params, headers: { Authorization: auth_token }, as: :json
        end
        let(:vehicle) { valid_params.merge(color: "Red") }
        run_test! do |response|
          expect(response.parsed_body["error"]).to eq("License plate already registered")
        end
      end

      response '422', 'returns 422 when customer does not exist' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:vehicle) { valid_params.merge(customer_id: 999_999) }
        run_test! do |response|
          expect(response.parsed_body["error"]).to eq("Customer not found")
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:vehicle) { valid_params }
        run_test!
      end
    end
  end

  path '/api/v1/vehicles/{id}' do
    get 'Get vehicle by ID' do
      tags 'Vehicles'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'returns the vehicle' do
        schema '$ref' => '#/components/schemas/Vehicle'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: customer_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
          post "/api/v1/vehicles", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @vehicle_id = response.parsed_body["id"]
        end
        let(:id) { @vehicle_id }
        run_test! do |response|
          expect(response.parsed_body["make"]).to eq("Toyota")
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end

      response '404', 'returns 404 when vehicle not found' do
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        run_test!
      end
    end

    patch 'Update vehicle' do
      tags 'Vehicles'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :vehicle, in: :body, schema: {
        type: :object,
        properties: {
          color: { type: :string }
        }
      }

      response '200', 'updates vehicle color' do
        schema '$ref' => '#/components/schemas/Vehicle'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: customer_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
          post "/api/v1/vehicles", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @vehicle_id = response.parsed_body["id"]
        end
        let(:id) { @vehicle_id }
        let(:vehicle) { { color: "Black" } }
        run_test! do |response|
          expect(response.parsed_body["color"]).to eq("Black")
        end
      end

      response '422', 'returns 422 when vehicle not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        let(:vehicle) { { color: "Black" } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        let(:vehicle) { { color: "Black" } }
        run_test!
      end

      response '404', 'not found' do
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        let(:vehicle) { { color: "Black" } }
        run_test!
      end
    end
  end
end
