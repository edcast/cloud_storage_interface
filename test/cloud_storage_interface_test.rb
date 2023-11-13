require_relative '../test_helper.rb'

class CloudStorageInterfaceTest < ActiveSupport::TestCase

  def setup
    @class = CloudStorageInterface::AbstractInterface
  end

  def test_cannot_be_instantiated_directly
    e = assert_raise(RuntimeError) do
      @class.new
    end
    assert e.message.include?("Do not use this class directly")
  end

  def test_with_tempfile_static_method
    text = "foo\nbar"
    path = nil
    test_blk = -> (file) do
      assert File.exist?(file.path)
      path = file.path
      assert_equal text, File.read(file)
    end
    CloudStorageInterface.with_tempfile(text, &test_blk)
    refute File.exist? path
  end

end