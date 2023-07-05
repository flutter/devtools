To retake the snapshots:

1. Create counter app with `flutter create`
2. Update button handler to take snapshot after increasing counter:

```
final fileName = '/Users/polinach/Downloads/counter_snapshot$_counter.json';
NativeRuntime.writeHeapSnapshotToFile(fileName);
```
3. Run the counter for macos and click the button four times.
4.
