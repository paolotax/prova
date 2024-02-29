# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

require 'faker'


u = User.find_by_name("paolotax")

# if u
#   100.times do |i|
#     u.appunti.create!(nome: Faker::BossaNova.artist, body: Faker::BossaNova.song, email: Faker::Internet.email, telefono: Faker::PhoneNumber.cell_phone, stato: "nuovo")
#   end
# end

if u
  50.times do |i|
    u.appunti.create!(nome: Faker::Cannabis.strain, body: Faker::Cannabis.buzzword )
  end
end