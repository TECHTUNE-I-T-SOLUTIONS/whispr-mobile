# Push notifications (FCM) — what is done and what you must do

The Dart/Gradle code for Firebase Cloud Messaging is finished and safe to build
with or without credentials. Three **credential artefacts** are still missing,
and only you can download them. Until they exist, the app compiles and runs but
push notifications silently do nothing.

Current state of the code:

- `firebase_core` + `firebase_messaging` are wired in.
- `PushNotificationService._initializeFcm()` calls `Firebase.initializeApp()`,
  requests permission, registers the token to `POST /push/fcm-token`, handles
  token refresh, and routes notification taps.
- `android/app/build.gradle.kts` applies the `com.google.gms.google-services`
  plugin **only when `android/app/google-services.json` exists**, so a missing
  file never breaks the build — it just disables FCM.

---

## Step 0 — package ID (DONE)

The package ID is now **`com.whisprwords.app`**, applied in:

- `android/app/build.gradle.kts` — `namespace` + `applicationId`
- `android/app/src/main/kotlin/com/whisprwords/app/MainActivity.kt` — `package`
- `ios/Runner.xcodeproj/project.pbxproj` — `PRODUCT_BUNDLE_IDENTIFIER`
- `ios/Runner/Info.plist` — `CFBundleURLName`
- `codemagic.yaml` — `PACKAGE_NAME`

`google-services.json` is bound to this ID, so **do not change it again** after
creating the Firebase Android app — a later rename means deleting and
re-creating the Firebase app and re-downloading the file.

The MethodChannel name (`com.whispr.whisprmobile/screenshot`) and the
`whisprmobile://` deep-link scheme were deliberately left alone: they are
internal identifiers, not the package ID, and changing them would need matching
Dart-side edits for no benefit.

---

## Step 1 — client config files (DONE)

Both client configs are in place and both are gitignored, so they exist only on
this machine and in Codemagic's env group — never in git history.

| File | Location | Bound to |
| --- | --- | --- |
| `google-services.json` | `android/app/google-services.json` | `com.whisprwords.app` |
| `GoogleService-Info.plist` | `ios/Runner/GoogleService-Info.plist` | `com.whisprwords.app` |

The iOS plist is wired into the Runner target (Resources build phase) in
`project.pbxproj`, not just dropped in the folder — a plist that is present but
not in the target is silently ignored at runtime. The same is true of a new
file added only to the group without a `PBXBuildFile` entry.

iOS push capability is also wired:

- `ios/Runner/Runner.entitlements` — `aps-environment` (`development`; Xcode
  rewrites this to `production` for App Store builds)
- `CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements` on all three Runner
  build configurations
- `UIBackgroundModes → remote-notification` in `Info.plist`

Note: `firebase_core` and `firebase_messaging` were already in `pubspec.yaml`,
so no pod install runs are needed beyond the normal `pod install` Flutter does.

---

## Step 1b — notification icon

Android draws the status-bar notification icon as a **monochrome silhouette**:
it uses only the alpha channel and tints it. A coloured icon therefore renders
as a solid white blob. The brand mark is supplied as white-on-transparent PNGs
generated from `assets/monochrome.png`:

| Density | Size | Path |
| --- | --- | --- |
| mdpi | 24×24 | `res/drawable-mdpi/ic_whispr_notification.png` |
| hdpi | 36×36 | `res/drawable-hdpi/ic_whispr_notification.png` |
| xhdpi | 48×48 | `res/drawable-xhdpi/ic_whispr_notification.png` |
| xxhdpi | 72×72 | `res/drawable-xxhdpi/ic_whispr_notification.png` |
| xxxhdpi | 96×96 | `res/drawable-xxxhdpi/ic_whispr_notification.png` |

The art is scaled to 86% of the canvas so the system's circular/rounded mask
does not clip it. To regenerate after changing `assets/monochrome.png`: crop to
the alpha bounding box, then re-export at those five sizes.

Where it is used:

- `AndroidManifest.xml` → `com.google.firebase.messaging.default_notification_icon`.
  This is what FCM uses for notifications delivered while the app is
  backgrounded or closed — the ones that appear at the top of the screen.
- `AndroidManifest.xml` → `default_notification_color` =
  `@color/notification_accent` (`#C00000`), the tint applied on Android 7+.
- `push_notification_service.dart` → `AndroidInitializationSettings` and every
  `AndroidNotificationDetails` for locally-shown notifications.

The **coloured** launcher icon (`@mipmap/launcher_icon`) is passed as
`largeIcon` on each notification — that is the full-colour mark shown in the
expanded shade, not the status bar.

iOS has no equivalent setting: the notification icon is always the app icon,
taken from `Assets.xcassets/AppIcon.appiconset`.

---

## Step 1c — the reference steps, for a fresh project

In the Firebase console, open project **`whispr-8c624`** and add an app:

**Android**

1. Add app → Android.
2. Android package name: the final `applicationId` from Step 0.
3. Register, then download `google-services.json`.
4. Place it at `android/app/google-services.json`.

**iOS** (only if you ship iOS)

1. Add app → iOS, bundle ID = the iOS bundle identifier.
2. Download `GoogleService-Info.plist` → `ios/Runner/GoogleService-Info.plist`.
3. In Xcode, enable the *Push Notifications* capability and *Background Modes →
   Remote notifications*.

You do **not** need a SHA-1 fingerprint for FCM. That is only required for
Google Sign-In and Phone Auth.

---

## Step 2 — server-side sending (where the Admin key actually goes)

The file at
`whispr-8c624-firebase-adminsdk-fbsvc-bde177d00f.json`
(in `C:\Users\PRINCE TECHTUNE\Downloads\whatsapp docs\`) is a **Firebase Admin
SDK service-account key**. It contains a private key and is used to *send*
messages from the backend. It is deliberately **not** copied into this repo:
there is no Android or iOS destination for it, because it is not a client
config.

- **Never** copy it into the mobile repo — it is a server credential and would
  leak in git history.
- Put it in the **web project's** gitignored `.env` (or Codemagic's env group)
  as e.g. `FIREBASE_SERVICE_ACCOUNT_JSON` or `FIREBASE_SERVICE_ACCOUNT_BASE64`.
- If it was ever committed or shared, rotate it in the Firebase console
  (Project settings → Service accounts → Generate new private key, and delete
  the old one).

The backend endpoint that sends to a stored token is expected at the web API
(`/push/...`), and the mobile app registers device tokens through
`POST /push/fcm-token`.

---

## Step 3 — give Codemagic the files (it has no access to your disk)

In the Codemagic UI, create the env group **`whispr_android_signing`**, which
`codemagic.yaml` already references, and add:

| Variable | Value |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 whispr-release.jks` |
| `KEYSTORE_PASSWORD` | your keystore password |
| `KEY_ALIAS` | your key alias |
| `KEY_PASSWORD` | your key password |

And in the **`whisprmobile`** group (or the same one), add:

| Variable | Value |
| --- | --- |
| `GOOGLE_SERVICES_JSON_BASE64` | `base64 -w0 android/app/google-services.json` |

To generate the base64 strings locally (Git Bash):

```bash
base64 -w0 android/app/google-services.json
```

If you do not have a keystore yet, create one (keep it and its passwords safe —
losing it means you can never update the app on Play under the same listing):

```bash
keytool -genkey -v -keystore whispr-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias whispr
```

Commit `whispr-release.jks` **nowhere**. `.gitignore` should already cover
`android/key.properties` and `*.jks` — verify that before your first push.

---

## Step 4 — verify it works

1. Build with the `google-services.json` in place.
2. Run on a real device (FCM does not work on most emulators without Google
   Play services).
3. Grant the notification permission when prompted.
4. In the Firebase console → Messaging → *Send test message*, paste the device
   token (log it from `FirebaseMessaging.instance.getToken()`).
5. Confirm the notification arrives and that tapping it routes into the app via
   `NotificationRouter.handle()`.

---

## Troubleshooting

- **Build succeeds but no push**: `google-services.json` missing, or its
  package name does not match `applicationId`. Check the Gradle output for
  `google-services.json not found - building without FCM.`
- **`Firebase.initializeApp()` throws on iOS without a plist**: `main.dart`
  guards this, but confirm `GoogleService-Info.plist` is in the Runner target,
  not just the folder.
- **Notifications arrive in the foreground but not background**: the Android
  manifest needs the `FirebaseMessagingService` receiver — already added in
  `AndroidManifest.xml`; re-check it survived the manifest merge.

---

## Step 5 — the backend contract (implemented in the web repo)

The web app (`D:\Codes\whispr`) now owns the sending side. Files added there:

| File | Role |
| --- | --- |
| `lib/firebase-admin.ts` | Lazy, memoised Admin SDK init from `FIREBASE_SERVICE_ACCOUNT_BASE64`. Never throws on import, so builds without credentials still work. |
| `lib/mobile-push.ts` | The service: token upsert, deactivate, batched delivery, dead-token pruning. |
| `app/api/push/fcm-token/route.ts` | `POST` register, `DELETE` unregister, `GET` diagnostics. |
| `migrations/013_create_mobile_push_tokens.sql` | The `mobile_push_tokens` table. |

`push_subscriptions` could not be reused: its `endpoint` / `p256dh` / `auth`
columns are `NOT NULL` and describe a browser `PushSubscription`. An FCM token
is one opaque string, so it gets its own table.

### Endpoint

`POST /api/push/fcm-token` — auth is `Authorization: Bearer <supabase access
token>`, not the admin cookie, because the app has no cookie jar.

```json
{ "token": "<fcm token>", "platform": "android" }
```

`DELETE` with `{"token": "..."}` deactivates one device; with no body it
deactivates every device for the user. The app calls this on sign-out, before
the session is cleared.

### Delivery

`sendMobilePushToUsers(userIds, payload)` and `sendMobilePushToAll(payload)`
batch through `sendEach` in chunks of 500 (FCM's per-call limit) and mark
tokens inactive when FCM returns `registration-token-not-registered` or
`invalid-registration-token`, so the table does not grow forever.

These are already wired into the existing web push paths, so one call reaches
browsers and phones:

- `lib/push-notifications.ts` → `sendPushNotificationToSubscribers` (broadcast)
- `lib/push-notifications.ts` → `notifyCreator` (single creator)
- `app/api/push/send/route.ts` → honours `targetUsers`, skips the
  single-endpoint welcome flow

### Payload keys the app reads

The Flutter `NotificationRouter` only accepts `whispr://` URIs, so the backend
translates web paths (`/chronicles/x`) into `whispr://chronicles/x` and sends
them as `data.link` (plus `data.payload` for older builds). A payload without a
`whispr://` link is ignored by the app rather than crashing it.

### Before it works

1. Run `migrations/013_create_mobile_push_tokens.sql` in the Supabase SQL editor.
2. Confirm `FIREBASE_SERVICE_ACCOUNT_BASE64` is set in the web deployment env
   (it is in local `.env.local`).
3. Sign in on a device, then `GET /api/push/fcm-token` should report
   `devices: 1` and `pushConfigured: true`.
