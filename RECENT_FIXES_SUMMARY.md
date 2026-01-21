# Recent Fixes Summary

## Date: January 21, 2026

This document summarizes all the fixes and improvements made to address the Turbo Frame issues, message filtering, and Pusher notifications.

---

## 1. Reverted Turbo Frame User Switching

### Problem
- Turbo Frame replacement for user switching was causing JavaScript errors
- The "Support" button was not being re-activated after switching users
- `deferredPrompt` variable declaration errors with Turbo Stream updates

### Solution
- Removed Turbo Frame from user switching mechanism
- Changed `switch_user` action to use simple redirect instead of `respond_to` with turbo_stream
- Deleted `app/views/dashboard/switch_user.turbo_stream.erb`
- User switching now triggers a full page reload

### Files Modified
- `app/controllers/dashboard_controller.rb` - Simplified `switch_user` action
- `app/views/dashboard/index.html.erb` - Removed `turbo_frame_tag` wrapper
- `app/views/dashboard/switch_user.turbo_stream.erb` - Deleted

### Code Changes
```ruby
# Before (with Turbo Stream)
def switch_user
  respond_to do |format|
    format.html { redirect_to dashboard_path }
    format.turbo_stream do
      # ... complex turbo stream logic
    end
  end
end

# After (simple redirect)
def switch_user
  if @current_user.admin?
    session[:selected_user_id] = params[:selected_user_id]
    selected_user = User.find_by(id: session[:selected_user_id])
    update_conversation_activity(@current_user, selected_user) if selected_user.present?
  end
  
  redirect_to dashboard_path
end
```

---

## 2. Fixed Message Filtering (Critical Security Issue)

### Problem
**CRITICAL**: All users were seeing messages that the admin sent to ANY user, not just messages intended for them. This was a severe privacy issue.

### Root Cause
The `get_conversation_messages` method was filtering only by `user_id` (sender) without checking `recipient_id` (receiver):

```ruby
# Old (WRONG)
Message.where(user_id: [user1.id, user2.id])
```

This meant if Admin sent a message to User A, User B could also see it.

### Solution
Updated the query to filter by BOTH sender AND recipient:

```ruby
# New (CORRECT)
Message.where(
  "(user_id = ? AND recipient_id = ?) OR (user_id = ? AND recipient_id = ?)",
  user1.id, user2.id, user2.id, user1.id
)
.where.not(recipient_id: nil)
```

Now:
- User A only sees messages between User A ↔ Admin
- User B only sees messages between User B ↔ Admin
- Admin only sees messages for the currently selected user

### Files Modified
- `app/controllers/dashboard_controller.rb` - Updated `get_conversation_messages` method

### Important Note
Messages without `recipient_id` are intentionally excluded to prevent privacy leaks. If you have old messages, run:
```bash
rails messages:backfill_recipients
```

---

## 3. Fixed Pusher Real-Time Notifications

### Problem
- Pusher notifications were not working at all
- Used `@user` instead of `@current_user` (outdated variable name)
- No sender information in notifications
- Admin couldn't see which user sent a message when viewing a different conversation
- No visual indicators for new messages from inactive users

### Solution Implemented

#### 3.1 Fixed Pusher Subscription
**Changed**: `@user` → `@current_user`
```javascript
// Before
var channel = pusher.subscribe('my-channel-<%=@user&.id%>');

// After
var channel = pusher.subscribe('my-channel-<%=@current_user&.id%>');
```

#### 3.2 Enhanced Pusher Notification Data
Added sender information to notifications:

```ruby
# app/controllers/dashboard_controller.rb
pusher.trigger("my-channel-#{@person.id}", "my-event", {
  message: 'new',
  sender_id: @current_user.id,           # NEW
  sender_username: @current_user.username # NEW
})
```

#### 3.3 Smart Notification Handling for Admin

**For Regular Users**:
- Receive notification → Reload messages immediately

**For Admin Users**:
- Message from **active user** → Reload messages in chat window
- Message from **inactive user** → Show red pulsing badge (●) on that user's switch button

#### 3.4 Visual Badge Indicators
- Red pulsing dot appears on user switch buttons when they send a message
- Badge automatically disappears when admin clicks on that user
- Uses `data-user-id` attribute to target the correct button

### Files Modified
- `app/views/layouts/application.html.erb` - Enhanced Pusher subscription logic
- `app/controllers/dashboard_controller.rb` - Added sender info to Pusher notifications
- `app/views/dashboard/index.html.erb` - Added `data-user-id` to user buttons

### JavaScript Logic
```javascript
channel.bind('my-event', function(data) {
  const isAdmin = <%= @current_user&.admin? || false %>;
  const selectedUserId = <%= session[:selected_user_id] || 'null' %>;
  const senderId = data.sender_id;
  
  if (isAdmin && selectedUserId && senderId) {
    if (parseInt(selectedUserId) === parseInt(senderId)) {
      // Message from active user - reload chat
      indicator.value = "true";
    } else {
      // Message from inactive user - show badge
      const userButton = document.querySelector(`a[data-user-id="${senderId}"]`);
      // Add pulsing red badge...
    }
  } else {
    // Regular user - reload chat
    indicator.value = "true";
  }
});
```

---

## 4. Reverted PWA Script Changes

### Problem
Attempted to fix JavaScript errors by using `window.deferredPrompt` and `data-turbo-eval="false"`, but this didn't solve the underlying Turbo Frame issues.

### Solution
Reverted to original, simpler PWA installation script:
- Removed `data-turbo-eval="false"`
- Changed back to `let deferredPrompt`
- Removed flag checks for `window.beforeInstallListenerAdded`

Since we removed Turbo Frame from user switching, these JavaScript errors no longer occur.

### Files Modified
- `app/views/layouts/application.html.erb` - Reverted PWA script

---

## Testing Checklist

### Message Filtering
- [ ] Login as User A, send message to admin
- [ ] Login as User B, send message to admin
- [ ] Login as User A again - verify you DON'T see User B's messages
- [ ] Login as admin, switch to User A - verify you only see User A's messages
- [ ] Switch to User B - verify you only see User B's messages

### Pusher Notifications
- [ ] Login as User A, send message to admin
- [ ] As admin viewing User B's chat, verify badge appears on User A's button
- [ ] Click on User A's button, verify badge disappears and messages appear
- [ ] As admin viewing User A's chat, have User A send another message
- [ ] Verify message appears in chat window without page refresh

### User Switching
- [ ] Login as admin
- [ ] Click different user buttons
- [ ] Verify page loads correctly each time
- [ ] Verify Support button appears/disappears appropriately
- [ ] Verify no JavaScript console errors

---

## Files Changed Summary

1. `app/controllers/dashboard_controller.rb`
   - Simplified `switch_user` action (removed Turbo Stream)
   - Fixed `get_conversation_messages` query (security fix)
   - Added sender info to Pusher notifications

2. `app/views/layouts/application.html.erb`
   - Fixed `@user` → `@current_user` in Pusher subscription
   - Added smart notification handling for admin
   - Added badge management JavaScript
   - Reverted PWA script to original version

3. `app/views/dashboard/index.html.erb`
   - Removed Turbo Frame wrapper from user switcher
   - Added `data-user-id` attribute to user buttons
   - Removed `support-button-container` wrapper

4. `app/views/dashboard/switch_user.turbo_stream.erb`
   - **DELETED** (no longer needed)

---

## Documentation Created

1. `MESSAGE_FILTERING_FIX.md` - Explains the message filtering security issue and fix
2. `PUSHER_NOTIFICATIONS.md` - Comprehensive guide to Pusher implementation
3. `RECENT_FIXES_SUMMARY.md` - This file

---

## Security Improvements

### Before These Fixes
❌ Users could see each other's conversations with admin  
❌ No proper conversation isolation  
❌ Privacy was severely compromised  

### After These Fixes
✅ Each user only sees their own conversation with admin  
✅ Proper message filtering by both sender and recipient  
✅ Messages without `recipient_id` are excluded (security measure)  
✅ Real-time notifications work correctly with conversation context  

---

## Performance Improvements

1. **Removed unnecessary Turbo Stream complexity** - Full page reloads are simpler and more reliable for user switching
2. **Smarter message loading** - Admin only reloads messages for active conversations
3. **Visual feedback** - Users know when new messages arrive without constant polling

---

## Known Limitations

1. **Old Messages**: Messages created before `recipient_id` column was added won't appear until backfilled
   - Run: `rails messages:backfill_recipients`

2. **Pusher Credentials**: Currently hardcoded in controller
   - **TODO**: Move to environment variables for production

3. **Message Polling**: Still uses 3-second polling as a fallback
   - Consider removing if Pusher is reliable enough

---

## Future Improvements (Optional)

1. Move Pusher credentials to environment variables
2. Add sound notifications for new messages
3. Add unread message count instead of just a badge indicator
4. Consider using Action Cable instead of Pusher (built-in to Rails)
5. Add typing indicators
6. Add "mark as read" functionality

---

## Rollback Instructions

If issues occur, you can rollback by:

1. Restore the old `get_conversation_messages` query (NOT recommended - security issue)
2. Revert Pusher changes in `application.html.erb`
3. Keep the simplified `switch_user` action (recommended)

**Important**: Do NOT rollback the message filtering fix, as it's a critical security issue.
