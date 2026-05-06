# BantayPamilya

BantayPamilya is a Flutter-based parent-child safety and device control app. It supports QR pairing, a parent allowlist with time limits, and a child-mode launcher with an app blocker.

## Key Features

- QR pairing between parent and child devices
- Parent allowlist with per-app daily limits
- Child installed app sync + real-time rules
- App blocking via Android Accessibility Service
- Child launcher that shows only allowed apps


## Setup

1. Install Flutter and the Android SDK.
2. Run `flutter pub get`.
3. Configure Firebase using FlutterFire CLI and ensure the Android `google-services.json` is in place.
4. Enable Firestore in the Firebase console.
5. On the child device, grant:
   - Usage Access
   - Accessibility access for the app blocker
6. Optional: Set this app as the default Home launcher to use the child launcher UI.

## Basic Flow

1. On the child device, sign in and open **Device QR** to show the pairing code.
2. On the parent device, scan the QR code and set allowed apps and time limits.
3. On the child device, open **Child Mode** to sync installed apps and enforce limits.
4. Use **Child Launcher** to show only allowed apps.
