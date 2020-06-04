# Using Tab Bar

A material design widget to view downloaded network images.  Warning this is a case study that will eventually crash with out of memory.

To fix in the ListView.builder uncomment the cacheHeight and cacheWidth.

            // Decode image to a specified height and width (ResizeImage).
            cacheHeight: 1024,
            cacheWidth: 1024,

The parameters cacheWidth or cacheHeight indicates to the engine that the image should be decoded at the specified size e.g., thumbnail. The image will be rendered to the constraints of the layout or width and height regardless of these parameters. These parameters are intended to reduce the memory usage of ImageCache

Read [[Documentation](https://docs.flutter.io/flutter/material/TabBar-class.html)] [[Material Design Spec](https://material.io/guidelines/components/tabs.html)]

<img src="demo_img.gif" height="600em" />


## Getting Started

For help getting started with Flutter, view online [documentation](http://flutter.io/).