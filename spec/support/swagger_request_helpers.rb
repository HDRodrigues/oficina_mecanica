# frozen_string_literal: true

module SwaggerRequestHelpers
  def auth_token(user: default_test_mechanic)
    "Bearer #{access_token_for(user)}"
  end

  def bearer_auth!
    parameter name: :Authorization, in: :header, type: :string, required: true, description: 'Bearer token'
    let(:Authorization) { auth_token }
  end
end

RSpec.configure do |config|
  config.include SwaggerRequestHelpers, type: :request
end
