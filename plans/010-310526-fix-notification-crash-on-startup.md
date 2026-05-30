# Fix: Notification crash on startup

## Context

Verification of the `mesocycle + calendar page` branch found the app stuck on the splash
screen indefinitely. The root cause is in `NotificationService.init()`:

```
AndroidInitializationSettings('ic_launcher')
```

`flutter_local_notifications` looks for `ic_launcher` in `drawable/`, but the file only
exists in `mipmap-*/` (the launcher icon location). The plugin throws a
`PlatformException(invalid_icon, ...)` which propagates unhandled through `main()`,
preventing `runApp()` from ever being called.

## Fix

Two changes — both required:

### 1. Correct the icon name (`lib/services/notification_service.dart:33`)

```dart
// before
const androidSettings = AndroidInitializationSettings('ic_launcher');

// after
const androidSettings = AndroidInitializationSettings('ic_launcher_foreground');
```

`ic_launcher_foreground.png` already exists in all `drawable-{hdpi,mdpi,xhdpi,xxhdpi,xxxhdpi}/`
densities — no new assets needed.

### 2. Graceful degradation in main (`lib/main.dart:36`)

```dart
// before
await NotificationService.instance.init();

// after
try {
  await NotificationService.instance.init();
} catch (_) {
  // Notification init failure must not prevent the app from launching.
}
```

Notification permission can be denied at runtime; the app must never crash because of that.

## Files changed

- `lib/services/notification_service.dart` — line 33
- `lib/main.dart` — line 36

## Verification

1. `flutter run -d emulator-5554` — app should reach `WorkoutListScreen`, not hang on splash.
2. Navigate to calendar and mesocycle screens — both should render.
3. No `PlatformException` or `Unhandled Exception` in the console.
