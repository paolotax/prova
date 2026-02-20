module ProtectedFromDestroy
  extend ActiveSupport::Concern

  included do
    before_destroy :ensure_no_movimenti
  end

  private

  def ensure_no_movimenti
    checks = []
    checks << [:appunti, appunti] if respond_to?(:appunti)
    checks << [:documenti, documenti] if respond_to?(:documenti)
    checks << [:tappe, tappe] if respond_to?(:tappe)
    checks << [:consegne_saggio, consegne_saggio] if respond_to?(:consegne_saggio)

    checks.each do |name, relation|
      if relation.any?
        errors.add(:base, "non può essere eliminata: ha #{name} collegati")
        throw(:abort)
      end
    end

    if respond_to?(:classi) && classi_con_movimenti?
      errors.add(:base, "non può essere eliminata: ha classi con movimenti collegati")
      throw(:abort)
    end

    if respond_to?(:plessi) && plessi_con_movimenti?
      errors.add(:base, "non può essere eliminata: ha plessi con movimenti collegati")
      throw(:abort)
    end
  end

  def classi_con_movimenti?
    classe_ids = classi.pluck(:id)
    return false if classe_ids.empty?

    Appunto.where(appuntabile_type: "Classe", appuntabile_id: classe_ids).exists? ||
      Documento.where(clientable_type: "Classe", clientable_id: classe_ids).exists? ||
      ConsegnaSaggio.joins(:adozione).where(adozioni: { classe_id: classe_ids }).exists?
  end

  def plessi_con_movimenti?
    plesso_ids = plessi.pluck(:id)
    return false if plesso_ids.empty?

    Appunto.where(appuntabile_type: "Scuola", appuntabile_id: plesso_ids).exists? ||
      Documento.where(clientable_type: "Scuola", clientable_id: plesso_ids).exists? ||
      Tappa.where(tappable_type: "Scuola", tappable_id: plesso_ids).exists?
  end
end
