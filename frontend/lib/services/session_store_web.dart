import 'dart:js_interop';

@JS('sessionStorage.getItem')
external JSString? _get(JSString key);
@JS('sessionStorage.setItem')
external void _set(JSString key, JSString value);
@JS('sessionStorage.removeItem')
external void _remove(JSString key);
String? readSessionValue(String key) => _get(key.toJS)?.toDart;
void writeSessionValue(String key, String value) => _set(key.toJS, value.toJS);
void clearSessionValue(String key) => _remove(key.toJS);
