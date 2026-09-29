export 'adapter_config_stub.dart'
    if (dart.library.js_interop) 'adapter_config_web.dart'
    if (dart.library.html) 'adapter_config_web.dart';
