## Contributing code

![GitHub contributors](https://img.shields.io/github/contributors/flutter/devtools.svg)

We gladly accept contributions via GitHub pull requests!

You must complete the
[Contributor License Agreement](https://cla.developers.google.com/clas).
You can do this online, and it only takes a minute. If you've never submitted code before,
you must add your (or your organization's) name and contact info to the [AUTHORS](AUTHORS)
file.

## Development

- `git clone https://github.com/flutter/devtools`
- `cd devtools/packages/devtools`
- `pub get`

From a separate terminal:
- `cd <path/to/flutter-sdk>/examples/flutter_gallery`
- ensure the iOS Simulator is open (or a physical device is connected)
- `flutter run`

From the packages/devtools directory:
- `pub global activate webdev` (install webdev globally)
- `export PATH=$PATH:~/.pub-cache/bin` (make globally activated packages available from the command line)
- `webdev serve`

Then, open a browser window to the local url specified by webdev. After the page has loaded, append
`?port=xxx` to the url, where xxx is the port number of the service protocol port, as specified by
the `flutter run` output.

For more productive development, launch your Flutter application specifying
`--observatory-port` so the observatory is available on a fixed port. This
lets you avoid manually entering the observatory port parameter each time
you launch the application.

- `flutter run --observatory-port=8888`
- `open http://localhost:8080/?port=8888`

`webdev` provides a fast development server that incrementally
rebuilds the portion of the application that was edited each time you reload
the page in the browser. If initial app load times become slow as this tool
grows, we can integrate with the hot restart support in `webdev`.

## Testing

### Running tests that depend on the Flutter SDK

Make sure your Flutter SDK matches the tip of trunk before
running these tests.

```
cd packages/devtools
pub run test -j1 --tags useFlutterSdk
```

### Run all other tests

```
cd packages/devtools
pub run test --exclude-tags useFlutterSdk
pub run test --exclude-tags useFlutterSdk --platform chrome-no-sandbox
```

### Updating golden files

Some of the golden file tests will fail if Flutter changes the implementation or diagnostic
properties of widgets used by the inspector tests. If this happens, make sure the golden
file output still looks reasonable and execute the following command to update the golden files.

```
./tool/update_goldens.sh
```

To update the Stable versions of the Golden files, switch to Flutter's current stable
branch and run with the `--stable` switch.

```
./tool/update_goldens.sh --stable
```

### third_party dependencies

All content not authored by the Flutter team must go in the third_party
directory. As an expedient to make the third_party code work well with our build scripts,
code in third_party should be given a stub pubspec.yaml file so that you can
reference the resources from the packages directory from
`packages/devtools/web/index.html`
