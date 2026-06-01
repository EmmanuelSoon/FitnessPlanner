import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'run_session.dart';

// typeId 6 reserved for RunSession — do not reuse.
class RunSessionAdapter extends TypeAdapter<RunSession> {
  @override
  final int typeId = 6;

  @override
  RunSession read(BinaryReader reader) =>
      RunSession.fromJson(json.decode(reader.readString()) as Map<String, dynamic>);

  @override
  void write(BinaryWriter writer, RunSession obj) =>
      writer.writeString(json.encode(obj.toJson()));
}
