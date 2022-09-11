Scenes allow you to define application state that can be both used for testing and
run a s application.

To generate:
flutter pub run build_runner build --delete-conflicting-outputs

To run:
flutter run -t test/scenes/hello.stager_app.dart -d macos
