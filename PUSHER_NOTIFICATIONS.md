# Pusher Real-Time Notifications

## Overview
The app uses Pusher for real-time message notifications, allowing users to see new messages without refreshing the page.

## How It Works

### For Regular Users
1. When a regular user receives a message from the admin, Pusher triggers a notification
2. The `new-message-indicator` hidden input is set to `true`
3. Every 3 seconds, the JavaScript checks this indicator and reloads messages if it's `true`
4. The chat window updates automatically with the new message

### For Admin Users
The admin can switch between different users to view their conversations. Pusher notifications work differently for admins:

#### When Admin Receives a Message
1. **Message from Currently Active User**: 
   - If the message is from the user whose chat is currently displayed
   - The `new-message-indicator` is set to `true`
   - Messages reload automatically in the chat window

2. **Message from Inactive User**:
   - If the message is from a user whose chat is NOT currently displayed
   - A red pulsing badge (●) appears on that user's switch button
   - The badge indicates there's a new unread message from that user
   - When admin clicks the button to view that user's chat, the badge automatically disappears

## Technical Implementation

### Backend (Controller)
```ruby
def send_pusher
  pusher = Pusher::Client.new(...)
  
  # Send notification to recipient with sender information
  pusher.trigger("my-channel-#{@person.id}", "my-event", {
    message: 'new',
    sender_id: @current_user.id,
    sender_username: @current_user.username
  })
end
```

### Frontend (JavaScript)
```javascript
// Subscribe to user's personal channel
var channel = pusher.subscribe('my-channel-<user_id>');

channel.bind('my-event', function(data) {
  if (isAdmin && selectedUserId && senderId) {
    if (selectedUserId === senderId) {
      // Reload messages for active conversation
      indicator.value = "true";
    } else {
      // Show badge on inactive user's button
      // Creates a red pulsing dot badge
    }
  } else {
    // Regular user - always reload
    indicator.value = "true";
  }
});
```

### User Switcher Buttons
Each user button in the admin's switcher includes a `data-user-id` attribute:
```html
<a href="/switch_user?user_id=1" data-user-id="1">Username</a>
```

This allows JavaScript to find the correct button and add/remove badges.

## Visual Indicators

### Badge Appearance
- **Color**: Red (`bg-red-500`)
- **Style**: Rounded badge with pulsing animation
- **Content**: Bullet point (●)
- **Position**: Right side of the user button text

### Badge Behavior
- Appears automatically when a new message arrives from an inactive user
- Pulses to draw attention
- Disappears when the admin clicks on that user's button
- Only one badge per user (doesn't stack multiple badges)

## Configuration

### Pusher Credentials
Located in `app/controllers/dashboard_controller.rb`:
```ruby
app_id: '1837761'
key: '268265a228eff4a444d7'
cluster: 'ap2'
```

### Channel Naming Convention
- Each user has their own channel: `my-channel-{user_id}`
- Admin's channel: `my-channel-{admin_user_id}`
- Regular user's channel: `my-channel-{regular_user_id}`

## Message Flow

### Regular User Sends Message to Admin
1. User sends message via `/dash/msg`
2. Message saved with `recipient_id = admin.id`
3. `send_pusher` triggers notification on admin's channel
4. Admin receives notification with `sender_id` of the regular user

### Admin Sends Message to User
1. Admin sends message while viewing a specific user's chat
2. Message saved with `recipient_id = selected_user.id`
3. `send_pusher` triggers notification on that user's channel
4. User receives notification and their chat reloads

## Polling Fallback
Even though Pusher provides real-time notifications, there's a polling mechanism as backup:
- Interval: Every 3 seconds
- Checks the `new-message-indicator` value
- Reloads messages if indicator is `true`
- This ensures messages are received even if Pusher fails

## Debugging

### Console Logging
Pusher logging is enabled in development:
```javascript
Pusher.logToConsole = true;
```

Check browser console for:
- "Pusher message received: {data}"
- Connection status
- Channel subscription confirmations

### Common Issues

1. **Messages not appearing for regular users**
   - Check if `@current_user` is properly set in the view
   - Verify Pusher channel subscription: `my-channel-{user_id}`
   - Check browser console for Pusher errors

2. **Badge not showing on admin's user buttons**
   - Verify `data-user-id` attribute exists on user buttons
   - Check if `sender_id` is included in Pusher notification
   - Inspect browser console for JavaScript errors

3. **Badge not disappearing when clicked**
   - Ensure click event listener is attached
   - Check if `DOMContentLoaded` event fires properly
   - Verify button has `data-user-id` attribute

## Security Notes
- Each user only subscribes to their own channel
- Messages are filtered by `recipient_id` to prevent cross-user visibility
- Pusher credentials should be moved to environment variables in production
