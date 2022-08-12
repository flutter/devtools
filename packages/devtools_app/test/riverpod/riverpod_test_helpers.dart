import 'package:devtools_app/src/screens/riverpod/nodes/container_node.dart';
import 'package:devtools_app/src/screens/riverpod/nodes/riverpod_node.dart';
import 'package:flutter_test/flutter_test.dart';

TypeMatcher<ContainerNode> matchContainerNode({
  required String id,
  required List<Matcher> providers,
}) {
  return isA<ContainerNode>()
      .having((r) => r.id, 'id', equals(id))
      .having((e) => e.providers, 'providers', providers);
}

TypeMatcher<RiverpodNode> matchRiverpodNode({
  required String id,
  required String containerId,
  required String title,
}) {
  return isA<RiverpodNode>()
      .having((r) => r.id, 'id', equals(id))
      .having((r) => r.containerId, 'containerId', equals(containerId))
      .having(
        (r) => r.title,
        'title',
        equals(
          title,
        ),
      );
}
