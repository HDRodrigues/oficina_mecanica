# frozen_string_literal: true

require "rails_helper"

RSpec.describe Quotes::ApproveQuoteByToken do
  let(:quote) { Quotes::Quote.new(id: 1, work_order_id: 77, status: :sent, approval_token: "tok-123") }

  let(:quote_repository) do
    double("QuoteRepository").tap do |repo|
      allow(repo).to receive(:find_by_approval_token).with("tok-123").and_return(quote)
      allow(repo).to receive(:find_by_approval_token).with("unknown").and_return(nil)
    end
  end

  let(:approve_quote) do
    double("ApproveQuote").tap do |uc|
      allow(uc).to receive(:call).with(id: 1).and_return(Shared::Result.success(quote))
    end
  end

  let(:use_case) do
    described_class.new(quote_repository: quote_repository, approve_quote: approve_quote)
  end

  describe "#call" do
    it "resolves the quote by token and delegates to ApproveQuote" do
      result = use_case.call(approval_token: "tok-123")

      expect(result).to be_success
      expect(approve_quote).to have_received(:call).with(id: 1)
    end

    it "returns failure without delegating when the token is unknown" do
      result = use_case.call(approval_token: "unknown")

      expect(result).to be_failure
      expect(result.error).to eq("Quote not found")
      expect(approve_quote).not_to have_received(:call)
    end

    it "propagates a failure from ApproveQuote" do
      allow(approve_quote).to receive(:call).and_return(Shared::Result.failure("Insufficient stock"))

      result = use_case.call(approval_token: "tok-123")

      expect(result).to be_failure
      expect(result.error).to eq("Insufficient stock")
    end
  end
end
