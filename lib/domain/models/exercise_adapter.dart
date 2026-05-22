import 'package:hive_flutter/hive_flutter.dart';
import 'exercise.dart';

// typeId 0 reserved for Exercise — do not reuse
class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 0;

  @override
  Exercise read(BinaryReader reader) {
    final name = reader.readString();
    final reps = reader.readInt();
    final sets = reader.readInt();
    final restUs = reader.readInt();
    final weight = reader.readDouble();
    return Exercise(
      name: name,
      reps: reps,
      sets: sets,
      restTime: Duration(microseconds: restUs),
      weight: weight,
    );
  }

  @override
  void write(BinaryWriter writer, Exercise obj) {
    writer.writeString(obj.name);
    writer.writeInt(obj.reps);
    writer.writeInt(obj.sets);
    writer.writeInt(obj.restTime.inMicroseconds);
    writer.writeDouble(obj.weight);
  }
}
