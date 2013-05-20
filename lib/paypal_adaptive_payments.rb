class PaypalAdaptivePayments

  # returns a pre approval key using which the user is redirected to the paypal site
  def self.setup_preapproved_payment!(max_amount, return_url, cancel_url)
    api = PayPal::SDK::AdaptivePayments::API.new

    pre_approval = api.build_preapproval({
                                             :cancelUrl => cancel_url,
                                             :currencyCode => "USD",
                                             :maxAmountPerPayment => max_amount,
                                             :returnUrl => return_url,
                                             :startingDate => Time.now.to_s})

    pre_approval_response = api.preapproval(pre_approval)

    raise PaypalAdaptivePaymentException.new(pre_approval_response.error) if pre_approval_response.responseEnvelope.ack.to_s != "Success"
    pre_approval_response.preapprovalKey.to_s

  end

  def self.preapproval_valid_for_amount?(preapproval_key, amount)

    preapproval_details_response = get_preapproval_details(preapproval_key)

    if preapproval_details_response && preapproval_details_response.responseEnvelope.ack.to_s == "Success"
      return preapproval_details_response.approved && preapproval_details_response.maxAmountPerPayment >= amount && preapproval_details_response.status == "ACTIVE"
    end
    false
  end

  def self.get_preapproval_details(preapproval_key)
    api = PayPal::SDK::AdaptivePayments::API.new

    preapproval_details = api.build_preapproval_details({ :preapprovalKey => preapproval_key })

    preapproval_details_response = api.preapproval_details(preapproval_details)

    if preapproval_details_response.responseEnvelope.ack.to_s == "Success"
       return preapproval_details_response
    end
    nil
  end

  def self.deposit!(preapproval_key, amount, return_url, cancel_url)
    api = PayPal::SDK::AdaptivePayments::API.new
    pay = api.build_pay({
                            :actionType => "PAY",
                            :currencyCode => "USD",
                            :feesPayer => "EACHRECEIVER",
                            :returnUrl => return_url,
                            :cancelUrl => cancel_url,
                            :receiverList => {
                                :receiver => [{
                                                  :amount => amount,
                                                  :email => Rails.configuration.paypal_merchant_account_email
                                              },
                                ]},
                            :preapprovalKey => preapproval_key
                        })

    pay_response = api.pay(pay)

    raise PaypalAdaptivePaymentException.new(pay_response.error) if pay_response.responseEnvelope.ack.to_s != "Success"
    pay_response.payKey.to_s
  end

  def self.withdraw!(amount, receiver_email, return_url, cancel_url)
    api = PayPal::SDK::AdaptivePayments::API.new
    pay = api.build_pay({
                            :actionType => "PAY",
                            :currencyCode => "USD",
                            :feesPayer => "EACHRECEIVER",
                            :returnUrl => return_url,
                            :cancelUrl => cancel_url,
                            :receiverList => {
                                :receiver => [{
                                                  :amount => amount,
                                                  :email => receiver_email
                                              },
                                ]},
                            :sender => {
                                :email => Rails.configuration.paypal_merchant_account_email}
                        })

    pay_response = api.pay(pay)

    raise PaypalAdaptivePaymentException.new(pay_response.error) if pay_response.responseEnvelope.ack.to_s != "Success"
    pay_response.payKey.to_s
  end



  # return a pay key, using which secondary account is paid later
  def self.initialize_chained_payment!(amount, secondary_receiver_email, return_url, cancel_url, params)
    api = PayPal::SDK::AdaptivePayments::API.new
    secondary_receiver_amount = (1 - (Rails.configuration.commission_rate/100))*amount
    pay = api.build_pay({
                            :actionType => "PAY_PRIMARY",
                            :currencyCode => "USD",
                            :feesPayer => "PRIMARYRECEIVER",
                            :returnUrl => return_url,
                            :cancelUrl => cancel_url,
                            :receiverList => {
                                :receiver => [{
                                                  :amount => amount,
                                                  :email => Rails.configuration.paypal_merchant_account_email,
                                                  :primary => true},
                                              {
                                                  :amount => secondary_receiver_amount,
                                                  :email => secondary_receiver_email,
                                                  :primary => false}
                                ]}
                        }.merge(params))

    pay_response = api.pay(pay)

    raise PaypalAdaptivePaymentException.new(pay_response.error) if pay_response.responseEnvelope.ack.to_s != "Success"
    pay_response.payKey.to_s
  end

  # completes the delayed chained adaptive method, sending through the money to the secondary receiver, returns the transaction id
  def self.complete_chained_payment!(pay_key)
    api = PayPal::SDK::AdaptivePayments::API.new

    execute_payment = api.build_execute_payment({
                                                    :payKey => pay_key})

    execute_payment_response = api.execute_payment(execute_payment)

    raise PaypalAdaptivePaymentException.new(execute_payment_response.error) if execute_payment_response.responseEnvelope.ack.to_s != "Success"
    execute_payment_response.responseEnvelope.correlationId.to_s
  end


  def self.refund_payment!(pay_key)
    api = PayPal::SDK::AdaptivePayments::API.new

    refund = api.build_refund({:payKey => pay_key })

    refund_response = api.refund(refund)

    raise PaypalAdaptivePaymentException.new(refund_response.error) if refund_response.responseEnvelope.ack.to_s != "Success"
    refund_response.responseEnvelope.correlationId.to_s
  end

end