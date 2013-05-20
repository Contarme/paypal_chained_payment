class PaypalAdaptivePaymentException < StandardError

  attr_accessor :error, :message

  def initialize(error_obj)
     @error = error_obj
     @message = if @error.is_a? Array
      @error.collect(&:message).join(', ')
     else
       @error.message
     end
  end

  def to_s
    @message
  end


end