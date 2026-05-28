import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  /// Centralized endpoint base URL loaded from .env file or falling back to String.fromEnvironment or default value.
  static final String apiBaseUrl = dotenv.env['API_BASE_URL'] ?? const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.29.118:4000/api/v1',
  );
}
