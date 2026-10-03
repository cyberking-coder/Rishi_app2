import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

/// Phase 1 integration-test placeholder.
///
/// Confirms the `integration_test` binding compiles and runs on a device/
/// emulator so the separate (initially non-blocking) CI job has an entry
/// point. The real journeys (auth, course→lesson→playback, offline
/// playback, account deletion) arrive in Phase 9.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('integration harness runs', (tester) async {
    expect(true, isTrue);
  });
}
