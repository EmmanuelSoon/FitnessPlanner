# Quick Start Guide - Fitness Planner

## Initial Setup

### 1. Open Android Studio
- Open the `fitnessPlanner` project
- Wait for Gradle sync to complete
- Ensure no red error marks in the project

### 2. Connect Device or Emulator
- Connect an Android device with USB debugging enabled, OR
- Open Android Emulator (API level 34 or higher)

### 3. Run the App
- Click the green "Run" button (or press Shift+F10)
- Select your device
- Wait for the app to install and launch

---

## Using the Fitness Planner

### Creating Your First Workout

1. **Open the app** - You'll see the main screen with empty workout list
2. **Click "Create Workout"** button at the top
3. **Enter Workout Details**:
   - Workout Name: e.g., "Monday Upper Body"
   - Description (optional): e.g., "Back and chest focus"
4. **Add Exercises**:
   - Type exercise name in the text field (e.g., "Bench Press")
   - Click "Add Exercise"
   - Repeat for each exercise in your workout
5. **Add Sets for Each Exercise**:
   - Select an exercise from the list below
   - Enter the number of reps (e.g., 10)
   - Choose rest duration:
     - **30s** - Short rest for cardio-style training
     - **60s** - Standard rest between sets
     - **90s** - Longer rest for heavy compounds
     - **120s** - Extra long rest for max strength
     - Or enter a custom value in seconds
   - Click "Add Set"
   - Repeat to add multiple sets per exercise
6. **Save Workout** - Click the green "Save Workout" button

**Example Workout Structure:**
```
Upper Body Workout
├── Bench Press
│   ├── Set 1: 10 reps, 60s rest
│   ├── Set 2: 10 reps, 60s rest
│   └── Set 3: 8 reps, 60s rest
├── Rows
│   ├── Set 1: 12 reps, 60s rest
│   ├── Set 2: 12 reps, 60s rest
│   └── Set 3: 10 reps, 90s rest
└── Shoulder Press
    ├── Set 1: 8 reps, 60s rest
    └── Set 2: 8 reps, 60s rest
```

### Executing a Workout

1. **From Main Screen** - Click "Start" button next to your workout
2. **Workout Executor Screen Opens**:
   - Shows workout name at top
   - Displays current exercise name
   - Shows "Set: 1/X" (current set / total sets)
   - Shows "Reps: Y" (reps for this exercise)
3. **Perform Your Exercise**:
   - Do the required number of reps
   - When finished, click "Next Set"
4. **Rest Timer Starts**:
   - Large countdown timer appears (MM:SS format in red)
   - Shows how many seconds left to rest
   - When timer reaches 00:00:
     - 🔊 **BEEP** - Audio alert sounds
     - 📳 Phone vibrates for 200ms
5. **Continue With Next Set**:
   - New exercise/set loads automatically
   - Follow same process: perform reps → click "Next Set" → rest
6. **Finish Workout**:
   - After the final set, click "Finish Workout" button
   - Your workout is logged with completion time
   - You're returned to main screen

### Tracking Your History

1. **Click "Workout History"** from main screen
2. **Calendar View Appears**:
   - Shows current month and year
   - Green-highlighted dates = days you completed workouts
   - White dates = no workout completed
3. **Understanding the Display**:
   - Each cell represents one day
   - First row shows: Sun, Mon, Tue, Wed, Thu, Fri, Sat
   - Scroll or navigate to see different months

---

## Tips & Tricks

### Timer Management
- **Skip Rest Early**: Click "Next Set" button to advance immediately
- **Adjust Rests**: Custom rest times help tailor intensity
- **Keep Screen On**: Screen auto-locks during workout to stay active

### Workout Design
- **Progressive Overload**: Add more sets or reps each week
- **Mix Durations**: Use shorter rests (30-60s) for hypertrophy, longer (90-120s) for strength
- **Exercise Order**: Start with compound movements, finish with isolation

### History Tracking
- **Consistency**: Finish workouts to build your calendar history
- **Green Dates**: Visual motivation to see your progress
- **Frequency**: Track which days you're most consistent

---

## Common Tasks

### Edit a Workout
1. Delete the old workout: Main Screen → Click "Delete"
2. Create a new one with updated details

### Delete a Workout
1. From Main Screen, click "Delete" on any workout
2. Confirm deletion (permanent)

### View Past Workouts
1. Click "Workout History"
2. Look for green-highlighted dates on calendar
3. That date indicates you completed a workout that day

### Create Multiple Workouts
- Create different routines for different days
- Name them clearly (e.g., "Monday Push", "Wednesday Pull", "Friday Legs")
- Switch between workouts from the main screen

---

## Troubleshooting

### Timer Doesn't Sound
- Check phone is not on silent (mute switch)
- Ensure volume is turned up in settings
- Restart the app

### Workout Doesn't Save
- Ensure you filled in all required fields (workout name, at least one exercise and set)
- Check that sets have valid rep counts (positive numbers)
- Try creating again

### Calendar Shows No Workouts
- Workouts only appear after you click "Finish Workout"
- Closing the app without finishing doesn't log the workout
- Check you selected correct month

### App Crashes
- Update to latest Android OS on your device
- Reinstall the app
- Clear app data in Settings → Apps → fitnessPlanner → Clear Cache/Storage

---

## Screen Keeps Locking

The app is designed to keep the screen ON during workouts. If it still locks:
1. Go to Settings → Display → Screen Timeout
2. Set to "Never" or maximum duration
3. Close Settings
4. Restart the app

---

## Data Storage

Your workouts and history are stored locally on your device in a SQLite database. They persist even after closing the app.

**No cloud sync** - Data stays on your device unless you uninstall the app.

To backup:
- Connect device to computer
- Navigate to: `Android/data/com.example.fitnessplanner/`
- Copy the database files

---

## Feedback & Improvements

If you find issues or want to add features:
1. Keep detailed notes of what happened
2. Note the steps to reproduce
3. Screenshots help explain problems
4. Share feedback for app improvements

---

**Ready to start your fitness journey!** 💪

Create your first workout now and track your progress! 🎯

