# Profile Screen - URLs & Email Reference

## Quick Reference

### Website
```
https://quickpost.arisesolo.com
```

### Email Addresses
```
Support:  arisesoloapp@gmail.com
Feedback: arisesoloapp@gmail.com
```

### Play Store
```
https://play.google.com/store/apps/details?id=com.quickpost.app
```

---

## Feature Routes

| Feature | Route | Destination |
|---------|-------|-------------|
| **Check for Updates** | URL | Play Store |
| **Report a Bug** | URL | Play Store |
| **Privacy Policy** | URL | https://quickpost.arisesolo.com/privacy |
| **Terms of Service** | URL | https://quickpost.arisesolo.com/terms |
| **Help & Support** | Email | support@quickpost.arisesolo.com |
| **Send Feedback** | Email | feedback@quickpost.arisesolo.com |
| **Share App** | Native Share | SMS, Email, WhatsApp, etc. |
| **Rate Us** | URL | Play Store |
| **Visit Website** | URL | https://quickpost.arisesolo.com |

---

## Email Templates

### Support Email
```
To: arisesoloapp@gmail.com
Subject: QuickPost Support - v{VERSION}

Hello,

I need help with QuickPost.

App Version: {VERSION}
Build: {BUILD_NUMBER}

Please describe your issue:
```

### Feedback Email
```
To: arisesoloapp@gmail.com
Subject: QuickPost Feedback - v{VERSION}

User Feedback:

{USER_MESSAGE}

App Version: {VERSION}
Build: {BUILD_NUMBER}
```

---

## Implementation

All routes are implemented in `lib/screens/profile/profile_screen.dart`:

### URL Links
```dart
_launchUrl('https://quickpost.arisesolo.com')
_launchUrl('https://quickpost.arisesolo.com/privacy-policy')
_launchUrl('https://quickpost.arisesolo.com/terms')
_launchUrl('https://play.google.com/store/apps/details?id=com.quickpost.app')
```

### Email Routes
```dart
_sendSupportEmail()      // Opens support email
_sendFeedbackEmail()     // Opens feedback dialog → email
```

### Share
```dart
_shareApp()              // Opens native share sheet
```

---

## Testing

### Test All Routes
1. ✅ Check for Updates → Opens Play Store
2. ✅ Report a Bug → Opens Play Store
3. ✅ Privacy Policy → Opens website
4. ✅ Terms of Service → Opens website
5. ✅ Help & Support → Opens email client
6. ✅ Send Feedback → Opens dialog → email
7. ✅ Share App → Opens share sheet
8. ✅ Rate Us → Opens Play Store
9. ✅ Visit Website → Opens website

---

## Configuration

### Before Release
- [ ] Verify all email addresses are correct
- [ ] Verify all URLs are correct
- [ ] Set up email forwarding
- [ ] Test all routes on device
- [ ] Verify website pages exist
- [ ] Set up auto-responders (optional)

---

## Support

For issues or questions about profile routes:
1. Check `docs/PROFILE_ROUTES_AND_URLS.md`
2. Review `lib/screens/profile/profile_screen.dart`
3. Test on actual device
4. Check Flutter console for errors

---

**All routes configured and ready! 🚀**
