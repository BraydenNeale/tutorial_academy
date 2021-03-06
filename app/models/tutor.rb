class Tutor < ActiveRecord::Base
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable, :confirmable

  validates :firstname, presence: true, length: { in: 2..35 }
  validates :lastname, presence: true, length: { in: 2..35 }
  validates :about, length: { maximum: 3000 }
  validates :rate, presence: true, numericality: true, if: :rate
  validates :experience, length: { maximum: 3000 }

  serialize :availability

  mount_uploader :picture, PictureUploader

  acts_as_messageable # mailboxer

  has_one :bank_account, dependent: :destroy, as: :provider
  accepts_nested_attributes_for :bank_account, allow_destroy: true
  has_one :wwc_card, dependent: :destroy
  accepts_nested_attributes_for :wwc_card, allow_destroy: true
  has_and_belongs_to_many :subjects

  has_many :associations
  has_many :organisations, -> { where(associations: {confirmed: true} )}, through: :associations, source: :organisation
  has_many :organisation_requests, -> { where(associations: {confirmed: false} )}, through: :associations, source: :organisation

  has_many :lessons, dependent: :destroy
  validate :uniqueness_of_user_email

  enum sex: ['Female','Male']
  @@tutorial_academy_fee = 5 # we take a fixed price of $5

  after_create :staging_auto_confirm

  def uniqueness_of_user_email
    Student.all.each do |student|
      if(student.email == self.email)
        errors.add(:field, "- Student account exists with that email address")
      end
    end
  end

  def self.get_tutorial_academy_fee
    # can't use defined helper :(
    ActionController::Base.helpers.number_to_currency(@@tutorial_academy_fee)
  end

  def display_name
    return "#{self.firstname} #{self.lastname}".titleize
  end

  def display_rate
    return helper.number_to_currency(self.rate)
  end

  def display_rate_with_organisation_fees
    return helper.number_to_currency(rate_with_organisation_fees)
  end

  def rate_with_organisation_fees
    if not self.rate.present?
      return 0;
    end
    cost = self.rate

    if not self.has_bank_account?
      return cost
    end

    cost += @@tutorial_academy_fee
    self.organisations.each do |org|
      cost += org.fee
    end

    return cost
  end

  def area
    # default is Perth city so this should always be valid
    area = Area.find_by_id(self.suburb)

    if not area.present?
      area = Area.first
    end

    return area
  end

  def check_verify
    # all required fields have been filled out, tutor has a valid wwc card and tutor has an account linked (how to check valid?)
    rate = self.rate.present?
    birth = self.date_of_birth.present?
    # wwc = verify_wwc_card(self.wwc_card)
    wwc = true

    # account information

    if(rate and birth and wwc)
      self.verified = true
      self.save!
    end
  end

  def display_suburb
    return "#{self.area.display_name}, #{self.area.state}"
  end

  # if you want message updates to notify them in email
  def mailboxer_email(object)
    #return the model's email here
    return self.email
  end

  def name
    return display_name
  end

  def has_valid_wwc_card?
    return verify_wwc_card(self.wwc_card)
  end

  def hash_tag_list
    return self.subjects.map(&:faculty).uniq.take(2)
  end

  def get_age
    if self.date_of_birth.nil?
      return nil
    end

    now = Time.now.utc.to_date
    dob = self.date_of_birth
    now.year - dob.year - ((now.month > dob.month || (now.month == dob.month && now.day >= dob.day)) ? 0 : 1)
  end

  def is_get_ahead_tutor?
    get_ahead_tutoring = Organisation.all.where(name: "Get Ahead Tutoring").first

    return false if not get_ahead_tutoring.present?

    self.organisations.each do |org|
      if org.id == get_ahead_tutoring.id
        return true
      end
    end

    return false
  end

  def self.featured_tutors
    # return self.all.order("RANDOM()").limit(8)
    return self.all.where(verified: true).order("RANDOM()").limit(8)
  end

  def self.similar_tutors(tutor)
    # Some similariy algorithm here to return the 2 closes tutors - same subjects/area...
    return self.all.where.not(id: tutor.id).where(verified: true).order("RANDOM()").limit(2)
  end

  def self.simple_search(area, faculty)
    tutors = Array.new

    if not(area.present? or faculty.present?)
      return tutors
    end

    if(area.present?)
      ar = Area.where("lower(name) like ?", "%#{area.downcase}%").first
    end
    
    subs = Subject.where("faculty like ?", "#{faculty.downcase}")

    if(subs.present?)
      tutors = self.joins(:subjects).where(subjects: { id: subs.ids }).distinct
    else
      tutors = Tutor.all
    end

    # only want verified tutors
    tutors = tutors.select {|t| t.verified }

    if(ar.present?)
      tutors.sort_by! do |tut| 
        area_sort(tut, ar)
      end
    end

    return tutors
  end

  def helper
    ActionController::Base.helpers
  end

  def self.area_sort(tutor, area)
    # Haversine argument error... don't have time to properly debug this
    #require 'haversine'

    #distance = Haversine.distance(tutor.area.latitude, tutor.area.longitude, 
    #  area.latitude, area.longitude)

    # temp taxi-cab formula: dist((x,y), (a,b)) = |x - a| + |y - b|
    distance = (tutor.area.latitude - area.latitude).abs + (tutor.area.longitude - area.longitude).abs

    return distance
  end

  def has_bank_account?
    if not self.bank_account.present?
      return false
    end

    if self.bank_account.bsb.nil? or self.bank_account.number.nil? or self.bank_account.name.nil?
      return false
    end

    if self.bank_account.bsb.blank? or self.bank_account.number.blank? or self.bank_account.name.blank?
      return false
    end

    # BSB is 6 numbers
    if self.bank_account.bsb.length != 6
      return false
    end

    # bsb is all digits
    if !/\A\d+\z/.match(self.bank_account.bsb) # if not a positive number
      return false
    end

    #account number is all digits
    if !/\A\d+\z/.match(self.bank_account.number) # if not a positive number
      return false
    end

    return true
  end

  def staging_auto_confirm
    if Rails.env.production?
      if(ENV['HEROKU_APP_ENVIRONMENT'] == 'STAGING')
        self.confirm!
      end
    end
  end

  private

  def verify_wwc_card(wwc)
    if not wwc.present?
      return false
    end

    if not wwc.number.present?
      return false
    end

    if not wwc.expiry.present?
      return false
    end

    # WWC num is 6 chars long - can also be 7...
    if wwc.number.length < 6
      # errors.add :base, 'Number not correct format'
      return false
    end

    # WWC num is all digits
    if !/\A\d+\z/.match(wwc.number) # if not a positive number
      # errors.add :base, 'Number not correct format'
      return false
    end

    # if card has expired
    if(wwc.expiry <= Date.today)
      # errors.add :base, "Card has expired"
      return false
    end

    # complex selenium script or compare with webscraped data 
    # to determine if is valid according to www.checkwwc.wa.gov.au/
    return true
  end
end
