export 'package:meta/meta.dart';
export 'package:collection/collection.dart';

const nullable = Object();
const freezed = Object();

class Default {
  const Default(Object value);
}

class Assert {
  const Assert(String exp);
}

class JsonKey {
  const JsonKey({
    bool ignore,
    Object defaultValue,
  });
}
