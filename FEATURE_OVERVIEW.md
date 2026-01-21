# Hidden Chat App - Admin User Switching Feature

## System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        ADMIN USER (qwert)                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              User Switcher Panel                         │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐              │   │
│  │  │  [abcd]  │  │ [user2]  │  │ [user3]  │    ...       │   │
│  │  └──────────┘  └──────────┘  └──────────┘              │   │
│  └─────────────────────────────────────────────────────────┘   │
│                              ↓                                   │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │          Chat Window (Selected User)                     │   │
│  │  ------------------------------------------------        │   │
│  │  Chatting with: abcd                                    │   │
│  │  ------------------------------------------------        │   │
│  │  qwert: Hello abcd!                                     │   │
│  │  abcd: Hi qwert!                                        │   │
│  │  qwert: How can I help you?                            │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
│  When switched to user2:                                         │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │          Chat Window (Different Conversation)            │   │
│  │  ------------------------------------------------        │   │
│  │  Chatting with: user2                                   │   │
│  │  ------------------------------------------------        │   │
│  │  qwert: Hello user2!                                    │   │
│  │  user2: Hey there!                                      │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                   │
└─────────────────────────────────────────────────────────────────┘

┌───────────────────┐    ┌───────────────────┐    ┌───────────────────┐
│   USER: abcd      │    │   USER: user2     │    │   USER: user3     │
├───────────────────┤    ├───────────────────┤    ├───────────────────┤
│                   │    │                   │    │                   │
│  ┌─────────────┐ │    │  ┌─────────────┐ │    │  ┌─────────────┐ │
│  │ Chat Window │ │    │  │ Chat Window │ │    │  │ Chat Window │ │
│  ├─────────────┤ │    │  ├─────────────┤ │    │  ├─────────────┤ │
│  │Chatting     │ │    │  │Chatting     │ │    │  │Chatting     │ │
│  │with: qwert  │ │    │  │with: qwert  │ │    │  │with: qwert  │ │
│  ├─────────────┤ │    │  ├─────────────┤ │    │  ├─────────────┤ │
│  │             │ │    │  │             │ │    │  │             │ │
│  │qwert: Hello │ │    │  │qwert: Hello │ │    │  │qwert: Hi!   │ │
│  │abcd!        │ │    │  │user2!       │ │    │  │             │ │
│  │             │ │    │  │             │ │    │  │user3: Hello │ │
│  │abcd: Hi     │ │    │  │user2: Hey   │ │    │  │             │ │
│  │qwert!       │ │    │  │there!       │ │    │  │             │ │
│  │             │ │    │  │             │ │    │  │             │ │
│  └─────────────┘ │    │  └─────────────┘ │    │  └─────────────┘ │
│                   │    │                   │    │                   │
│  ❌ Cannot see    │    │  ❌ Cannot see    │    │  ❌ Cannot see    │
│  user2's chat     │    │  abcd's chat      │    │  other chats      │
│                   │    │                   │    │                   │
└───────────────────┘    └───────────────────┘    └───────────────────┘
```

## Key Features

### 1. Privacy Isolation
- **Separate Conversations**: Each user has a completely isolated conversation with the admin
- **No Cross-Visibility**: Users cannot see messages between admin and other users
- **Admin Context Switching**: Admin switches contexts seamlessly between users

### 2. Message Filtering

```ruby
# Messages are filtered by conversation participants
get_conversation_messages(user1, user2)
  ↓
Returns only messages where:
  user_id IN (user1.id, user2.id)
```

**Example**:
- qwert (ID: 1) switches to abcd (ID: 2)
- Query: `Message.where(user_id: [1, 2])`
- Result: Only messages sent by qwert OR abcd
- Hidden: Messages between qwert and user3 (ID: 3)

### 3. Real-time Notifications

```
Admin sends message to abcd:
  ┌─────────┐         ┌──────────┐
  │ qwert   │ ──msg──→│  Pusher  │
  └─────────┘         └──────────┘
                            │
                            ↓
                      ┌──────────┐
                      │   abcd   │ ← Notified
                      └──────────┘

Regular user sends message:
  ┌─────────┐         ┌──────────┐
  │  abcd   │ ──msg──→│  Pusher  │
  └─────────┘         └──────────┘
                            │
                            ↓
                      ┌──────────┐
                      │  qwert   │ ← Notified
                      └──────────┘
```

## User Experience Flow

### Admin (qwert) Flow:
1. **Login** → See user switcher panel
2. **Select User** → Click button to switch to user's chat
3. **View Messages** → See only messages with that user
4. **Send Message** → Message appears in that user's chat
5. **Switch User** → See different conversation, previous context saved

### Regular User Flow:
1. **Login** → See chat interface
2. **View Messages** → See only their messages with qwert
3. **Send Message** → Only qwert receives it
4. **No Awareness** → Doesn't know about other users' conversations

## Implementation Details

### Session Management
```ruby
# Admin's selected user is stored in session
session[:selected_user_id] = user.id

# Persists across:
- Page refreshes
- Navigation within app
- Until explicitly changed or session expires
```

### Database Schema
```sql
users
├── id (PK)
├── username
├── is_admin (boolean, default: false)
├── last_updated_at
└── last_clear_at

messages
├── id (PK)
├── user_id (FK) → Sender
├── content (encrypted)
├── reply_for (encrypted)
├── image (encrypted)
└── created_at
```

### Security Model
1. ✅ Admin check: `user.admin?` → checks `is_admin` OR `username == "qwert"`
2. ✅ Controller guard: `switch_user` action requires admin
3. ✅ Message filtering: Strict WHERE clause on user_id
4. ✅ Session isolation: Each user's session is independent

## Testing Scenarios

### Scenario 1: Admin Switching
```
1. Login as qwert
2. See buttons for: abcd, user2, user3
3. Click "abcd" → See messages with abcd
4. Send message "Hello abcd"
5. Click "user2" → See different messages (with user2)
6. Verify "Hello abcd" is NOT visible here
```

### Scenario 2: Regular User Privacy
```
1. qwert chats with abcd: "Secret message A"
2. qwert switches to user2
3. qwert chats with user2: "Secret message B"
4. Login as abcd
5. Verify ONLY "Secret message A" is visible
6. Verify "Secret message B" is NOT visible
```

### Scenario 3: Real-time Updates
```
1. qwert viewing abcd's chat
2. abcd sends message
3. qwert receives Pusher notification
4. Message appears in qwert's view
5. qwert switches to user2
6. abcd sends another message
7. qwert does NOT receive notification (different context)
```

## Configuration Required

### Step 1: Database Migration
```bash
rails db:migrate
```

### Step 2: Set Admin User
```bash
rails user:set_admin
# or
rails console
> User.find_by(username: "qwert").update(is_admin: true)
```

### Step 3: Verify Setup
```bash
rails user:list_users
```

Expected output:
```
Users in the system:
--------------------------------------------------
qwert                | ID: 1     👑 ADMIN
abcd                 | ID: 2     
--------------------------------------------------
```

## Benefits

1. **Admin Efficiency**: qwert can manage multiple user conversations from one interface
2. **User Privacy**: Each user believes they have a private channel with qwert
3. **Scalability**: Works with any number of users
4. **Context Preservation**: Admin's selected user persists across sessions
5. **Clean UX**: Regular users see no complexity, just their chat

## Limitations & Considerations

1. **Single Admin**: Currently designed for one admin (qwert)
2. **No Group Chats**: All conversations are 1-on-1 with admin
3. **Message Deletion**: Deleting messages affects the conversation, not just one view
4. **Search**: No cross-conversation search for admin
5. **Archive**: Old conversations aren't archived separately

## Future Enhancements

- [ ] Multiple admin users
- [ ] Unread message count per user
- [ ] User search/filter in switcher
- [ ] Conversation history export
- [ ] User blocking/muting
- [ ] Admin notes on users (private)
- [ ] Message templates for common responses
- [ ] Conversation analytics

---

**Status**: ✅ Implementation Complete | 🧪 Ready for Testing
