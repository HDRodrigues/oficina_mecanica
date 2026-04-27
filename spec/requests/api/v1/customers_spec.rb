# frozen_string_literal: true

require "rails_helper"
require 'swagger_helper'

RSpec.describe "Api::V1::Customers", openapi_spec: 'v1/swagger.json', type: :request do
  let(:valid_params) do
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

  path '/api/v1/customers' do
    post 'Create customer' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :customer, in: :body, schema: {
        type: :object,
        properties: {
          person_type: { type: :string, enum: %w[individual company] },
          document: { type: :string },
          name: { type: :string },
          email: { type: :string },
          phone: { type: :string },
          address: {
            type: :object,
            properties: {
              zip_code: { type: :string },
              street: { type: :string },
              number: { type: :string },
              city: { type: :string },
              state: { type: :string }
            }
          }
        },
        required: %w[person_type document name email phone address]
      }

      response '201', 'creates a customer with valid data' do
        schema '$ref' => '#/components/schemas/Customer'
        let(:Authorization) { auth_token }
        let(:customer) { valid_params }
        run_test! do |response|
          body = response.parsed_body
          expect(body["name"]).to eq("João Silva")
          expect(body["document"]).to eq("529.982.247-25")
          expect(body["person_type"]).to eq("individual")
          expect(body["status"]).to eq("active")
          expect(body["address"]["city"]).to eq("São Paulo")
        end
      end

      response '201', 'creates a company customer with CNPJ' do
        schema '$ref' => '#/components/schemas/Customer'
        let(:Authorization) { auth_token }
        let(:customer) { valid_params.merge(person_type: "company", document: "11.222.333/0001-81") }
        run_test! do |response|
          body = response.parsed_body
          expect(body["person_type"]).to eq("company")
          expect(body["document"]).to eq("11.222.333/0001-81")
        end
      end

      response '422', 'returns 422 with invalid document' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:customer) { valid_params.merge(document: "00000000000") }
        run_test! do |response|
          body = response.parsed_body
          expect(body["error"]).to match(/Invalid CPF/)
        end
      end

      response '422', 'returns 422 with duplicate document' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:customer) { valid_params }
        before do
          post "/api/v1/customers", params: valid_params, headers: { Authorization: auth_token }, as: :json
        end
        run_test! do |response|
          body = response.parsed_body
          expect(body["error"]).to eq("Document already registered")
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:customer) { valid_params }
        run_test!
      end
    end

    get 'List customers' do
      tags 'Customers'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :page, in: :query, type: :integer, required: false, description: 'Page number'
      parameter name: :per_page, in: :query, type: :integer, required: false, description: 'Items per page'

      response '200', 'returns all customers' do
        schema type: :array,
               items: { '$ref' => '#/components/schemas/Customer' }
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: valid_params, headers: { Authorization: auth_token }, as: :json
          post "/api/v1/customers", params: valid_params.merge(
            document: "11.222.333/0001-81",
            person_type: "company",
            name: "Empresa X",
            email: "x@test.com"
          ), headers: { Authorization: auth_token }, as: :json
        end
        run_test! do |response|
          expect(response.parsed_body.size).to eq(2)
        end
      end

      response '200', 'returns empty array when no customers' do
        schema type: :array,
               items: { '$ref' => '#/components/schemas/Customer' }
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
  end

  path '/api/v1/customers/{id}' do
    get 'Get customer by ID' do
      tags 'Customers'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'returns the customer' do
        schema '$ref' => '#/components/schemas/Customer'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
        end
        let(:id) { @customer_id }
        run_test! do |response|
          expect(response.parsed_body["name"]).to eq("João Silva")
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end

      response '404', 'returns 404 when customer not found' do
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        run_test!
      end
    end

    patch 'Update customer' do
      tags 'Customers'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :customer, in: :body, schema: {
        type: :object,
        properties: {
          person_type: { type: :string, enum: %w[individual company] },
          document: { type: :string },
          name: { type: :string },
          email: { type: :string },
          phone: { type: :string },
          address: {
            type: :object,
            properties: {
              zip_code: { type: :string },
              street: { type: :string },
              number: { type: :string },
              city: { type: :string },
              state: { type: :string }
            }
          }
        }
      }

      response '200', 'updates customer name' do
        schema '$ref' => '#/components/schemas/Customer'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
        end
        let(:id) { @customer_id }
        let(:customer) { { name: "Maria Silva" } }
        run_test! do |response|
          expect(response.parsed_body["name"]).to eq("Maria Silva")
        end
      end

      response '200', 'updates customer address' do
        schema '$ref' => '#/components/schemas/Customer'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
        end
        let(:id) { @customer_id }
        let(:customer) { { address: { zip_code: "02002-000", street: "Rua Nova", number: "42", city: "RJ", state: "RJ" } } }
        run_test! do |response|
          expect(response.parsed_body["address"]["street"]).to eq("Rua Nova")
        end
      end

      response '422', 'returns 422 when customer not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        let(:customer) { { name: "Test" } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        let(:customer) { { name: "Test" } }
        run_test!
      end

      response '422', 'not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        let(:customer) { { name: "Test" } }
        run_test!
      end
    end

    delete 'Delete customer' do
      tags 'Customers'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'deactivates the customer' do
        schema '$ref' => '#/components/schemas/Customer'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
        end
        let(:id) { @customer_id }
        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("inactive")
        end
      end

      response '422', 'returns 422 when already inactive' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/customers", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @customer_id = response.parsed_body["id"]
          delete "/api/v1/customers/#{@customer_id}", headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @customer_id }
        run_test! do |response|
          expect(response.parsed_body["error"]).to match(/already inactive/)
        end
      end

      response '422', 'returns 422 when customer not found' do
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
