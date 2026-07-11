import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'run_override.dart';

// typeId 7 reserved for RunOverride — do not reuse
// (0=Exercise, 1=Workout, 2=WorkoutSession, 3=LoggedSet, 4=Mesocycle,
//  5=DayOverride, 6=RunSession)
class RunOverrideAdapter extends TypeAdapter<RunOverride> {
  @override
  final int typeId = 7;

  @override
  RunOverride read(BinaryReader reader) =>
      RunOverride.fromJson(json.decode(reader.readString()) as Map<String, dynamic>);

  @override
  void write(BinaryWriter writer, RunOverride obj) =>
      writer.writeString(json.encode(obj.toJson()));
}
