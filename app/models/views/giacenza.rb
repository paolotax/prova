# == Schema Information
#
# Table name: view_giacenze
#
#  carichi     :bigint
#  codice_isbn :string
#  ordini      :bigint
#  titolo      :string
#  vendite     :bigint
#  libro_id    :bigint
#  user_id     :bigint
#

class Views::Giacenza < ApplicationRecord 

  belongs_to :user, class_name: "User", foreign_key: "user_id"
  belongs_to :libro, class_name: "Libro", primary_key: "id", foreign_key: "id"


end
