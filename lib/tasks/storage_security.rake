namespace :storage do
  desc "Make every Active Storage S3 object private (set APPLY=true to execute)"
  task make_private: :environment do
    service = ActiveStorage::Blob.service
    abort "Active Storage is not using S3" unless service.class.name == "ActiveStorage::Service::S3Service"

    apply = ActiveModel::Type::Boolean.new.cast(ENV["APPLY"])
    total = ActiveStorage::Blob.count
    changed = 0
    failed = 0

    puts "Active Storage blobs: #{total}"
    unless apply
      puts "Dry run only. Re-run with APPLY=true to set every object ACL to private."
      next
    end

    client = service.client.client
    bucket = service.bucket.name

    ActiveStorage::Blob.find_each do |blob|
      client.put_object_acl(bucket: bucket, key: blob.key, acl: "private")
      changed += 1
      puts "Updated #{changed}/#{total}" if (changed % 100).zero?
    rescue Aws::S3::Errors::NoSuchKey
      failed += 1
      warn "Missing S3 object for blob #{blob.id}"
    rescue Aws::S3::Errors::ServiceError => error
      failed += 1
      warn "S3 error for blob #{blob.id}: #{error.class}"
    end

    puts "Completed: #{changed} private, #{failed} failed"
    abort "Some objects could not be made private" if failed.positive?
  end
end
