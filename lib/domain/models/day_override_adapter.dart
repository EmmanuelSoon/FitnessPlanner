import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'day_override.dart';

// typeId 5 reserved for DayOverride — do not reuse
class DayOverrideAdapter extends TypeAdapter<DayOverride> {
  @override
  final int typeId = 5;

  @override
  DayOverride read(BinaryReader reader) =>
      DayOverride.fromJson(json.decode(reader.readString()) as Map<String, dynamic>);

  @override
  void write(BinaryWriter writer, DayOverride obj) =>
      writer.writeString(json.encode(obj.toJson()));
}
