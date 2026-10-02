import 'dart:js_interop';

// Use localStorage (not sessionStorage) so order state persists across
// tab closes, page refreshes, and browser restarts. sessionStorage is wiped
// when the tab is closed, causing paid orders to appear lost on reload.
@JS('localStorage.getItem')
external JSString? _get(JSString key);
@JS('localStorage.setItem')
external void _set(JSString key, JSString value);
@JS('localStorage.removeItem')
external void _remove(JSString key);

String? readSessionValue(String key) => _get(key.toJS)?.toDart;
void writeSessionValue(String key, String value) => _set(key.toJS, value.toJS);
void clearSessionValue(String key) => _remove(key.toJS);
