# Shared DevTools Components

This package contains UI, utility, and service components from
[Dart & Flutter DevTools](https://docs.flutter.dev/tools/devtools/overview) that can
be shared between DevTools, DevTools extensions, and other tooling surfaces that need
the same logic or styling.

## Usage

Add a dependency to your `pubspec.yaml` file:
```yaml
devtools_app_shared: ^0.0.2
```

Import the component library that you need:
```dart
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/service_extensions.dart' as extensions;
import 'package:devtools_app_shared/ui.dart';
import 'package:devtools_app_shared/utils.dart';
```

### Examples

1. Set and access global variables.

```dart
import 'package:devtools_app_shared/utils.dart';

MyCoolClass get coolClass => globals[MyCoolClass] as MyCoolClass;

void main() {
  // Creates a globally accessible variable (`globals[ServiceManager]`);
  setGlobal(MyCoolClass, MyCoolClass());
  coolClass.foo();
}
```

2. Use utilities like the `AutoDisposeMixin`, which supports adding listeners
that will automatically dispose as part of the `StatefulWidget` lifecycle.

```dart
import 'package:devtools_app_shared/utils.dart';

class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({super.key});

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class _MyStatefulWidgetState extends State<MyStatefulWidget>
    with AutoDisposeMixin {
  var foo = 'hi';

  @override
  void initState() {
    super.initState();
    addAutoDisposeListener(someListenable, () {
      setState(() {
        foo = '$foo hi';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Text(foo);
  }
}
```

3. Access shared UI components and styling.

```dart
import 'package:devtools_app_shared/ui.dart';
...
@override
Widget build(BuildContext context) {
  return RoundedOutlinedBorder( // Shared component
    child: Column(
      children: [
        AreaPaneHeader( // Shared component
          roundedTopBorder: false,
          includeTopBorder: false,
          title: Text('This is a section header'),
        ),
        Expanded(
          child: FooWidget(
            child: Text(
              'Foo',
              style: Theme.of(context).subtleTextStyle, // Shared style
            ),
          ),
        ),
      ],
    ),
  );
}
```

4. VM service management, including access to isolates and service extensions.

```dart
import 'package:devtools_app_shared/service.dart';
import 'package:devtools_app_shared/service_extensions.dart' as extensions;
import 'package:devtools_shared/service.dart';

void main() {
  final serviceManager = ServiceManager();

  // Use the [connectedState] notifier to listen for connection updates.
  serviceManager.connectedState.addListener(() {
    if (serviceManager.connectedState.value.connected) {
      print('Manager connected to VM service');
    } else {
      print('Manager not connected to VM service');
    }
  });

  // To get a [VmService] object from a vm service URI, consider importing
  // `package:devtools_shared/service.dart` from `package:devtools_shared`.
  final finishedCompleter = Completer<void>();
  final vmService = await connect<VmService>(
    uri: Uri.parse(vmServiceUri),
    finishedCompleter: finishedCompleter,
    createService: ({
      // ignore: avoid-dynamic, code needs to match API from VmService.
      required Stream<dynamic> /*String|List<int>*/ inStream,
      required void Function(String message) writeMessage,
      required Uri connectedUri,
    }) {
      return VmService(inStream, writeMessage);
    },
  );

  await serviceManager.vmServiceOpened(
    vmService,
    onClosed: finishedCompleter.future,
  );

  // Get a service extension state.
  final ValueListenable<ServiceExtensionState> performanceOverlayEnabled =
      serviceManager.manager.serviceExtensionManager.getServiceExtensionState(
        extensions.performanceOverlay.extension,
      );

  // Set a service extension state.
  await serviceManager.manager.serviceExtensionManager.setServiceExtensionState(
    extensions.performanceOverlay.extension,
    enabled: true,
    value: true,
  );

  // Access isolates.
  final myIsolate = serviceManager.isolateManager.mainIsolate.value;

  // Etc.
}
```

## Issues & feedback

This package is developed as part of the larger
[flutter/devtools](https://github.com/flutter/devtools) project.
Please report any issues or feedback there.
