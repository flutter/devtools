To retake the snapshots:

1. Create counter app with `flutter create`.
2. Update button handler to take snapshot after increasing counter:

```
  void _incrementCounter() {
    setState(() {
      _counter++;
    });
    var fileName = 'counter_snapshot$_counter';
    fileName = p.absolute(fileName);
    print('saving snapshot to $fileName');
    NativeRuntime.writeHeapSnapshotToFile(fileName);
  }
```

3. Run the counter and click the button four times.
4. Copy the collected files to this folder.
