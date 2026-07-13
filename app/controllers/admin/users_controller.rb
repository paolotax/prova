class Admin::UsersController < Admin::BaseController
  def show
    @user = User.friendly.find(params[:id])
    @accounts = @user.accounts.order(:created_at)
    @visite = Ahoy::Visit.where(user_id: @user.id)
    @ultimo_accesso = [ @user.sessions.maximum(:last_active_at), @visite.maximum(:started_at) ].compact.max

    @conteggi = {
      "Documenti" => @user.documenti.count,
      "Appunti" => @user.appunti.count,
      "Tappe" => @user.tappe.count,
      "Giri" => @user.giri.count,
      "Propagande" => @user.propagande.count,
      "Clienti" => @user.clienti.count,
      "Libri" => @user.libri.count,
      "Sconti" => @user.sconti.count,
      "Entries" => Entry.where(user_id: @user.id).count,
      "Voice notes" => @user.voice_notes.count,
      "Chat" => @user.chats.count,
      "Import" => @user.import_records.count
    }
  end

  # Elimina l'utente e i suoi account senza altri membri (cascata su
  # scuole, clienti, documenti, ecc. via dependent: :destroy). La cascata
  # può durare minuti: la fa DestroyUserJob in background.
  def destroy
    user = User.friendly.find(params[:id])

    if user == current_user
      return redirect_to admin_accounts_path, alert: "Non puoi eliminare te stesso"
    end

    unless DestroyUserJob.destroying?(user.id)
      DestroyUserJob.mark_destroying(user.id)
      DestroyUserJob.perform_later(user.id)
    end

    # Dalla lista niente refresh: la riga passa allo stato "in eliminazione"
    if params[:da_lista]
      render turbo_stream: turbo_stream.replace(helpers.dom_id(user),
        partial: "admin/accounts/utente_senza_account", locals: { user: user })
    else
      redirect_to admin_accounts_path, notice: "Eliminazione di #{user.email} avviata in background"
    end
  end
end
