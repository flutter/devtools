class RiverpodNode {
  RiverpodNode({
    required this.id,
    required this.containerId,
    required this.stateId,
    required this.type,
    required this.name,
    required this.mightBeOutdated,
  });

  final String id;
  final String containerId;
  final String stateId;
  final String type;
  final String? name;
  final bool mightBeOutdated;

  String get title {
    final typeString = '$type()';
    return name != null ? '$name - $typeString' : typeString;
  }

  RiverpodNode copy({required String stateId}) {
    return RiverpodNode(
      id: id,
      containerId: containerId,
      stateId: stateId,
      type: type,
      name: name,
      mightBeOutdated: mightBeOutdated,
    );
  }
}
