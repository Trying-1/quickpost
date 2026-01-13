# Disabled Features Guide

## Overview

The Logout and Delete Account features are visible in the Profile screen but disabled (greyed out) until authentication is implemented.

---

## Visual Appearance

### Disabled State

```
┌─────────────────────────────────┐
│ DANGER ZONE                     │
├─────────────────────────────────┤
│ 🚪 Logout                [Soon] │
│    Sign out from account        │
│    (Coming with auth)           │
│    (greyed out, not clickable)  │
├─────────────────────────────────┤
│ 🗑️  Delete Account        [Soon] │
│    Permanently delete data      │
│    (Coming with auth)           │
│    (greyed out, not clickable)  │
└─────────────────────────────────┘
```

---

## Implementation Details

### Disabled ListTile Component

```dart
Widget _buildDisabledListTile({
  required IconData icon,
  required String title,
  required String subtitle,
  Color? titleColor,
}) {
  return Container(
    color: Colors.grey[100],  // Light grey background
    child: ListTile(
      leading: Icon(
        icon,
        color: (titleColor ?? Colors.purple).withOpacity(0.5),  // 50% opacity
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: (titleColor ?? Colors.purple).withOpacity(0.5),  // Greyed out
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey[600],
        ),
      ),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Soon',  // "Soon" badge
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    ),
  );
}
```

---

## Features of Disabled State

### Visual Indicators
- ✅ Light grey background (Colors.grey[100])
- ✅ Icons with 50% opacity (greyed out)
- ✅ Text with 50% opacity (greyed out)
- ✅ "Soon" badge on the right
- ✅ Updated subtitle: "Coming with auth"

### User Experience
- ✅ Not clickable (no onTap)
- ✅ Clearly indicates "coming soon"
- ✅ Doesn't confuse users
- ✅ Professional appearance
- ✅ Easy to enable later

---

## How to Enable

### Step 1: Locate the Code
File: `lib/screens/profile/profile_screen.dart`
Lines: 263-280

### Step 2: Replace Disabled with Enabled
```dart
// BEFORE (Disabled):
_buildDisabledListTile(
  icon: Icons.logout,
  title: 'Logout',
  subtitle: 'Sign out from your account (Coming with auth)',
  titleColor: Colors.orange,
),

// AFTER (Enabled):
_buildListTile(
  icon: Icons.logout,
  title: 'Logout',
  subtitle: 'Sign out from your account',
  titleColor: Colors.orange,
  onTap: () => _showLogoutDialog(context),
),
```

### Step 3: Do the Same for Delete Account
```dart
// BEFORE (Disabled):
_buildDisabledListTile(
  icon: Icons.delete_forever,
  title: 'Delete Account',
  subtitle: 'Permanently delete your account and data (Coming with auth)',
  titleColor: Colors.red,
),

// AFTER (Enabled):
_buildListTile(
  icon: Icons.delete_forever,
  title: 'Delete Account',
  subtitle: 'Permanently delete your account and data',
  titleColor: Colors.red,
  onTap: () => _showDeleteAccountDialog(context),
),
```

### Step 4: Rebuild
```bash
flutter clean
flutter run
```

---

## Current Implementation

### Logout & Delete Account Section

```dart
// Danger Zone Section (Disabled for now - no auth implemented)
_buildSection(
  title: 'Danger Zone',
  children: [
    _buildDisabledListTile(
      icon: Icons.logout,
      title: 'Logout',
      subtitle: 'Sign out from your account (Coming with auth)',
      titleColor: Colors.orange,
    ),
    _buildDisabledListTile(
      icon: Icons.delete_forever,
      title: 'Delete Account',
      subtitle: 'Permanently delete your account and data (Coming with auth)',
      titleColor: Colors.red,
    ),
  ],
),
```

---

## Related Methods

### Dialog Methods (Already Implemented)
These methods are already in the code and will work once enabled:

```dart
void _showLogoutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Logout?'),
      content: const Text('Are you sure you want to logout?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Logged out successfully!')),
            );
          },
          child: const Text('Logout', style: TextStyle(color: Colors.orange)),
        ),
      ],
    ),
  );
}

void _showDeleteAccountDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Account?'),
      content: const Text(
        'This action cannot be undone. All your data will be permanently deleted.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account deletion initiated...')),
            );
          },
          child: const Text('Delete', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
}
```

---

## Comparison: Disabled vs Enabled

### Disabled (Current)
```
Icon: Orange/Red with 50% opacity
Text: Orange/Red with 50% opacity
Background: Light grey
Trailing: "Soon" badge
Clickable: NO
Subtitle: "Coming with auth"
```

### Enabled (After Auth)
```
Icon: Orange/Red with 100% opacity
Text: Orange/Red with 100% opacity
Background: White
Trailing: Chevron icon
Clickable: YES
Subtitle: Original text
```

---

## Testing

### Before Enabling
- [ ] Logout button is visible
- [ ] Delete Account button is visible
- [ ] Both are greyed out
- [ ] "Soon" badge displays
- [ ] Not clickable
- [ ] No errors in console

### After Enabling
- [ ] Logout button is clickable
- [ ] Delete Account button is clickable
- [ ] Dialogs appear on click
- [ ] Buttons are not greyed out
- [ ] No "Soon" badge
- [ ] No errors in console

---

## Future: Authentication Implementation

When implementing authentication, you'll need to:

1. **Create Auth Service**
   - User login/signup
   - Session management
   - Token handling

2. **Update Profile Screen**
   - Replace disabled with enabled buttons
   - Add actual logout logic
   - Add account deletion logic

3. **Update Navigation**
   - Redirect to login on logout
   - Handle auth state

4. **Add Security**
   - Confirm password before delete
   - Secure token handling
   - Proper error handling

---

## Summary

✅ **Logout & Delete Account are:**
- Visible in the UI
- Clearly marked as "Coming Soon"
- Greyed out and disabled
- Ready to be enabled when auth is implemented
- Professional and user-friendly

**No changes needed until authentication is implemented!**

---

## Related Documentation

- [PROFILE_IMPROVEMENTS_SUMMARY.md](./PROFILE_IMPROVEMENTS_SUMMARY.md)
- [PROFILE_QUICK_START.md](../PROFILE_QUICK_START.md)
