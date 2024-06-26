# Download and render network images.

A material design widget to view downloaded network images.

**Warning:** This is a case study that will eventually crash running out of memory.

**Using DevTools**

```
cd case_study/memory_leaks/images_1
flutter pub get
flutter run
```

Open DevTools and copy paste URL displayed on this line e.g.,

```

Flutter run key commands.
r Hot reload.
...
An Observatory debugger and profiler on AOSP on IA Emulator is available at: http://127.0.0.1:43473/5IvsZcde53E=/
```

After DevTools has connected to the running Flutter application, click on the Memory tab.

Click on the leaky Image Viewer app (the image) and drag down for a few images to load.  The Memory profile chart should appear like the below chart.

<img src="readme_images/memory_startup.png" />

Press the Snapshot button to collect information about all objects in the Dart VM Heap.

<img src="readme_images/snapshot.png" />

When complete a Heat Map will appear.  Turn off the Heat Map switch:

<img src="readme_images/heatmap_off.png" />

When the Heat Map is switched off a table view is displayed of all objects in the Dart VM heap.

<img src="readme_images/table_first.png" />

Press the Analyze button to analyze the current Snapshot

<img src="readme_images/analyze.png" />

After the snapshot analysis a child row inside of > Analysis will be added titled "Snapshot ..." with the timestamp of the snapshot e.g., "Snapshot Jun 09 12:23:44".

<img src="readme_images/analysis_1.png" />

The analysis collects the raw memory objects that contain the images, any classes concerning images in Flutter under the

```
>Snapshot Jun 09 12:27:25
  > Externals
```

Expand Externals

```
> Snapshot MMM DD HH:MM:SS
   > Externals
     > _Int32List
       > Buckets
```
       
You'll notice a number of chunks of _Int32List memory is displayed into their corresponding bucket sizes.  The images are in the 1M..10M and 50M+ buckets.  Eleven images total ~284M.

The next interesting piece of information is to expand:

```
> Snapshot MMM DD HH:MM:SS
     > Library filters
       > ImageCache
```

This will display the number objects in the ImageCache for pending, cache and live images.

Now start scrolling through the images in the "Image Viewer" (click and drag) for a number of pictures - causing lots of images to be loaded over the network.  Notice the memory is growing rapidly, over time, first 500M, then 900M, then 1b, and finally topping 2b in total memory used.  Eventually, this app will run out of memory and crash.

<img src="readme_images/chart_before_crash.png" />

As the graph grows press "Snapshot" and then "Analyze" the snapshot analysis should appear:

<img src="readme_images/analysis_before_crash.png" />

Notice as you expand the _Int32List under Externals that the size has now grown to 771M.

```
193M for seven images in the 10M..50M range.
138M for twenty-six images in the 1M..10M range.
438M for five images in the 50M+ range.
```

In addition, many images are pending, in the cache and live to consume more data as the images are received over the network.

**Problem:** The images downloaded are very detailed and beautiful, some images are over 50 MB in size.  The details of these images are lost on the small device they are rendered on.  Using a fraction of the size will eliminate keeping 50M image(s) to render in a 3" x 3" area.

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

<img src="readme_images/leak_app.png" height="600em" />

## Getting Started

For help getting started with Flutter, view online [documentation](http://flutter.io/).
