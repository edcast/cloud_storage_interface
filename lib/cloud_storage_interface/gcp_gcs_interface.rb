# frozen_string_literal: true

require "google/cloud/storage"

class CloudStorageInterface::GcpGcsInterface

    class BucketNotFoundError < StandardError; end
    class ObjectNotFoundError < StandardError; end

    PROJECT_ID = ENV.fetch("GCP_PROJECT_ID",'gcp-us-central1-prod')

    attr_reader :gcs_client

    def initialize(**opts)
      @gcs_client = Google::Cloud::Storage.new project: PROJECT_ID
    end

    # NOTE: we don't support upload_opts (multipart_threshold) for GCS.
    # we also don't return the checksum here.
    # NOTE: This will overwrite the file if the key already exists
    def upload_file(bucket_name:, key:, file:, **opts)
      if opts[:acl] && opts[:acl]&.to_s == 'public-read'
        opts[:acl] = :public_read
      end

      result = get_bucket!(bucket_name).create_file file.path, key, **opts
      return {
        checksum: result.crc32c
      }
    end

    def download_file(bucket_name:, key:, local_path:)
      get_object!(bucket_name, key).download(local_path)
      File.exists?(local_path) # emulating the return val of the S3 API
    end

    def presigned_url(bucket_name:, key:, expires_in:)
      get_object!(bucket_name, key).signed_url(expires: expires_in)
    end

    def delete_file!(bucket_name:, key:)
      get_object!(bucket_name, key).delete
      nil
    end

    # will still raise an error if the bucket doesnt exist
    def file_exists?(bucket_name:, key:)
      !!get_bucket!(bucket_name).file(key)
    end

    def list_objects(bucket_name:, prefix: "", **opts)
      get_bucket!(bucket_name, **opts).files(prefix: prefix).map do |f|
        {
          key: f.name,
          content_type: obj.content_type,
          last_modified: f.updated_at
        }
      end
    end

    # this is an unsigned static url
    # It will only work for objects that have public read permission
    def public_url(bucket_name:, key:)
      "https://storage.googleapis.com/#{bucket_name}/#{key}"
    end

    # https://cloud.google.com/storage/docs/xml-api/post-object#usage_and_examples
    # https://www.rubydoc.info/gems/google-cloud-storage/1.0.1/Google/Cloud/Storage/Bucket:post_object
    def presigned_post(bucket_name:, key:, acl:, success_action_status:, expiration: nil)
      expiration ||= (Time.now + 1.hour).iso8601

      policy = {
        expiration: expiration,
        conditions: [
          ["starts-with", "$key", "" ],
          ["starts-with", "$Content-Type", "" ],
          { acl: acl },
          { success_action_status: success_action_status }
        ]
      }

      post_obj = get_bucket!(bucket_name).post_object(key, policy: policy)

      # We might want to remove this transformation from here, S3 adapter,
      # and the browser - it's not necessary.
      url_obj = { host: URI.parse(post_obj.url).host }

      # Wierd inconsistency between S3 and GCS APIs.
      # GCS escapes ${filename} in the key before returning it in the fields.
      # We need to manually unescape it.
      post_obj.fields[:key] = URI.unescape(post_obj.fields[:key])

      # Have to manually merge in these fields
      fields = post_obj.fields.merge(
        acl: acl,
        success_action_status: success_action_status,
      )

      return { fields: fields, url: url_obj }
    end

    # Return file resource details. At the moment, we're including etag and content
    # type from GCS file object
    # REFER: https://googleapis.dev/ruby/google-cloud-storage/latest/Google/Cloud/Storage/File.html
    def object_details(bucket_name:, key:)
      file = get_object!(bucket_name, key)
      [:etag, :content_type].each_with_object({}) do |file_method, memo|
        memo[file_method] = file.send file_method
      end
    end

    private

    # Helper method to get a bucket.
    # Will raise an error if the bucket doesn't exist.
    def get_bucket!(bucket_name, **opts)
      bucket = gcs_client.bucket(bucket_name, **opts)
      return bucket if bucket
      raise BucketNotFoundError.new("Bucket \"#{bucket_name}\" not found")
    end

    # Helper method to get an object.
    # Will raise an error if the bucket or object doesn't exist.
    def get_object!(bucket_name, key, **opts)
      bucket = get_bucket!(bucket_name, **opts)
      obj = bucket.file(key)
      return obj if obj
      raise ObjectNotFoundError.new(
        "Object \"#{key}\" not found in bucket \"#{bucket.name}\""
      )
    end

end
