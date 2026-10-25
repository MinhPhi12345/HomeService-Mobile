# HomeService Mobile

Flutter client for customer and Tasker flows. Requires Flutter 3.44+ (Dart 3.12+) and the HomeService API.

## Run

From this directory:

```powershell
flutter pub get
flutter run
```

By default, the app calls `http://10.0.2.2:8080/api`, which reaches the host machine from an Android Emulator running the backend with Docker Compose. Override it for another environment:

```powershell
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080/api
```

For a physical device, use the development machine's LAN IP. Use HTTPS for release builds; cleartext traffic is enabled only in the Android debug manifest.

## Implemented flows

- Customer: register/sign in, load service categories, share current GPS coordinates, create cash or simulated online bookings, view bookings, and manage notifications.
- Tasker: register/sign in, view and accept/reject offers, manage availability, view bookings, and manage notifications. A Tasker profile must already exist in the backend.

JWTs are stored with platform secure storage. API and response models are in `lib/data/api_client.dart`; screens are in `lib/ui/app_pages.dart`.

Run checks with:

```powershell
flutter analyze
flutter test
flutter build apk --debug
```
