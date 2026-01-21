# Admin User Management - Quick Start

## 🚀 Setup (2 Steps)

### Step 1: Run Migration
```bash
cd /Users/jai/Workspace/apps/samples/dmart
rails db:migrate
```

### Step 2: Start the App
```bash
rails server
```

---

## 📋 How to Use

### Access User Management

1. **Login as admin** (`qwert`)
2. Click **"👥 Manage Users"** button on dashboard
3. You'll see the user management page at `/admin/users`

---

## ✨ Quick Actions

### 1️⃣ Create a New User

```
Click "Create New User" button
Fill in:
  - Username: unique_name
  - Name: Real Name (optional, only you see this)
  - Password: at least 6 characters
  - Confirm Password: same as above
Click "Create User"
```

### 2️⃣ Change Someone's Password

```
Find user in table
Click 🔑 (key icon)
Enter new password
Confirm password
Click "Change Password"
```

**Note:** No old password needed!

### 3️⃣ Disable a User's Login

```
Find user in table
Click ✗ (red X icon)
Confirm action
```

User will see: "Your account has been disabled"

### 4️⃣ Enable a Disabled User

```
Find disabled user (red "Disabled" badge)
Click ✓ (green checkmark icon)
Confirm action
```

User can now login again!

### 5️⃣ Reset Username or Password

```
Find user in table
Click 🔄 (reset icon)
Enter new username (or leave blank)
Enter new password (or leave blank)
Click "Reset Credentials"
```

**⚠️ Warning:** User must use new credentials immediately!

### 6️⃣ Edit User's Private Name

```
Find user in table
Click ✏️ (edit icon)
Update name field
Click "Update"
```

**Note:** Only you (admin) can see this name!

### 7️⃣ Delete a User

```
Find user in table
Click 🗑️ (trash icon)
Confirm deletion
```

**Note:** Cannot delete admin users!

---

## 🎨 Icon Legend

| Icon | Action | Color |
|------|--------|-------|
| ✏️ | Edit Name | Blue |
| 🔑 | Change Password | Yellow |
| 🔄 | Reset Credentials | Purple |
| ✓ | Enable Login | Green |
| ✗ | Disable Login | Red |
| 🗑️ | Delete User | Red |

---

## 🔍 User Status Indicators

| Badge | Meaning |
|-------|---------|
| ✓ Active (green) | User can login |
| ✗ Disabled (red) | User cannot login |
| 👑 Admin | Admin privileges |
| 👤 User | Regular user |

---

## 💡 Common Scenarios

### Scenario: Forgot User's Password

**Solution:**
1. Click 🔑 icon for that user
2. Set new password
3. Tell user their new password

### Scenario: Need to Lock Account Temporarily

**Solution:**
1. Click ✗ icon to disable
2. User cannot login until you enable again
3. Click ✓ icon to re-enable when ready

### Scenario: User Needs Username Change

**Solution:**
1. Click 🔄 icon
2. Enter new username
3. Leave password blank (keeps current)
4. Click "Reset Credentials"

### Scenario: Create User for Testing

**Solution:**
1. Click "Create New User"
2. Username: test_user
3. Password: test123
4. Create, test, then delete when done

### Scenario: Track Real Names Privately

**Solution:**
1. Click ✏️ icon for user
2. Enter real name in "Name" field
3. Only you see this - user never sees it
4. Useful for identifying users internally

---

## ⚠️ Important Notes

### What Admin Can Do:
- ✅ Create unlimited users
- ✅ Change any user's password
- ✅ Enable/disable any account
- ✅ Reset credentials without old info
- ✅ See private names
- ✅ Delete non-admin users

### What Admin Cannot Do:
- ❌ Delete admin users (safety)
- ❌ Bypass username uniqueness
- ❌ See user passwords (hashed)

### What Regular Users See:
- ❌ No "Manage Users" button
- ❌ No access to /admin/users
- ❌ Cannot see other users' info
- ❌ Cannot see their "name" field

---

## 🐛 Troubleshooting

### Problem: "Access Denied" when accessing /admin/users

**Solution:**
```bash
rails console
User.find_by(username: "qwert").update(is_admin: true)
exit
```

### Problem: User can't login after creation

**Check:**
1. Is password at least 6 characters?
2. Is user enabled? (should be by default)
3. Did username save correctly?

### Problem: Modal won't close

**Solutions:**
- Click outside the modal
- Press Escape key
- Refresh the page

---

## 📖 Need More Details?

See **ADMIN_USER_MANAGEMENT.md** for:
- Complete technical documentation
- Database schema details
- Security considerations
- API routes and controllers
- Testing scenarios

---

## 🎯 Quick Reference

| Task | Steps | Time |
|------|-------|------|
| Create user | Click button → Fill form → Create | 30 sec |
| Change password | Click 🔑 → Enter password → Save | 20 sec |
| Disable user | Click ✗ → Confirm | 10 sec |
| Enable user | Click ✓ → Confirm | 10 sec |
| Reset both | Click 🔄 → Fill → Reset | 30 sec |
| Edit name | Click ✏️ → Update → Save | 20 sec |
| Delete user | Click 🗑️ → Confirm | 10 sec |

---

**Version:** 1.0  
**Last Updated:** January 21, 2026  
**Status:** ✅ Ready to Use
