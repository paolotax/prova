json.extract! qrcode, :id, :description, :url, :qrcodable_id, :qrcodable_type, :created_at, :updated_at
json.url qrcode_url(qrcode, format: :json)
