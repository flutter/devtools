import 'dart:async';
import 'dart:io';

void main() {
  int count = 108;

  Timer.periodic(new Duration(seconds: 4), (Timer timer) {
    foo(count--);

    if (count == 0) {
      count = 108;
    }
  });
}

void foo(int count) {
  final Directory dir = new Directory('.');

  print('$count:00');

  for (FileSystemEntity entity in dir.listSync()) {
    final String path = entity.path;

    print('  $path');
  }

  print('');
}
