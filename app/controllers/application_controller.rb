class ApplicationController < ActionController::Base
  # Prevent CSRF attacks by raising an exception.
  # For APIs, you may want to use :null_session instead.
  protect_from_forgery with: :exception
  # Devise firstname and lastname - added
  before_filter :configure_permitted_parameters, if: :devise_controller?
  devise_group :user, contains: [:student, :tutor]

  around_filter :with_timezone
  
  rescue_from ActiveRecord::RecordNotFound do
    flash[:warning] = 'Resource not found.'
    redirect_back_or root_path
  end

  def redirect_back_or(path)
    redirect_to request.referer || path
  end

  def after_sign_in_path_for(resource)
    if current_user.is_a? Student 
      return dashboard_student_path(current_user)
    else
      if current_user.verified
        return dashboard_tutor_path(current_user)
      end

      return edit_tutor_path(current_user)
    end

    # never reached
    request.env['omniauth.origin'] || resource || root_path
  end


  protected
  def configure_permitted_parameters
    devise_parameter_sanitizer.for(:sign_up) { |u| u.permit(:firstname, :lastname, :email, :password, :password_confirmation, :remember_me) }
    devise_parameter_sanitizer.for(:account_update) { |u| u.permit(:firstname, :lastname, :email, :password, :password_confirmation, :current_password) }
  end

  private 
  def with_timezone
    timezone = Time.find_zone(cookies[:timezone])
    Time.use_zone(timezone) { yield }
  end
end
