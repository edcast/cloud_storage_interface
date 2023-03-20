# frozen_string_literal: true

require 'aws-sdk'

class CloudStorageInterface::AwsS3Interface

  # Little confusing, the aws sdk v2 uses two different APIs
  attr_reader :s3_client, :s3_resource

  def initialize(**opts)
    aws_access_key_id = (
      opts[:aws_access_key_id] ||
      ENV['AWS_ACCESS_KEY_ID'] ||
      (Settings.aws_access_key_id if defined?(Settings))
    )

    aws_secret_access_key = (
      opts[:aws_secret_access_key] ||
      ENV['AWS_SECRET_ACCESS_KEY'] ||
      (Settings.aws_secret_access_key if defined?(Settings))
    )

    Aws.config.update({
       credentials: Aws::Credentials.new(
        aws_access_key_id, aws_secret_access_key
      )
    })

    s3_region = ENV['AWS_REGION'] || 'us-east-1'
    @s3_client = Aws::S3::Client.new(region: s3_region)

    @s3_resource = Aws::S3::Resource.new(
      client: @s3_client,
      region: s3_region
    )
  end

  def upload_file(bucket_name:, key:, file:, **opts)
    bucket_obj = s3_resource.bucket(bucket_name).object(key)
    bucket_obj.upload_file(file.path, **opts)

    return {
      checksum: bucket_obj.etag
    }
  end

  # returns true or false
  def download_file(bucket_name:, key:, local_path:)
    s3_resource.bucket(bucket_name).object(key).download_file(local_path)
  end

  # Note, expires_in cannot be more than 1 week due to S3 restrictions
  def presigned_url(bucket_name:, key:, expires_in:, response_content_type:)
    signer = Aws::S3::Presigner.new(client: @s3_client)
    signer.presigned_url(:get_object, {
      bucket: bucket_name,
      key: key,
      expires_in: expires_in,
      response_content_type: response_content_type
    })
  end

  def delete_file!(bucket_name:, key:)
    s3_resource.bucket(bucket_name).object(key).delete
    nil
  end

  def file_exists?(bucket_name:, key:)
    s3_resource.bucket(bucket_name).object(key).exists?
  end

  # This is performing n+1 network calls. We need content type of the s3 object in LXP
  # A feature change required on LXP end to remove this call.
  def list_objects(bucket_name:, fetch_object_content_type: false, **opts)
    response_objects = s3_client.list_objects(bucket: bucket_name, **opts)
    formatted_objects = response_objects.contents.map do |obj|
      metadata = {
        key: obj.key,
        last_modified: obj.last_modified,
      }
      if fetch_object_content_type
        metadata.merge!(object_details(bucket_name: bucket_name, key: obj.key))
      end
      metadata
    end
  end

  # this is an unsigned static url
  # It will only work for objects that have public read permission
  def public_url(bucket_name:, key:)
    "https://#{bucket_name}.s3.amazonaws.com/#{key}"
  end

  def presigned_post(bucket_name:, key:, **opts)
    response = s3_resource.
      bucket(bucket_name).
      presigned_post(key: key, content_type_starts_with: '', **opts)

    {
      fields: response.fields,
      url:    { host: URI.parse(response.url).host }
    }
  end

  # return all the object properties.
  # REFER HERE https://docs.aws.amazon.com/sdkforruby/api/Aws/S3/Object.html
  def object_details(bucket_name:, key:)
    s3_client.get_object(bucket: bucket_name, key: key).to_h
  end

end
