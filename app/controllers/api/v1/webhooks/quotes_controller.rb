# frozen_string_literal: true

module Api
  module V1
    module Webhooks
      # Public entry point for external approval/rejection of a Quote (e.g. a link
      # sent by e-mail to the customer). Authentication is the possession of an
      # unguessable per-quote approval_token instead of a user JWT — the same
      # pattern already used by TrackingController for read-only OS tracking.
      #
      # Both actions delegate to the existing Quotes::ApproveQuote/RejectQuote use
      # cases, so the domain state machine and side effects (WO transition, stock
      # decrement) are identical to the authenticated staff endpoints.
      class QuotesController < Api::V1::ApplicationController
        skip_before_action :authenticate!

        def approve
          result = approve_quote_by_token.call(approval_token: params[:approval_token])

          if result.success?
            render json: Quotes::Presenters::Quote.call(result.value)
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        def reject
          result = reject_quote_by_token.call(approval_token: params[:approval_token])

          if result.success?
            render json: Quotes::Presenters::Quote.call(result.value)
          else
            render json: { error: result.error }, status: :unprocessable_entity
          end
        end

        private

        def repository
          @repository ||= Persistence::Quotes::ActiveRecordQuoteRepository.new
        end

        def work_order_repository
          @work_order_repository ||= Persistence::WorkOrders::ActiveRecordWorkOrderRepository.new
        end

        def inventory_item_repository
          @inventory_item_repository ||= Persistence::Inventory::ActiveRecordInventoryItemRepository.new
        end

        def customer_repository
          @customer_repository ||= Persistence::Registrations::ActiveRecordCustomerRepository.new
        end

        def approve_quote_by_token
          Quotes::ApproveQuoteByToken.new(
            quote_repository: repository,
            approve_quote: Quotes::ApproveQuote.new(
              quote_repository: repository,
              approve_work_order: WorkOrders::ApproveWorkOrder.new(
                work_order_repository: work_order_repository,
                notifier: notifier
              ),
              decrease_quantity: Inventory::DecreaseQuantity.new(inventory_item_repository: inventory_item_repository)
            )
          )
        end

        def reject_quote_by_token
          Quotes::RejectQuoteByToken.new(
            quote_repository: repository,
            reject_quote: Quotes::RejectQuote.new(
              quote_repository: repository,
              reject_work_order: WorkOrders::RejectWorkOrder.new(
                work_order_repository: work_order_repository,
                notifier: notifier
              )
            )
          )
        end

        def notifier
          @notifier ||= Shared::WorkOrderNotifier.new(
            notifiers: [
              Shared::WorkOrderEmailNotifier.new(
                customer_repository: customer_repository,
                quote_repository: repository
              )
            ]
          )
        end
      end
    end
  end
end
