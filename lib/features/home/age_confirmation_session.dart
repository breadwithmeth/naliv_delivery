import 'package:flutter/foundation.dart';

/// The Home acknowledgment is not a saved legal consent or an account property.
final class AgeConfirmationSession extends ChangeNotifier {
  static final currentRun = AgeConfirmationSession();

  bool _isConfirmed = false;
  bool get isConfirmed => _isConfirmed;

  void confirm() {
    if (_isConfirmed) return;
    _isConfirmed = true;
    notifyListeners();
  }
}
