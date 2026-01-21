namespace :messages do
  desc "Backfill recipient_id for existing messages"
  task backfill_recipients: :environment do
    puts "Starting to backfill recipient_id for existing messages..."
    
    admin = User.admin_user
    total_messages = Message.where(recipient_id: nil).count
    
    if total_messages.zero?
      puts "✓ No messages need backfilling. All messages have recipient_id set."
      next
    end
    
    puts "Found #{total_messages} messages without recipient_id"
    updated_count = 0
    
    Message.where(recipient_id: nil).find_each do |message|
      # Determine recipient based on sender
      if message.user.admin?
        # If admin sent it, we can't determine recipient from old data
        # Set to nil or first non-admin user (best guess)
        recipient = User.where.not(id: message.user_id).first
      else
        # If regular user sent it, recipient is admin
        recipient = admin
      end
      
      if recipient && message.update(recipient_id: recipient.id)
        updated_count += 1
        print "." if updated_count % 10 == 0
      end
    end
    
    puts "\n✓ Backfilled #{updated_count} out of #{total_messages} messages"
    puts "\nNote: Messages sent by admin were assigned to the first available user."
    puts "This is a best-guess. Future messages will have explicit recipients."
  end

  desc "Show message statistics"
  task stats: :environment do
    total = Message.count
    with_recipient = Message.where.not(recipient_id: nil).count
    without_recipient = Message.where(recipient_id: nil).count
    
    puts "\n" + "=" * 50
    puts "MESSAGE STATISTICS"
    puts "=" * 50
    puts "Total messages:              #{total}"
    puts "With recipient_id:           #{with_recipient} (#{with_recipient * 100 / total}%)" if total > 0
    puts "Without recipient_id:        #{without_recipient} (#{without_recipient * 100 / total}%)" if total > 0
    puts "=" * 50
    
    if without_recipient > 0
      puts "\n⚠️  Run 'rails messages:backfill_recipients' to fix"
    else
      puts "\n✓ All messages have proper recipients!"
    end
    puts ""
  end
end
