# Download and render network images.

A material design widget to view downloaded network images.

**Warning:** This is a case study that will eventually crash running out of memory.

**Solution:** Fix the ListView.builder add the parameters cacheHeight and cacheWidth to the Image.network constructor e.g.,

Look for:
```dart
Widget listView() => ListView.builder
```
Find the Image.network constructor then add the below parameters:
```dart
// Decode image to a specified height and width (ResizeImage).
cacheHeight: 1024,
cacheWidth: 1024,
```
Original code:
```dart
final image = Image.network(
  imgUrl,
  width: 750.0,
  height: 500,
  scale: 1.0,
  fit: BoxFit.fitWidth,
  loadingBuilder: (
    BuildContext context,
    Widget child,
    ImageChunkEvent loadingProgress,
  ) {
    if (loadingProgress == null) return child;
    return recordLoadedImage(loadingProgress, imgUrl);
  },
);
```
Fixed code:
```dart
final image = Image.network(
  imgUrl,
  width: 750.0,
  height: 500,
  scale: 1.0,
  // Decode image to a specified height and width (ResizeImage).
  cacheHeight: 1024,
  cacheWidth: 1024,
  fit: BoxFit.fitWidth,
  loadingBuilder: (
    BuildContext context,
    Widget child,
    ImageChunkEvent loadingProgress,
  ) {
    if (loadingProgress == null) return child;
    return recordLoadedImage(loadingProgress, imgUrl);
  },
);
```

The parameters cacheWidth or cacheHeight indicates to the engine that the image should be decoded at the specified size e.g., thumbnail. If not specified the full image will be used each time when all that is needed is a much smaller image.  The image will be rendered to the constraints of the layout or width and height regardless of these parameters. These parameters are intended to reduce the memory usage of ImageCache

Read [[Image.network Documentation](https://api.flutter.dev/flutter/widgets/Image/Image.network.html)].

<img src="leak_app.png" height="600em" />

## Getting Started

For help getting started with Flutter, view online [documentation](http://flutter.io/).
