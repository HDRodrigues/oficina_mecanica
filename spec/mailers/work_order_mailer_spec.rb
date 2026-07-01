# frozen_string_literal: true

require "rails_helper"

RSpec.describe WorkOrderMailer do
  let(:work_order) do
    instance_double(
      WorkOrders::WorkOrder,
      protocol: "ABC12345",
      status: instance_double(WorkOrders::ValueObjects::WorkOrderStatus, to_sym: :completed)
    )
  end
  let(:customer_email) { "cliente@example.com" }

  describe "#status_changed" do
    subject(:mail) { described_class.status_changed(work_order, customer_email) }

    it "sends to the customer email" do
      expect(mail.to).to eq([ customer_email ])
    end

    it "includes the protocol in the subject" do
      expect(mail.subject).to include("ABC12345")
    end

    it "includes the status label in the subject" do
      expect(mail.subject).to include("concluído")
    end

    it "includes the protocol in the body" do
      expect(mail.body.encoded).to include("ABC12345")
    end

    it "does not include approval links for non-approval statuses" do
      expect(mail.body.encoded).not_to include("/webhooks/quotes/")
    end
  end

  describe "#status_changed for a quote awaiting approval" do
    subject(:mail) do
      described_class.status_changed(work_order, customer_email, approval_token: "tok-abc-123")
    end

    let(:work_order) do
      instance_double(
        WorkOrders::WorkOrder,
        protocol: "ABC12345",
        status: instance_double(WorkOrders::ValueObjects::WorkOrderStatus, to_sym: :awaiting_approval)
      )
    end


    it "includes the approve and reject webhook links when a token is given" do
      text = mail.text_part.body.decoded

      expect(text).to include("/api/v1/webhooks/quotes/tok-abc-123/approve")
      expect(text).to include("/api/v1/webhooks/quotes/tok-abc-123/reject")
    end

    it "omits the links when no token is available" do
      mail = described_class.status_changed(work_order, customer_email)

      expect(mail.text_part.body.decoded).not_to include("/webhooks/quotes/")
    end
  end
end
