# == Schema Information
#
# Table name: view_adozioni144ant_editori
#
#  dell_editore_in_italia           :bigint
#  dell_editore_in_provincia        :bigint
#  dell_editore_in_regione          :bigint
#  differenza_media_nazionale       :decimal(, )
#  editore                          :string
#  in_provincia                     :bigint
#  mercato                          :text
#  percentuale_editore_in_italia    :decimal(, )
#  percentuale_editore_in_provincia :decimal(, )
#  percentuale_editore_in_regione   :decimal(, )
#  provincia                        :string
#  regione                          :string
#
# Indexes
#
#  index_view_adozioni144ant_editori_on_editore                (editore)
#  index_view_adozioni144ant_editori_on_provincia_and_editore  (provincia,editore) UNIQUE
#

class Views::Adozioni144antEditore < ApplicationRecord

end
