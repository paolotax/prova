module Clienti
  class RiepilogoLibro
    
    attr_accessor :user_id, :id, :codice_isbn, :categoria, :titolo, :editore, :uscite, :entrate, :valore

    def initialize(hash)
      @user_id = hash['user_id']
      @id = hash['id']
      @codice_isbn = hash['codice_isbn']
      @categoria = hash['categoria']
      @titolo = hash['titolo']
      @editore = hash['editore']
      @uscite = hash['uscite'].to_i
      @entrate = hash['entrate'].to_i
      @valore = hash['valore'].to_f
    end
  end
end