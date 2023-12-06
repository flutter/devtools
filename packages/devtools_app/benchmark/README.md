# DevTools benchmark tests

There are two types of benchmarks that we currently support: size and performance.
- devtools_benchmarks_test.dart (measures DevTools frame times)
- web_bundle_size_test.dart (measures DevTools release build size)

The benchmark tests are run automatically on the CI.
See the "benchmark-performance" and "benchmark-size" jobs.

## Running benchmark tests locally

> [!NOTE] 
> The performance and size benchmarks cannot be run concurrently
> (e.g. by running `flutter test benchmark/`). See the [#caveats](#caveats)
> section below.

### Performance benchmarks

To run the performance benchmark tests locally, run:
```sh
dart run run_benchmarks.dart
```

To run the test that verifies we can run benchmark tests, run:
```sh
flutter test benchmark/devtools_benchmarks_test.dart
```

### Size benchmarks

To run the size benchmark test locally, run:
```sh
flutter test benchmark/web_bundle_size_test.dart
```

### Caveats

The size benchmark must be ran by itself because it actually modifies the
`devtools_app/build` folder to create and measure the release build web bundle size.
If this test is ran while other tests are running, it can affect the measurements
that the size benchmark test takes, and it can affect the DevTools build that
the other running tests are using with.
