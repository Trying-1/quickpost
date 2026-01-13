# Profile & Settings - Quick Start Guide

## 🚀 What's New

A complete **Profile & Settings screen** has been added to QuickPost!

---

## 📍 Where to Find It

**Bottom Navigation Bar** → Tap the **Profile** icon (last tab)

---

## ✨ What's Included

### User Profile Section
- Avatar with gradient background
- User name and email
- Subscription status (Free Plan)

### Account Management
- User profile settings
- Subscription plan details
- Notification preferences

### App Information
- Current version number
- Build number
- Check for updates
- What's new section

### Storage & Cache
- Clear app cache
- Free up space

### Preferences
- Theme selection (light/dark)
- Language selection

### Legal & Support
- Privacy Policy
- Terms of Service
- Help & Support
- Report a Bug
- Send Feedback

### Social & Sharing
- Share the app
- Rate on Play Store
- Visit website

### Account Actions
- Logout
- Delete account

---

## 🔧 Installation

### 1. Install Dependencies
```bash
flutter pub get
```

### 2. Rebuild the App
```bash
flutter clean
flutter run
```

### 3. Test
- Launch the app
- Tap the "Profile" tab
- Verify everything loads

---

## 📝 Configuration

### Update URLs (Before Release)
Edit `lib/screens/profile/profile_screen.dart`:

```dart
// Line 1: Privacy Policy
_launchUrl('https://your-privacy-policy-url.com')

// Line 2: Terms of Service
_launchUrl('https://your-terms-url.com')

// Line 3: Website
_launchUrl('https://your-website.com')
```

### Update User Email (When Auth is Ready)
Replace hardcoded email with actual user data:

```dart
// Current (hardcoded):
'user@quickpost.app'

// Future (with auth):
authService.currentUser?.email ?? 'user@quickpost.app'
```

---

## 🎯 Features Status

| Feature | Status | Notes |
|---------|--------|-------|
| Profile Header | ✅ Done | Shows user info |
| Account Settings | ✅ Done | Placeholder for future |
| App Info | ✅ Done | Dynamic version loading |
| Storage Management | ✅ Done | Clear cache button |
| Preferences | ✅ Done | Placeholder for future |
| Legal Links | ✅ Done | Opens in browser |
| Support Options | ✅ Done | Placeholder for future |
| Social Sharing | ✅ Done | Placeholder for future |
| Logout | ✅ Done | With confirmation |
| Delete Account | ✅ Done | With warning |

---

## 🔮 Coming Soon

### High Priority
- Download History
- Statistics Dashboard
- Subscription Management
- Backup & Restore

### Medium Priority
- Accessibility Settings
- Advanced Preferences
- Connected Accounts
- Notification Settings

### Low Priority
- Referral Program
- Achievements
- Support Tickets
- Device Management

See `docs/PROFILE_SETTINGS_PROPOSAL.md` for details.

---

## 🐛 Troubleshooting

### Profile tab not showing?
```bash
flutter clean
flutter pub get
flutter run
```

### Links not working?
- Check internet permission in `AndroidManifest.xml`
- Verify URLs are correct
- Test with `url_launcher` example app

### Package info not loading?
- Ensure `package_info_plus` is installed
- Check app has proper permissions
- Verify `pubspec.yaml` has the dependency

---

## 📚 Documentation

- **Full Details**: `docs/PROFILE_SETTINGS_PROPOSAL.md`
- **Integration Summary**: `docs/PROFILE_INTEGRATION_SUMMARY.md`
- **Quick Reference**: This file

---

## 💡 Tips

1. **Customize Colors**: Edit the purple gradient in `_buildProfileHeader()`
2. **Add More Sections**: Use `_buildSection()` widget
3. **Add More Items**: Use `_buildListTile()` widget
4. **Change Icons**: Replace `Icons.*` with any Material icon
5. **Update Branding**: Change "QuickPost" to your app name

---

## 🎨 Customization Examples

### Change Primary Color
```dart
// From:
color: Colors.purple

// To:
color: Colors.blue
```

### Add New Section
```dart
_buildSection(
  title: 'My New Section',
  children: [
    _buildListTile(
      icon: Icons.star,
      title: 'My Feature',
      subtitle: 'Feature description',
      onTap: () => print('Tapped!'),
    ),
  ],
)
```

### Add New List Item
```dart
_buildListTile(
  icon: Icons.favorite,
  title: 'Favorites',
  subtitle: 'View your favorites',
  onTap: () => Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const FavoritesScreen(),
    ),
  ),
)
```

---

## 📊 Analytics (Optional)

Track profile screen usage:

```dart
// In initState:
FirebaseAnalytics.instance.logScreenView(
  screenName: 'profile_screen',
);

// Track feature access:
FirebaseAnalytics.instance.logEvent(
  name: 'profile_feature_accessed',
  parameters: {
    'feature': 'privacy_policy',
  },
);
```

---

## ✅ Pre-Release Checklist

- [ ] URLs updated to production
- [ ] User email integrated with auth
- [ ] All links tested
- [ ] Dialogs tested
- [ ] No console errors
- [ ] Responsive on all screen sizes
- [ ] Accessibility verified
- [ ] Analytics configured (if using)
- [ ] Release notes prepared

---

## 🆘 Need Help?

1. Check `docs/PROFILE_SETTINGS_PROPOSAL.md` for detailed info
2. Review `lib/screens/profile/profile_screen.dart` source code
3. Check Flutter documentation for specific widgets
4. Test with `flutter run -v` for verbose output

---

## 📞 Support

For issues or questions:
1. Check the documentation files
2. Review the source code comments
3. Test with a fresh `flutter clean && flutter run`
4. Check Flutter/Dart console for errors

---

**Happy coding! 🎉**
