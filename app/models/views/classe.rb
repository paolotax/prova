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

    scope :prime, -> { where(classe: "1") }
    scope :seconde, -> { where(classe: "2") }
    scope :terze, -> { where(classe: "3") }
    scope :quarte, -> { where(classe: "4") }
    scope :quinte, -> { where(classe: "5") }

    scope :tempo_pieno, -> { where("view_classi.combinazione like ?", "%40 ORE%") }
end