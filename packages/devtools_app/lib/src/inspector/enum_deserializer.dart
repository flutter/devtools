import '../ui/fake_flutter/fake_flutter.dart';

/// A class for getting an enum object from its string with high performance
///  will return null for invalid string value
///
/// Description:
/// Currently Flutter framework serialize Enum object by calling describeForEnum()
/// This class contains the reverse of that mapping.
///
///
/// Example usage:
/// enum Color {
///   red, green, blue
/// }
/// ```
///   EnumDeserializer<Color> deserializer = EnumDeserializer(Color.values);
///   deserializer.deserialize('red'); -> Color.red
/// ```
class EnumDeserializer<T> {
  // currently there's no way to
  EnumDeserializer(List<T> enumValues) {
    for (var val in enumValues) lookupTable[describeEnum(val)] = val;
  }

  final Map<String, T> lookupTable = {};

  T deserialize(String enumDescription) {
    if (lookupTable.containsKey(enumDescription)) {
      return lookupTable[enumDescription];
    }
    return null;
  }
}
