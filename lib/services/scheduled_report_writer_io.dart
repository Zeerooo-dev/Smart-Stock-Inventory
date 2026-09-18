import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;

Future<bool> writeScheduledFile(
  String directory,
  String fileName,
  Uint8List bytes,
) async {
  if (directory.trim().isEmpty) return false;
  final dir = Directory(directory);
  await dir.create(recursive: true);
  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return true;
}
