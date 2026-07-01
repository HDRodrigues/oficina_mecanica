# frozen_string_literal: true

require_relative "../shared/repository"

module Quotes
  module QuoteRepository
    include Shared::Repository

    def find_by_work_order_id(work_order_id)
      raise NotImplementedError, "#{self.class}#find_by_work_order_id not implemented"
    end

    def find_by_approval_token(approval_token)
      raise NotImplementedError, "#{self.class}#find_by_approval_token not implemented"
    end
  end
end
