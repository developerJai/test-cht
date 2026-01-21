# Admin Self-Management Feature

## Overview
Admins can now see and manage their own account in the user management interface, including changing their own password. However, they are protected from accidentally disabling or deleting themselves.

## Changes Made

### 1. **Admin Now Appears in User List**

**Before:**
```ruby
@users = User.where.not(id: @current_user.id).order(created_at: :desc)
```
This excluded the current admin from the list.

**After:**
```ruby
@users = User.all.order(created_at: :desc)
```
All users now appear, including the current admin.

### 2. **Visual Indicators**

#### Mobile View
- Current admin's card has a **blue border** (instead of gray)
- Username shows a **"You" badge** (blue background, white text)

#### Desktop View
- Current admin's row has a **light blue background**
- Username shows a **"You" badge** (blue background, white text)

### 3. **Protected Actions**

Admin **CAN** do to themselves:
- ✅ Edit name
- ✅ Change password
- ✅ Reset credentials

Admin **CANNOT** do to themselves:
- ❌ Disable account
- ❌ Delete account

These actions show:
- **Mobile**: Grayed out buttons with "Can't Disable Self" or "Protected" text
- **Desktop**: Grayed out icons with tooltips

## Visual Examples

### Mobile View (Current Admin)
```
┌────────────────────────────┐ ← Blue border
│ 👤  admin                  │
│     Administrator   [You]  │ ← "You" badge
├────────────────────────────┤
│ Status:      ✓ Active      │
│ Type:        👑 Admin      │
│ Created:     30 days ago   │
├────────────────────────────┤
│ Edit | Password | Reset    │
│ Can't Disable | Protected  │ ← Grayed out
└────────────────────────────┘
```

### Desktop View (Current Admin)
```
┌────────────────────────────────────────────────────────────┐
│ admin [You] │ John Doe │ ✓ Active │ 👑 Admin │ 30d │ Actions│
└────────────────────────────────────────────────────────────┘
         ↑                                              ↑
     "You" badge                               Edit/Password/Reset work
                                              Disable/Delete grayed out
```

## Backend Protection

Even if someone tries to bypass the UI (e.g., via curl or API), the backend prevents self-harm:

### Toggle Status Protection
```ruby
def toggle_status
  if @edit_user.id == @current_user.id
    flash[:error] = "You cannot disable your own account"
    redirect_to admin_users_path
    return
  end
  # ... rest of the logic
end
```

**Result**: Returns error message instead of disabling

### Delete Protection
```ruby
def destroy
  if @edit_user.id == @current_user.id
    flash[:error] = "You cannot delete your own account"
  elsif @edit_user.admin?
    flash[:error] = "Cannot delete admin users"
  # ... rest of the logic
end
```

**Result**: Returns error message instead of deleting

## Use Cases

### Use Case 1: Admin Changes Own Password
1. Admin logs into user management
2. Sees their own account at top (or sorted alphabetically)
3. Clicks "Password" button
4. Enters new password
5. ✅ Password changed successfully

### Use Case 2: Admin Tries to Disable Self
1. Admin sees their account
2. "Disable" button is grayed out
3. Hover shows: "Cannot disable yourself"
4. ❌ Action not possible (UI prevents it)

### Use Case 3: API Attempt to Disable Self
1. Someone tries: `curl -X PATCH /admin/users/1/toggle_status`
2. Backend checks: `@edit_user.id == @current_user.id`
3. Returns error: "You cannot disable your own account"
4. ❌ Action blocked (backend prevents it)

### Use Case 4: Admin Updates Own Name
1. Admin clicks "Edit" button on their card
2. Updates the private name field
3. Saves changes
4. ✅ Name updated successfully

## Technical Implementation

### Frontend (View)

#### Detecting Current User
```erb
<% @users.each do |user| %>
  <% is_current_user = (user.id == @current_user.id) %>
  
  <!-- Apply special styling if current user -->
  <div class="<%= is_current_user ? 'border-blue-500' : 'border-gray-200' %>">
    <!-- Show badge -->
    <% if is_current_user %>
      <span class="badge">You</span>
    <% end %>
    
    <!-- Disable dangerous actions -->
    <% if is_current_user %>
      <span class="text-gray-400">Can't Disable Self</span>
    <% else %>
      <%= button_to "Disable" %>
    <% end %>
  </div>
<% end %>
```

### Backend (Controller)

#### Protection Logic
```ruby
before_action :set_current_user
before_action :require_admin

def toggle_status
  # Prevent self-disable
  if @edit_user.id == @current_user.id
    flash[:error] = "You cannot disable your own account"
    return redirect_to admin_users_path
  end
  # ... continue with normal logic
end

def destroy
  # Prevent self-delete
  if @edit_user.id == @current_user.id
    flash[:error] = "You cannot delete your own account"
    return redirect_to admin_users_path
  end
  # ... continue with normal logic
end
```

## Security Considerations

### Why Prevent Self-Disable?
If an admin disables themselves:
- They would be locked out immediately
- No one could re-enable them (unless another admin exists)
- System could become inaccessible
- Recovery would require database access

### Why Prevent Self-Delete?
If an admin deletes themselves:
- **Permanent data loss**
- All their messages would be orphaned
- System could become inaccessible
- No undo possible

### Defense in Depth
Protection exists at **two layers**:
1. **Frontend**: UI prevents clicking dangerous buttons
2. **Backend**: API prevents executing dangerous actions

This ensures security even if:
- JavaScript is disabled
- Someone uses curl/API directly
- Someone modifies HTML in browser

## Edge Cases Handled

### Edge Case 1: Only One Admin
If there's only one admin in the system:
- ✅ Can still change password
- ✅ Can still edit name
- ❌ Cannot disable self (would lock everyone out)
- ❌ Cannot delete self (would remove all admins)

### Edge Case 2: Multiple Admins
If there are multiple admins:
- ✅ Admin A can disable Admin B
- ✅ Admin B can disable Admin A
- ❌ Admin A cannot disable themselves
- ❌ Admin B cannot disable themselves

### Edge Case 3: Admin Creates Another Admin
1. Admin creates a new user
2. Promotes them to admin (via database or separate feature)
3. Now both can manage each other
4. But still neither can disable themselves

## Testing

### Manual Testing Steps

**Test 1: Can See Own Account**
```
1. Login as admin
2. Go to User Management
3. ✅ Verify your account appears in the list
4. ✅ Verify "You" badge appears next to your username
5. ✅ Verify card/row has special styling
```

**Test 2: Can Change Own Password**
```
1. Click "Password" button on your account
2. Enter new password
3. Confirm new password
4. Submit
5. ✅ Verify success message
6. Logout and login with new password
7. ✅ Verify new password works
```

**Test 3: Cannot Disable Self (UI)**
```
1. Look at your account's action buttons
2. ✅ Verify "Disable" button is grayed out
3. ✅ Verify tooltip says "Cannot disable yourself"
4. Try to click it
5. ✅ Verify nothing happens
```

**Test 4: Cannot Disable Self (API)**
```bash
# Get your user ID and session cookie
curl -X PATCH http://localhost:3000/admin/users/YOUR_ID/toggle_status \
  -H "Cookie: your_session_cookie"

# Expected: Error message, not disabled
```

**Test 5: Can Disable Others**
```
1. Find another user in the list
2. Click their "Disable" button
3. Confirm the action
4. ✅ Verify they are disabled
5. ✅ Verify status changes to "Disabled"
```

### Automated Testing (Optional)

```ruby
# test/controllers/admin/users_controller_test.rb

test "admin cannot disable themselves" do
  admin = users(:admin_user)
  sign_in_as(admin)
  
  patch toggle_status_admin_user_path(admin)
  
  assert_equal "You cannot disable your own account", flash[:error]
  assert admin.reload.enabled?, "Admin should still be enabled"
end

test "admin cannot delete themselves" do
  admin = users(:admin_user)
  sign_in_as(admin)
  
  assert_no_difference('User.count') do
    delete admin_user_path(admin)
  end
  
  assert_equal "You cannot delete your own account", flash[:error]
end

test "admin can change own password" do
  admin = users(:admin_user)
  sign_in_as(admin)
  
  patch admin_user_path(admin), params: {
    user: {
      password: "newpassword123",
      password_confirmation: "newpassword123"
    }
  }
  
  assert_equal "Password updated", flash[:success]
  assert admin.reload.authenticate("newpassword123"), "New password should work"
end
```

## Files Modified

1. **`app/controllers/admin/users_controller.rb`**
   - Changed query to include all users
   - Added self-disable protection in `toggle_status`
   - Added self-delete protection in `destroy`

2. **`app/views/admin/users/index.html.erb`**
   - Added `is_current_user` detection
   - Added "You" badge display
   - Added special styling for current admin
   - Disabled dangerous action buttons for current admin
   - Updated both mobile and desktop views

## Future Enhancements (Optional)

1. **Promote Other Users to Admin**
   - Add UI to make other users admins
   - Require at least 2 admins before allowing self-demotion

2. **Admin Activity Log**
   - Track when admin changes their own password
   - Track when admin is promoted/demoted

3. **Password Strength Indicator**
   - Show strength when changing password
   - Require minimum strength level

4. **Two-Factor Authentication**
   - Add 2FA option for admin accounts
   - Require 2FA for sensitive actions

5. **Account Recovery**
   - Add password reset via email
   - Add security questions

## Summary

✅ Admin can now see their own account  
✅ Admin can change their own password  
✅ Admin can edit their own name  
✅ Admin is protected from self-disable  
✅ Admin is protected from self-delete  
✅ Protection exists at UI and API levels  
✅ Clear visual indicators ("You" badge)  
✅ Works on both mobile and desktop  

The system is now more flexible while remaining safe!
