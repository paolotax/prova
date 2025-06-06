# == Schema Information
#
# Table name: import_scuole
#
#  id                                        :integer          not null, primary key
#  ANNOSCOLASTICO                            :string
#  AREAGEOGRAFICA                            :string
#  REGIONE                                   :string
#  PROVINCIA                                 :string
#  CODICEISTITUTORIFERIMENTO                 :string
#  DENOMINAZIONEISTITUTORIFERIMENTO          :string
#  CODICESCUOLA                              :string
#  DENOMINAZIONESCUOLA                       :string
#  INDIRIZZOSCUOLA                           :string
#  CAPSCUOLA                                 :string
#  CODICECOMUNESCUOLA                        :string
#  DESCRIZIONECOMUNE                         :string
#  DESCRIZIONECARATTERISTICASCUOLA           :string
#  DESCRIZIONETIPOLOGIAGRADOISTRUZIONESCUOLA :string
#  INDICAZIONESEDEDIRETTIVO                  :string
#  INDICAZIONESEDEOMNICOMPRENSIVO            :string
#  INDIRIZZOEMAILSCUOLA                      :string
#  INDIRIZZOPECSCUOLA                        :string
#  SITOWEBSCUOLA                             :string
#  SEDESCOLASTICA                            :string
#  created_at                                :datetime         not null
#  updated_at                                :datetime         not null
#  slug                                      :string
#  latitude                                  :float
#  longitude                                 :float
#  geocoded                                  :boolean
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
