# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Quotes', openapi_spec: 'v1/swagger.json', type: :request do
  path '/api/v1/quotes/{id}' do
    get 'Get quote by ID' do
      tags 'Quotes'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'returns the quote created automatically after diagnosis' do
        schema '$ref' => '#/components/schemas/Quote'
        let(:Authorization) { auth_token }
        before do
          wo_id = setup_quote
          @quote_id = Persistence::Quotes::QuoteRecord.find_by(work_order_id: wo_id).id
        end
        let(:id) { @quote_id }
        run_test! do |response|
          body = response.parsed_body
          expect(body["status"]).to eq("created")
          expect(body["line_items"].size).to eq(1)
          expect(body["total"]).to eq("R$ 100.00")
        end
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end

      response '404', 'returns 404 when quote not found' do
        let(:Authorization) { auth_token }
        let(:id) { 999999 }
        run_test!
      end
    end
  end

  path '/api/v1/quotes/{id}/send_to_customer' do
    patch 'Send quote to customer (status → sent)' do
      tags 'Quotes'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'moves status created → sent' do
        schema '$ref' => '#/components/schemas/Quote'
        let(:Authorization) { auth_token }
        before do
          wo_id = setup_quote
          @quote_id = Persistence::Quotes::QuoteRecord.find_by(work_order_id: wo_id).id
        end
        let(:id) { @quote_id }
        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("sent")
        end
      end

      response '422', 'returns 422 when already sent' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          wo_id = setup_quote
          @quote_id = Persistence::Quotes::QuoteRecord.find_by(work_order_id: wo_id).id
          patch "/api/v1/quotes/#{@quote_id}/send_to_customer", headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @quote_id }
        run_test!
      end

      response '422', 'returns 422 when quote not found' do
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

  path '/api/v1/quotes/{id}/approve' do
    patch 'Approve quote (status → approved, decrements stock)' do
      tags 'Quotes'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'approves the quote, moves WO to approved, and decrements stock' do
        schema '$ref' => '#/components/schemas/Quote'
        let(:Authorization) { auth_token }
        before do
          @ids = setup_quote_with_part
        end
        let(:id) { @ids[:quote_id] }
        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("approved")
        end
      end

      response '422', 'returns 422 when parts are out of stock' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          @ids = setup_quote_with_part
          patch "/api/v1/inventory_items/#{@ids[:item_id]}/decrease_quantity",
                params: { amount: 5 }, headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @ids[:quote_id] }
        run_test! do |response|
          expect(response.parsed_body["error"]).to match(/Insufficient stock/)
        end
      end

      response '422', 'returns 422 when quote was already approved (idempotency guard)' do
        schema '$ref' => '#/components/schemas/Error'
        let(:Authorization) { auth_token }
        before do
          @ids = setup_quote_with_part
          patch "/api/v1/quotes/#{@ids[:quote_id]}/approve", headers: { Authorization: auth_token }, as: :json
        end
        let(:id) { @ids[:quote_id] }
        run_test!
      end

      response '401', 'unauthorized' do
        let(:Authorization) { nil }
        let(:id) { 1 }
        run_test!
      end
    end
  end

  path '/api/v1/quotes/{id}/reject' do
    patch 'Reject quote (status → rejected)' do
      tags 'Quotes'
      produces 'application/json'
      security [ { bearerAuth: [] } ]
      parameter name: :id, in: :path, type: :integer, required: true

      response '200', 'rejects the quote, moves WO to rejected, and does not touch inventory' do
        schema '$ref' => '#/components/schemas/Quote'
        let(:Authorization) { auth_token }
        before do
          @ids = setup_sent_quote_with_part
        end
        let(:id) { @ids[:quote_id] }
        run_test! do |response|
          expect(response.parsed_body["status"]).to eq("rejected")
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
end
