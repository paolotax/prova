# == Schema Information
#
# Table name: view_adozioni144ant_editori
#
#  regione                          :string
#  provincia                        :string
#  editore                          :string
#  mercato                          :text
#  in_provincia                     :integer
#  dell_editore_in_provincia        :integer
#  percentuale_editore_in_provincia :decimal(, )
#  differenza_media_nazionale       :decimal(, )
#  dell_editore_in_italia           :integer
#  percentuale_editore_in_italia    :decimal(, )
#  dell_editore_in_regione          :integer
#  percentuale_editore_in_regione   :decimal(, )
#
# Indexes
#
#  index_view_adozioni144ant_editori_on_editore                (editore)
#  index_view_adozioni144ant_editori_on_provincia_and_editore  (provincia,editore) UNIQUE
#

class Views::Adozioni144antEditore < ApplicationRecord

end
