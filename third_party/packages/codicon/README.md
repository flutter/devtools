# codicon

__codicon__ is an easy to use package that exposes
[vscode-icons](https://marketplace.visualstudio.com/items?itemName=vscode-icons-team.vscode-icons)
for Flutter.

## Example Usage
In the pubspec.yaml file add the `codicon` dependency as below:
```yaml
dependencies:
#  codicon: any # uncomment and change for latest version
```

Import the `codicon` package where you want to use the icon:
```dart
import 'package:codicon/codicon.dart';
```

Use the icon in an [Icon](https://api.flutter.dev/flutter/widgets/Icon-class.html) widget:
```dart
Icon(
  Codicons.lightBulb,
), 
```