/// Application-level constants that can be reused across layers.
class AppConstants {
  AppConstants._();

  static const String whisperDefaultModel = 'assets/models/ggml-base.en.bin';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration cacheTtl = Duration(minutes: 30);
  static const String dateFormat = 'yyyy-MM-dd HH:mm';
  static const String appName = 'SmartTutor Lite';

  // Performance monitoring
  static const String performanceChannel = 'smarttutor_performance';
}
