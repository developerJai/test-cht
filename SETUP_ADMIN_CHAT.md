# Admin Chat Feature - Setup Guide

## Overview

This hidden chat app now supports an admin user (`qwert`) who can switch between different users to view and manage individual conversations. Regular users can only see their own chat with the admin.

## Features Implemented

### For Admin User (qwert):
- ✅ **User Switcher**: Buttons to switch between different users
- ✅ **Individual Conversations**: View messages only between admin and the selected user
- ✅ **Session Persistence**: Selected user remains active across page refreshes
- ✅ **Visual Indicators**: Currently selected user is highlighted

### For Regular Users:
- ✅ **Private Chat**: Only see their own conversation with `qwert`
- ✅ **Isolation**: Cannot see messages between admin and other users
- ✅ **Seamless Experience**: Chat interface remains the same

## Setup Instructions

### 1. Run the Database Migration

```bash
cd /Users/jai/Workspace/apps/samples/dmart
rails db:migrate
```

This adds the `is_admin` column to the users table.

### 2. Set Admin Flag for qwert

Run the rake task to set `qwert` as admin:

```bash
rails user:set_admin
```

Or manually in Rails console:

```bash
rails console
User.find_by(username: "qwert").update(is_admin: true)
exit
```

### 3. Verify User Setup

List all users and check admin status:

```bash
rails user:list_users
```

## How It Works

### Database Changes
- Added `is_admin` boolean column to `users` table (default: false)

### Model Changes
- **User Model**: Added `admin?` helper method and `admin_user` class method

### Controller Changes
- **Dashboard Controller**:
  - Modified `index` action to handle user switching for admin
  - Added `switch_user` action for switching between users
  - Added `get_conversation_messages` method to filter messages by participants
  - Updated `send_pusher` to notify the correct user based on context

### View Changes
- **Dashboard Index**: Added user switcher UI (visible only to admin)
- **Chat Partial**: Updated to show current conversation participant

## Usage

### As Admin (qwert):
1. Login as `qwert`
2. You'll see a "Switch User Chat" panel with buttons for each user
3. Click on any user button to view your conversation with that user
4. Send messages - they will be visible only to that specific user
5. Switch to another user to view a different conversation

### As Regular User (e.g., abcd):
1. Login as your username (e.g., `abcd`)
2. You'll only see messages between you and `qwert`
3. Send messages - only `qwert` will see them
4. You cannot see conversations between `qwert` and other users

## Technical Details

### Message Filtering
Messages are filtered using the `get_conversation_messages` method which:
- Takes two users as parameters
- Returns only messages where `user_id` belongs to either user
- Maintains all existing filters (recent messages, unclear messages, etc.)

### Session Management
- Admin's selected user is stored in `session[:selected_user_id]`
- Persists across page refreshes
- Can be overridden by URL parameter `?selected_user_id=X`

### Pusher Notifications
- When admin sends a message: notifies the selected user
- When regular user sends a message: notifies the admin
- Ensures real-time updates for both participants

## Files Modified

1. `db/migrate/20260121000001_add_is_admin_to_users.rb` - New migration
2. `app/models/user.rb` - Added admin methods
3. `app/controllers/dashboard_controller.rb` - Added user switching logic
4. `app/views/dashboard/index.html.erb` - Added user switcher UI
5. `app/views/dashboard/_chat.html.erb` - Updated chat header
6. `config/routes.rb` - Added switch_user route
7. `lib/tasks/set_admin.rake` - New rake task for admin setup

## Security Notes

- The `admin?` method checks both the `is_admin` flag and username == "qwert"
- Regular users cannot access the `switch_user` action (controller checks `@user.admin?`)
- Messages are strictly filtered by conversation participants

## Troubleshooting

### User switcher not showing
- Verify `qwert` has `is_admin` set to true: `rails user:list_users`
- Check if other users exist in the database

### Messages not filtering correctly
- Clear your chat history and test with fresh messages
- Check that `last_clear_at` is not interfering with message visibility

### Pusher notifications not working
- Verify Pusher credentials in `dashboard_controller.rb`
- Check browser console for JavaScript errors

## Future Enhancements

Possible improvements:
- Add unread message counters for each user
- Display user online/offline status
- Add user search functionality for many users
- Implement conversation archiving
- Add typing indicators per conversation

---

**Note**: This is a hidden chat system. Make sure all users understand the privacy model and their access levels.
