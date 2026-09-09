import 'session_store_contract.dart';

/// Browser refresh credentials stay in the backend's HttpOnly cookie.
SessionStore createSessionStore() => MemorySessionStore();
