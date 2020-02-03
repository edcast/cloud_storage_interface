require_relative '../test_helper'

class AwsS3FileUploaderTest < ActiveSupport::TestCase

  def setup
    @class = CloudStorageInterface::AwsS3Interface
    @inst = @class.new(
      aws_access_key_id: "foo",
      aws_secret_access_key: "bar"
    )

    @bucket_name = "foo"
    @key = "bar"
    @checksum = "1234"
    @file_path = "/fake.txt"

    @file = mock
    @stub_bucket = mock
    @stub_obj = mock
    @chainable = mock

    @file.stubs(:path).returns @file_path
    @inst.s3_resource.stubs(:bucket).with(@bucket_name).returns @stub_bucket
    @stub_bucket.stubs(:object).with(@key).returns @stub_obj
    @stub_obj.stubs(:etag).returns @checksum
  end

  def test_initialize
    assert @inst.s3_client.is_a?(Aws::S3::Client)
    assert @inst.s3_resource.is_a?(Aws::S3::Resource)
  end

  def test_upload_file
    opts = { multipart_threshold: 100.megabytes }

    @stub_obj.expects(:upload_file).with(@file_path, **opts)

    result = @inst.upload_file(
      bucket_name: @bucket_name,
      key: @key,
      file: @file,
      **opts
    )
    assert_equal({checksum: @checksum}, result)
  end

  def test_presigned_url
    expires_in = 10.minutes.to_i
    stub_url = "http://foo.bar.csv"

    result = @inst.presigned_url(
      bucket_name: @bucket_name,
      key: @key,
      expires_in: expires_in,
      response_content_type: 'application/csv'
    )

    path, params_str = result.split("?")
    params = CGI.parse params_str

    %w{
      X-Amz-Algorithm X-Amz-Credential    X-Amz-Date
      X-Amz-Expires   X-Amz-SignedHeaders X-Amz-Signature
    }.each { |key| assert params.key? key }
  end

  def test_delete_file
    @stub_obj.expects(:delete)
    assert_nil @inst.delete_file!(bucket_name: @bucket_name, key: @key)
  end

  def test_file_exists?
    @stub_obj.expects(:exists?).returns true
    assert @inst.file_exists?(bucket_name: @bucket_name, key: @key)
  end

  def test_list_objects
    times = [Time.now, Time.now + 1.hour]
    opts = { prefix: "pre" }
    stub_objs = %w{a b}.map.with_index do |key, idx|
      OpenStruct.new(
        key: key,
        last_modified: times[idx]
      )
    end

    @inst.s3_client.
      expects(:list_objects).
      with(bucket: @bucket_name, **opts).
      returns(OpenStruct.new(contents: stub_objs))

    result = @inst.list_objects(bucket_name: @bucket_name, **opts)

    assert_equal(
      [
        {key: 'a', last_modified: times[0]},
        {key: 'b', last_modified: times[1]}
      ],
      result
    )
  end

  def test_public_url
    expected = "https://#{@bucket_name}.s3.amazonaws.com/#{@key}"
    assert_equal expected, @inst.public_url(bucket_name: @bucket_name, key: @key)
  end

  def test_presigned_post
    presigned_post_opts = {
      success_action_status: "201",
      acl: "public-read"
    }

    stub_presigned_post = OpenStruct.new(
      fields: [{foo: "bar"}],
      url: "http://some.host.com"
    )

    @stub_bucket.
      expects(:presigned_post).
      with(key: @key, content_type_starts_with: '', **presigned_post_opts).
      returns(stub_presigned_post)

    expected = {
      fields: stub_presigned_post.fields,
      url: { host: "some.host.com" }
    }
    assert_equal expected, @inst.presigned_post(
      bucket_name: @bucket_name,
      key: @key,
      **presigned_post_opts
    )
  end

end