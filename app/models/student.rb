class Student < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable

  has_one :card, :as => :user
  has_many :lessons, dependent: :destroy

  acts_as_messageable

  validate :uniqueness_of_user_email

  validates :firstname, presence: true, length: { in: 2..35 }
  validates :lastname, presence: true, length: { in: 2..35 }

  after_create :staging_auto_confirm

  def uniqueness_of_user_email
    Tutor.all.each do |tutor|
      if(tutor.email == self.email)
        errors.add(:field, " - Tutor account exists with that email address")
      end
    end
  end

  def display_name
    return "#{self.firstname} #{self.lastname}".titleize
  end

  def mailboxer_email(object)
 		#return the model's email here
    return self.email
	end

  def name
    return self.display_name
  end

  def has_payment_info?
    braintree_customer_id
  end

  def staging_auto_confirm
    if Rails.env.production?
      if(ENV['HEROKU_APP_ENVIRONMENT'] == 'STAGING')
        self.confirm!
      end
    end
  end
end