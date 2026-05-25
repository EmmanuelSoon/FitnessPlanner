import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'superset.dart';

// typeId 4 reserved for Superset — do not reuse
class SupersetAdapter extends TypeAdapter<Superset> {
  @override
  final int typeId = 4;

  @override
  Superset read(BinaryReader reader) =>
      Superset.fromJson(json.decode(reader.readString()) as Map<String, dynamic>);

  @override
  void write(BinaryWriter writer, Superset obj) =>
      writer.writeString(json.encode(obj.toJson()));
}
