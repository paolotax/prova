class GiacenzeController < ApplicationController
  before_action :authenticate_user!

  ORDINAMENTI = {
    "titolo" => "libri.titolo ASC",
    "disponibile" => "COALESCE(giacenze.disponibile, 0) DESC, libri.titolo ASC",
    "impegnato" => "COALESCE(giacenze.impegnato, 0) DESC, libri.titolo ASC",
    "fabbisogno" => <<~SQL.squish
      GREATEST(libri.adozioni_count -
        (COALESCE(giacenze.disponibile, 0) - COALESCE(giacenze.impegnato, 0)), 0) DESC,
      libri.titolo ASC
    SQL
  }.freeze

  def index
    scope = Current.account.libri.left_joins(:giacenza).includes(:editore, :giacenza)
    scope = scope.search_all_word(params[:q]) if params[:q].present?
    scope = applica_stato(scope)

    @totali = totali(scope.except(:includes, :order))
    @ordinamento = ORDINAMENTI.key?(params[:ordinamento]) ? params[:ordinamento] : "fabbisogno"
    @stato = params[:stato].presence_in(%w[tutti adottati fabbisogno impegnati sotto_scorta]) || "tutti"
    @total_count = scope.count

    # Alcuni scope (in particolare pg_search) hanno gia' un ORDER BY: va
    # sostituito, non accodato, altrimenti la scelta dell'utente e' secondaria.
    set_page_and_extract_portion_from scope.reorder(Arel.sql(ORDINAMENTI.fetch(@ordinamento)))
  end

  private

    def applica_stato(scope)
      libero = "COALESCE(giacenze.disponibile, 0) - COALESCE(giacenze.impegnato, 0)"

      case params[:stato]
      when "adottati"
        # Il counter comprende solo le adozioni mie con da_acquistare = true.
        scope.where("libri.adozioni_count > 0")
      when "fabbisogno"
        scope.where("libri.adozioni_count > (#{libero})")
      when "impegnati"
        scope.where("COALESCE(giacenze.impegnato, 0) > 0")
      when "sotto_scorta"
        scope.where("#{libero} < 0")
      else
        scope
      end
    end

    def totali(scope)
      row = scope.pick(
        Arel.sql("COALESCE(SUM(COALESCE(giacenze.disponibile, 0)), 0)"),
        Arel.sql("COALESCE(SUM(COALESCE(giacenze.impegnato, 0)), 0)"),
        Arel.sql("COALESCE(SUM(COALESCE(giacenze.campionario, 0)), 0)"),
        Arel.sql("COALESCE(SUM(GREATEST(libri.adozioni_count - (COALESCE(giacenze.disponibile, 0) - COALESCE(giacenze.impegnato, 0)), 0)), 0)")
      )

      %i[disponibile impegnato campionario fabbisogno].zip(row.map(&:to_i)).to_h
    end
end
