class Views::Classe < ApplicationRecord

    self.primary_key = [
        "codice_ministeriale",
        "classe",
        "sezione",
        "combinazione"
    ]

    has_many :import_adozioni, query_constraints: [
        :CODICESCUOLA, :ANNOCORSO, :SEZIONEANNO, :COMBINAZIONE
    ]

end