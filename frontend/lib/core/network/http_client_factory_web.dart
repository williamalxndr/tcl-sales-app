import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

/// Enables the backend's HttpOnly refresh and CSRF cookies in Flutter web.
http.Client createHttpClient() => BrowserClient()..withCredentials = true;
