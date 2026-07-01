# frozen_string_literal: true

module Shared
  # Orchestrator — calls every registered notifier in sequence.
  # Add new channels (SMS, push) by appending to the notifiers list.
  class WorkOrderNotifier
    def initialize(notifiers:)
      @notifiers = notifiers
    end

    def notify_status_changed(work_order)
      @notifiers.each { |n| n.notify_status_changed(work_order) }
    end
  end

  # Email channel — resolves customer e-mail and enqueues via WorkOrderMailer.
  # When the work order is awaiting approval, the customer's e-mail is the only
  # place the opaque approval_token is delivered — it is never exposed through
  # the API. quote_repository is optional so callers that never reach the
  # awaiting_approval transition can omit it.
  class WorkOrderEmailNotifier
    def initialize(customer_repository:, quote_repository: nil)
      @customer_repository = customer_repository
      @quote_repository = quote_repository
    end

    def notify_status_changed(work_order)
      customer = @customer_repository.find(work_order.customer_id)
      return unless customer&.email

      WorkOrderMailer
        .status_changed(work_order, customer.email, approval_token: approval_token_for(work_order))
        .deliver_later
    rescue StandardError => e
      Rails.logger.error("[WorkOrderEmailNotifier] Failed to enqueue email: #{e.message}")
    end

    private

    def approval_token_for(work_order)
      return nil unless work_order.status.to_sym == :awaiting_approval
      return nil unless @quote_repository

      @quote_repository.find_by_work_order_id(work_order.id)&.approval_token
    end
  end

  class NullNotifier
    def notify_status_changed(_work_order); end
  end
end
