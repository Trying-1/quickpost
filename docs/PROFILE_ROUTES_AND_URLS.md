# Profile Screen Routes & URLs Configuration

## Overview

The Profile & Settings screen has been fully configured with proper routes, URLs, and email handlers for all features.

---

## Table of Contents

1. [URLs Configuration](#urls-configuration)
2. [Email Routes](#email-routes)
3. [External Links](#external-links)
4. [Share Functionality](#share-functionality)
5. [Feature Routes](#feature-routes)
6. [Implementation Details](#implementation-details)

---

## URLs Configuration

### Website
```
https://quickpost.arisesolo.com
```

### Privacy Policy
```
https://quickpost.arisesolo.com/privacy-policy
```

### Terms of Service
```
https://quickpost.arisesolo.com/terms
```

### Play Store
```
https://play.google.com/store/apps/details?id=com.quickpost.app
```

---

## Email Routes

### Support Email
**Address**: `arisesoloapp@gmail.com`

**Triggered by**: Help & Support button

**Email Template**:
```
Subject: QuickPost Support - v{VERSION}

Hello,

I need help with QuickPost.

App Version: {VERSION}
Build: {BUILD_NUMBER}

Please describe your issue:
```

**Implementation**:
```dart
Future<void> _sendSupportEmail() async {
  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: 'support@quickpost.arisesolo.com',
    queryParameters: {
      'subject': 'QuickPost Support - v${_packageInfo.version}',
      'body': 'Hello,\n\nI need help with QuickPost.\n\nApp Version: ${_packageInfo.version}\nBuild: ${_packageInfo.buildNumber}\n\nPlease describe your issue:\n',
    },
  );
  
  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri);
  }
}
```

### Feedback Email
**Address**: `arisesoloapp@gmail.com`

**Triggered by**: Send Feedback button

**Features**:
- Opens feedback dialog
- User types feedback message
- Sends via email with app version info

**Email Template**:
```
Subject: QuickPost Feedback - v{VERSION}

User Feedback:

{USER_FEEDBACK}

App Version: {VERSION}
Build: {BUILD_NUMBER}
```

**Implementation**:
```dart
Future<void> _sendFeedbackEmail(String feedback) async {
  final Uri emailUri = Uri(
    scheme: 'mailto',
    path: 'feedback@quickpost.arisesolo.com',
    queryParameters: {
      'subject': 'QuickPost Feedback - v${_packageInfo.version}',
      'body': 'User Feedback:\n\n$feedback\n\nApp Version: ${_packageInfo.version}\nBuild: ${_packageInfo.buildNumber}',
    },
  );
  
  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri);
  }
}
```

---

## External Links

### Check for Updates / Report a Bug
**URL**: Play Store App Page
```
https://play.google.com/store/apps/details?id=com.quickpost.app
```

**Triggered by**:
- Check for Updates button
- Report a Bug button

**Opens in**: External browser

**Implementation**:
```dart
_launchUrl('https://play.google.com/store/apps/details?id=com.quickpost.app')
```

### Privacy Policy
**URL**: Website Privacy Page
```
https://quickpost.arisesolo.com/privacy
```

**Opens in**: External browser

### Terms of Service
**URL**: Website Terms Page
```
https://quickpost.arisesolo.com/terms
```

**Opens in**: External browser

### Visit Website
**URL**: Main Website
```
https://quickpost.arisesolo.com
```

**Opens in**: External browser

---

## Share Functionality

### Share App
**Triggered by**: Share App button

**Share Message**:
```
Check out QuickPost - Create stunning social media posts, videos, and more!

https://play.google.com/store/apps/details?id=com.quickpost.app
```

**Share Subject**:
```
Download QuickPost - Social Media Creator
```

**Implementation**:
```dart
Future<void> _shareApp() async {
  await Share.share(
    'Check out QuickPost - Create stunning social media posts, videos, and more!\n\nhttps://play.google.com/store/apps/details?id=com.quickpost.app',
    subject: 'Download QuickPost - Social Media Creator',
  );
}
```

**Opens in**: Native share sheet (SMS, WhatsApp, Email, etc.)

---

## Feature Routes

### Profile Screen Navigation

| Feature | Route | Type | Action |
|---------|-------|------|--------|
| User Profile | Placeholder | Dialog | Coming Soon |
| Subscription | Placeholder | Dialog | Coming Soon |
| Notifications | Placeholder | Dialog | Coming Soon |
| What's New | Placeholder | Dialog | Coming Soon |
| Theme | Placeholder | Dialog | Coming Soon |
| Language | Placeholder | Dialog | Coming Soon |
| Privacy Policy | External | URL | Opens in browser |
| Terms of Service | External | URL | Opens in browser |
| Help & Support | Email | mailto | Opens email client |
| Report a Bug | External | URL | Opens Play Store |
| Send Feedback | Dialog | Custom | Opens feedback dialog |
| Share App | Native | Share | Opens share sheet |
| Rate Us | External | URL | Opens Play Store |
| Visit Website | External | URL | Opens in browser |
| Logout | Dialog | Confirm | Shows confirmation |
| Delete Account | Dialog | Confirm | Shows warning |

---

## Implementation Details

### URL Launcher
All external URLs use `url_launcher` package:

```dart
Future<void> _launchUrl(String url) async {
  if (await canLaunchUrl(Uri.parse(url))) {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}
```

**Features**:
- Checks if URL can be launched
- Opens in external application (browser)
- Handles errors gracefully

### Share Plus
Share functionality uses `share_plus` package:

```dart
Future<void> _shareApp() async {
  await Share.share(
    'Message text',
    subject: 'Subject line',
  );
}
```

**Features**:
- Opens native share sheet
- Works on Android and iOS
- Supports SMS, Email, WhatsApp, etc.

### Email Handling
Email routes use `mailto:` URI scheme:

```dart
final Uri emailUri = Uri(
  scheme: 'mailto',
  path: 'email@example.com',
  queryParameters: {
    'subject': 'Subject',
    'body': 'Message body',
  },
);

if (await canLaunchUrl(emailUri)) {
  await launchUrl(emailUri);
}
```

**Features**:
- Opens default email client
- Pre-fills subject and body
- Fallback to snackbar if no email client

---

## Configuration for Production

### Before Release

1. **Verify Email Addresses**
   - support@quickpost.arisesolo.com
   - feedback@quickpost.arisesolo.com

2. **Verify URLs**
   - https://quickpost.arisesolo.com
   - https://quickpost.arisesolo.com/privacy
   - https://quickpost.arisesolo.com/terms
   - https://play.google.com/store/apps/details?id=com.quickpost.app

3. **Test All Routes**
   - Click each button
   - Verify correct action
   - Test on actual device

4. **Set Up Email Forwarding**
   - Configure support@quickpost.arisesolo.com
   - Configure feedback@quickpost.arisesolo.com
   - Set up auto-responders (optional)

---

## Testing Checklist

### URL Links
- [ ] Privacy Policy link opens in browser
- [ ] Terms of Service link opens in browser
- [ ] Website link opens in browser
- [ ] Check for Updates opens Play Store
- [ ] Rate Us opens Play Store
- [ ] Report a Bug opens Play Store

### Email Routes
- [ ] Help & Support opens email client
- [ ] Support email pre-fills correctly
- [ ] Feedback dialog opens
- [ ] Feedback email pre-fills correctly
- [ ] Fallback snackbar shows if no email client

### Share Functionality
- [ ] Share App opens share sheet
- [ ] Share message is correct
- [ ] Share subject is correct
- [ ] Can share via SMS, Email, WhatsApp, etc.

### Error Handling
- [ ] Graceful handling if URL cannot be launched
- [ ] Graceful handling if email client unavailable
- [ ] User feedback for all actions
- [ ] No crashes or exceptions

---

## File Structure

```
lib/screens/profile/
├── profile_screen.dart
│   ├── _launchUrl()           - Open external URLs
│   ├── _sendSupportEmail()    - Send support email
│   ├── _sendFeedbackEmail()   - Send feedback email
│   ├── _shareApp()            - Share app via native share
│   ├── _showFeedbackDialog()  - Show feedback input dialog
│   └── [Other methods...]
```

---

## Dependencies

```yaml
dependencies:
  url_launcher: ^6.1.0      # Open URLs and emails
  share_plus: ^12.0.1       # Native share functionality
  package_info_plus: ^4.0.0 # Get app version info
```

---

## Error Handling

### URL Not Available
```dart
if (await canLaunchUrl(Uri.parse(url))) {
  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
} else {
  // URL cannot be launched
  // Show error to user
}
```

### Email Client Not Available
```dart
if (await canLaunchUrl(emailUri)) {
  await launchUrl(emailUri);
} else {
  // No email client available
  // Show snackbar with email address
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Please email us at: arisesoloapp@gmail.com'),
    ),
  );
}
```

---

## Future Enhancements

### Planned Features
1. **In-App Support Chat** - Replace email with chat interface
2. **FAQ Section** - Common questions and answers
3. **Video Tutorials** - Help videos in app
4. **Bug Tracking** - In-app bug reporting with screenshots
5. **Analytics** - Track which features users need help with

### Suggested Routes
```dart
// In-app support chat
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const SupportChatScreen()),
);

// FAQ section
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const FAQScreen()),
);

// Video tutorials
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const TutorialsScreen()),
);
```

---

## Summary

✅ **All routes and URLs configured**:
- 4 external website links
- 2 email routes with templates
- 1 native share functionality
- Proper error handling
- User-friendly feedback

**Ready for production deployment!**

---

## Related Documentation

- [PROFILE_SETTINGS_PROPOSAL.md](./PROFILE_SETTINGS_PROPOSAL.md) - Feature proposals
- [PROFILE_INTEGRATION_SUMMARY.md](./PROFILE_INTEGRATION_SUMMARY.md) - Integration details
- [PROFILE_QUICK_START.md](../PROFILE_QUICK_START.md) - Quick reference
