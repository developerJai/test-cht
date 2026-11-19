require "test_helper"

if defined?(Rails::LineFiltering)
  module Rails
    module LineFiltering
      def run(*args, **kwargs, &block)
        super
      end
    end
  end
end

# Uploading is the slow, failure-prone path, so these cover what the user
# actually hits: wrong type, too big, nothing chosen, and the happy case.
# Cloudinary itself is stubbed - the point is our handling, not their API.
class UploadTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  def setup
    Message.delete_all
    User.delete_all

    @admin = User.create!(username: "qwert", password: "secret1", password_confirmation: "secret1")
    @alice = User.create!(username: "alice", password: "secret1", password_confirmation: "secret1")

    post auth_path, params: { username: "qwert", password: "secret1" }
    get switch_user_path(selected_user_id: @alice.id), as: :json

    @uploaded = []
    Cloudinary::Uploader.define_singleton_method(:upload) do |file, **options|
      { "secure_url" => "https://res.cloudinary.com/demo/#{options[:folder]}/fake.jpg" }
    end
  end

  def teardown
    Cloudinary::Uploader.singleton_class.send(:remove_method, :upload) rescue nil
  end

  # A browser sends multipart/form-data and asks for JSON back. Posting
  # `as: :json` instead turns the file into a plain parameters hash, which is
  # not what the app ever receives.
  def upload(io, filename, type)
    post upload_img_path,
         params: { image: Rack::Test::UploadedFile.new(io, type, original_filename: filename) },
         headers: { "Accept" => "application/json" }
  end

  def tempfile(bytes, name)
    file = Tempfile.new(name)
    file.binmode
    file.write("x" * bytes)
    file.rewind
    file
  end

  test "a picture is stored and addressed to the open conversation" do
    assert_difference -> { Message.count }, 1 do
      upload(tempfile(1_000, "pic"), "pic.jpg", "image/jpeg")
    end

    assert_response :success
    assert JSON.parse(response.body)["ok"]

    msg = Message.order(:id).last
    assert_equal @alice.id, msg.recipient_id
    assert_equal @admin.id, msg.user_id
    assert_equal "Image", msg.content
    assert msg.image.present?
  end

  test "a video is labelled as one" do
    upload(tempfile(2_000, "clip"), "clip.mp4", "video/mp4")
    assert_response :success
    assert_equal "Video", Message.order(:id).last.content
  end

  # This used to raise: `cloud` was only assigned inside the image and video
  # branches, and the else did cloud["secure_url"] = nil on nil.
  test "an unsupported file is refused instead of crashing" do
    assert_no_difference -> { Message.count } do
      upload(tempfile(500, "notes"), "notes.txt", "text/plain")
    end

    assert_response :unprocessable_entity
    assert_match(/pictures and videos/i, JSON.parse(response.body)["error"])
  end

  test "a file over the limit is refused with the sizes spelled out" do
    oversize = DashboardController::MAX_IMAGE_BYTES + 1

    assert_no_difference -> { Message.count } do
      upload(tempfile(oversize, "big"), "big.jpg", "image/jpeg")
    end

    assert_response :unprocessable_entity
    error = JSON.parse(response.body)["error"]
    assert_match(/limit/i, error)
    assert_match(/MB/, error)
  end

  test "sending nothing says so rather than failing silently" do
    post upload_img_path, params: {}, headers: { "Accept" => "application/json" }
    assert_response :unprocessable_entity
    assert_match(/pick a file/i, JSON.parse(response.body)["error"])
  end

  test "a normal user can only ever send a file to the admin" do
    post logout_path
    post auth_path, params: { username: "alice", password: "secret1" }

    upload(tempfile(1_000, "pic"), "pic.jpg", "image/jpeg")
    assert_response :success

    msg = Message.order(:id).last
    assert_equal @admin.id, msg.recipient_id
    assert_equal @alice.id, msg.user_id
  end
end
