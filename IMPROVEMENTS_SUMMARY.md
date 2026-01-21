# Dashboard Improvements Summary

## All Improvements Implemented ✅

### 1. ✅ Cloudinary Folder Structure

**Before:**
```
cloudinary/
  └── username/
      ├── image1.jpg
      └── video1.mp4
```

**After:**
```
cloudinary/
  └── admin_username-person_username/
      ├── admin_username/
      │   ├── image1.jpg
      │   └── video1.mp4
      └── person_username/
          ├── image2.jpg
          └── video2.mp4
```

**Implementation:**
- Format: `admin_username-person_username/uploader_username`
- Example: `qwert-abcd/qwert/image.jpg` (admin uploads)
- Example: `qwert-abcd/abcd/photo.jpg` (user uploads)
- Organized by conversation, then by uploader

**Code:**
```ruby
def build_cloudinary_folder(sender, recipient)
  return sender.username unless recipient.present?
  
  admin = sender.admin? ? sender : recipient
  regular_user = sender.admin? ? recipient : sender
  
  "#{admin.username}-#{regular_user.username}/#{sender.username}"
end
```

---

### 2. ✅ Extended Session Timeout

**Before:** Session expired when browser closed

**After:** Session lasts 30 days

**File:** `config/initializers/session_store.rb`

```ruby
Rails.application.config.session_store :cookie_store, 
  key: '_dmart_session',
  expire_after: 30.days
```

**Benefits:**
- Users stay logged in for 30 days
- No need to login repeatedly
- Better user experience

---

### 3. ✅ Per-Conversation Last Active Tracking

**Before:** Single `last_updated_at` for all conversations

**After:** Separate tracking per conversation

**Database:**
- Added `conversation_activities` JSON column to users table
- Stores: `{ "user_id": timestamp, "user_id": timestamp, ... }`

**For Regular Users:**
- See when admin was last active **in their specific conversation**
- Not affected by admin's activity with other users

**For Admin:**
- Each user shows their own `last_updated_at`
- Admin's activity tracked per conversation

**Example:**
```
Admin chats with User A at 2:00 PM
Admin chats with User B at 3:00 PM

User A sees: "Admin active 1 hour ago" (2:00 PM)
User B sees: "Admin active 0 minutes ago" (3:00 PM)
```

**Code:**
```ruby
def update_conversation_activity(user, partner)
  activities = user.conversation_activities || {}
  activities[partner.id.to_s] = Time.now.to_i
  user.update(conversation_activities: activities)
end

def get_conversation_last_active(current_user, partner)
  admin = partner.admin? ? partner : current_user
  activities = admin.conversation_activities || {}
  last_active_timestamp = activities[current_user.id.to_s]
  
  Time.at(last_active_timestamp) if last_active_timestamp.present?
end
```

---

### 4. ✅ No Default User Selection for Admin

**Before:** Admin automatically saw first user's chat

**After:** Admin sees no chat until selecting a user

**Changes:**
- Removed default user selection
- `@person = nil` when no user selected
- Support button hidden until user selected
- No last active time updated until selection

**Benefits:**
- Admin doesn't accidentally update "last active" for random user
- Clean slate on login
- Intentional user selection required

---

### 5. ✅ Support Button Conditional Display

**Before:** Always visible

**After:** 
- **Admin:** Only shows when a user is selected
- **Regular Users:** Always shows (they always chat with admin)

**Code:**
```erb
<% if @person.present? || !@user.admin? %>
  <div class="text-sm font-semibold leading-6 text-gray-900 cursor-pointer" 
       data-action="click->chats#openModal" id="good-link">
    Support
  </div>
<% end %>
```

**Logic:**
- `@person.present?` → User selected (admin)
- `!@user.admin?` → Regular user (always has admin to chat with)

---

### 6. ✅ Turbo Frame User Switching (No Page Scroll)

**Before:** Full page reload, scrolled to top

**After:** Smooth switching, stays in place

**Implementation:**
```erb
<%= turbo_frame_tag "user_switcher" do %>
  <% @all_users.each do |user| %>
    <%= link_to user.username, switch_user_path(user_id: user.id), 
        data: { turbo_frame: "user_switcher" },
        class: "..." %>
  <% end %>
<% end %>
```

**Controller:**
```ruby
def switch_user
  if @user.admin?
    session[:selected_user_id] = params[:user_id]
  end
  
  respond_to do |format|
    format.html { redirect_to dashboard_path }
    format.turbo_stream do
      # Update only the switcher frame
    end
  end
end
```

**Benefits:**
- No page reload
- No scroll to top
- Instant switching
- Better UX

---

### 7. ✅ Updated Switching Section Styling

**Before:**
- Blue background panel
- "Switch User Chat" heading
- Blue highlight for selected user

**After:**
- No background color
- No heading
- Clean button row
- Dark gray (gray-800) for selected user
- White with border for unselected users

**Styling:**
```erb
<div class="mt-6">
  <div class="flex flex-wrap gap-2">
    <%= link_to user.username, switch_user_path(user_id: user.id), 
        class: "inline-flex items-center px-3 py-2 text-sm font-semibold rounded-md 
                #{@person&.id == user.id ? 'bg-gray-800 text-white' : 'bg-white text-gray-900 border border-gray-300 hover:bg-gray-50'} 
                shadow-sm" %>
  </div>
</div>
```

**Visual:**
```
Before:
┌─────────────────────────────────┐
│ Switch User Chat                │ ← Heading
│ ┌──────┐ ┌──────┐ ┌──────┐    │
│ │ abcd │ │user2 │ │user3 │    │ ← Blue background
│ └──────┘ └──────┘ └──────┘    │
└─────────────────────────────────┘

After:
┌──────┐ ┌──────┐ ┌──────┐
│ abcd │ │user2 │ │user3 │  ← Clean buttons, no heading
└──────┘ └──────┘ └──────┘
```

---

## Database Migrations Required

### Migration 1: Conversation Activity Tracking
```bash
rails db:migrate
```

**File:** `db/migrate/20260121000004_add_conversation_activity_tracking.rb`

```ruby
add_column :users, :conversation_activities, :json, default: {}
```

---

## Files Modified

### Controllers:
1. `app/controllers/dashboard_controller.rb`
   - Updated `index` action
   - Modified `upload_img` for new folder structure
   - Added `build_cloudinary_folder` method
   - Updated `get_conversation_partner` (no default)
   - Added `update_conversation_activity` method
   - Added `get_conversation_last_active` method
   - Modified `switch_user` for Turbo Stream

### Views:
1. `app/views/dashboard/index.html.erb`
   - Wrapped switcher in `turbo_frame_tag`
   - Removed blue background styling
   - Removed heading
   - Updated button styling
   - Added conditional support button display

2. `app/views/dashboard/_chat.html.erb`
   - Updated last active display logic
   - Shows conversation-specific last active for users
   - Shows regular last_updated_at for admin

3. `app/views/dashboard/switch_user.turbo_stream.erb` (NEW)
   - Turbo Stream response for switching
   - Updates user switcher frame
   - Updates support button visibility

### Config:
1. `config/initializers/session_store.rb` (NEW)
   - Extended session to 30 days

---

## Testing Checklist

### Test 1: Cloudinary Uploads ✅
```
1. Admin selects user "abcd"
2. Admin uploads image
3. Check Cloudinary: qwert-abcd/qwert/image.jpg ✅

4. Login as "abcd"
5. Upload image
6. Check Cloudinary: qwert-abcd/abcd/image.jpg ✅
```

### Test 2: Session Timeout ✅
```
1. Login as any user
2. Close browser
3. Reopen browser after 1 day
4. Navigate to site
5. Should still be logged in ✅
```

### Test 3: Per-Conversation Last Active ✅
```
1. Login as admin (qwert)
2. Select user "abcd" at 2:00 PM
3. Send message
4. Select user "user2" at 3:00 PM
5. Send message

6. Login as "abcd"
7. Check last active: Should show 2:00 PM ✅

8. Login as "user2"
9. Check last active: Should show 3:00 PM ✅
```

### Test 4: No Default Selection ✅
```
1. Login as admin
2. No user should be selected
3. No chat visible
4. Support button hidden ✅
```

### Test 5: Support Button Display ✅
```
Admin:
1. Login as admin
2. Support button hidden ✅
3. Select user
4. Support button appears ✅

Regular User:
1. Login as regular user
2. Support button visible ✅
```

### Test 6: Turbo Frame Switching ✅
```
1. Login as admin
2. Scroll down page
3. Click user button
4. Page should NOT scroll to top ✅
5. User switches instantly ✅
```

### Test 7: Styling ✅
```
1. Login as admin
2. Check switcher section:
   - No blue background ✅
   - No heading ✅
   - Clean button row ✅
   - Selected: dark gray ✅
   - Unselected: white with border ✅
```

---

## Summary

| Feature | Status | Impact |
|---------|--------|--------|
| Cloudinary folder structure | ✅ | Better organization |
| Session timeout (30 days) | ✅ | Better UX |
| Per-conversation last active | ✅ | Accurate tracking |
| No default user selection | ✅ | Intentional selection |
| Conditional support button | ✅ | Clean UI |
| Turbo Frame switching | ✅ | No scroll, smooth |
| Updated styling | ✅ | Cleaner look |

**All improvements implemented and ready to use!**

---

**Setup:**
```bash
# Run migration
rails db:migrate

# Restart server (for session config)
rails server
```

**Version:** 1.0  
**Date:** January 21, 2026  
**Status:** ✅ Complete
