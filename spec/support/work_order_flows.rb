# frozen_string_literal: true

module WorkOrderFlows
  def customer_params
    {
      person_type: "individual",
      document: "52998224725",
      name: "John Doe",
      email: "john@example.com",
      phone: "+5511999999999",
      address: {
        zip_code: "01310100",
        street: "Av. Paulista",
        number: "1000",
        city: "São Paulo",
        state: "SP"
      }
    }
  end

  def vehicle_params
    {
      license_plate: "ABC1D23",
      make: "Honda",
      model: "Civic",
      year: 2020,
      color: "black"
    }
  end

  def service_params
    { name: "Oil Change", description: "Full oil change", base_price: 5000, estimated_duration_minutes: 30 }
  end

  def inventory_params
    { name: "Brake Pad", code: "BP-01", unit_price: 2000, quantity: 5 }
  end

  def create_customer(headers = nil)
    headers ||= { Authorization: auth_token }
    post "/api/v1/customers", params: customer_params, headers: headers, as: :json
    response.parsed_body["id"]
  end

  def create_vehicle(customer_id, headers = nil)
    headers ||= { Authorization: auth_token }
    post "/api/v1/vehicles", params: vehicle_params.merge(customer_id: customer_id), headers: headers, as: :json
    response.parsed_body["id"]
  end

  def create_service(headers = nil, **overrides)
    headers ||= { Authorization: auth_token }
    base = service_params
    post "/api/v1/services", params: base.merge(overrides), headers: headers, as: :json
    response.parsed_body["id"]
  end

  def create_inventory_item(headers = nil, **overrides)
    headers ||= { Authorization: auth_token }
    base = inventory_params
    post "/api/v1/inventory_items", params: base.merge(overrides), headers: headers, as: :json
    response.parsed_body["id"]
  end

  def create_work_order(customer_id, vehicle_id, headers = nil, **overrides)
    headers ||= { Authorization: auth_token }
    base = { customer_id: customer_id, vehicle_id: vehicle_id, problem_description: "Engine noise" }
    post "/api/v1/work_orders", params: base.merge(overrides), headers: headers, as: :json
    response.parsed_body["id"]
  end

  def setup_quote(headers = nil)
    headers ||= { Authorization: auth_token }
    customer_id = create_customer(headers)
    vehicle_id = create_vehicle(customer_id, headers)
    service_id = create_service(headers)
    wo_id = create_work_order(customer_id, vehicle_id, headers)
    patch "/api/v1/work_orders/#{wo_id}/assign", params: { mechanic_id: default_test_mechanic.id }, headers: headers, as: :json
    post "/api/v1/work_orders/#{wo_id}/line_items",
         params: { item_type: "service", reference_id: service_id, quantity: 2 },
         headers: headers, as: :json
    patch "/api/v1/work_orders/#{wo_id}/diagnose", headers: headers, as: :json
    wo_id
  end

  def setup_quote_with_part(headers = nil)
    headers ||= { Authorization: auth_token }
    customer_id = create_customer(headers)
    vehicle_id = create_vehicle(customer_id, headers)
    service_id = create_service(headers)
    item_id = create_inventory_item(headers)
    wo_id = create_work_order(customer_id, vehicle_id, headers)
    patch "/api/v1/work_orders/#{wo_id}/assign", params: { mechanic_id: default_test_mechanic.id }, headers: headers, as: :json
    post "/api/v1/work_orders/#{wo_id}/line_items",
         params: { item_type: "service", reference_id: service_id, quantity: 1 },
         headers: headers, as: :json
    post "/api/v1/work_orders/#{wo_id}/line_items",
         params: { item_type: "part", reference_id: item_id, quantity: 3 },
         headers: headers, as: :json
    patch "/api/v1/work_orders/#{wo_id}/diagnose", headers: headers, as: :json
    quote_id = Persistence::Quotes::QuoteRecord.find_by(work_order_id: wo_id).id
    patch "/api/v1/quotes/#{quote_id}/send_to_customer", headers: headers, as: :json
    { wo_id: wo_id, quote_id: quote_id, item_id: item_id }
  end

  def setup_sent_quote_with_part(headers = nil)
    headers ||= { Authorization: auth_token }
    item_id = create_inventory_item(headers)
    customer_id = create_customer(headers)
    vehicle_id = create_vehicle(customer_id, headers)
    wo_id = create_work_order(customer_id, vehicle_id, headers)
    patch "/api/v1/work_orders/#{wo_id}/assign", params: { mechanic_id: default_test_mechanic.id }, headers: headers, as: :json
    post "/api/v1/work_orders/#{wo_id}/line_items",
         params: { item_type: "part", reference_id: item_id, quantity: 2 },
         headers: headers, as: :json
    patch "/api/v1/work_orders/#{wo_id}/diagnose", headers: headers, as: :json
    quote_id = Persistence::Quotes::QuoteRecord.find_by(work_order_id: wo_id).id
    patch "/api/v1/quotes/#{quote_id}/send_to_customer", headers: headers, as: :json
    { wo_id: wo_id, quote_id: quote_id, item_id: item_id }
  end

  def setup_approved_work_order(headers = nil)
    headers ||= { Authorization: auth_token }
    ids = setup_quote_with_part(headers)
    patch "/api/v1/quotes/#{ids[:quote_id]}/approve", headers: headers, as: :json
    ids
  end
end

RSpec.configure do |config|
  config.include WorkOrderFlows, type: :request
end
