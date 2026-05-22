import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'exercise.dart';

// typeId 0 reserved for Exercise — do not reuse
class ExerciseAdapter extends TypeAdapter<Exercise> {
  @override
  final int typeId = 0;

  @override
  Exercise read(BinaryReader reader) =>
      Exercise.fromJson(json.decode(reader.readString()) as Map<String, dynamic>);

  @override
  void write(BinaryWriter writer, Exercise obj) =>
      writer.writeString(json.encode(obj.toJson()));
}
