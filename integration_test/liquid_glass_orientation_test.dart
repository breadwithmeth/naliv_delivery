// Runs the dock orientation check on the device's real renderer:
//   flutter test integration_test/liquid_glass_orientation_test.dart -d <android>
// Use a debug-signed build on a test device or emulator only.
import 'package:integration_test/integration_test.dart';

import '../test/regression/liquid_glass_orientation_test.dart' as orientation;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  orientation.main();
}
