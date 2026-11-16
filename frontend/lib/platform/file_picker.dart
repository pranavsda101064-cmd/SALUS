import '../api.dart';
import 'file_picker_stub.dart' if (dart.library.html) 'file_picker_web.dart' as impl;

Future<PickedFile?> pickInvestigationFile() => impl.pickInvestigationFile();
