# Message Filtering Fix

## Problem
All users were seeing messages that the admin sent to specific users, regardless of whether those messages were intended for them. This was a critical privacy issue.

## Root Cause
The `get_conversation_messages` method in `dashboard_controller.rb` was filtering messages only by `user_id` without checking `recipient_id`. This meant:
- If admin sent a message to User A, User B could also see it
- The query was: `Message.where(user_id: [user1.id, user2.id])`
- This returned ALL messages sent by either user, not just messages between them

## Solution
Updated the `get_conversation_messages` method to properly filter messages by both sender and recipient:

```ruby
def get_conversation_messages(user1, user2)
  return Message.none if user1.nil? || user2.nil?
  
  # Get messages between these two specific users only
  # Messages where user1 sent to user2 OR user2 sent to user1
  Message.where(
    "(user_id = ? AND recipient_id = ?) OR (user_id = ? AND recipient_id = ?)",
    user1.id, user2.id, user2.id, user1.id
  )
         .where.not(recipient_id: nil)  # Ensure recipient_id is set
         .recent_messages
         .unclear(user1&.last_clear_at)
         .order(created_at: "DESC")
end
```

Now the query ensures:
- User A only sees messages between User A and Admin
- User B only sees messages between User B and Admin
- Admin sees messages only for the selected user conversation

## Important: Old Messages

If you have existing messages in your database from before the `recipient_id` column was added, those messages will NOT show up until you run the backfill task.

### Check if you need to backfill:
```bash
rails messages:stats
```

### Run the backfill task if needed:
```bash
rails messages:backfill_recipients
```

This will:
- Set `recipient_id = admin` for all messages sent by regular users
- Set `recipient_id = first_user` for messages sent by admin (best guess)

## Security Note
Messages without `recipient_id` are intentionally excluded from display to prevent privacy leaks. This is a security feature, not a bug.

## Testing
1. Login as User A and send a message
2. Login as User B and send a message
3. Login as Admin, switch to User A - you should only see messages with User A
4. Switch to User B - you should only see messages with User B
5. Login as User A - you should only see your own messages with Admin, not User B's messages
