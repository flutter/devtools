import 'package:devtools_app/src/inspector/flutter/layout_tab.dart';
import 'package:devtools_app/src/ui/fake_flutter/_real_flutter.dart';
import 'package:test/test.dart';

void main() {
  test('FlexProperties.fromJson creates correct value from enum', () {
    for (var direction in Axis.values) {
      for (var mainAxisAlignment in MainAxisAlignment.values) {
        for (var mainAxisSize in MainAxisSize.values) {
          for (var crossAxisAlignment in CrossAxisAlignment.values) {
            for (var textDirection in TextDirection.values) {
              for (var verticalDirection in VerticalDirection.values) {
                for (var textBaseline in TextBaseline.values) {
                  final Map<String, Object> flexJson = {
                    'direction': direction.toString(),
                    'mainAxisAlignment': mainAxisAlignment.toString(),
                    'mainAxisSize': mainAxisSize.toString(),
                    'crossAxisAlignment': crossAxisAlignment.toString(),
                    'textDirection': textDirection.toString(),
                    'verticalDirection': verticalDirection.toString(),
                    'textBaseline': textBaseline.toString(),
                    'size': <String, double>{
                      'width': 100.0,
                      'height': 200.0,
                    },
                  };
                  final FlexProperties flexProperties = FlexProperties.fromJson(flexJson);
                  expect(flexProperties.direction, direction);
                  expect(flexProperties.mainAxisAlignment, mainAxisAlignment);
                  expect(flexProperties.mainAxisSize, mainAxisSize);
                  expect(flexProperties.crossAxisAlignment, crossAxisAlignment);
                  expect(flexProperties.textDirection, textDirection);
                  expect(flexProperties.verticalDirection, verticalDirection);
                  expect(flexProperties.textBaseline, textBaseline);
                  expect(flexProperties.size.width, 100.0);
                  expect(flexProperties.size.height, 200.0);
                }
              }
            }
          }
        }
      }
    }
  });
}
