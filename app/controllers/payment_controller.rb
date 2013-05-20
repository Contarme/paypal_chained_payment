class PaymentController < ApplicationController

  def create
    cancel_url = params.delete(:cancel_url)
    begin
      pay_key = PaypalAdaptivePayments.initialize_chained_payment!(params.delete(:price).to_i, params.delete(:receiver_email), params.delete(:success_url), cancel_url, params)
    rescue StandardError => e
      Airbrake.notify(e)
      redirect_to params.delete(:error_url) || cancel_url
      return
    end
    redirect_to Rails.configuration.paypal_initiate_payment_url + pay_key
  end


end
