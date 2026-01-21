# Unseen Message Counters for Admin

## Overview
The admin can now see a counter badge on each user's switch button showing how many unseen messages that user has sent. This helps the admin prioritize which conversations to check first.

## How It Works

### Message Seen Tracking
Each message has a `seen_by_admin_at` timestamp field:
- `NULL` = Message has NOT been seen by admin
- `DateTime` = Message WAS seen by admin at that time

### When Messages Are Marked as Seen
Messages are automatically marked as seen by admin when:
1. Admin switches to view a specific user's chat
2. The conversation loads in the chat window
3. All unseen messages from that user to admin are marked with `seen_by_admin_at = current_time`

### Counter Display
- Counters appear as **red badges** with numbers on user switch buttons
- Only show for users who have **unseen messages** (count > 0)
- Counter disappears when admin clicks the button (messages get marked as seen)
- Counter updates in **real-time** via Pusher when new messages arrive

## Visual Appearance

### User Button Without Unseen Messages
```
┌──────────────┐
│  john_doe    │
└──────────────┘
```

### User Button With Unseen Messages
```
┌──────────────────┐
│  john_doe  [ 3 ] │  ← Red pulsing badge showing 3 unseen messages
└──────────────────┘
```

## Database Schema

### Migration
```ruby
add_column :messages, :seen_by_admin_at, :datetime
add_index :messages, :seen_by_admin_at
add_index :messages, [:recipient_id, :seen_by_admin_at]
```

### Message Model Fields
- `seen_by_admin_at` (datetime) - When admin viewed this message
- Indexed for fast queries on unseen messages

## Implementation Details

### Backend (Controller)

#### Marking Messages as Seen
```ruby
def mark_messages_as_seen_by_admin(admin, sender_user)
  return unless admin.admin?
  
  # Find all unseen messages from sender_user to admin
  Message.where(user_id: sender_user.id, recipient_id: admin.id, seen_by_admin_at: nil)
         .update_all(seen_by_admin_at: Time.current)
end
```

Called automatically when admin loads a user's conversation in the `index` action.

#### Calculating Unseen Counts
```ruby
def calculate_unseen_counts_per_user(admin, users)
  counts = {}
  
  users.each do |user|
    count = Message.where(
      user_id: user.id,
      recipient_id: admin.id,
      seen_by_admin_at: nil
    ).count
    
    counts[user.id] = count if count > 0
  end
  
  counts
end
```

Returns a hash like: `{ 1 => 3, 5 => 7 }` meaning User #1 has 3 unseen, User #5 has 7 unseen.

### Frontend (View)

#### User Button with Counter
```erb
<% @all_users.each do |user| %>
  <% unseen_count = @unseen_counts&.fetch(user.id, 0) || 0 %>
  <%= link_to switch_user_path(selected_user_id: user.id), 
      data: { user_id: user.id },
      class: "inline-flex items-center px-3 py-2 text-sm font-semibold rounded-md" do %>
    <%= user.username %>
    <% if unseen_count > 0 %>
      <span class="unseen-badge ml-2 inline-flex items-center justify-center px-2 py-0.5 text-xs font-bold text-white bg-red-500 rounded-full" data-count="<%= unseen_count %>">
        <%= unseen_count %>
      </span>
    <% end %>
  <% end %>
<% end %>
```

### Frontend (JavaScript - Pusher)

#### Real-Time Counter Updates
```javascript
channel.bind('my-event', function(data) {
  const isAdmin = <%= @current_user&.admin? || false %>;
  const selectedUserId = <%= session[:selected_user_id] || 'null' %>;
  const senderId = data.sender_id;
  
  if (isAdmin && selectedUserId && senderId) {
    if (parseInt(selectedUserId) === parseInt(senderId)) {
      // Message from active user - reload messages
      indicator.value = "true";
    } else {
      // Message from inactive user - increment counter
      const userButton = document.querySelector(`a[data-user-id="${senderId}"]`);
      let unseenBadge = userButton.querySelector('.unseen-badge');
      
      if (unseenBadge) {
        // Increment existing counter
        let currentCount = parseInt(unseenBadge.getAttribute('data-count') || '0');
        currentCount++;
        unseenBadge.setAttribute('data-count', currentCount);
        unseenBadge.textContent = currentCount;
        unseenBadge.classList.add('animate-pulse');
      } else {
        // Create new counter badge starting at 1
        unseenBadge = document.createElement('span');
        unseenBadge.className = 'unseen-badge ml-2 inline-flex items-center justify-center px-2 py-0.5 text-xs font-bold text-white bg-red-500 rounded-full animate-pulse';
        unseenBadge.setAttribute('data-count', '1');
        unseenBadge.textContent = '1';
        userButton.appendChild(unseenBadge);
      }
    }
  }
});
```

#### Clear Counter on Click
```javascript
document.addEventListener('click', function(e) {
  const userButton = e.target.closest('a[data-user-id]');
  if (userButton) {
    const unseenBadge = userButton.querySelector('.unseen-badge');
    if (unseenBadge) {
      unseenBadge.remove();  // Badge removed from DOM
    }
  }
});
```

## User Flow Examples

### Example 1: New Message from Inactive User

1. Admin is viewing User A's chat
2. User B sends a message
3. Pusher notification arrives with `sender_id: B`
4. JavaScript checks: `selectedUserId (A) !== senderId (B)`
5. Counter badge appears on User B's button showing "1"
6. User B sends another message
7. Counter updates to "2"

### Example 2: Admin Switches to User

1. User B's button shows counter: "2"
2. Admin clicks on User B's button
3. JavaScript removes the counter badge
4. Page redirects to User B's conversation
5. Backend marks all messages from User B as seen (`seen_by_admin_at = now`)
6. Messages load in chat window
7. Counter no longer appears on page reload

### Example 3: Multiple Users Sending Messages

1. Admin is viewing User A's chat
2. User B sends 3 messages → Counter shows "3"
3. User C sends 5 messages → Counter shows "5"
4. User D sends 1 message → Counter shows "1"
5. Admin can see at a glance: C has most messages, then B, then D

## Database Queries

### Find All Unseen Messages for Admin
```ruby
Message.where(recipient_id: admin.id, seen_by_admin_at: nil)
```

### Find Unseen Messages from Specific User
```ruby
Message.where(user_id: user.id, recipient_id: admin.id, seen_by_admin_at: nil)
```

### Count Unseen by User
```ruby
Message.where(recipient_id: admin.id, seen_by_admin_at: nil)
       .group(:user_id)
       .count
# Returns: { 1 => 3, 2 => 7, 5 => 2 }
```

### Mark All Messages from User as Seen
```ruby
Message.where(user_id: user.id, recipient_id: admin.id, seen_by_admin_at: nil)
       .update_all(seen_by_admin_at: Time.current)
```

## Model Scopes

Added convenient scopes to Message model:

```ruby
# Get unseen messages
Message.unseen_by_admin

# Get messages from specific user to admin
Message.from_user_to_admin(user_id, admin_id)

# Combine scopes
Message.from_user_to_admin(user.id, admin.id).unseen_by_admin.count
```

## Performance Considerations

### Indexes
Added database indexes for fast queries:
- `index_messages_on_seen_by_admin_at`
- `index_messages_on_recipient_id_and_seen_by_admin_at`

These make unseen message queries very fast, even with thousands of messages.

### Query Optimization
- Counters calculated once per page load, not per user button
- Results stored in `@unseen_counts` hash for O(1) lookup
- Only users with unseen messages include the badge in HTML

## Styling

### CSS Classes
- `unseen-badge` - Base badge styling
- `animate-pulse` - Tailwind animation for attention
- `bg-red-500` - Red background color
- `rounded-full` - Circular badge shape

### Customization
To change badge appearance, modify the classes in `index.html.erb`:
```erb
<span class="unseen-badge ... bg-red-500 ...">
```

Change `bg-red-500` to:
- `bg-blue-500` for blue
- `bg-green-500` for green
- `bg-yellow-500` for yellow
- etc.

## Testing

### Manual Testing Steps

1. **Setup**
   - Login as admin
   - Have 2+ regular user accounts ready

2. **Test Counter Creation**
   - Login as User A, send a message to admin
   - Login as admin (viewing different user or no user selected)
   - Check: User A's button should show "1"

3. **Test Counter Increment**
   - While admin is viewing different user
   - Login as User A again, send 2 more messages
   - Check: User A's counter should update to "3"

4. **Test Counter Clear**
   - As admin, click on User A's button
   - Check: Counter should disappear
   - Check: Messages load in chat window

5. **Test Multiple Users**
   - Have User A, B, C all send messages while admin views User D
   - Check: All three should show counters
   - Click User B - only User B's counter should clear

6. **Test Real-Time Updates**
   - As admin, view User A's chat
   - Have User B send message
   - Check: Counter appears on User B's button immediately (via Pusher)

### Database Verification

```ruby
# Rails console
admin = User.admin_user
user = User.find_by(username: 'john')

# Check unseen count
Message.where(user_id: user.id, recipient_id: admin.id, seen_by_admin_at: nil).count

# Mark as seen manually
Message.where(user_id: user.id, recipient_id: admin.id, seen_by_admin_at: nil)
       .update_all(seen_by_admin_at: Time.current)

# Verify count is now 0
Message.where(user_id: user.id, recipient_id: admin.id, seen_by_admin_at: nil).count
# Should return: 0
```

## Migration Instructions

### If Migration Hasn't Run Yet

Run the migration to add the `seen_by_admin_at` column:

```bash
rails db:migrate
```

Expected output:
```
== 20260121000005 AddSeenByAdminAtToMessages: migrating =======================
-- add_column(:messages, :seen_by_admin_at, :datetime)
   -> 0.0234s
-- add_index(:messages, :seen_by_admin_at)
   -> 0.0156s
-- add_index(:messages, [:recipient_id, :seen_by_admin_at])
   -> 0.0198s
== 20260121000005 AddSeenByAdminAtToMessages: migrated (0.0592s) ============
```

### Existing Messages

All existing messages will have `seen_by_admin_at = NULL` (unseen).

**Option 1**: Mark all existing messages as seen:
```ruby
# Rails console
Message.update_all(seen_by_admin_at: Time.current)
```

**Option 2**: Leave them as unseen (they'll show in counters until admin views each conversation)

## Troubleshooting

### Counter Not Appearing
1. Check if migration ran: `Message.column_names.include?('seen_by_admin_at')`
2. Check if user has unseen messages: `Message.where(user_id: user.id, recipient_id: admin.id, seen_by_admin_at: nil).count`
3. Check `@unseen_counts` in view: `<%= @unseen_counts.inspect %>`

### Counter Not Updating via Pusher
1. Check browser console for Pusher logs
2. Verify `sender_id` is in Pusher notification
3. Verify `data-user-id` attribute exists on user buttons
4. Check JavaScript console for errors

### Counter Not Clearing on Click
1. Check if click event listener is attached
2. Verify user button has `data-user-id` attribute
3. Check if `mark_messages_as_seen_by_admin` is called in controller

### Performance Issues
1. Check if indexes exist: `\d messages` in psql
2. Monitor slow queries: `tail -f log/development.log`
3. Consider adding more specific indexes if needed

## Security Notes

- Only admin can see counters (regular users don't see them)
- Counters only count messages sent TO the admin
- Messages admin sends to users don't affect counters
- Each user can only see their own conversation, not counts

## Future Enhancements (Optional)

1. **Total Unseen Count**: Show total across all users
2. **Sort by Unseen**: Sort user buttons by unseen count (highest first)
3. **Sound Notification**: Play sound when counter increments
4. **Mark as Unread**: Allow admin to mark conversation as unread
5. **Seen Receipts**: Show regular users when admin has seen their message
6. **Auto-Archive**: Auto-mark very old messages as seen
