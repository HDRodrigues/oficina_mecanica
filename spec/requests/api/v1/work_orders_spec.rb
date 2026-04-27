# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::WorkOrders', openapi_spec: 'v1/swagger.json', type: :request do
  path '/api/v1/work_orders' do
    get 'List work orders' do
      tags 'Work Orders'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      response '200', 'successful' do
        schema type: :object,
               properties: {
                 data: { type: :array, items: { '$ref' => '#/components/schemas/WorkOrder' } },
                 pagination: {
                   type: :object,
                   properties: {
                     page: { type: :integer },
                     per_page: { type: :integer },
                     total: { type: :integer },
                     total_pages: { type: :integer }
                   }
                 }
               }
        let(:Authorization) { auth_token }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        run_test!
      end
    end

    post 'Create work order' do
      tags 'Work Orders'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :work_order, in: :body, schema: {
        type: :object,
        properties: {
          customer_id: { type: :integer },
          vehicle_id: { type: :integer },
          problem_description: { type: :string }
        },
        required: %w[customer_id vehicle_id problem_description]
      }

      response '201', 'creates a work order with valid references' do
        schema '$ref' => '#/components/schemas/WorkOrder'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
        end
        let(:work_order) { { customer_id: @customer_id, vehicle_id: @vehicle_id, problem_description: "Engine noise" } }
        run_test! do |response|
          body = response.parsed_body
          expect(body["status"]).to eq("received")
          expect(body["problem_description"]).to eq("Engine noise")
          expect(body["line_items"]).to eq([])
        end
      end

      response '422', 'returns 422 when customer does not exist' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          @vehicle_id = create_vehicle(create_customer)
        end
        let(:work_order) { { customer_id: 999_999, vehicle_id: @vehicle_id, problem_description: "x" } }
        run_test! do |response|
          expect(response.parsed_body["error"]).to eq("Customer not found")
        end
      end

      response '422', 'returns 422 when vehicle does not exist' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
        end
        let(:work_order) { { customer_id: @customer_id, vehicle_id: 999_999, problem_description: "x" } }
        run_test! do |response|
          expect(response.parsed_body["error"]).to eq("Vehicle not found")
        end
      end

      response '422', 'returns 422 when problem_description is missing' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
        end
        let(:work_order) { { customer_id: @customer_id, vehicle_id: @vehicle_id } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:work_order) { { customer_id: 1, vehicle_id: 1, problem_description: "x" } }
        run_test!
      end
    end
  end

  path '/api/v1/work_orders/{id}' do
    get 'Get work order by ID' do
      tags 'Work Orders'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'returns the work order' do
        schema '$ref' => '#/components/schemas/WorkOrder'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @wo_id = create_work_order(@customer_id, @vehicle_id)
        end
        let(:id) { @wo_id }
        run_test! do |response|
          expect(response.parsed_body["id"]).to eq(@wo_id)
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end

      response '404', 'returns 404 when work order not found' do
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        run_test!
      end
    end
  end

  path '/api/v1/work_orders/{id}/assign' do
    patch 'Assign mechanic to work order' do
      tags 'Work Orders'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          mechanic_id: { type: :integer }
        },
        required: %w[mechanic_id]
      }

      response '200', 'mechanic assigned, status → diagnosing' do
        schema '$ref' => '#/components/schemas/WorkOrder'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @wo_id = create_work_order(@customer_id, @vehicle_id)
        end
        let(:id) { @wo_id }
        let(:body) { { mechanic_id: default_test_mechanic.id } }
        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("diagnosing")
        end
      end

      response '422', 'unprocessable entity' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        let(:body) { { mechanic_id: default_test_mechanic.id } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        let(:body) { { mechanic_id: 1 } }
        run_test!
      end
    end
  end

  path '/api/v1/work_orders/{id}/line_items' do
    post 'Add line item to work order' do
      tags 'Work Orders'
      consumes 'application/json'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          item_type: { type: :string, enum: %w[service part] },
          reference_id: { type: :integer },
          quantity: { type: :integer }
        },
        required: %w[item_type reference_id quantity]
      }

      response '201', 'adds a service line item with current price as snapshot' do
        schema '$ref' => '#/components/schemas/WorkOrder'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @wo_id = create_work_order(@customer_id, @vehicle_id)
          @service_id = create_service
          patch "/api/v1/work_orders/#{@wo_id}/assign", params: { mechanic_id: default_test_mechanic.id }, headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @wo_id }
        let(:body) { { item_type: "service", reference_id: @service_id, quantity: 1 } }
        run_test! do |response|
          item = response.parsed_body["line_items"].last
          expect(item["price_snapshot"]).to eq("R$ 50.00")
        end
      end

      response '201', 'adds a part line item from inventory' do
        schema '$ref' => '#/components/schemas/WorkOrder'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @wo_id = create_work_order(@customer_id, @vehicle_id)
          @item_id = create_inventory_item
          patch "/api/v1/work_orders/#{@wo_id}/assign", params: { mechanic_id: default_test_mechanic.id }, headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @wo_id }
        let(:body) { { item_type: "part", reference_id: @item_id, quantity: 2 } }
        run_test!
      end

      response '201', 'preserves price snapshot after catalog price change' do
        schema '$ref' => '#/components/schemas/WorkOrder'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @wo_id = create_work_order(@customer_id, @vehicle_id)
          @service_id = create_service
          patch "/api/v1/work_orders/#{@wo_id}/assign", params: { mechanic_id: default_test_mechanic.id }, headers: { Authorization: auth_token }, as: :json
          post "/api/v1/work_orders/#{@wo_id}/line_items",
               params: { item_type: "service", reference_id: @service_id, quantity: 1 },
               headers: { Authorization: auth_token }, as: :json
          patch "/api/v1/services/#{@service_id}", params: { base_price: 9000 }, headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @wo_id }
        let(:body) { { item_type: "service", reference_id: @service_id, quantity: 1 } }
        run_test! do |response|
          item = response.parsed_body["line_items"].last
          expect(item["price_snapshot"]).to eq("R$ 50.00")
        end
      end

      response '422', 'returns 422 when work order is still in received' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @wo_id = create_work_order(@customer_id, @vehicle_id)
          @service_id = create_service
        end
        let(:id) { @wo_id }
        let(:body) { { item_type: "service", reference_id: @service_id, quantity: 1 } }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        let(:body) { { item_type: "service", reference_id: 1, quantity: 1 } }
        run_test!
      end
    end
  end

  path '/api/v1/work_orders/{id}/diagnose' do
    patch 'Diagnose work order (generates quote)' do
      tags 'Work Orders'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'moves to awaiting_approval after items are added' do
        schema '$ref' => '#/components/schemas/WorkOrder'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @wo_id = create_work_order(@customer_id, @vehicle_id)
          @service_id = create_service
          patch "/api/v1/work_orders/#{@wo_id}/assign", params: { mechanic_id: default_test_mechanic.id }, headers: { Authorization: auth_token }, as: :json
          post "/api/v1/work_orders/#{@wo_id}/line_items",
               params: { item_type: "service", reference_id: @service_id, quantity: 1 },
               headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @wo_id }
        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("awaiting_approval")
        end
      end

      response '422', 'returns 422 when there are no line items' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @wo_id = create_work_order(@customer_id, @vehicle_id)
          patch "/api/v1/work_orders/#{@wo_id}/assign", params: { mechanic_id: default_test_mechanic.id }, headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @wo_id }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end
    end
  end

  path '/api/v1/work_orders/ready_to_execute' do
    get 'List work orders ready for execution' do
      tags 'Work Orders'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      response '200', 'returns only approved work orders, oldest approval first' do
        schema type: :array, items: { '$ref' => '#/components/schemas/WorkOrder' }
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @service_id = create_service
          @first_id = create_approved_wo(@customer_id, @vehicle_id, @service_id)
          sleep 0.01
          @second_id = create_approved_wo(@customer_id, @vehicle_id, @service_id)
          create_work_order(@customer_id, @vehicle_id)
        end
        run_test! do |response|
          body = response.parsed_body
          expect(body.size).to eq(2)
          expect(body.map { |wo| wo["status"] }).to all(eq("approved"))
          expect(body.map { |wo| wo["id"] }).to eq([@first_id, @second_id])
        end
      end

      response '200', 'returns an empty array when there are no approved WOs' do
        schema type: :array, items: { '$ref' => '#/components/schemas/WorkOrder' }
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

  path '/api/v1/work_orders/{id}/execute' do
    patch 'Execute work order' do
      tags 'Work Orders'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'transitions approved → in_progress' do
        schema '$ref' => '#/components/schemas/WorkOrder'
        let(:Authorization) { auth_token }
        before do
          @ids = setup_approved_work_order
        end
        let(:id) { @ids[:wo_id] }
        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("in_progress")
        end
      end

      response '422', 'returns 422 when work order is not approved' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          @customer_id = create_customer
          @vehicle_id = create_vehicle(@customer_id)
          @wo_id = create_work_order(@customer_id, @vehicle_id)
        end
        let(:id) { @wo_id }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end
    end
  end

  path '/api/v1/work_orders/{id}/complete' do
    patch 'Complete work order' do
      tags 'Work Orders'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'transitions in_progress → completed' do
        schema '$ref' => '#/components/schemas/WorkOrder'
        let(:Authorization) { auth_token }
        before do
          @ids = setup_approved_work_order
          patch "/api/v1/work_orders/#{@ids[:wo_id]}/execute", headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @ids[:wo_id] }
        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("completed")
        end
      end

      response '422', 'unprocessable entity' do
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

  private

  def create_approved_wo(customer_id, vehicle_id, service_id)
    headers = { Authorization: auth_token }
    wo_id = create_work_order(customer_id, vehicle_id, headers)
    patch "/api/v1/work_orders/#{wo_id}/assign", params: { mechanic_id: default_test_mechanic.id }, headers: headers, as: :json
    post "/api/v1/work_orders/#{wo_id}/line_items",
         params: { item_type: "service", reference_id: service_id, quantity: 1 }, headers: headers, as: :json
    patch "/api/v1/work_orders/#{wo_id}/diagnose", headers: headers, as: :json
    quote_id = Persistence::Quotes::QuoteRecord.find_by(work_order_id: wo_id).id
    patch "/api/v1/quotes/#{quote_id}/send_to_customer", headers: headers, as: :json
    patch "/api/v1/quotes/#{quote_id}/approve", headers: headers, as: :json
    wo_id
  end
end
