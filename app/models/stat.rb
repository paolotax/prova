# == Schema Information
#
# Table name: stats
#
#  id              :bigint           not null, primary key
#  anno            :string
#  categoria       :string
#  condizioni      :string
#  descrizione     :string
#  ordina_per      :string
#  position        :integer
#  raggruppa_per   :string
#  seleziona_campi :string
#  testo           :text
#  titolo          :string
#  visible         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#

class Stat < ApplicationRecord
  # SQL keywords that are NOT allowed in stat queries
  FORBIDDEN_SQL_KEYWORDS = %w[
    INSERT UPDATE DELETE DROP ALTER CREATE TRUNCATE
    GRANT REVOKE EXECUTE EXEC INTO
  ].freeze

  # Allowed placeholder patterns for parameter binding
  ALLOWED_PLACEHOLDERS = %w[:user_id :account_id].freeze

  positioned on: [:categoria], column: :position

  validates :titolo, presence: true
  validates :testo, presence: true
  validate :validate_sql_safety

  def test_execution
    test_user = User.first
    return false unless test_user

    execute(test_user)
    update_column(:visible, true)
    true
  rescue StandardError => e
    Rails.logger.error("Stat execution failed: #{e.message}")
    update_column(:visible, false)
    false
  end

  def execute(user)
    raise SecurityError, "SQL query is not safe" unless sql_safe?

    sanitized_sql = sanitize_query(user)
    ActiveRecord::Base.connection.exec_query(sanitized_sql).to_a
  end

  def raggruppa
    raggruppa_per.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def totali
    seleziona_campi.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  def sql_safe?
    return false if testo.blank?

    normalized = testo.upcase.gsub(/\s+/, " ")

    # Must start with SELECT (after stripping whitespace and comments)
    clean_sql = normalized.gsub(/--.*$/, "").gsub(/\/\*.*?\*\//m, "").strip
    return false unless clean_sql.start_with?("SELECT")

    # Check for forbidden keywords
    FORBIDDEN_SQL_KEYWORDS.none? { |keyword| normalized.include?(keyword) }
  end

  private

  def validate_sql_safety
    return if testo.blank?

    unless sql_safe?
      errors.add(:testo, "contiene operazioni SQL non permesse. Solo SELECT è consentito.")
    end

    # Validate placeholders
    placeholders = testo.scan(/:(\w+)/).flatten.map { |p| ":#{p}" }
    invalid_placeholders = placeholders - ALLOWED_PLACEHOLDERS
    if invalid_placeholders.any?
      errors.add(:testo, "contiene placeholder non validi: #{invalid_placeholders.join(', ')}. Usa solo: #{ALLOWED_PLACEHOLDERS.join(', ')}")
    end
  end

  def sanitize_query(user)
    sql = testo.dup

    # Use proper parameter binding with sanitize_sql_array
    # Replace :user_id and {{user.id}} with properly quoted value
    bindings = {
      user_id: user.id,
      account_id: Current.account&.id
    }

    # Replace named placeholders with sanitized values
    bindings.each do |key, value|
      placeholder_patterns = [":#{key}", "{{user.id}}"] if key == :user_id
      placeholder_patterns ||= [":#{key}"]

      placeholder_patterns.each do |pattern|
        sql = sql.gsub(pattern, ActiveRecord::Base.connection.quote(value))
      end
    end

    sql
  end
end
