# frozen_string_literal: true

require_relative "../shared/result"
require_relative "../shared/use_case"

module Quotes
  # Resolves the quote from an opaque approval_token (webhook-style entry point,
  # no user session) and delegates to ApproveQuote so the same state machine and
  # side effects (WO approval, stock decrement) apply regardless of caller.
  class ApproveQuoteByToken < Shared::UseCase
    def initialize(quote_repository:, approve_quote:)
      @repository = quote_repository
      @approve_quote = approve_quote
    end

    private

    def perform(approval_token:)
      quote = @repository.find_by_approval_token(approval_token)
      return Shared::Result.failure("Quote not found") unless quote

      @approve_quote.call(id: quote.id)
    end
  end
end
