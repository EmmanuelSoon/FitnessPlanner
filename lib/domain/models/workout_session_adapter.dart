import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'workout_session.dart';

// typeId 2 reserved for WorkoutSession — do not reuse
class WorkoutSessionAdapter extends TypeAdapter<WorkoutSession> {
  @override
  final int typeId = 2;

  @override
  WorkoutSession read(BinaryReader reader) =>
      WorkoutSession.fromJson(json.decode(reader.readString()) as Map<String, dynamic>);

  @override
  void write(BinaryWriter writer, WorkoutSession obj) =>
      writer.writeString(json.encode(obj.toJson()));
}
