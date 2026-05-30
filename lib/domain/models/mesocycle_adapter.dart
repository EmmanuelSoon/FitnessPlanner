import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'mesocycle.dart';

// typeId 4 reserved for Mesocycle — do not reuse
class MesocycleAdapter extends TypeAdapter<Mesocycle> {
  @override
  final int typeId = 4;

  @override
  Mesocycle read(BinaryReader reader) =>
      Mesocycle.fromJson(json.decode(reader.readString()) as Map<String, dynamic>);

  @override
  void write(BinaryWriter writer, Mesocycle obj) =>
      writer.writeString(json.encode(obj.toJson()));
}
