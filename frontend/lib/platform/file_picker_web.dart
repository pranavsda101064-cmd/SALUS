// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

import '../api.dart';

Future<PickedFile?> pickInvestigationFile() async {
  final input = html.FileUploadInputElement()
    ..accept = '.csv,.xlsx,.xlsm'
    ..style.display = 'none';
  html.document.body?.children.add(input);
  final completer = Completer<PickedFile?>();

  input.onChange.listen((_) {
    final files = input.files;
    if (files == null || files.isEmpty) {
      completer.complete(null);
      input.remove();
      return;
    }
    final file = files.first;
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoad.listen((_) {
      final result = reader.result;
      Uint8List bytes;
      if (result is ByteBuffer) {
        bytes = result.asUint8List();
      } else if (result is Uint8List) {
        bytes = result;
      } else if (result is List) {
        bytes = Uint8List.fromList(result.cast<int>());
      } else {
        completer.completeError('Could not read the selected file.');
        input.remove();
        return;
      }
      completer.complete(PickedFile(file.name, bytes));
      input.remove();
    });
    reader.onError.listen((_) {
      completer.completeError('Could not read the selected file.');
      input.remove();
    });
  });

  input.click();
  return completer.future;
}
