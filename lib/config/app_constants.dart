import 'secrets.dart';

class AppConstants {
  // API keys loaded from secrets.dart (not committed to git)
  static const String googleMapsApiKey = Secrets.googleMapsApiKey;
  static const String geminiApiKey = Secrets.geminiApiKey;

  static const double defaultLat = 3.1862;
  static const double defaultLng = 101.7234;
  static const double defaultZoom = 14.0;
}
