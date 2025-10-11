# == Schema Information
#
# Table name: import_scuole
#
#  id                                        :bigint           not null, primary key
#  ANNOSCOLASTICO                            :string
#  AREAGEOGRAFICA                            :string
#  CAPSCUOLA                                 :string
#  CODICECOMUNESCUOLA                        :string
#  CODICEISTITUTORIFERIMENTO                 :string
#  CODICESCUOLA                              :string
#  DENOMINAZIONEISTITUTORIFERIMENTO          :string
#  DENOMINAZIONESCUOLA                       :string
#  DESCRIZIONECARATTERISTICASCUOLA           :string
#  DESCRIZIONECOMUNE                         :string
#  DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA :string
#  INDICAZIONESEDEDIRETTIVO                  :string
#  INDICAZIONESEDEOMNICOMPRENSIVO            :string
#  INDIRIZZOEMAILSCUOLA                      :string
#  INDIRIZZOPECSCUOLA                        :string
#  INDIRIZZOSCUOLA                           :string
#  PROVINCIA                                 :string
#  REGIONE                                   :string
#  SEDESCOLASTICA                            :string
#  SITOWEBSCUOLA                             :string
#  geocoded                                  :boolean
#  latitude                                  :float
#  longitude                                 :float
#  slug                                      :string
#  created_at                                :datetime         not null
#  updated_at                                :datetime         not null
#
# Indexes
#
#  idx_on_DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA_20c3bcb01a  (DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA)
#  index_import_scuole_on_CODICESCUOLA                          (CODICESCUOLA) UNIQUE
#  index_import_scuole_on_PROVINCIA                             (PROVINCIA)
#  index_import_scuole_on_slug                                  (slug) UNIQUE
#

require "test_helper"

class ImportScuolaTest < ActiveSupport::TestCase
  # test "the truth" do
  #   assert true
  # end
end
