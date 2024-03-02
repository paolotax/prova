module Authenticable
    extend ActiveSupport::Concern
  
    included do
      
      devise :database_authenticatable, :registerable,
      :recoverable, :rememberable, :validatable, :confirmable,
      authentication_keys: [:login]

      validates :name, presence: true, uniqueness: true

      attr_accessor :login

      def login
      @login || self.name || self.email
      end

      protected


      def after_confirmation
        WelcomeMailer.send_greetings_notification(self)
                    .deliver_now
      end
  
      def self.find_for_database_authentication(warden_condition)
        conditions = warden_condition.dup
        if(login = conditions.delete(:login))
          where(conditions.to_h).where(["lower(name) = :value OR lower(email) = :value", { value: login.downcase }]).first
        elsif conditions.has_key?(:name) || conditions.has_key?(:email)
          where(conditions.to_h).first
        end
      end
    
      # Attempt to find a user by it's email. If a record is found, send new
      # password instructions to it. If not user is found, returns a new user
      # with an email not found error.
      # def self.send_reset_password_instructions(attributes = {})
      #   recoverable = find_recoverable_or_initialize_with_errors(reset_password_keys, attributes, :not_found)
      #   recoverable.send_reset_password_instructions if recoverable.persisted?
      #   recoverable
      # end
  
      # def self.find_recoverable_or_initialize_with_errors(required_attributes, attributes, error = :invalid)
      #   (case_insensitive_keys || []).each {|k| attributes[k].try(:downcase!)}
  
      #   attributes = attributes.slice(*required_attributes)
      #   attributes.delete_if {|_key, value| value.blank?}
  
      #   if attributes.keys.size == required_attributes.size
      #     if attributes.key?(:login)
      #       login = attributes.delete(:login)
      #       record = find_record(login)
      #     else
      #       record = where(attributes).first
      #     end
      #   end
  
      #   unless record
      #     record = new
  
      #     required_attributes.each do |key|
      #       value = attributes[key]
      #       record.send("#{key}=", value)
      #       record.errors.add(key, value.present? ? error : :blank)
      #     end
      #   end
      #   record
      # end
  
      # def self.find_record(login)
      #   where(["name = :value OR email = :value", {value: login}]).first
      # end
    end
  end