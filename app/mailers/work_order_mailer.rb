# frozen_string_literal: true

class WorkOrderMailer < ApplicationMailer
  STATUS_LABELS = {
    awaiting_approval: "Aguardando aprovação do orçamento",
    approved:          "Orçamento aprovado",
    in_progress:       "Serviço em execução",
    completed:         "Serviço concluído — veículo pronto para retirada",
    delivered:         "Veículo entregue",
    rejected:          "Orçamento recusado"
  }.freeze

  def status_changed(work_order, customer_email, approval_token: nil)
    @protocol    = work_order.protocol
    @status      = work_order.status.to_sym
    @status_label = STATUS_LABELS.fetch(@status, work_order.status.to_s)

    if @status == :awaiting_approval && approval_token.present?
      @approve_url = api_v1_webhooks_quote_approval_url(approval_token: approval_token)
      @reject_url  = api_v1_webhooks_quote_rejection_url(approval_token: approval_token)
    end

    mail(
      to: customer_email,
      subject: "Ordem de Serviço #{@protocol} — #{@status_label}"
    )
  end
end
