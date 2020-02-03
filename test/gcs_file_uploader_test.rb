require_relative '../test_helper.rb'

class GcsFileUploaderTest < ActiveSupport::TestCase

  def setup
    @class = CloudStorageInterface::GcpGcsInterface

    # Need to mock out Google::Cloud::Storage.new so we can instantiate a client
    @stub_gcs_client = mock
    Google::Cloud::Storage.stubs(:new).with(
      project: @class::PROJECT_ID
    ).returns @stub_gcs_client

    # Now we can instantiate a client
    @inst = @class.new

    @bucket_name = "foo"
    @key = "bar"
    @other_key = "asd"
    @file_path = "/fake.txt"
    @prefix = "pre"

    @file = mock
    @stub_bucket = mock
    @stub_obj = mock

    @inst.gcs_client.stubs(:bucket).with(@bucket_name, {}).returns @stub_bucket
    @inst.gcs_client.stubs(:bucket).with(@bucket_name, prefix: @prefix).returns @stub_bucket
    @file.stubs(:path).returns @file_path
    @stub_bucket.stubs(:file).with(@key).returns @stub_obj
    @stub_bucket.stubs(:file).with(@other_key).returns nil
  end

  def test_initialize
    assert_equal @stub_gcs_client, @inst.gcs_client
  end

  def test_upload_file
    @stub_bucket.
      expects(:create_file).
      with(@file_path, @key, multipart_threshold: 100.megabytes).
      returns OpenStruct.new(crc32c: "foo")

    result = @inst.upload_file(
      bucket_name: @bucket_name,
      key: @key,
      file: @file,
      multipart_threshold: 100.megabytes # This option is ignored for GCS
    )

    assert_equal({checksum: "foo"}, result)
  end

  def test_presigned_url
    stub_url = "http://fake.presigned.csv"
    expires_in = 10.minutes.to_i
    @stub_obj_list = %w{a b}.map { |key| OpenStruct.new(key: key) }
    @stub_obj.expects(:signed_url).with(expires: expires_in).returns stub_url

    assert_equal stub_url, @inst.presigned_url(
      bucket_name: @bucket_name,
      key: @key,
      expires_in: expires_in,
      response_content_type: 'application/csv'
    )
  end

  def test_delete_file
    @stub_obj.expects(:delete)

    assert_nil @inst.delete_file!(bucket_name: @bucket_name, key: @key)
  end

  def test_file_exists?
    assert @inst.file_exists?(bucket_name: @bucket_name, key: @key)
    refute @inst.file_exists?(bucket_name: @bucket_name, key: @other_key)
  end

  def test_list_objects
    times = [Time.now, Time.now + 1.hour]
    opts = { prefix: "pre" }
    stub_objs = %w{a b}.map.with_index do |key, idx|
      OpenStruct.new(
        name: key,
        updated_at: times[idx]
      )
    end

    @stub_bucket.
      expects(:files).
      returns(stub_objs)

    expected = stub_objs.map.with_index do |obj, idx|
      { key: obj.name, content_type: nil, last_modified: times[idx] }
    end

    assert_equal expected, @inst.list_objects(
      bucket_name: @bucket_name,
      prefix: @prefix
    )
  end

  def test_public_url
    expected = "https://storage.googleapis.com/#{@bucket_name}/#{@key}"
    assert_equal expected, @inst.public_url(bucket_name: @bucket_name, key: @key)
  end

  def test_presigned_post
    now = Time.now
    Time.stubs(:now).returns now

    @stub_presigned_post = OpenStruct.new(
      # GCS Escapes ${filename}. We are checking that it gets unescaped
      # before being returned by our presigned_post method
      fields: {key: "$%7Bfilename%7D"},
      url: "https://foo.com"
    )

    acl = "public_read"
    success_action_status = "201"

    policy = {
      expiration: (now + 1.hour).iso8601,
      conditions: [
        ["starts-with", "$key", "" ],
        ["starts-with", "$Content-Type", "" ],
        { acl: acl },
        { success_action_status: success_action_status }
      ]
    }

    @stub_bucket.
      stubs(:post_object).
      with(@key, policy: policy).
      returns @stub_presigned_post

    expected = {
      url: { host: URI.parse(@stub_presigned_post.url).host },
      fields: {
        acl: acl,
        success_action_status: success_action_status,
        key: "${filename}"
      }
    }

    actual = @inst.presigned_post(
      bucket_name: @bucket_name,
      key: @key,
      acl: acl,
      success_action_status: success_action_status
    )

    assert_equal expected, actual
  end
end
