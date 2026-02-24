class AddSiglaToZone < ActiveRecord::Migration[8.1]
  SIGLE = {
    "AGRIGENTO" => "AG", "ALESSANDRIA" => "AL", "ANCONA" => "AN", "AOSTA" => "AO",
    "AREZZO" => "AR", "ASCOLI PICENO" => "AP", "ASTI" => "AT", "AVELLINO" => "AV",
    "BARI" => "BA", "BARLETTA-ANDRIA-TRANI" => "BT", "BELLUNO" => "BL", "BENEVENTO" => "BN",
    "BERGAMO" => "BG", "BIELLA" => "BI", "BOLOGNA" => "BO", "BOLZANO" => "BZ",
    "BRESCIA" => "BS", "BRINDISI" => "BR", "CAGLIARI" => "CA", "CALTANISSETTA" => "CL",
    "CAMPOBASSO" => "CB", "CASERTA" => "CE", "CATANIA" => "CT", "CATANZARO" => "CZ",
    "CHIETI" => "CH", "COMO" => "CO", "COSENZA" => "CS", "CREMONA" => "CR",
    "CROTONE" => "KR", "CUNEO" => "CN", "ENNA" => "EN", "FERMO" => "FM",
    "FERRARA" => "FE", "FIRENZE" => "FI", "FOGGIA" => "FG", "FORLI'-CESENA" => "FC",
    "FROSINONE" => "FR", "GENOVA" => "GE", "GORIZIA" => "GO", "GROSSETO" => "GR",
    "IMPERIA" => "IM", "ISERNIA" => "IS", "L'AQUILA" => "AQ", "LA SPEZIA" => "SP",
    "LATINA" => "LT", "LECCE" => "LE", "LECCO" => "LC", "LIVORNO" => "LI",
    "LODI" => "LO", "LUCCA" => "LU", "MACERATA" => "MC", "MANTOVA" => "MN",
    "MASSA-CARRARA" => "MS", "MATERA" => "MT", "MESSINA" => "ME", "MILANO" => "MI",
    "MODENA" => "MO", "MONZA E DELLA BRIANZA" => "MB", "NAPOLI" => "NA", "NOVARA" => "NO",
    "NUORO" => "NU", "ORISTANO" => "OR", "PADOVA" => "PD", "PALERMO" => "PA",
    "PARMA" => "PR", "PAVIA" => "PV", "PERUGIA" => "PG", "PESARO E URBINO" => "PU",
    "PESCARA" => "PE", "PIACENZA" => "PC", "PISA" => "PI", "PISTOIA" => "PT",
    "PORDENONE" => "PN", "POTENZA" => "PZ", "PRATO" => "PO", "RAGUSA" => "RG",
    "RAVENNA" => "RA", "REGGIO CALABRIA" => "RC", "REGGIO EMILIA" => "RE", "RIETI" => "RI",
    "RIMINI" => "RN", "ROMA" => "RM", "ROVIGO" => "RO", "SALERNO" => "SA",
    "SASSARI" => "SS", "SAVONA" => "SV", "SIENA" => "SI", "SIRACUSA" => "SR",
    "SONDRIO" => "SO", "SUD SARDEGNA" => "SU", "TARANTO" => "TA", "TERAMO" => "TE",
    "TERNI" => "TR", "TORINO" => "TO", "TRAPANI" => "TP", "TRENTO" => "TN",
    "TREVISO" => "TV", "TRIESTE" => "TS", "UDINE" => "UD", "VARESE" => "VA",
    "VENEZIA" => "VE", "VERBANO-CUSIO-OSSOLA" => "VB", "VERCELLI" => "VC",
    "VERONA" => "VR", "VIBO VALENTIA" => "VV", "VICENZA" => "VI", "VITERBO" => "VT"
  }.freeze

  def up
    add_column :zone, :sigla, :string, limit: 2

    SIGLE.each do |provincia, sigla|
      execute "UPDATE zone SET sigla = '#{sigla}' WHERE provincia = '#{provincia.gsub("'", "''")}'"
    end
  end

  def down
    remove_column :zone, :sigla
  end
end
