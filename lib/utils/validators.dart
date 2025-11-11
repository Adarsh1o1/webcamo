class AppValidator {
  AppValidator._();

  static String? validatePhoneNumber(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your phone number';
    }
    if (value.length != 10) {
      return 'Please enter a valid 10-digit number';
    }
    final isDigitsOnly = RegExp(r'^[0-9]+$').hasMatch(value);
    if (!isDigitsOnly) {
      return 'Please enter a valid number';
    }
    return null;
  }
}
