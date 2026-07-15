# Stato dell'onboarding di un account, derivato dai dati (niente colonna):
# azienda -> zone -> importazione -> mandati -> fine.
class Account::Onboarding
  STEPS = %i[azienda zone importazione mandati fine].freeze

  def initialize(account)
    @account = account
  end

  # Memoizzato: build_azienda sull'account (form con errori) non deve far
  # avanzare lo step a meta' richiesta.
  def step
    @step ||= begin
      if !account.azienda&.persisted? then :azienda
      elsif account.zone.none? then :zone
      elsif !account.zone_tutte_attive? then :importazione
      elsif account.mandati.none? then :mandati
      else :fine
      end
    end
  end

  def da_completare? = step != :fine

  # Vero solo per un account appena creato: guida il redirect post-login senza
  # intrappolare gli account storici che non hanno mai compilato l'azienda.
  def da_iniziare? = account.azienda.nil? && account.zone.none?

  private

  attr_reader :account
end
