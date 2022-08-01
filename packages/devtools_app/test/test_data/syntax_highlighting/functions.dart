void simplePrint() {
  print('hello world');
}

noReturnValue() {
  print('hello world');
}

Future<void> asyncPrint() async {
  await Future.delayed(const Duration(seconds: 1));
  print('hello world');
}
