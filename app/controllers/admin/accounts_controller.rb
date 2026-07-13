class Admin::AccountsController < Admin::BaseController
  include HasVista

  def index
    @columns = resolve_colonne(Account::Columns)
    @sort = resolve_sort(@columns)

    scope = Account::Columns.apply_scopes(Account.select("accounts.*").order(:created_at), @columns)
    @accounts = apply_sort(scope, @sort).load

    # Registrati ma senza alcun account: solo utenza, nessun dato
    @utenti_senza_account = User.where.missing(:memberships).order(:created_at)
  end

  def show
    @account = Account.find(params[:id])
    @memberships = @account.memberships.includes(:user).order(:created_at)
    @scuole = @account.scuole
    @province = @scuole.where.not(provincia: [ nil, "" ]).distinct.pluck(:provincia).sort

    @conteggi = {
      "Scuole" => @scuole.count,
      "Classi" => @account.classi.count,
      "Adozioni" => @account.adozioni.count,
      "Persone" => @account.persone.count,
      "Documenti" => @account.documenti.count,
      "Appunti" => @account.appunti.count,
      "Clienti" => @account.clienti.count,
      "Libri" => @account.libri.count,
      "Collane" => @account.collane.count,
      "Entries" => @account.entries.count,
      "Eventi" => @account.events.count,
      "Import" => @account.import_records.count
    }
  end

  # Elimina l'account con tutti i suoi dati (DestroyAccountJob, in
  # background). I membri restano come utenti registrati.
  def destroy
    account = Account.find(params[:id])

    if account.users.exists?(current_user.id)
      return redirect_to admin_accounts_path, alert: "Non puoi eliminare un account di cui sei membro"
    end

    if DestroyAccountJob.destroying?(account.id)
      return redirect_to admin_accounts_path, notice: "Eliminazione di #{account.name} già in corso"
    end

    DestroyAccountJob.mark_destroying(account.id)
    DestroyAccountJob.perform_later(account.id)

    redirect_to admin_accounts_path, notice: "Eliminazione di #{account.name} avviata in background"
  end
end
