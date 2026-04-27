# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Auth::Tokens', openapi_spec: 'v1/swagger.json', type: :request do
  path '/api/v1/auth/refresh' do
    post 'Refresh access token' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security []
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          refresh_token: { type: :string }
        },
        required: %w[refresh_token]
      }

      response '200', 'issues a new access token from a valid refresh token' do
        schema type: :object,
               properties: {
                 access_token: { type: :string }
               }
        let(:body) { { refresh_token: refresh_token_for(default_test_user) } }
        run_test! do |response|
          expect(response.parsed_body["access_token"]).to be_a(String)
        end
      end

      response '401', 'returns 401 when an access token is sent as refresh' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { refresh_token: access_token_for(default_test_user) } }
        run_test!
      end

      response '401', 'returns 401 when refresh token is malformed' do
        schema '$ref' => '#/components/schemas/Error'
        let(:body) { { refresh_token: "garbage" } }
        run_test!
      end
    end
  end
end
