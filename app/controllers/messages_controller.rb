class MessagesController < ApplicationController
  before_action :authenticate_user!

  def new
    @tutor = Tutor.find_by(id: params[:tutor])
    
    conv_check_1 = Mailboxer::Conversation.participant(@tutor)
    conv_check_2 = Mailboxer::Conversation.participant(current_user)
    existing = (conv_check_1 & conv_check_2).first

    unless existing.nil? or !existing.is_participant?(current_user)
      redirect_to conversation_path(existing)
    end
    
    # should work - but error is thrown
    #existing_conversation = Mailboxer::Conversation.participant(current_user).where('conversations.id in (?)', Mailboxer::Conversation.participant(@tutor).collect(&:id))
    # existing_conversation = Mailboxer::Conversation.participant(current_user).participant(@tutor).first

    # if existing_conversation.present?
    #   redirect_to conversation_path(existing_conversation)
    # end
  end

  def create
    recipient = Tutor.find_by(id: params[:tutor])
    conversation = current_user.send_message(recipient, params[:message][:body], params[:message][:subject]).conversation
    flash[:success] = "Message has been sent!"
    redirect_to conversation_path(conversation)
  end
end