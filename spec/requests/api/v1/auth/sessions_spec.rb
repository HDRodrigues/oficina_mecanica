# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Auth::Sessions', openapi_spec: 'v1/swagger.json', type: :request do
  let(:repository) { Persistence::Accounts::ActiveRecordUserRepository.new }
  let(:password) { "secret-1234" }

  path '/api/v1/auth/login' do
    post 'Login' do
      tags 'Authentication'
      consumes 'application/json'
      produces 'application/json'
      security []
      parameter name: :credentials, in: :body, schema: {
        type: :object,
        properties: {
          email: { type: :string },
          password: { type: :string }
        },
        required: %w[email password]
      }

      response '200', 'returns access and refresh tokens with valid credentials' do
        schema type: :object,
               properties: {
                 access_token: { type: :string },
                 refresh_token: { type: :string },
                 user: {
                   type: :object,
                   properties: {
                     id: { type: :integer },
                     email: { type: :string },
                     name: { type: :string }
                   }
                 }
               }
        before do
          Accounts::RegisterUser.new(user_repository: repository).call(
            email: "login@example.com",
            name: "Login User",
            password: password
          )
        end
        let(:credentials) { { email: "login@example.com", password: password } }
        run_test! do |response|
          body = response.parsed_body
          expect(body["access_token"]).to be_a(String)
          expect(body["refresh_token"]).to be_a(String)
          expect(body["user"]["email"]).to eq("login@example.com")
        end
      end

      response '401', 'returns 401 with wrong password' do
        schema '$ref' => '#/components/schemas/Error'
        before do
          Accounts::RegisterUser.new(user_repository: repository).call(
            email: "login@example.com",
            name: "Login User",
            password: password
          )
        end
        let(:credentials) { { email: "login@example.com", password: "wrong" } }
        run_test!
      end

      response '401', 'returns 401 with unknown email' do
        schema '$ref' => '#/components/schemas/Error'
        let(:credentials) { { email: "missing@example.com", password: password } }
        run_test!
      end

      response '401', 'returns 401 when user is inactive' do
        schema '$ref' => '#/components/schemas/Error'
        before do
          result = Accounts::RegisterUser.new(user_repository: repository).call(
            email: "login@example.com",
            name: "Login User",
            password: password
          )
          record = Persistence::Accounts::UserRecord.find(result.value.id)
          record.update!(status: :inactive)
        end
        let(:credentials) { { email: "login@example.com", password: password } }
        run_test!
      end
    end
  end
end
