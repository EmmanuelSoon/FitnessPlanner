# Android verifier — FitnessPlanner

Launches the app on the Pixel_8 AVD and gives you a running handle so
you can observe any change at the real Android surface.

---

## 1. Start the emulator (if not already running)

```powershell
flutter devices 2>&1
```

If `emulator` already appears in the output, skip to step 2.
Otherwise launch it:

```powershell
flutter emulators --launch Pixel_8
```

Then poll until the device is ready (usually 30–60 s):

```powershell
$deadline = (Get-Date).AddMinutes(3)
do {
  Start-Sleep -Seconds 5
  $out = flutter devices 2>&1
} until ($out -match 'emulator' -or (Get-Date) -gt $deadline)
flutter devices
```

## 2. Capture the emulator device ID

```powershell
$deviceId = (flutter devices 2>&1 |
  Select-String 'emulator' |
  Select-Object -First 1 |
  ForEach-Object { ($_.Line -split '•')[1].Trim() })
Write-Host "Device: $deviceId"
```

## 3. Build and run

```powershell
flutter pub get
flutter run -d $deviceId --no-pub
```

Wait for **"Flutter run key commands"** — the app is live.
Keep the process running; open a second terminal for screenshot
commands.

## 4. Take screenshots

From the second terminal, any time you want to capture the current
emulator screen:

```powershell
$deviceId = (flutter devices 2>&1 |
  Select-String 'emulator' |
  Select-Object -First 1 |
  ForEach-Object { ($_.Line -split '•')[1].Trim() })

New-Item -ItemType Directory -Force verify-screenshots | Out-Null
flutter screenshot -d $deviceId --out "verify-screenshots\<name>.png"
```

Or via adb directly:

```powershell
adb -s $deviceId exec-out screencap -p > "verify-screenshots\<name>.png"
```

Screenshots go in `verify-screenshots/` at the repo root (do not
commit them).

## 5. Hot-reload / hot-restart

While `flutter run` is open, press:
- **r** — hot reload (UI changes, keeps state)
- **R** — hot restart (full restart, clears state)
- **q** — quit

---

## What to do with this handle

Once the app is running, drive it to wherever the changed code
executes and observe. Standard approach:

1. **Read the diff** — identify which screen / flow the change lives in.
2. **Navigate there** in the emulator — tap through the app just as a
   user would.
3. **Trigger the changed behaviour** — the exact action that exercises
   the diff (tap a button, submit a form, let a timer fire, etc.).
4. **Observe and capture** — screenshot the result; note what you see
   vs. what was expected.
5. **Probe adjacent paths** — try the edge cases the change is nearest
   to (empty input, rapid taps, back-button mid-flow, etc.).

---

## Reporting template

```
## Verification: <one-line what changed>

**Verdict:** PASS | FAIL | BLOCKED | SKIP

**Claim:** <what the change is supposed to do>

**Method:** Flutter run on Pixel_8 AVD (Android)

### Steps

1. ✅/❌/⚠️/🔍 <action on running app> → <what you observed>
   <screenshot path or captured output>

**Screenshot:** verify-screenshots/<key-frame>.png

### Findings
<anything that made you pause — bugs, friction, surprises, probe results>
```

`🔍` marks a probe step (off the happy path). Include at least one.
`⚠️` flags anything worth interrupting the reviewer for.
