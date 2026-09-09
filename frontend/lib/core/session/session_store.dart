import 'session_store_contract.dart';
import 'session_store_platform_stub.dart'
    if (dart.library.html) 'session_store_platform_web.dart'
    if (dart.library.io) 'session_store_platform_native.dart'
    as platform;

export 'session_store_contract.dart';

SessionStore createSessionStore() => platform.createSessionStore();
