// Copyright 2019 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html' hide VoidCallback;
import 'dart:js';

import 'package:meta/meta.dart';

import '../framework/framework.dart';
import 'elements.dart';
import 'fake_flutter/fake_flutter.dart';

// Generally, chunkSize should be a power of 2 for more efficient GPU handling
// of canvases.
//
// Using a smaller chunk size results in lower overall memory usage at the cost
// of creating more tiles.
const int chunkSize = 512;

// Enable this flag to help debug viewport canvas rendering.
const bool _debugChunks = false;

int _nextChunkId = 0;

num _devicePixelRatio = window.devicePixelRatio;

/// Helper class managing a [chunkSize] x [chunkSize] canvas used to render a
/// single tile of the [ViewportCanvas].
class _CanvasChunk {
  _CanvasChunk(_ChunkPosition position)
      : canvas = CanvasElement(
            width: chunkSize * _devicePixelRatio,
            height: chunkSize * _devicePixelRatio) {
    canvas.style
      ..position = 'absolute'
      ..width = '${chunkSize}px'
      ..height = '${chunkSize}px';
    _context = canvas.context2D
      ..scale(_devicePixelRatio, _devicePixelRatio)
      ..save();
    this.position = position;
    _dirty = true;
    if (_debugChunks) {
      canvas.dataset['chunkId'] = '$_nextChunkId';
      _nextChunkId++;
    }
  }

  final CanvasElement canvas;

  CanvasRenderingContext2D get context => _context;
  CanvasRenderingContext2D _context;
  bool _empty = true;

  bool get dirty => _dirty;
  bool _dirty;

  bool attached = false;
  int _lastFrameRendered = -1;
  Rect rect;

  _ChunkPosition get position => _position;
  _ChunkPosition _position;

  set position(_ChunkPosition p) {
    if (_position == p) return;
    _position = p;
    rect = Rect.fromLTWH(
      (position.x * chunkSize).toDouble(),
      (position.y * chunkSize).toDouble(),
      chunkSize.toDouble(),
      chunkSize.toDouble(),
    );
    canvas.style.transform = 'translate(${rect.left}px, ${rect.top}px)';

    context
      ..restore()
      ..save()
      // Modify the canvas's coordinate system to match the global coordinates.
      // This allows user code to paint to the canvas without knowledge of what
      // the coordinate system of the chunk is.
      ..translate(-rect.left, -rect.top);

    _debugPaint();
    markNeedsPaint();
  }

  void markNeedsPaint() {
    _dirty = true;
  }

  void markPainted() {
    _dirty = false;
    _empty = false;
  }

  void clear() {
    if (_empty) return;
    _context.clearRect(rect.left, rect.top, chunkSize, chunkSize);
    _debugPaint();
    _empty = true;
  }

  void _debugPaint() {
    if (_debugChunks) {
      _context
        ..save()
        ..strokeStyle = 'red'
        ..fillStyle = 'red'
        ..fillStyle = '#DDDDDD'
        ..fillRect(rect.left + 2, rect.top + 2, rect.width - 2, rect.height - 2)
        ..fillText('$rect', rect.left + 50, rect.top + 50)
        ..restore();
    }
  }
}

class _ChunkPosition {
  _ChunkPosition(this.x, this.y);

  @override
  bool operator ==(dynamic other) {
    if (other is! _ChunkPosition) return false;
    return y == other.y && x == other.x;
  }

  @override
  int get hashCode => y * 37 + x;

  final int x;
  final int y;
}

typedef CanvasPaintCallback = void Function(
    CanvasRenderingContext2D context, Rect rect);

typedef MouseCallback = void Function(Offset offset);

/// Class that enables efficient rendering of an arbitrarily large canvas by
/// managing a set of [chunkSize] x [chunkSize] tiles and only rendering tiles
/// for content within the current viewport.
///
/// This class is only compatible with browsers that support
/// [IntersectionObserver].
/// https://caniuse.com/#feat=intersectionobserver
class ViewportCanvas extends Object with SetStateMixin {
  ViewportCanvas({
    @required CanvasPaintCallback paintCallback,
    MouseCallback onTap,
    MouseCallback onMouseMove,
    VoidCallback onMouseLeave,
    String classes,
    this.addBuffer = true,
  })  : _paintCallback = paintCallback,
        _onTap = onTap,
        _onMouseMove = onMouseMove,
        _onMouseLeave = onMouseLeave,
        _element = div(
          a: 'flex',
          c: classes,
        ),
        _content = div(),
        _spaceTop = div(),
        _spaceBottom = div(),
        _spaceLeft = div(),
        _spaceRight = div() {
    // This styling is added directly instead of via CSS as it is critical for
    // correctness of the viewport calculations.
    _element.element.style..overflow = 'scroll';
    _content.element.style
      ..position = 'relative'
      ..width = '0'
      ..height = '0'
      ..overflow = 'hidden';
    _element.add(_content);

    final spacers = <CoreElement>[
      _spaceTop,
      _spaceBottom,
      _spaceLeft,
      _spaceRight
    ];
    for (var spacer in spacers) {
      spacer.element.style
        ..position = 'absolute'
        ..overflow = 'hidden';
    }
    _spaceLeft.element.style
      ..top = '0'
      ..bottom = '0'
      ..left = '0'
      ..width = '0';
    _spaceRight.element.style
      ..top = '0'
      ..bottom = '0'
      ..right = '0'
      ..width = '0';
    _spaceTop.element.style
      ..top = '0'
      ..left = '0'
      ..right = '0'
      ..height = '0';
    _spaceBottom.element.style
      ..bottom = '0'
      ..left = '0'
      ..right = '0'
      ..height = '0';

    _content.add(spacers);

    // TODO(jacobr): remove call to allowInterop once
    // https://github.com/dart-lang/sdk/issues/35484 is fixed.
    _visibilityObserver = IntersectionObserver(
        allowInterop(_onVisibilityChange), {'root': _element.element});
    for (var spacer in spacers) {
      _visibilityObserver.observe(spacer.element);
    }

    element.onScroll.listen((_) {
      if (_currentMouseHover != null) {
        _dispatchMouseMoveEvent();
      }
      // Add a buffer when mouse wheel scrolling as that event is unfortunately
      // async so we risk flickering UI if we don't render with a buffer.
      rebuild(force: false);
    });
    if (_onTap != null) {
      _content.onClick.listen((e) {
        _onTap(_clientToGlobal(e.client));
      });
    }
    _content.element.onMouseLeave.listen((_) {
      _currentMouseHover = null;
      if (_onMouseLeave != null) {
        _onMouseLeave();
      }
    });
    _content.element.onMouseMove.listen((e) {
      _currentMouseHover = e.client;
      _dispatchMouseMoveEvent();
    });
  }

  Point _currentMouseHover;

  /// Id used to help debug what was rendered as part of the current frame.
  int _frameId = 0;

  final CanvasPaintCallback _paintCallback;
  final MouseCallback _onTap;
  final MouseCallback _onMouseMove;
  final VoidCallback _onMouseLeave;
  final Map<_ChunkPosition, _CanvasChunk> _chunks = {};

  static const int maxChunks = 50;

  /// Intersection observer used to detect when the viewport needs to be
  /// recomputed.
  IntersectionObserver _visibilityObserver;

  CoreElement get element => _element;
  final CoreElement _element;

  /// Element containing all content that scrolls within the viewport.
  final CoreElement _content;

  // Fixed sized divs placed around the the content that is currently rendered.
  // These divs only exist to ensure that [_visibilityObserver] fires
  // fire when content that was outside the viewport moves inside the viewport.
  final CoreElement _spaceTop;
  final CoreElement _spaceBottom;
  final CoreElement _spaceLeft;
  final CoreElement _spaceRight;

  double _contentWidth = 0;
  double _contentHeight = 0;
  bool _contentSizeChanged = true;
  bool _hasPendingRebuild = false;

  Rect get viewport => _viewport;

  /// Whether to add an extra buffer of canvas tiles around the viewport to
  /// reduce flicker when mouse wheel scrolling where the scroll events are
  /// async.
  final bool addBuffer;

  /// The rendered viewport may be larger than _viewport if we have rendered
  /// additional content outside the real viewport to avoid flicker on
  /// scrollwheel events which may trigger scrolling.
  Rect _renderedViewport;
  Rect _viewport = Rect.zero;

  void _dispatchMouseMoveEvent() {
    if (_onMouseMove != null) {
      _onMouseMove(_clientToGlobal(_currentMouseHover));
    }
  }

  Offset _clientToGlobal(Point client) {
    final elementRect = _content.element.getBoundingClientRect();
    return Offset(client.x - elementRect.left, client.y - elementRect.top);
  }

  void dispose() {
    _visibilityObserver.disconnect();
  }

  void _onVisibilityChange(List entries, IntersectionObserver observer) {
    _scheduleRebuild();
  }

  void _scheduleRebuild() {
    if (!_hasPendingRebuild) {
      // Set a flag to ensure we don't schedule rebuilds if there's already one
      // in the queue.
      _hasPendingRebuild = true;
      setState(() {
        _hasPendingRebuild = false;
        rebuild(force: false);
      });
    }
  }

  // If [addBuffer] is true, a buffer of content is added around the visible
  // content to reduce flicker when mouse wheel scrolling.
  void rebuild({@required bool force}) {
    final lastViewport = _viewport;
    final rawElement = _element.element;
    _viewport = Rect.fromLTWH(
      rawElement.scrollLeft.toDouble(),
      rawElement.scrollTop.toDouble(),
      rawElement.offsetWidth.toDouble(),
      rawElement.offsetHeight.toDouble(),
    );

    if (addBuffer) {
      // Expand the viewport by a chunk in each direction to reduce flicker on
      // mouse wheel scroll.
      // TODO(jacobr): initially render a smaller viewport and then expand the
      // viewport on idle.
      _renderedViewport = _viewport
          .inflate(chunkSize.toDouble())
          // Avoid extending the viewport outside of the actual content area.
          .intersect(Rect.fromLTWH(0, 0, _contentWidth, _contentHeight));
    } else {
      _renderedViewport = _viewport;
    }

    // TODO(jacobr): round viewport to the nearest chunk multiple so we
    // don't get notifications until we actually need them.
    // TODO(jacobr): consider using the _renderedViewport to display the spacers
    // instead of the client viewport.

    // Position spacers to take up all the space around the viewport so we are
    // notified when the viewport changes.
    if (lastViewport.left != _renderedViewport.left || _contentSizeChanged) {
      _spaceLeft.element.style.width = '${_renderedViewport.left - 1}px';
    }
    if (lastViewport.right != _renderedViewport.right || _contentSizeChanged) {
      _spaceRight.element.style.width =
          '${_contentWidth - _renderedViewport.right - 1}px';
    }
    if (lastViewport.top != _renderedViewport.top || _contentSizeChanged) {
      _spaceTop.element.style.height = '${_renderedViewport.top - 1}px';
    }
    if (lastViewport.bottom != _renderedViewport.bottom ||
        _contentSizeChanged) {
      _spaceBottom.element.style.height =
          '${_contentHeight - _renderedViewport.bottom - 1}px';
    }
    _contentSizeChanged = false;

    _render(force);
  }

  void setContentSize(double width, double height) {
    if (width == _contentWidth && height == _contentHeight) {
      return;
    }
    _contentWidth = width;
    _contentHeight = height;
    _content.element.style
      ..width = '${width}px'
      ..height = '${height}px';
    if (!_contentSizeChanged) {
      _contentSizeChanged = true;
      _scheduleRebuild();
    }
  }

  // Trigger a re-render of all content matching rect.
  void markNeedsPaint(Rect rect) {
    final start = _getChunkPosition(rect.topLeft);
    final end = _getChunkPosition(rect.bottomRight);
    for (int y = start.y; y <= end.y; y++) {
      for (int x = start.x; x <= end.x; x++) {
        _chunks[_ChunkPosition(x, y)]?.markNeedsPaint();
      }
    }
    setState(() {
      rebuild(force: false);
    });
  }

  _ChunkPosition _getChunkPosition(Offset offset) {
    return _ChunkPosition(offset.dx ~/ chunkSize, offset.dy ~/ chunkSize);
  }

  _CanvasChunk _getChunk(_ChunkPosition position) {
    var existing = _chunks[position];
    if (existing != null) {
      if (existing.dirty) {
        existing.clear();
      }
      return existing;
    }
    // Find an unused chunk. TODO(jacobr): consider using a LRU cache.
    // The number of chunks is small so there is no need to really optimize this
    // case.
    for (_CanvasChunk chunk in _chunks.values) {
      if (!_isVisible(chunk)) {
        existing = chunk;
        final removed = _chunks.remove(chunk.position);
        assert(removed == existing);
        existing.position = position;
        _chunks[position] = existing;
        if (existing.dirty) {
          existing.clear();
        }
        return existing;
      }
    }
    assert(existing == null);
    final chunk = _CanvasChunk(position);
    _chunks[position] = chunk;
    return chunk;
  }

  void _render(bool force) {
    if (force) {
      for (var chunk in _chunks.values) {
        chunk.markNeedsPaint();
        chunk.clear();
      }
    }
    _frameId++;

    final start = _getChunkPosition(_renderedViewport.topLeft);
    final end = _getChunkPosition(_renderedViewport.bottomRight);
    for (int y = start.y; y <= end.y; y++) {
      for (int x = start.x; x <= end.x; x++) {
        final chunk = _getChunk(_ChunkPosition(x, y));
        if (chunk.dirty) {
          try {
            _paintCallback(chunk.canvas.context2D, chunk.rect);
          } catch (e, st) {
            window.console..error(e)..error(st);
          }
          chunk.markPainted();
        }
        chunk._lastFrameRendered = _frameId;
      }
    }
    for (_CanvasChunk chunk in _chunks.values) {
      final attach = chunk._lastFrameRendered == _frameId;
      if (attach != chunk.attached) {
        if (attach) {
          _content.element.append(chunk.canvas);
        } else {
          chunk.canvas.remove();
        }
        chunk.attached = attach;
      }
    }
  }

  bool _isVisible(_CanvasChunk chunk) => chunk.rect.overlaps(_renderedViewport);

  void scrollToRect(Rect target) {
    setState(() {
      // This rebuild is for convenience to make sure the UI is in a sensible
      // state before we start scrolling. Rebuilding is generally incremental
      // so there is little cost due to triggering an extra rebuild.
      rebuild(force: false);
      // We have to reimplement some scrolling functionality as modifying the
      // dom like this class does while a scroll is in progress interferes with
      // built in scrolling into view logic.
      if (_viewport.contains(target.topLeft) &&
          _viewport.contains(target.bottomLeft)) {
        // Already fully in view. Do nothing.
        return;
      }
      final bool overlaps = _viewport.overlaps(target);

      num x = _viewport.left;
      num y = _viewport.top;
      if (viewport.top > target.top) {
        // Scroll up
        y = target.top.toInt();
      } else if (viewport.bottom < target.bottom) {
        // Scroll down only as much as needed if the viewport overlaps
        y = overlaps ? target.bottom - viewport.height : target.top;
      }

      if (viewport.left > target.left) {
        // Scroll left.
        x = target.left.toInt();
      } else if (viewport.right < target.right) {
        // Scroll right
        x = (target.right - viewport.width).toInt();
      }
      _element.element.scrollTo(x, y);
    });
  }
}
