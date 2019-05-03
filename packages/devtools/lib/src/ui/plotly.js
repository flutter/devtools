// Plotly wrappers.

// TODO(terry): Remove JS code move to Dart JS interop.

function hookupPlotlyClick(domName, jsFunction) {
  var graph = document.getElementById(domName);
  graph.on('plotly_click', jsFunction);
}

function hookupPlotlyHover(domName, jsFunction) {
  var graph = document.getElementById(domName);
  graph.on('plotly_hover', jsFunction);
}

// Return false to cancel default handling, true to cause default handling.
function hookupPlotlyLegendClick(domName, jsFunction) {
  var graph = document.getElementById(domName);
  graph.on('plotly_legendclick', jsFunction);
}

function hookupPlotlyDoubleClick(domName, jsFunction) {
  var graph = document.getElementById(domName);
  graph.on('plotly_doubleclick', jsFunction);
}

function _copyTrace(x, y, orgTrace, xData, yData, traces) {
  if (x.length > 0) {
    var newX = [];
    var newY = [];
    for (var idx = 0; idx < x.length; idx++) {
      newX.push(x[idx]);
      newY.push(y[idx]);
    }
    xData.push(newX);
    yData.push(newY);
    traces.push(orgTrace);
  }
}

// TODO(terry): Used instead of normal JS interop (reified List).  Need to eliminate.
function extendTraces1(domName, x0, y0, orgTraces) {
  var data = {};
  var xData = [];
  var yData = [];
  var traces = [];

  _copyTrace(x0, y0, orgTraces[0], xData, yData, traces);

  data = {x: xData, y: yData};

  Plotly.extendTraces(domName, data, traces);
}

function extendTraces2(domName, x0, x1, y0, y1, orgTraces) {
  var data = {};
  var xData = [];
  var yData = [];
  var traces = [];

  _copyTrace(x0, y0, orgTraces[0], xData, yData, traces);
  _copyTrace(x1, y1, orgTraces[1], xData, yData, traces);

   data = {x: xData, y: yData};

  Plotly.extendTraces(domName, data, traces);
}

function extendTraces4(domName, x0, x1, x2, x3, y0, y1, y2, y3, orgTraces) {
  var data = {};
  var xData = [];
  var yData = [];
  var traces = [];

  _copyTrace(x0, y0, orgTraces[0], xData, yData, traces);
  _copyTrace(x1, y1, orgTraces[1], xData, yData, traces);
  _copyTrace(x2, y2, orgTraces[2], xData, yData, traces);
  _copyTrace(x3, y3, orgTraces[3], xData, yData, traces);

  data = {x: xData, y: yData};

  Plotly.extendTraces(domName, data, traces);
}

// Red glow a janking frame.
function createGlowShape(shapeIndex, x, y, fillColor, lineColor) {
    var jsShape = {};
    jsShape['shapes[' + shapeIndex + ']'] = {
        'fillcolor': fillColor,
        'line': {
            'color': lineColor,
            'width': 1,
        },
        'type': "rect",
        'x0': x - .4,
        'y0': '0',
        'x1': x + .4,
        'y1': y,
        'yref': 'y',
        layer: 'above',
    };

    return jsShape;
}

// Need to create dynamic key/value pair for Shape.
function createEventShape(devToolEvent, shapeIndex, lastEventTime, time) {
  var jsShape = {};
  jsShape['shapes[' + shapeIndex + ']'] = {
    'devtool_event_type': devToolEvent,
    'fillcolor': 'lightblue',
      'line': {
        'width': 0,
      },
      'opacity': .8,
      'type': "rect",
      'x0': lastEventTime,
      'y0': '.80',
      'x1': time,
      'y1': '1.20',
      'yref': 'y2',
      layer: 'below',
  };

  return jsShape;
}
