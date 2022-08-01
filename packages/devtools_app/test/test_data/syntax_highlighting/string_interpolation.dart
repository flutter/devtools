void values() {
  final i = 1;
  final j = 2;

  print('the value of \$i is $i');
  print('the value after \$i is ${i + 1}');
  print('the value of \$i + \$j is ${i + j}');
}

void functions() {
  print('${() {
    return 'Hello';
  }}');
  print('print(${() {
    return 'Hello';
  }()})');
  print('${() => 'Hello'}');
  print('print(${(() => 'Hello')()})');
}
