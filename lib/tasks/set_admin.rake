namespace :user do
  desc "Set qwert as admin user"
  task set_admin: :environment do
    user = User.find_by(username: "qwert")
    if user
      user.update(is_admin: true)
      puts "✓ User 'qwert' is now set as admin"
    else
      puts "✗ User 'qwert' not found"
    end
  end

  desc "List all users with admin status"
  task list_users: :environment do
    puts "\nUsers in the system:"
    puts "-" * 50
    User.all.each do |user|
      admin_badge = user.admin? ? "👑 ADMIN" : ""
      puts "#{user.username.ljust(20)} | ID: #{user.id.to_s.ljust(5)} #{admin_badge}"
    end
    puts "-" * 50
  end
end
