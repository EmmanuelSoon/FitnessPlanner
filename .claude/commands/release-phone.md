# Release build on physical phone — FitnessPlanner

Builds and runs the app in **release mode** on the connected Android phone
(not the emulator). Uses `flutter run --release` so the build, install,
and launch happen in one step.

---

## 1. Verify a physical device is connected

```powershell
$adb = "C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb devices
```

You should see a device listed as `device` (not `emulator`). If the status
is `unauthorized`, ask the user to accept the RSA prompt on the phone screen
and re-run. If no device appears, ask the user to connect the phone via USB
and enable USB debugging.

## 2. Capture the physical device ID

```powershell
$adb = "C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$deviceId = (& $adb devices |
  Select-String '^\S+\s+device$' |
  Where-Object { $_.Line -notmatch 'emulator' } |
  Select-Object -First 1 |
  ForEach-Object { ($_.Line -split '\s+')[0] })
Write-Host "Physical device: $deviceId"
```

If `$deviceId` is empty, stop and tell the user no physical device was found.

## 3. Build and run in release mode

```powershell
flutter pub get
flutter run --release -d $deviceId --no-pub
```

Wait for **"An Observatory debugger"** or the app to launch on the phone.
Release builds take longer than debug (~1–3 min on first run); subsequent
runs are faster due to Gradle caching.

> **Note:** `flutter run --release` connects Dart's release runtime but
> does NOT attach the debugger — this is the same binary that would go to
> production. Hot-reload is **not** available in release mode.

## 4. Confirm the app launched

Take a screenshot via adb to confirm the home screen is visible:

```powershell
$adb = "C:\Users\emman\AppData\Local\Android\Sdk\platform-tools\adb.exe"
New-Item -ItemType Directory -Force verify-screenshots | Out-Null
& $adb -s $deviceId exec-out screencap -p > "verify-screenshots\release-launch.png"
```

Then send the screenshot to the user.

## 5. Stop the run

Press **q** in the terminal running `flutter run` to quit (this does not
uninstall the app — it stays installed on the phone).

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| `device unauthorized` | Accept RSA fingerprint on phone → re-run step 1 |
| `No devices found` | Enable USB debugging in Developer Options |
| Gradle build failure | Run `flutter clean` then retry step 3 |
| App crashes on launch | Run `& $adb -s $deviceId logcat -d` and report the last 50 lines |
