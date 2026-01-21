# Quick Start Guide - Admin Chat Switching

## 🚀 Get Started in 3 Steps

### Step 1: Run Migration
```bash
cd /Users/jai/Workspace/apps/samples/dmart
rails db:migrate
```

### Step 2: Set qwert as Admin
```bash
rails user:set_admin
```

### Step 3: Start the App
```bash
rails server
```

---

## 🎯 How to Use

### As Admin (qwert):

1. **Login** with username: `qwert`

2. **See the User Switcher**
   - Look for the blue panel with "Switch User Chat"
   - You'll see buttons for each user (abcd, etc.)

3. **Click a User Button**
   - Example: Click "abcd"
   - Chat window updates to show messages with abcd
   - Button turns blue to show it's selected

4. **Send Messages**
   - Type in the text area
   - Click send (→)
   - Only the selected user sees this message

5. **Switch to Another User**
   - Click a different user button
   - Chat window updates to show different conversation
   - Previous selection is remembered

### As Regular User (abcd):

1. **Login** with username: `abcd`

2. **Chat with qwert**
   - You only see messages between you and qwert
   - No user switcher (you're not admin)
   - You can't see qwert's chats with others

3. **Send Messages**
   - Type and send normally
   - Only qwert sees your messages

---

## 🔍 Quick Test

### Test 1: Verify Isolation
```bash
1. Login as qwert
2. Switch to abcd
3. Send: "Hello abcd"
4. Switch to another user (if available)
5. Send: "Hello user2"
6. Logout

7. Login as abcd
8. Verify you see "Hello abcd"
9. Verify you DON'T see "Hello user2"
✅ Working correctly!
```

### Test 2: Verify Admin Switching
```bash
1. Login as qwert
2. Note the user switcher panel exists
3. Click different user buttons
4. Verify chat content changes
5. Verify selected button is highlighted
✅ Working correctly!
```

---

## ⚙️ Troubleshooting

### Problem: No user switcher visible for qwert
**Solution:**
```bash
rails console
User.find_by(username: "qwert").update(is_admin: true)
exit
```

### Problem: All users see all messages
**Solution:**
- Clear your browser cache
- Logout and login again
- Check if migration ran: `rails db:migrate:status`

### Problem: Can't switch users
**Solution:**
- Make sure you're logged in as qwert
- Check if other users exist in database:
  ```bash
  rails console
  User.pluck(:username)
  exit
  ```

---

## 📋 Quick Reference

| Action | Admin (qwert) | Regular User (abcd) |
|--------|---------------|---------------------|
| See user switcher | ✅ Yes | ❌ No |
| Switch conversations | ✅ Yes | ❌ No |
| See own messages | ✅ Yes | ✅ Yes |
| See other users' messages | ✅ Yes (when switched to them) | ❌ No |
| Send to specific user | ✅ Yes (currently selected) | ✅ Yes (to admin only) |

---

## 🎨 UI Reference

### Admin Dashboard:
```
┌─────────────────────────────────────────┐
│ Welcome, qwert                          │
│ Medicine Information Dashboard          │
│                                         │
│ ┌─────────────────────────────────┐   │
│ │   Switch User Chat              │   │
│ │ ┌──────┐ ┌──────┐ ┌──────┐    │   │
│ │ │ abcd │ │user2 │ │user3 │    │   │ ← Click to switch
│ │ └──────┘ └──────┘ └──────┘    │   │
│ └─────────────────────────────────┘   │
│                                         │
│ [Logout]  [Support]                    │
└─────────────────────────────────────────┘
```

### Regular User Dashboard:
```
┌─────────────────────────────────────────┐
│ Welcome, abcd                           │
│ Medicine Information Dashboard          │
│                                         │
│ Chatting with: qwert                   │
│ (Active 2 minutes ago)                 │
│                                         │
│ [Logout]  [Support]                    │
└─────────────────────────────────────────┘
```

---

## 📞 Support

If you encounter issues:

1. Check `SETUP_ADMIN_CHAT.md` for detailed setup
2. Check `FEATURE_OVERVIEW.md` for architecture details
3. Run `rails user:list_users` to verify user setup
4. Check Rails logs: `tail -f log/development.log`

---

**Version**: 1.0  
**Last Updated**: January 21, 2026  
**Status**: ✅ Production Ready
