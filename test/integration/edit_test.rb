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

# Editing rewrites what a conversation says, so the rules matter more than
# the UI: only your own, only text, never empty, and never someone else's.
class EditMessageTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  def setup
    Message.delete_all
    User.delete_all

    @admin = User.create!(username: "qwert", password: "secret1", password_confirmation: "secret1")
    @alice = User.create!(username: "alice", password: "secret1", password_confirmation: "secret1")

    @mine   = Message.create!(user: @admin, recipient_id: @alice.id, content: "first draft")
    @theirs = Message.create!(user: @alice, recipient_id: @admin.id, content: "not yours to touch")
    @photo  = Message.create!(user: @admin, recipient_id: @alice.id, content: "Image",
                              image: "https://res.cloudinary.com/demo/x.jpg")

    login(@admin)
  end

  def login(user)
    post logout_path
    post auth_path, params: { username: user.username, password: "secret1" }
  end

  def edit(message_id, text)
    patch "/dash/msg/#{message_id}",
          params: { encrypted_data: Base64.encode64(text) }.to_json,
          headers: { "Content-Type" => "application/json", "Accept" => "application/json" }
  end

  test "a user can rewrite their own message" do
    edit(@mine.id, "second draft")

    assert_response :success
    assert JSON.parse(response.body)["ok"]

    @mine.reload
    assert_equal "second draft", @mine.content
    assert @mine.edited_at.present?, "the edit was not stamped"
  end

  test "an unchanged message is left exactly as it was" do
    before = @mine.updated_at
    edit(@mine.id, "first draft")

    assert_response :success
    body = JSON.parse(response.body)
    assert body["ok"]
    assert body["unchanged"]

    @mine.reload
    assert_nil @mine.edited_at, "an unchanged message should not be marked edited"
    assert_equal before.to_i, @mine.updated_at.to_i
  end

  test "someone else's message cannot be touched" do
    edit(@theirs.id, "rewritten by the wrong person")

    assert_response :forbidden
    assert_equal "not yours to touch", @theirs.reload.content
  end

  test "a picture cannot be edited into text" do
    edit(@photo.id, "sneaky caption")

    assert_response :unprocessable_entity
    assert_equal "Image", @photo.reload.content
    assert @photo.image.present?
  end

  test "a message cannot be emptied" do
    edit(@mine.id, "   ")

    assert_response :unprocessable_entity
    assert_equal "first draft", @mine.reload.content
  end

  test "a normal user cannot edit the admin's message" do
    login(@alice)
    edit(@mine.id, "alice was here")

    assert_response :forbidden
    assert_equal "first draft", @mine.reload.content
  end

  test "a normal user can still edit their own" do
    login(@alice)
    edit(@theirs.id, "alice rewrote her own")

    assert_response :success
    assert_equal "alice rewrote her own", @theirs.reload.content
  end

  test "editing never moves a message to a different conversation" do
    edit(@mine.id, "still for alice")

    @mine.reload
    assert_equal @admin.id, @mine.user_id
    assert_equal @alice.id, @mine.recipient_id
  end
end
