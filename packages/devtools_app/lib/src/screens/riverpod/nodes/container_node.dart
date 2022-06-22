import 'riverpod_node.dart';

class ContainerNode {
  const ContainerNode({
    required this.id,
    required this.providers,
  });

  final String id;
  final List<RiverpodNode> providers;
}
