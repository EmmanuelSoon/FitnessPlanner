import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'workout.dart';

// typeId 1 reserved for Workout — do not reuse
class WorkoutAdapter extends TypeAdapter<Workout> {
  @override
  final int typeId = 1;

  @override
  Workout read(BinaryReader reader) =>
      Workout.fromJson(json.decode(reader.readString()) as Map<String, dynamic>);

  @override
  void write(BinaryWriter writer, Workout obj) =>
      writer.writeString(json.encode(obj.toJson()));
}
