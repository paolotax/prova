namespace :storage do
  PUBLIC_ATTACHMENTS = {
    "Libro" => %w[copertina],
    "EdizioneTitolo" => %w[copertina]
  }.freeze

  desc "Reconcile S3 visibility: shared covers public, every other blob private"
  task reconcile_visibility: :environment do
    private_service = ActiveStorage::Blob.services.fetch("amazon")
    public_service = ActiveStorage::Blob.services.fetch("amazon_public")
    abort "The amazon service is not S3" unless private_service.class.name == "ActiveStorage::Service::S3Service"
    abort "The amazon_public service is not S3" unless public_service.class.name == "ActiveStorage::Service::S3Service"

    apply = ActiveModel::Type::Boolean.new.cast(ENV["APPLY"])
    counts = Hash.new(0)
    failures = 0

    ActiveStorage::Blob.includes(:attachments).find_each do |blob|
      attachments = blob.attachments.to_a
      public_asset = attachments.any? && attachments.all? do |attachment|
        PUBLIC_ATTACHMENTS.fetch(attachment.record_type, []).include?(attachment.name)
      end
      target = public_asset ? "amazon_public" : "amazon"
      counts[target] += 1
      next unless apply

      service = public_asset ? public_service : private_service
      service.client.client.put_object_acl(
        bucket: service.bucket.name,
        key: blob.key,
        acl: public_asset ? "public-read" : "private"
      )
      blob.update_column(:service_name, target) unless blob.service_name == target
    rescue Aws::S3::Errors::NoSuchKey
      failures += 1
      warn "Missing S3 object for blob #{blob.id}"
    rescue Aws::S3::Errors::ServiceError => error
      failures += 1
      warn "S3 error for blob #{blob.id}: #{error.class}"
    end

    puts "Classification: #{counts['amazon_public']} public covers, #{counts['amazon']} private blobs"
    puts(apply ? "ACLs and service names updated" : "Dry run only; re-run with APPLY=true to update production")
    abort "#{failures} objects could not be updated" if failures.positive?
  end
end
