require "test_helper"

# This box has minitest 6 against Rails 7.1, whose Rails::LineFiltering#run
# takes (reporter, options) while minitest 6 calls it with three arguments, so
# `rails test` dies before running anything. That is a pre-existing problem
# with the installed gems, not with these tests. Neutralise the filter so the
# suite can run; it only costs the ability to filter by line number.
if defined?(Rails::LineFiltering)
  module Rails
    module LineFiltering
      def run(*args, **kwargs, &block)
        super
      end
    end
  end
end

# Switching conversations is the one place where getting it wrong means a
# message reaches the wrong person, so these tests care about routing, not UI.
class ConversationSwitchingTest < ActionDispatch::IntegrationTest
  # test/fixtures/users.yml names a `password` column that does not exist, so
  # `fixtures :all` in test_helper blows up before any test runs. Also
  # pre-existing. These tests build exactly the rows they need anyway.
  self.fixture_table_names = []

  def setup
    Message.delete_all
    User.delete_all

    @admin = User.create!(username: "qwert", password: "secret1", password_confirmation: "secret1")
    @alice = User.create!(username: "alice", password: "secret1", password_confirmation: "secret1")
    @bob   = User.create!(username: "bob",   password: "secret1", password_confirmation: "secret1")

    @alice_msg = Message.create!(user: @alice, recipient_id: @admin.id, content: "alice to admin")
    @admin_to_alice = Message.create!(user: @admin, recipient_id: @alice.id, content: "admin to alice")
    @bob_msg   = Message.create!(user: @bob,   recipient_id: @admin.id, content: "bob to admin")
  end

  def login(user)
    post auth_path, params: { username: user.username, password: "secret1" }
  end

  def send_message(text, reply_to: nil)
    post "/dash/msg", params: {
      encrypted_data: Base64.encode64(text),
      reply_to_id: reply_to
    }
  end

  # content is encrypted without a deterministic key, so it cannot be matched
  # in SQL - the comparison has to happen after Rails decrypts it.
  def count_said(text, from: nil, to: nil)
    Message.where(user_id: (from || @admin).id, recipient_id: (to || @alice).id)
           .count { |m| m.content == text }
  end

  # ---------------------------------------------------------------- switching

  test "admin switching stores the choice in the session and reports it back" do
    login(@admin)

    get switch_user_path(selected_user_id: @alice.id), as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert body["ok"], "expected the switch to be accepted"
    assert_equal @alice.id, body["selected_user_id"]
    assert_equal "alice", body["username"]

    get switch_user_path(selected_user_id: @bob.id), as: :json
    assert_equal @bob.id, JSON.parse(response.body)["selected_user_id"]
  end

  test "the conversation on screen is only the selected pair" do
    login(@admin)

    get switch_user_path(selected_user_id: @alice.id), as: :json
    get dashboard_path
    assert_response :success
    assert_match "alice to admin", response.body
    assert_match "admin to alice", response.body
    refute_match "bob to admin", response.body, "bob's message leaked into alice's conversation"

    get switch_user_path(selected_user_id: @bob.id), as: :json
    get dashboard_path
    assert_match "bob to admin", response.body
    refute_match "alice to admin", response.body, "alice's message leaked into bob's conversation"
  end

  # ------------------------------------------------------- where a send lands

  test "a message sent after switching goes to the newly selected user" do
    login(@admin)

    get switch_user_path(selected_user_id: @alice.id), as: :json
    send_message("for alice")
    assert_equal @alice.id, Message.order(:id).last.recipient_id

    get switch_user_path(selected_user_id: @bob.id), as: :json
    send_message("for bob")
    last = Message.order(:id).last
    assert_equal @bob.id, last.recipient_id
    assert_equal @admin.id, last.user_id
  end

  test "switching twice in a row never leaves a send pointed at the old user" do
    login(@admin)

    [@alice, @bob, @alice, @bob].each_with_index do |target, i|
      get switch_user_path(selected_user_id: target.id), as: :json
      # Unique text each time: identical consecutive content is suppressed,
      # which is a separate behaviour covered by its own test below.
      send_message("to #{target.username} #{i}")
      assert_equal target.id, Message.order(:id).last.recipient_id,
                   "a message landed on the wrong conversation after switching to #{target.username}"
    end
  end

  # ------------------------------------------------------------- the guards

  test "a normal user cannot switch conversations" do
    login(@alice)

    get switch_user_path(selected_user_id: @bob.id), as: :json
    send_message("alice speaking")

    last = Message.order(:id).last
    assert_equal @admin.id, last.recipient_id, "a normal user managed to address someone other than the admin"
    assert_equal @alice.id, last.user_id
  end

  test "a normal user only ever sees their own conversation with the admin" do
    login(@alice)
    get dashboard_path

    assert_match "alice to admin", response.body
    refute_match "bob to admin", response.body, "alice can read bob's messages"
  end

  test "a normal user cannot read another conversation by passing an id" do
    login(@alice)

    get switch_user_path(selected_user_id: @bob.id), as: :json
    get dashboard_path

    refute_match "bob to admin", response.body, "an id in the URL exposed another conversation"
  end

  # --------------------------------------------------------------- integrity

  test "every stored message has both ends set" do
    login(@admin)
    get switch_user_path(selected_user_id: @alice.id), as: :json
    send_message("hello")

    Message.find_each do |m|
      assert m.user_id.present?,      "message #{m.id} has no sender"
      assert m.recipient_id.present?, "message #{m.id} has no recipient"
    end
  end

  test "no conversation exists that does not involve the admin" do
    login(@admin)
    get switch_user_path(selected_user_id: @alice.id), as: :json
    send_message("hello")

    strays = Message.where.not(user_id: @admin.id).where.not(recipient_id: @admin.id)
    assert_equal 0, strays.count, "found messages between two non-admin users"
  end

  # ------------------------------------------------- repeated text delivery

  test "the same text can be sent again once it is not an instant double tap" do
    login(@admin)
    get switch_user_path(selected_user_id: @alice.id), as: :json

    send_message("ok")
    first = Message.order(:id).last
    assert_equal "ok", first.content

    # Pretend some time passed, the way it would between two real messages.
    first.update_column(:created_at, 10.seconds.ago)

    send_message("ok")
    assert_equal 2, count_said("ok"),
                 "sending the same word twice lost the second one"
  end

  test "an instant double submit of the same text still only stores one" do
    login(@admin)
    get switch_user_path(selected_user_id: @alice.id), as: :json

    send_message("double")
    send_message("double")

    assert_equal 1, count_said("double"),
                 "a double submit created two copies"
  end
end
