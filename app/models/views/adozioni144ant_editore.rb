# == Schema Information
#
# Table name: view_adozioni144ant_editori
#
#  regione                          :string
#  provincia                        :string
#  editore                          :string
#  mercato                          :text
#  in_provincia                     :bigint
#  dell_editore_in_provincia        :bigint
#  percentuale_editore_in_provincia :decimal(, )
#  differenza_media_nazionale       :decimal(, )
#  dell_editore_in_italia           :bigint
#  percentuale_editore_in_italia    :decimal(, )
#  dell_editore_in_regione          :bigint
#  percentuale_editore_in_regione   :decimal(, )
#
class Views::Adozioni144antEditore < ApplicationRecord

end
