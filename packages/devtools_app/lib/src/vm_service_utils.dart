import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart';

/// A line, column, and an optional tokenPos.
class SourcePosition {
  const SourcePosition(
      {@required this.line, @required this.column, this.file, this.tokenPos});

  factory SourcePosition.calculatePosition(Script script, int tokenPos) {
    final List<List<int>> table = script.tokenPosTable;
    if (table == null) {
      return null;
    }

    return SourcePosition(
      line: script.getLineNumberFromTokenPos(tokenPos),
      column: script.getColumnNumberFromTokenPos(tokenPos),
      tokenPos: tokenPos,
    );
  }

  final String file;
  final int line;
  final int column;
  final int tokenPos;

  @override
  bool operator ==(other) {
    return other is SourcePosition &&
        other.line == line &&
        other.column == column &&
        other.tokenPos == tokenPos;
  }

  @override
  int get hashCode => (line << 7) ^ column;

  @override
  String toString() => '$line:$column';
}
