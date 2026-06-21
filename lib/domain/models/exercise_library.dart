class LibraryExercise {
  final String name;
  final String category;
  final bool isTimed;

  const LibraryExercise({
    required this.name,
    required this.category,
    this.isTimed = false,
  });
}

const List<LibraryExercise> kExerciseLibrary = [
  // Chest
  LibraryExercise(name: 'Bench Press', category: 'Chest'),
  LibraryExercise(name: 'Incline Bench Press', category: 'Chest'),
  LibraryExercise(name: 'Dumbbell Fly', category: 'Chest'),
  LibraryExercise(name: 'Push-Up', category: 'Chest'),
  LibraryExercise(name: 'Wide Push-Up', category: 'Chest'),
  LibraryExercise(name: 'Diamond Push-Up', category: 'Chest'),
  LibraryExercise(name: 'Cable Crossover', category: 'Chest'),
  // Back
  LibraryExercise(name: 'Pull-Up', category: 'Back'),
  LibraryExercise(name: 'Chin-Up', category: 'Back'),
  LibraryExercise(name: 'Barbell Row', category: 'Back'),
  LibraryExercise(name: 'Dumbbell Row', category: 'Back'),
  LibraryExercise(name: 'Lat Pulldown', category: 'Back'),
  LibraryExercise(name: 'Seated Cable Row', category: 'Back'),
  LibraryExercise(name: 'Face Pull', category: 'Back'),
  LibraryExercise(name: 'Deadlift', category: 'Back'),
  // Legs
  LibraryExercise(name: 'Squat', category: 'Legs'),
  LibraryExercise(name: 'Romanian Deadlift', category: 'Legs'),
  LibraryExercise(name: 'Leg Press', category: 'Legs'),
  LibraryExercise(name: 'Lunge', category: 'Legs'),
  LibraryExercise(name: 'Bulgarian Split Squat', category: 'Legs'),
  LibraryExercise(name: 'Leg Curl', category: 'Legs'),
  LibraryExercise(name: 'Leg Extension', category: 'Legs'),
  LibraryExercise(name: 'Calf Raise', category: 'Legs'),
  LibraryExercise(name: 'Pistol Squat', category: 'Legs'),
  // Shoulders
  LibraryExercise(name: 'Overhead Press', category: 'Shoulders'),
  LibraryExercise(name: 'Dumbbell Shoulder Press', category: 'Shoulders'),
  LibraryExercise(name: 'Lateral Raise', category: 'Shoulders'),
  LibraryExercise(name: 'Front Raise', category: 'Shoulders'),
  LibraryExercise(name: 'Arnold Press', category: 'Shoulders'),
  LibraryExercise(name: 'Rear Delt Fly', category: 'Shoulders'),
  LibraryExercise(name: 'Upright Row', category: 'Shoulders'),
  // Arms
  LibraryExercise(name: 'Barbell Curl', category: 'Arms'),
  LibraryExercise(name: 'Dumbbell Curl', category: 'Arms'),
  LibraryExercise(name: 'Hammer Curl', category: 'Arms'),
  LibraryExercise(name: 'Preacher Curl', category: 'Arms'),
  LibraryExercise(name: 'Tricep Pushdown', category: 'Arms'),
  LibraryExercise(name: 'Skull Crusher', category: 'Arms'),
  LibraryExercise(name: 'Overhead Tricep Extension', category: 'Arms'),
  LibraryExercise(name: 'Close-Grip Bench Press', category: 'Arms'),
  // Core
  LibraryExercise(name: 'Plank', category: 'Core', isTimed: true),
  LibraryExercise(name: 'Side Plank', category: 'Core', isTimed: true),
  LibraryExercise(name: 'Hollow Hold', category: 'Core', isTimed: true),
  LibraryExercise(name: 'Crunch', category: 'Core'),
  LibraryExercise(name: 'Sit-Up', category: 'Core'),
  LibraryExercise(name: 'Leg Raise', category: 'Core'),
  LibraryExercise(name: 'Russian Twist', category: 'Core'),
  LibraryExercise(name: 'Ab Wheel Rollout', category: 'Core'),
  // Calisthenics
  LibraryExercise(name: 'Muscle-Up', category: 'Calisthenics'),
  LibraryExercise(name: 'Handstand Push-Up', category: 'Calisthenics'),
  LibraryExercise(name: 'L-Sit', category: 'Calisthenics', isTimed: true),
  LibraryExercise(name: 'Dead Hang', category: 'Calisthenics', isTimed: true),
  LibraryExercise(name: 'Wall Sit', category: 'Calisthenics', isTimed: true),
  LibraryExercise(name: 'Pike Push-Up', category: 'Calisthenics'),
  LibraryExercise(name: 'Archer Push-Up', category: 'Calisthenics'),
  LibraryExercise(name: 'Dips', category: 'Calisthenics'),
  // Cardio
  LibraryExercise(name: 'Jump Rope', category: 'Cardio', isTimed: true),
  LibraryExercise(name: 'Box Jump', category: 'Cardio'),
  LibraryExercise(name: 'Burpee', category: 'Cardio'),
  LibraryExercise(name: 'Mountain Climber', category: 'Cardio', isTimed: true),
  LibraryExercise(name: 'Jumping Jack', category: 'Cardio', isTimed: true),
  LibraryExercise(name: 'High Knees', category: 'Cardio', isTimed: true),
];
