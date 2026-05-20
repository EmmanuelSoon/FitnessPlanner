## Basic explanation of what is flutter and dart. 

Flutter is a single-codebase, no-backend framework — there's no frontend/backend split like a
  web app. Here's how it works:

  ---  Flutter vs traditional web
  In a web app you have:
  - Frontend (browser) — HTML/JS/CSS, talks to a server
  - Backend (server) — API, database, business logic

  In Flutter:
  - Everything runs on the device (phone, desktop)
  - The "database" is local storage on the device (Hive in your case)
  - There's no server unless you explicitly add one (e.g. Firebase, your own API)
  - Dart compiles down to native ARM code — not a webpage

  So your app is entirely self-contained right now.

  ---
  What each folder does in your project

  lib/
  ├── main.dart               ← App entry point. Boots Hive, wraps app in Riverpod,
  │                             sets the first screen. Think of it as index.js.
  │
  ├── domain/
  │   └── models/
  │       ├── exercise.dart           ← Plain data class. No Flutter, no UI.
  │       ├── workout.dart            ← Plain data class. Contains business logic
  │       │                             (generateWorkoutSequence, totalDuration).
  │       ├── exercise_adapter.dart   ← Teaches Hive how to serialize Exercise to disk.
  │       └── workout_adapter.dart    ← Teaches Hive how to serialize Workout to disk.
  │
  ├── data/
  │   └── workout_repository.dart    ← The "database layer". Wraps Hive box with
  │                                    getAll / save / delete methods. Also defines
  │                                    the Riverpod provider so the UI can access it.
  │
  └── presentation/
      └── create_workout.dart        ← All the UI: screens and widgets.
                                       StatefulWidgets, forms, buttons, navigation.

  Analogy if you're thinking in web terms:

  ┌────────────────────────────┬───────────────────────────────────────────┐
  │        Web concept         │          Your Flutter equivalent          │
  ├────────────────────────────┼───────────────────────────────────────────┤
  │ React component            │ Widget (StatelessWidget / StatefulWidget) │
  ├────────────────────────────┼───────────────────────────────────────────┤
  │ useState / Redux           │ Riverpod providers                        │
  ├────────────────────────────┼───────────────────────────────────────────┤
  │ SQL database               │ Hive box (stored on device)               │
  ├────────────────────────────┼───────────────────────────────────────────┤
  │ ORM / model class          │ Exercise, Workout in domain/models/       │
  ├────────────────────────────┼───────────────────────────────────────────┤
  │ Repository / service layer │ WorkoutRepository in data/                │
  ├────────────────────────────┼───────────────────────────────────────────┤
  │ Router / pages             │ Navigator.push(...)                       │
  ├────────────────────────────┼───────────────────────────────────────────┤
  │ index.html entry point     │ main.dart                                 │
  └────────────────────────────┴───────────────────────────────────────────┘

  ---
  How they link up

  main.dart
    └─ opens Hive box, registers adapters
    └─ wraps app in ProviderScope (Riverpod)
    └─ sets home screen → CreateWorkoutScreen

  CreateWorkoutScreen (presentation)
    └─ reads/writes Exercise objects (domain/models)
    └─ calls workoutRepositoryProvider (data) to save

  workoutRepositoryProvider (data)
    └─ holds a WorkoutRepository
    └─ WorkoutRepository talks to Hive box
    └─ Hive uses exercise_adapter + workout_adapter to serialize to disk

  The flow for saving a workout:
  1. User fills form → Exercise objects are built in memory
  2. "Save" tapped → UI calls ref.read(workoutRepositoryProvider).save(workout)
  3. Repository calls _box.put(workout.id, workout)
  4. Hive calls WorkoutAdapter.write() → bytes written to device storage

  ---
  Where a real "backend" would go

  If you ever add a server (e.g. sync workouts across devices), you'd add a third layer:

  lib/
    data/
      workout_repository.dart       ← local Hive (already exists)
      remote_workout_service.dart   ← HTTP calls to your API (future)

  But for this MVP, everything is local — no server needed.


## what other objects should be in /domain? 

The reason it's structured that way is that domain/ is meant to hold more than just models as  the app grows. In Clean Architecture, the domain layer typically has multiple concerns:
  domain/
    models/          ← data classes (what you have now)
    repositories/    ← abstract interfaces (contracts)
    usecases/        ← business logic operations

  repositories/ would hold abstract interfaces like:
  abstract class WorkoutRepository {
    List<Workout> getAll();
    Future<void> save(Workout workout);
  }
  The actual Hive implementation in data/ would implement that interface. This means your UI
  only depends on the abstract contract, not on Hive directly — so swapping Hive for SQLite
  later wouldn't touch the UI at all.

  usecases/ would hold single-purpose business logic classes like GenerateWorkoutSequenceUseCase   or CalculateTotalDurationUseCase — logic that currently lives inside the model classes
  themselves.

  ---
  For your MVP, you don't need repositories/ or usecases/ yet — the project is small enough that   the current structure works fine. The models/ subfolder is just forward-planning for when
  those other folders arrive. If you prefer, you could flatten it to domain/exercise.dart, domain/workout.dart for now and restructure later.