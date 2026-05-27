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
#  stato           :string           default("lab"), not null
#  testo           :text
#  titolo          :string
#  ultima_verifica :datetime
#  ultimo_errore   :text
#  visible         :boolean          default(TRUE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#
# Indexes
#
#  index_stats_on_stato  (stato)
#

class Stat < ApplicationRecord
  # SQL keywords that are NOT allowed in stat queries
  FORBIDDEN_SQL_KEYWORDS = %w[
    INSERT UPDATE DELETE DROP ALTER CREATE TRUNCATE
    GRANT REVOKE EXECUTE EXEC INTO
  ].freeze

  # Allowed placeholder patterns for parameter binding
  ALLOWED_PLACEHOLDERS = %w[:user_id :account_id].freeze

  STATI = %w[produzione lab archiviata].freeze

  positioned on: [:categoria], column: :position

  validates :titolo, presence: true
  validates :testo, presence: true
  validates :stato, inclusion: { in: STATI }
  validate :validate_sql_safety

  scope :produzione,  -> { where(stato: "produzione") }
  scope :lab,         -> { where(stato: "lab") }
  scope :archiviata,  -> { where(stato: "archiviata") }
  scope :visibili_a, ->(user) { user.admin? ? all : produzione }
  scope :con_errore,  -> { where.not(ultimo_errore: nil) }

  def produzione?  = stato == "produzione"
  def lab?         = stato == "lab"
  def archiviata?  = stato == "archiviata"

  # Esegue la query con l'utente passato (default: primo utente disponibile)
  # e popola ultima_verifica/ultimo_errore. NON cambia stato.
  def test_execution(user = User.first)
    return false unless user

    execute(user)
    update_columns(ultima_verifica: Time.current, ultimo_errore: nil)
    true
  rescue SecurityError, StandardError => e
    Rails.logger.error("Stat ##{id} execution failed: #{e.message}")
    update_columns(ultima_verifica: Time.current, ultimo_errore: e.message.to_s.truncate(2000))
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

  # Parsed declarations from seleziona_campi.
  #
  # Sintassi item:
  #   col                       → {kind: :col, op: :sum, col: ...}        (default)
  #   col:sum|avg|min|max|count → {kind: :col, op: ..., col: ...}
  #   col:pct_of_total          → {kind: :extra, op: :pct_of_total, col: ..., label: "..."}
  #   a/b:pct|ratio             → {kind: :extra, op: ..., a: ..., b: ..., label: "a/b"}
  def aggregazioni
    seleziona_campi.to_s.split(",").map(&:strip).reject(&:blank?).filter_map { |item| parse_aggregazione(item) }
  end

  # Backward compat: nomi delle colonne con aggregazione "per cella" (sum/avg/...).
  def totali
    aggregazioni.select { |a| a[:kind] == :col }.map { |a| a[:col] }
  end

  def sql_safe?
    return false if testo.blank?

    normalized = testo.upcase.gsub(/\s+/, " ")

    # Must start with SELECT or WITH (CTE) after stripping whitespace and comments
    clean_sql = normalized.gsub(/--.*$/, "").gsub(/\/\*.*?\*\//m, "").strip
    return false unless clean_sql.start_with?("SELECT") || clean_sql.start_with?("WITH")

    # Check for forbidden keywords
    FORBIDDEN_SQL_KEYWORDS.none? { |keyword| normalized.include?(keyword) }
  end

  private

  def parse_aggregazione(item)
    # Opzionale: alias "nome=espressione[:op]"
    alias_name, rest =
      if item.include?("=")
        n, r = item.split("=", 2).map(&:strip)
        [n.presence, r]
      else
        [nil, item]
      end

    expr, op = rest.split(":", 2).map(&:strip)
    op = (op.presence || "sum").to_sym
    return nil if expr.blank?

    if expr.include?("/")
      a, b = expr.split("/", 2).map(&:strip)
      return nil if a.blank? || b.blank?
      return nil unless %i[pct ratio].include?(op)

      { kind: :extra, op: op, a: a, b: b, label: alias_name || "#{a}/#{b}" }
    elsif op == :pct_of_total
      { kind: :extra, op: :pct_of_total, col: expr, label: alias_name || "% #{expr} sul totale" }
    elsif %i[sum avg min max count].include?(op)
      { kind: :col, op: op, col: expr }
    end
  end

  def validate_sql_safety
    return if testo.blank?

    unless sql_safe?
      errors.add(:testo, "contiene operazioni SQL non permesse. Solo SELECT è consentito.")
    end

    # Validate placeholders (ignore PostgreSQL type casts like ::text, ::integer)
    # Match :word but not ::word (type casts)
    placeholders = testo.scan(/(?<!:):(\w+)/).flatten.map { |p| ":#{p}" }
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
