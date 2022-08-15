class RiverpodNode {
  RiverpodNode({
    required this.id,
    required this.containerId,
    required this.stateId,
    required this.argumentId,
    required this.name,
    required this.mightBeOutdated,
  });

  final String id;
  final String containerId;
  final String stateId;
  final String? argumentId;
  final String name;
  final bool mightBeOutdated;

  RiverpodNode copy({required String stateId}) {
    return RiverpodNode(
      id: id,
      containerId: containerId,
      stateId: stateId,
      argumentId: argumentId,
      name: name,
      mightBeOutdated: mightBeOutdated,
    );
  }
}
