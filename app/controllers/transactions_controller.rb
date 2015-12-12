class TransactionsController < ApplicationController
  before_action :authenticate_student!

  # Braintree sandbox valid card numbers (for testing)
  # https://developers.braintreepayments.com/reference/general/testing/ruby#credit-card-numbers

  def new
    # gon.client_token = generate_client_token
  end

  def create
    # will be directed here from lesson accept or edit page as a student - amount will be determined from that
    # gon.client_token = generate_client_token

    @lesson = Lesson.find_by(id: params[:lesson_id])

    unless current_user.has_payment_info?
      @result = Braintree::Transaction.sale(
        amount: @lesson.braintree_payment,
        payment_method_nonce: params[:payment_method_nonce],
        customer: {
          first_name: current_user.firstname,
          last_name: current_user.lastname,
          email: current_user.email,
          phone: params[:phone]
        },
        options: {
          store_in_vault: true
        })
    else
      @result = Braintree::Transaction.sale(
        amount: @lesson.braintree_payment,
        payment_method_nonce: params[:payment_method_nonce])
    end
    # @result.transaction.payment_instrument_type is the type of payment that was used credit/paypal

    if @result.success?
      current_user.update(braintree_customer_id: @result.transaction.customer_details.id) unless current_user.has_payment_info?
      # Change state of lesson
      @lesson.update(status: "braintree")
      # some other validations ... in the db
      redirect_to root_url, notice: "Lesson has been booked"
    else
      flash[:alert] = "Something went wrong"
      gon.client_token = generate_client_token
      render :new
    end
  end

  private
  # def generate_client_token
  #   if current_user.has_payment_info?
  #     Braintree::ClientToken.generate(customer_id: current_user.braintree_customer_id)
  #   else
  #     Braintree::ClientToken.generate
  #   end
  # end
end
