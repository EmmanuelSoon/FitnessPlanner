import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'logged_set.dart';

// typeId 3 reserved for LoggedSet — do not reuse
class LoggedSetAdapter extends TypeAdapter<LoggedSet> {
  @override
  final int typeId = 3;

  @override
  LoggedSet read(BinaryReader reader) =>
      LoggedSet.fromJson(json.decode(reader.readString()) as Map<String, dynamic>);

  @override
  void write(BinaryWriter writer, LoggedSet obj) =>
      writer.writeString(json.encode(obj.toJson()));
}
