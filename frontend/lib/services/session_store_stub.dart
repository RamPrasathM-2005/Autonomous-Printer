final _values = <String, String>{};
String? readSessionValue(String key) => _values[key];
void writeSessionValue(String key, String value) {
  _values[key] = value;
}

void clearSessionValue(String key) {
  _values.remove(key);
}
