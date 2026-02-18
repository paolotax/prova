class DownloadsController < ApplicationController
  skip_before_action :authenticate, only: :extension

  def extension
    send_file Rails.root.join("lib", "assets", "whatsapp-scagnozz-extension.zip"),
      filename: "whatsapp-scagnozz-extension.zip",
      type: "application/zip"
  end
end
