# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Admin::Metrics', openapi_spec: 'v1/swagger.json', type: :request do
  path '/api/v1/admin/metrics' do
    get 'Get admin metrics' do
      tags 'Admin'
      produces 'application/json'
      security [ { bearerAuth: [] } ]

      response '200', 'returns nil average and zero count when there are no completed work orders' do
        schema type: :object,
               properties: {
                 average_execution_time_minutes: { type: :number, nullable: true },
                 completed_count: { type: :integer }
               }
        let(:Authorization) { auth_token }
        run_test! do |response|
          body = response.parsed_body
          expect(body["average_execution_time_minutes"]).to be_nil
          expect(body["completed_count"]).to eq(0)
        end
      end

      response '401', 'requires authentication' do
        let(:Authorization) { nil }
        run_test!
      end
    end
  end
end
