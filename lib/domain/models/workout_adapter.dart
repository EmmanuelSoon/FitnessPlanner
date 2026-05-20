import 'package:hive_flutter/hive_flutter.dart';
import 'exercise_adapter.dart';
import 'workout.dart';

// typeId 1 reserved for Workout — do not reuse
class WorkoutAdapter extends TypeAdapter<Workout> {
  @override
  final int typeId = 1;

  @override
  Workout read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final count = reader.readInt();
    final exerciseAdapter = ExerciseAdapter();
    final exercises = List.generate(count, (_) => exerciseAdapter.read(reader));
    return Workout(id: id, name: name, exercises: exercises);
  }

  @override
  void write(BinaryWriter writer, Workout obj) {
    final exerciseAdapter = ExerciseAdapter();
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeInt(obj.exercises.length);
    for (final exercise in obj.exercises) {
      exerciseAdapter.write(writer, exercise);
    }
  }
}
