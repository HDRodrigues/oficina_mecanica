# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::InventoryItems', openapi_spec: 'v1/swagger.json', type: :request do
  let(:valid_params) do
    {
      name: "Brake Pad",
      description: "Ceramic brake pad set",
      code: "BP-001",
      unit_price: 5000,
      quantity: 10,
      minimum_quantity: 2
    }
  end

  path '/api/v1/inventory_items' do
    get 'List inventory items' do
      tags 'Inventory'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      response '200', 'returns all items' do
        schema type: :array, items: { '$ref' => '#/components/schemas/InventoryItem' }
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          post "/api/v1/inventory_items", params: valid_params.merge(code: "OF-001", name: "Oil Filter"), headers: { Authorization: auth_token }, as: :json
        end
        run_test! do |response|
          expect(response.parsed_body.size).to eq(2)
        end
      end

      response '200', 'returns empty array when no items' do
        schema type: :array, items: { '$ref' => '#/components/schemas/InventoryItem' }
        let(:Authorization) { auth_token }
        run_test! do |response|
          expect(response.parsed_body).to eq([])
        end
      end

      response '200', 'shows below_minimum flag when quantity is below minimum' do
        schema type: :array, items: { '$ref' => '#/components/schemas/InventoryItem' }
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items",
               params: valid_params.merge(quantity: 1, minimum_quantity: 5),
               headers: { Authorization: auth_token }, as: :json
        end
        run_test! do |response|
          expect(response.parsed_body.first["below_minimum"]).to be true
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end

    post 'Create inventory item' do
      tags 'Inventory'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :inventory_item, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          code: { type: :string },
          unit_price: { type: :integer, description: 'Price in cents' },
          quantity: { type: :integer },
          minimum_quantity: { type: :integer }
        },
        required: %w[name code unit_price]
      }

      response '201', 'creates an item and returns 201 with identity fields' do
        schema '$ref' => '#/components/schemas/InventoryItem'
        let(:Authorization) { auth_token }
        let(:inventory_item) { valid_params }
        run_test! do |response|
          body = response.parsed_body
          expect(body["name"]).to eq("Brake Pad")
          expect(body["code"]).to eq("BP-001")
        end
      end

      response '201', 'returns price and quantity fields in the response' do
        schema '$ref' => '#/components/schemas/InventoryItem'
        let(:Authorization) { auth_token }
        let(:inventory_item) { valid_params }
        run_test! do |response|
          body = response.parsed_body
          expect(body["unit_price"]).to eq("R$ 50.00")
          expect(body["quantity"]).to eq(10)
          expect(body["minimum_quantity"]).to eq(2)
          expect(body["below_minimum"]).to be false
          expect(body["active"]).to be true
        end
      end

      response '201', 'defaults quantity and minimum_quantity to zero when omitted' do
        schema '$ref' => '#/components/schemas/InventoryItem'
        let(:Authorization) { auth_token }
        let(:inventory_item) { valid_params.slice(:name, :code, :unit_price) }
        run_test! do |response|
          body = response.parsed_body
          expect(body["quantity"]).to eq(0)
          expect(body["minimum_quantity"]).to eq(0)
        end
      end

      response '422', 'returns 422 with duplicate code' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:inventory_item) { valid_params }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
        end
        run_test! do |response|
          expect(response.parsed_body["error"]).to eq("Inventory item code already registered")
        end
      end

      response '422', 'returns 422 with negative unit_price' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:inventory_item) { valid_params.merge(unit_price: -100) }
        run_test!
      end

      response '422', 'returns 422 with negative quantity' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:inventory_item) { valid_params.merge(quantity: -1) }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:inventory_item) { valid_params }
        run_test!
      end
    end
  end

  path '/api/v1/inventory_items/{id}' do
    get 'Get inventory item by ID' do
      tags 'Inventory'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'returns the item' do
        schema '$ref' => '#/components/schemas/InventoryItem'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        run_test! do |response|
          expect(response.parsed_body["code"]).to eq("BP-001")
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end

      response '404', 'returns 404 when item not found' do
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        run_test!
      end
    end

    patch 'Update inventory item' do
      tags 'Inventory'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :inventory_item, in: :body, schema: {
        type: :object,
        properties: {
          name: { type: :string },
          description: { type: :string },
          unit_price: { type: :integer, description: 'Price in cents' },
          minimum_quantity: { type: :integer }
        }
      }

      response '200', 'updates item name' do
        schema '$ref' => '#/components/schemas/InventoryItem'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        let(:inventory_item) { { name: "Premium Brake Pad" } }
        run_test! do |response|
          expect(response.parsed_body["name"]).to eq("Premium Brake Pad")
        end
      end

      response '200', 'updates item unit_price' do
        schema '$ref' => '#/components/schemas/InventoryItem'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        let(:inventory_item) { { unit_price: 8000 } }
        run_test! do |response|
          expect(response.parsed_body["unit_price"]).to eq("R$ 80.00")
        end
      end

      response '422', 'returns 422 when item not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        let(:inventory_item) { { name: "Test" } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        let(:inventory_item) { { name: "Test" } }
        run_test!
      end
    end

    delete 'Deactivate inventory item' do
      tags 'Inventory'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'deactivates the item' do
        schema '$ref' => '#/components/schemas/InventoryItem'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        run_test! do |response|
          expect(response.parsed_body["active"]).to be false
        end
      end

      response '422', 'returns 422 when already inactive' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
          delete "/api/v1/inventory_items/#{@item_id}", headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @item_id }
        run_test! do |response|
          expect(response.parsed_body["error"]).to match(/already inactive/)
        end
      end

      response '422', 'returns 422 when item not found' do
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

  path '/api/v1/inventory_items/{id}/add_quantity' do
    patch 'Add stock quantity' do
      tags 'Inventory'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :integer }
        },
        required: %w[amount]
      }

      response '200', 'increments quantity and returns the full item' do
        schema '$ref' => '#/components/schemas/InventoryItem'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        let(:body) { { amount: 5 } }
        run_test! do |response|
          body = response.parsed_body
          expect(body["quantity"]).to eq(15)
          expect(body["code"]).to eq("BP-001")
        end
      end

      response '422', 'returns 422 when amount is zero' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        let(:body) { { amount: 0 } }
        run_test!
      end

      response '422', 'returns 422 when amount is negative' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        let(:body) { { amount: -5 } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        let(:body) { { amount: 5 } }
        run_test!
      end
    end
  end

  path '/api/v1/inventory_items/{id}/decrease_quantity' do
    patch 'Decrease stock quantity' do
      tags 'Inventory'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          amount: { type: :integer }
        },
        required: %w[amount]
      }

      response '200', 'decrements quantity and returns the full item' do
        schema '$ref' => '#/components/schemas/InventoryItem'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        let(:body) { { amount: 3 } }
        run_test! do |response|
          body = response.parsed_body
          expect(body["quantity"]).to eq(7)
          expect(body["code"]).to eq("BP-001")
        end
      end

      response '422', 'returns 422 when stock would go below zero' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        let(:body) { { amount: 50 } }
        run_test! do |response|
          expect(response.parsed_body["error"]).to match(/Insufficient stock/)
        end
      end

      response '422', 'returns 422 when amount is zero' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          post "/api/v1/inventory_items", params: valid_params, headers: { Authorization: auth_token }, as: :json
          @item_id = response.parsed_body["id"]
        end
        let(:id) { @item_id }
        let(:body) { { amount: 0 } }
        run_test!
      end

      response '422', 'returns 422 when item not found' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        let(:body) { { amount: 5 } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        let(:body) { { amount: 5 } }
        run_test!
      end
    end
  end
end
