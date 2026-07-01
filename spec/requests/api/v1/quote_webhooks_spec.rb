# frozen_string_literal: true

require 'swagger_helper'

RSpec.describe 'Api::V1::Webhooks::Quotes', openapi_spec: 'v1/swagger.json', type: :request do
  path '/api/v1/webhooks/quotes/{approval_token}/approve' do
    patch 'Approve quote via external token (public endpoint, status → approved, decrements stock)' do
      tags 'Quotes Webhooks'
      produces 'application/json'
      security []
      description 'Public endpoint (no JWT): authenticates the caller by possession of the ' \
                   'unguessable approval_token generated per quote, instead of a user session.'
      parameter name: :approval_token, in: :path, type: :string, required: true

      response '200', 'quote approved' do
        schema '$ref' => '#/components/schemas/Quote'
        run_test!
      end

      response '422', 'unprocessable entity (unknown token, wrong state, or insufficient stock)' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end

  path '/api/v1/webhooks/quotes/{approval_token}/reject' do
    patch 'Reject quote via external token (public endpoint, status → rejected)' do
      tags 'Quotes Webhooks'
      produces 'application/json'
      security []
      description 'Public endpoint (no JWT): authenticates the caller by possession of the ' \
                   'unguessable approval_token generated per quote, instead of a user session.'
      parameter name: :approval_token, in: :path, type: :string, required: true

      response '200', 'quote rejected' do
        schema '$ref' => '#/components/schemas/Quote'
        run_test!
      end

      response '422', 'unprocessable entity (unknown token or wrong state)' do
        schema '$ref' => '#/components/schemas/Error'
        run_test!
      end
    end
  end
end
