import 'dart:html';

class DragScroll {
  Expando<dynamic> mouseDownExpando = new Expando();
  Expando<dynamic> mouseUpExpando = new Expando();
  Expando<dynamic> mouseMoveExpando = new Expando();

  final mouseDown = 'mousedown';
  final mouseUp = 'mouseup';
  final mouseMove = 'mousemove';

  num newScrollX;
  num newScrollY;

  List<Node> dragged = [];

  void reset() {
    for (Element element in dragged) {
      element.removeEventListener(mouseDown, mouseDownExpando[element], false);
      window.removeEventListener(mouseUp, mouseUpExpando[element], false);
      window.removeEventListener(mouseMove, mouseMoveExpando[element], false);
    }

    dragged = document.getElementsByClassName('dragscroll');

    var lastClientX;
    var lastClientY;
    bool pushed = false;

    for (Element element in dragged) {
      element.addEventListener(
        mouseDown,
        mouseDownExpando[element] = (e) {
          if (!element.attributes.containsKey('nochilddrag') ||
              document.elementFromPoint(e.pageX, e.pageY) == element) {
            pushed = true;
            lastClientX = e.clientX;
            lastClientY = e.clientY;

            e.preventDefault();
          }
        },
        false,
      );

      window.addEventListener(
        mouseUp,
        mouseUpExpando[element] = (e) => pushed = false,
        false,
      );

      window.addEventListener(
        mouseMove,
        // same question. recursively calling itself?
        mouseMoveExpando[element] = (e) {
          if (pushed) {
            lastClientX = e.clientX;
            lastClientY = e.clientY;
            newScrollX = -lastClientX + lastClientX;
            newScrollY = -lastClientY + lastClientY;

            element.scrollLeft -= newScrollX;
            element.scrollTop -= newScrollY;

            if (element == document.body) {
              element = document.documentElement;
              element.scrollLeft -= newScrollX;
              element.scrollTop -= newScrollY;
            }
          }
        },
        false,
      );
    }
  }
}
