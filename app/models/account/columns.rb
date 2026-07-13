# Registro colonne della lista account admin. Owner, ultimo accesso e
# conteggi arrivano da subquery aggiunte alla select solo quando visibili.
class Account::Columns < DataTable::Columns
  self.prefix = "admin/accounts"

  # Owner = membership con role owner (enum 2), il più vecchio se più d'uno
  OWNER = <<~SQL.squish.freeze
    (SELECT users.name FROM memberships JOIN users ON users.id = memberships.user_id
      WHERE memberships.account_id = accounts.id AND memberships.role = 2
      ORDER BY memberships.created_at LIMIT 1) AS owner_nome,
    (SELECT users.email FROM memberships JOIN users ON users.id = memberships.user_id
      WHERE memberships.account_id = accounts.id AND memberships.role = 2
      ORDER BY memberships.created_at LIMIT 1) AS owner_email,
    (SELECT users.slug FROM memberships JOIN users ON users.id = memberships.user_id
      WHERE memberships.account_id = accounts.id AND memberships.role = 2
      ORDER BY memberships.created_at LIMIT 1) AS owner_slug
  SQL

  MEMBRI = "(SELECT COUNT(*) FROM memberships WHERE memberships.account_id = accounts.id) AS membri_count".freeze

  # Ultimo accesso tra tutti i membri (sessioni attive + storico Ahoy)
  ULTIMO_ACCESSO = <<~SQL.squish.freeze
    GREATEST(
      (SELECT MAX(sessions.last_active_at) FROM sessions
        JOIN memberships ON memberships.user_id = sessions.user_id
        WHERE memberships.account_id = accounts.id),
      (SELECT MAX(ahoy_visits.started_at) FROM ahoy_visits
        JOIN memberships ON memberships.user_id = ahoy_visits.user_id
        WHERE memberships.account_id = accounts.id)
    ) AS ultimo_accesso
  SQL

  PROVINCE = <<~SQL.squish.freeze
    (SELECT COUNT(DISTINCT scuole.provincia) FROM scuole
      WHERE scuole.account_id = accounts.id AND scuole.provincia <> '') AS province_count,
    (SELECT STRING_AGG(DISTINCT INITCAP(scuole.provincia), ', ' ORDER BY INITCAP(scuole.provincia)) FROM scuole
      WHERE scuole.account_id = accounts.id AND scuole.provincia <> '') AS province_nomi
  SQL

  SCUOLE_COUNT = "(SELECT COUNT(*) FROM scuole WHERE scuole.account_id = accounts.id) AS scuole_count".freeze

  column :nome,     label: "Account",  width: "minmax(9rem, 1fr)", sort: "accounts.name"
  column :owner,    label: "Owner",    width: "minmax(12rem, 1.2fr)", sort: "owner_nome",
         scope: ->(s) { s.select(OWNER) }
  column :membri,   label: "Membri",   width: "5rem", align: :end, hide_mobile: true, sort: "membri_count",
         scope: ->(s) { s.select(MEMBRI) }
  column :accesso,  label: "Ultimo accesso", width: "8.5rem", sort: "ultimo_accesso",
         scope: ->(s) { s.select(ULTIMO_ACCESSO) }
  column :province, label: "Province", width: "minmax(7rem, 0.8fr)", hide_mobile: true, sort: "province_count",
         scope: ->(s) { s.select(PROVINCE) }
  column :scuole,   label: "Scuole",   width: "5rem", align: :end, sort: "scuole_count",
         scope: ->(s) { s.select(SCUOLE_COUNT) }
  column :creato,   label: "Creato il", width: "7rem", hide_mobile: true, default: false, sort: "accounts.created_at"
end
