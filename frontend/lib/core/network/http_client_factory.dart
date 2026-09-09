import 'package:http/http.dart' as http;

import 'http_client_factory_stub.dart'
    if (dart.library.html) 'http_client_factory_web.dart'
    as platform;

http.Client createHttpClient() => platform.createHttpClient();
