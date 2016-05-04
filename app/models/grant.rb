class Grant < ActiveRecord::Base
  COMPONENTS = [:grants_reason_types, :people, :residence, :payees].freeze

  before_save :set_application_date
  before_create :set_initial_status

  # rubocop:disable Rails/HasAndBelongsToMany
  has_and_belongs_to_many :coverage_types
  has_and_belongs_to_many :payees

  default_scope -> { order(application_date: :desc) }

  belongs_to :user
  belongs_to :subsidy_type
  belongs_to :status, class_name: "GrantStatus", foreign_key: :grant_status_id
  belongs_to :residence
  belongs_to :previous_residence, class_name: "Residence", foreign_key: :previous_residence_id
  belongs_to :last_month_budget, class_name: "Budget"
  belongs_to :current_month_budget, class_name: "Budget"
  belongs_to :next_month_budget, class_name: "Budget"

  has_many :people, autosave: true
  has_many :other_payments
  has_many :comments
  has_many :grants_reason_types
  has_many :uploads
  has_many :reason_types, through: :grants_reason_types

  delegate :agency, to: :user

  accepts_nested_attributes_for(*COMPONENTS, reject_if: :all_blank, allow_destroy: true)

  def intialize_defaults(options = {})
    self.user_id = options[:user_id] if user_id.nil?
    people.build if people.empty?
    payees.build if payees.empty?
    build_residence unless residence.present?
  end

  def self.list(current_user, options = {})
    grants = joins(user: :agency).includes(:people, :status).order(id: :desc)
    if current_user.admin?
      filter_by_options(grants, options)
    else
      filter_for_worker(grants, current_user, options)
    end
  end

  def status_name
    raise "Grant can not have blank grant status" if status.blank?
    status.description
  end

  def primary_applicant
    people.first
  end

  def primary_applicant_name
    primary_applicant.full_name if primary_applicant.present?
  end

  def agency_name
    return "" unless user.present? && agency.present?
    agency.name
  end

  def case_worker_name
    return "" unless user.present?
    user.full_name
  end

  def grant_amount=(value)
    self[:grant_amount] = value.to_s.delete("$,")
  end

  private

  def set_application_date
    return if application_date.present?
    self.application_date = Time.zone.today
  end

  def set_initial_status
    return if status.present?
    self.status = GrantStatus.initial
  end

  def self.filter_by_user_id(grants, user_id)
    grants = grants.where(user_id: user_id) if user_id.present?
    grants
  end
  private_class_method :filter_by_user_id

  def self.filter_by_agency_id(grants, agency_id)
    grants = grants.where(users: { agency_id: agency_id }) if agency_id.present?
    grants
  end
  private_class_method :filter_by_agency_id

  def self.filter_by_options(grants, options)
    grants = filter_by_user_id(grants, options[:user_id])
    grants = filter_by_agency_id(grants, options[:agency_id])
    grants
  end
  private_class_method :filter_by_options

  def self.filter_for_worker(grants, current_user, options)
    if current_user.approved?
      grants = filter_by_agency_id(grants, current_user.agency_id)
      grants = filter_by_user_id(grants, options[:user_id])
    else
      grants = grants.where(user_id: current_user.id)
    end
    grants
  end
  private_class_method :filter_for_worker
end
