---
title: Using the Debugger
---

* toc
{:toc}


## Getting started

DevTools includes a full source level debugger, including breakpoints, stepping, and
variable inspection.

When you open the debugger tab, you should see all the libraries for you application
listed in bottom left of the screen (under the `Scripts` area), and the source for the
main entry-point for your app in the loaded in the main source area.

In order to browse around more of your application sources, you can scroll through
the `Scripts` area and select other source files to display.

<img src="images/debugger_screenshot.png" width="900" />

## Setting breakpoints

To set a breakpoint, click on the left margin (the line number ruler) in the source
area. Clicking once will set a breakpoint, which should also show up in the
`Breakpoints` area on the left. Clicking again will remove the breakpoint.

## The call stack and variables areas

When your application encounters a breakpoint, it'll pause there, and the DevTools
debugger will show the paused execution location in the source area. In addition,
the `Call stack` and `Variables` areas will populate with the current call stack
for the paused isolate, and the local variables for the selected frame. Selecting
other frames in the `Call stack` area will change the contents of the `Variables`
area.

Within the `Variables` area, you can inspect individual objects by toggling them open
to see their fields. Hovering over an object in the `Variables` area will call the
`toString()` method for that object and display the result.

## Stepping through source code

When paused, the three stepping buttons become active.

- use `Step in` to step into a method invocation, stopping at the first executable line
  in that invoked method
- use `Step over` to step over a method invocation; this steps through source lines in
  the current method
- use `Step out` to step out of the current method, without stopping at any intermediary
  lines

In addition, the `Resume` button will continue regular execution of the application.

## Console output

Console output for the running app (stdout and stderr) is displayed in the console, below
the source code area.

## Breaking on exceptions

To adjust the break on exceptions behavior, toggle the `Break on unhandled exceptions`
and `Break on all exceptions` checkboxes in the upper right of the debugger UI.

Breaking on unhandled exceptions will only pause execution if the breakpoint is considered
uncaught by the application code. Breaking on all exceptions will cause the debugger to
pause whether or not the breakpoint was caught by application code.

## Known issues

- when performing a hot restart for a Flutter application, user breakpoints are cleared
