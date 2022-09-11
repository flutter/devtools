Scenes allow you to define application state that can be both used for testing and
run as an application.

To generate scene runners:
```
flutter pub run build_runner build --delete-conflicting-outputs
```

To run:
```
flutter run -t test/scenes/hello.stager_app.dart -d macos
```
