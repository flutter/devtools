import 'dart:html';

class DragScroll {
  var mousemove = 'mousemove';
  var mouseup = 'mouseup';
  var mousedown = 'mousedown';
  var EventListener = 'EventListener';

// ??? what are these ???
//  var addEventListener = 'add'+EventListener;
//  var removeEventListener = 'remove'+EventListener;



  num newScrollX;
  num newScrollY;

  var dragged = [];

  void reset(int i, /*type?*/ eventListener) {
    while( i < dragged.length) {
      eventListener = dragged[i++];
      eventListener = eventListener.container ?? eventListener;
      /* what are mu mm md? mouse up, mouse move, and mouse down? */
      eventListener.removeEventListener(mousedown, eventListener.md, false);
      window.removeEventListener(mouseup, eventListener.mu, false);
      window.removeEventListener(mousemove, eventListener.mm, false);
    }

    dragged = document.getElementsByClassName('dragscroll');

    i = 0;
    while( i < dragged.length) {
      // is this (function) block a method? is function its name or a keyword?
      (function(
        /*type?*/ eventListener,
          num lastClientX,
          num lastClientY,
          num pushed,
          /*type?*/scroller,
          /*type?*/ container){

        container = eventListener.container ?? eventListener;

        container.addEventListener(
          mousedown,
          // container.md?? is this calling the above function recursively??
          container.md = function(e) {
            if (!eventListener.hasAttribute('nochilddrag') ||
              document.elementFromPoint(e.pageX, e.pageY) == container) {
                pushed = 1;
                lastClientX = e.clientX;
                lastClientY = e.clientY;

                e.preventDefault();
            }
          },
          false,
      );

      window.addEventListener(
        mouseup,
        container.mu => pushed = 0, // is this right?
        false,
      );

      window.addEventListener(
        mousemove,
        // same question. recursively calling itself?
        container.mm = function(e) {
          if (pushed) {
            scroller = eventListener.scroller ?? eventListener;
            newScrollX = -lastClientX + (lastClientX=e.clientX);
            newScrollY = -lastClientY + (lastClientY=e.clientY);

            scroller.scrollLeft -= newScrollX;
            scroller.scrollTop -= newScrollY;

            if (eventListener == document.body) {
              scroller = document.documentElement;
              scroller.scrollLeft -= newScrollX;
             scroller.scrollTop -= newScrollY;
            }
          }
        },
        false,
      );

      });

      dragged[i++];
    }
  }
}