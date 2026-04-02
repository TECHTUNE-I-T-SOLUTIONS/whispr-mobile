# Deep Linking Setup Guide - Whispr Mobile App

## Overview

The deep linking system allows users to share chronicles posts via links that:
- Open in the mobile app if installed
- Fall back to the web version if the app isn't installed
- Seamlessly switch between web and app experiences

## Architecture

```
Shared Link
    ↓
https://whisprwords.vercel.app/api/deeplink?type=chronicles&id=UUID
    ↓
Backend detects device type (mobile/desktop)
    ↓
Mobile: Redirects to → whispr://app/chronicles/UUID → Mobile App (com.whispr.whisprmobile)
Web/Desktop: Redirects to → https://whisprwords.vercel.app/chronicles/UUID

Website Smart Banner:
    ↓
User visits https://whisprwords.vercel.app/chronicles/UUID
    ↓
AppBanner detects mobile device
    ↓
Shows "Open in Whispr App" banner with deeplink button
    ↓
If app installed: Opens via deeplink
If app not installed: Shows store download button
```

## Components Setup

### 1. **Flutter Mobile App** ✅

#### Android Configuration
- **File**: `android/app/src/main/AndroidManifest.xml`
- **Added**: Deep link intent filters for:
  - Custom scheme: `whispr://`
  - HTTPS URLs: `https://whisprwords.vercel.app/chronicles/*`

#### iOS Configuration  
- **File**: `ios/Runner/Info.plist`
- **Added**: URL scheme support for `whispr://`

#### Router Configuration
- **File**: `lib/core/router/app_router.dart`
- **Updated**: 
  - Routes support deep link paths like `/chronicles/:id`
  - Public routes accessible without authentication
  - Deep linked posts/chronicles work for all users

#### Share Function
- **File**: `lib/features/chronicles/presentation/chronicles_post_detail_screen.dart`
- **Updated**: Uses `/api/deeplink` endpoint to generate smart share links

### 2. **Backend (Next.js)** ✅

#### New API Endpoint
- **File**: `app/api/deeplink/route.ts`
- **Purpose**: Intelligent redirect logic
- **Features**:
  - Detects Android/iOS/Desktop
  - Validates post IDs (UUID format)
  - Shows loading UI with web fallback
  - Auto-redirects to web after timeout if app not installed

#### Smart App Banner Component
- **File**: `components/app-banner.tsx`
- **Purpose**: Show intelligent banner on web for mobile users
- **Features**:
  - Mobile device detection
  - App installation detection via deeplink attempt
  - Smart "Open in App" button if installed
  - App store download links if not installed
  - User dismissal with 24-hour persistence
  - Mobile-responsive design
- **Integration**: Add to pages where content can be opened in app

### 3. **Environment Configuration** ✅

#### Flutter `.env` Files
```env
API_BASE_URL=http://192.168.1.116:3000/api        # Local backend
SHARE_BASE_URL=https://whisprwords.vercel.app     # Web domain for shares
```

#### Next.js Environment
- Already configured via `SHARE_BASE_URL` in Flutter

#### Android App Package Name
- **Changed from**: `com.example.whisprmobile` (placeholder)
- **Changed to**: `com.whispr.whisprmobile` (production)
- **Files updated**:
  - `android/app/build.gradle.kts`
  - `android/app/src/main/AndroidManifest.xml`

## How It Works

### User Shares a Chronicle:
1. User taps Share button on chronicle detail screen
2. Share URL is: `https://whisprwords.vercel.app/api/deeplink?type=chronicles&id={UUID}`
3. Share tracking API call to `/chronicles/posts/{id}/shares`

### Recipient Opens the Link:

#### On Mobile with App Installed:
1. Click link → `whisprwords.vercel.app/api/deeplink`
2. Backend detects: Android/iOS
3. Returns HTML page that tries: `whispr://app/chronicles/{id}`
4. Android/iOS OS intercepts and opens app ✅
5. App router navigates to chronicle detail screen
6. Falls back to web after 2 seconds if app doesn't respond

#### On Mobile without App Installed:
1. Click link → `whisprwords.vercel.app/api/deeplink`
2. Backend detects: Mobile (Android/iOS)
3. Returns HTML with fallback after 2 seconds
4. Deep link fails to open (no app handler)
5. Auto-redirects to web version: `whisprwords.vercel.app/chronicles/{id}`
6. User sees chronicle in browser ✅

#### On Desktop:
1. Click link → `whisprwords.vercel.app/api/deeplink`
2. Backend detects: Desktop (not mobile)
3. Directly redirects to web: `whisprwords.vercel.app/chronicles/{id}`
4. User sees chronicle on web ✅

## Installation & Build Instructions

### Android
```bash
# Flutter build
flutter pub get
flutter build apk

# Test deep links:
adb shell am start -W -a android.intent.action.VIEW \
  -d "whispr://app/chronicles/f8966533-7fa4-4b45-9f46-b49af86c21f6" \
  com.example.whisprmobile

# Or from web link:
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://whisprwords.vercel.app/api/deeplink?type=chronicles&id=f8966533-7fa4-4b45-9f46-b49af86c21f6"
```

### iOS
```bash
# Flutter build
flutter pub get
flutter build ios

# Test deep links:
# Via simulator:
xcrun simctl openurl booted "whispr://app/chronicles/f8966533-7fa4-4b45-9f46-b49af86c21f6"

# Or test via web link (will show 2-second loading screen before redirect)
```

### Testing Deeplinks

#### Quick Test on Android:
1. Share a chronicle from the app
2. Open the link in another app (Chrome, Messages, etc.)
3. Should see loading screen, then app opens with chronicle loaded

#### Manual Deep Link Test (Android):
```bash
# Using custom scheme
adb shell am start -W -a android.intent.action.VIEW \
  -d "whispr://app/chronicles/f8966533-7fa4-4b45-9f46-b49af86c21f6" \
  com.whispr.whisprmobile

# Using web fallback
adb shell am start -W -a android.intent.action.VIEW \
  -d "https://whisprwords.vercel.app/api/deeplink?type=chronicles&id=f8966533-7fa4-4b45-9f46-b49af86c21f6"
```

## Supported Deep Link Types

| Type | Route | Example |
|------|-------|---------|
| Chronicle | `/chronicles/{id}` | `/chronicles/f8966533-7fa4-4b45-9f46-b49af86c21f6` |
| Post | `/post/{id}` | `/post/abc123` |
| Creator | `/creator/{id}` | `/creator/user-123` |

## Future Enhancements

### To Add More Deep Link Types:
1. Add new route to `app_router.dart` with path parameter
2. Register paths in Android `AndroidManifest.xml` deep link intent filter
3. Register URL scheme in iOS `Info.plist` URL scheme config
4. Update backend `/api/deeplink` route to handle new type

### Pull-to-Refresh After Deep Link:
Add to app router redirect to refresh post data when opened via deep link:
```dart
redirect: (context, state) {
  // Refresh data if opened via deep link
  if (state.extra?['refreshData'] == true) {
    // Trigger refresh
  }
  return null;
}
```

### Analytics:
Track deep link opens:
```dart
// In app router
Future<void> _trackDeepLinkOpen(String type, String id) async {
  await apiService.post('/analytics/deeplink', data: {
    'type': type,
    'id': id,
  });
}
```

## Troubleshooting

### Deep Link Not Working on Android:
1. Rebuild APK after manifest changes: `flutter clean && flutter build apk`
2. Ensure `android:exported="true"` on MainActivity
3. Check intent filters are in correct activity
4. Verify app package name matches in ADB commands

### Deep Link Not Working on iOS:
1. Rebuild iOS app: `flutter clean && flutter build ios`
2. Check URL schemes in `Info.plist`
3. Verify `CFBundleURLSchemes` contains `whispr`
4. Test via Xcode: `xcrun simctl openurl booted`

### Share Link Shows Error:
1. Check backend is running and accessible
2. Verify post ID is valid UUID format
3. Check `/api/deeplink` endpoint returns 200 OK
4. Test URL in browser: `https://whisprwords.vercel.app/api/deeplink?type=chronicles&id={UUID}`

### Web Fallback Not Showing:
1. Check browser supports JavaScript (needed for redirect)
2. Verify `https://whisprwords.vercel.app/chronicles/{id}` exists and is public
3. Check 2-second timeout in deeplink route HTML

## Files Modified

```
Mobile App:
├── android/app/build.gradle.kts                  [UPDATED: Package name to com.whispr.whisprmobile]
├── android/app/src/main/AndroidManifest.xml     [ADDED: Deep link intent filters]
├── ios/Runner/Info.plist                         [ADDED: URL schemes]
├── lib/core/router/app_router.dart               [UPDATED: Public routes, deep link support]
├── lib/features/chronicles/presentation/
│   └── chronicles_post_detail_screen.dart        [UPDATED: Share function to use /api/deeplink]
└── lib/core/constants/app_constants.dart         [ADDED: shareBaseUrl constant]

Backend:
├── app/api/deeplink/route.ts                     [CREATED: Deep link redirect logic]
└── components/app-banner.tsx                     [CREATED: Smart app banner for mobile users]
```

## Next Steps

1. ✅ Test share functionality in dev environment
2. ✅ Verify deep links work on physical Android/iOS devices
3. ✅ Test web fallback with app not installed
4. ✅ Update Android app package name to `com.whispr.whisprmobile`
5. [ ] Integrate smart app banner component to web pages
6. [ ] Set up App Linking Verification on Google Play Console (Android)
7. [ ] Configure Apple App Site Association (.well-known/apple-app-site-association) for iOS
8. [ ] Update App Store links in AppBanner component with real app IDs
9. [ ] Monitor deep link analytics via `/analytics/deeplink` endpoint
10. [ ] Add campaign tracking parameters to share URLs

## Integration Summary

### Complete User Journey:

**Desktop User:**
```
Clicks Share Link
  ↓
Web: /api/deeplink redirects to /chronicles/{id}
  ↓
Views on web ✅
```

**Mobile User with App:**
```
Clicks Share Link (from messaging app)
  ↓
Web: /api/deeplink detects mobile + app installed
  ↓
Attempts whispr://app/chronicles/{id}
  ↓
App opens on Flutter side
  ↓
Router navigates to ChroniclesPostDetailScreen ✅
```

**Mobile User without App:**
```
Clicks Share Link (from messaging app)
  ↓
Web: AppBanner detects mobile
  ↓
Shows "Open in Whispr App" banner with Open button
  ↓
User taps Open
  ↓
Deeplink fails (no app)
  ↓
Banner shows "Get App" button
  ↓
User downloads from Play/App Store ✅
  ↓
Next time: Opens in app directly ✅
```

