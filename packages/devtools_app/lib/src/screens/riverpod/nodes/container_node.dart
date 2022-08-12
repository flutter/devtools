import 'riverpod_node.dart';

class ContainerNode {
  const ContainerNode({
    required this.id,
    required this.providers,
  });

  final String id;
  final List<RiverpodNode> providers;

  ContainerNode copy({required List<RiverpodNode> providers}) {
    return ContainerNode(
      id: id,
      providers: providers,
    );
  }
}
