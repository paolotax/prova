# Since we changed active_storage_attachments.record_id to string (to support UUID models),
# we need to tell Active Storage about the column type change.
# Without this, PostgreSQL raises "operator does not exist: character varying = bigint"
# when joining attachments with models that still use bigint primary keys.

Rails.application.config.to_prepare do
  ActiveStorage::Attachment.class_eval do
    attribute :record_id, :string
  end
end
