import 'dart:async';
import 'dart:math';

import 'package:mp_chart/mp/core/common_interfaces.dart';

class ChartAnimator {
  static const int REFRESH_RATE = 16;
  static const double MIN = 0.0;
  static const double MAX = 1.0;

  /// object that is updated upon animation update
  AnimatorUpdateListener _listener;

  /// The phase of drawn values on the y-axis. 0 - 1
  double _phaseY = MAX;

  /// The phase of drawn values on the x-axis. 0 - 1
  double _phaseX = MAX;

  double _angle;

  Timer _countdownTimer;

  bool _isShowed = false;

  ChartAnimator(AnimatorUpdateListener listener) {
    _listener = listener;
  }

  void reset() {
    _isShowed = false;
  }

  bool get needReset => _isShowed;

  void spin(int durationMillis, double fromAngle, double toAngle,
      EasingFunction easing) {
    if (_isShowed ||
        _countdownTimer != null ||
        durationMillis < 0 ||
        fromAngle >= toAngle) {
      return;
    }
    reset();
    _isShowed = true;
    final double totalTime = durationMillis.toDouble();
    _angle = fromAngle;
    _countdownTimer =
        Timer.periodic(Duration(milliseconds: REFRESH_RATE), (timer) {
      if (durationMillis < 0) {
        _angle = toAngle;
        _countdownTimer?.cancel();
        _countdownTimer = null;
      } else {
        _angle += toAngle *
            (1.0 - easing.getInterpolation(durationMillis / totalTime));
        if (_angle >= toAngle) {
          _angle = toAngle;
        }
        durationMillis -= REFRESH_RATE;
      }
      _listener?.onRotateUpdate(_angle);
    });
  }

  /// Animates values along the X axis, in a linear fashion.
  ///
  /// @param durationMillis animation duration
  void animateX1(int durationMillis) {
    animateX2(durationMillis, Easing.Linear);
  }

  /// Animates values along the X axis.
  ///
  /// @param durationMillis animation duration
  /// @param easing EasingFunction
  void animateX2(int durationMillis, EasingFunction easing) {
    if (_isShowed || _countdownTimer != null || durationMillis < 0) {
      return;
    }
    reset();
    _isShowed = true;
    final double totalTime = durationMillis.toDouble();
    _phaseX = MIN;
    _countdownTimer =
        Timer.periodic(Duration(milliseconds: REFRESH_RATE), (timer) {
      if (durationMillis < 0) {
        _phaseX = MAX;
        _countdownTimer?.cancel();
        _countdownTimer = null;
      } else {
        _phaseX = MAX - easing.getInterpolation(durationMillis / totalTime);
        if (_phaseX >= MAX) {
          _phaseX = MAX;
        }
        durationMillis -= REFRESH_RATE;
      }
      _listener?.onAnimationUpdate(_phaseX, _phaseY);
    });
  }

  /// Animates values along both the X and Y axes, in a linear fashion.
  ///
  /// @param durationMillisX animation duration along the X axis
  /// @param durationMillisY animation duration along the Y axis
  void animateXY1(int durationMillisX, int durationMillisY) {
    animateXY3(durationMillisX, durationMillisY, Easing.Linear, Easing.Linear);
  }

  /// Animates values along both the X and Y axes.
  ///
  /// @param durationMillisX animation duration along the X axis
  /// @param durationMillisY animation duration along the Y axis
  /// @param easing EasingFunction for both axes
  void animateXY2(
      int durationMillisX, int durationMillisY, EasingFunction easing) {
    if (_isShowed ||
        _countdownTimer != null ||
        durationMillisX < 0 ||
        durationMillisY < 0) {
      return;
    }
    reset();
    _isShowed = true;
    final double totalTimeX = durationMillisX.toDouble();
    final double totalTimeY = durationMillisY.toDouble();
    _phaseX = MIN;
    _phaseY = MIN;
    _countdownTimer =
        Timer.periodic(Duration(milliseconds: REFRESH_RATE), (timer) {
      if (durationMillisX < 0 && durationMillisY < 0) {
        _phaseX = MAX;
        _phaseY = MAX;
        _countdownTimer?.cancel();
        _countdownTimer = null;
      } else {
        _phaseX = MAX - easing.getInterpolation(durationMillisX / totalTimeX);
        if (_phaseX >= MAX) {
          _phaseX = MAX;
        }

        _phaseY = MAX - easing.getInterpolation(durationMillisY / totalTimeY);
        if (_phaseY >= MAX) {
          _phaseY = MAX;
        }

        durationMillisX -= REFRESH_RATE;
        durationMillisY -= REFRESH_RATE;
      }
      _listener?.onAnimationUpdate(_phaseX, _phaseY);
    });
  }

  /// Animates values along both the X and Y axes.
  ///
  /// @param durationMillisX animation duration along the X axis
  /// @param durationMillisY animation duration along the Y axis
  /// @param easingX EasingFunction for the X axis
  /// @param easingY EasingFunction for the Y axis
  void animateXY3(int durationMillisX, int durationMillisY,
      EasingFunction easingX, EasingFunction easingY) {
    if (_isShowed ||
        _countdownTimer != null ||
        durationMillisX < 0 ||
        durationMillisY < 0) {
      return;
    }
    reset();
    _isShowed = true;
    final double totalTimeX = durationMillisX.toDouble();
    final double totalTimeY = durationMillisY.toDouble();
    _phaseX = MIN;
    _phaseY = MIN;
    _countdownTimer =
        Timer.periodic(Duration(milliseconds: REFRESH_RATE), (timer) {
      if (durationMillisX < 0 && durationMillisY < 0) {
        _phaseX = MAX;
        _phaseY = MAX;
        _countdownTimer?.cancel();
        _countdownTimer = null;
      } else {
        _phaseX = MAX - easingX.getInterpolation(durationMillisX / totalTimeX);
        if (_phaseX >= MAX) {
          _phaseX = MAX;
        }

        _phaseY = MAX - easingY.getInterpolation(durationMillisY / totalTimeY);
        if (_phaseY >= MAX) {
          _phaseY = MAX;
        }

        durationMillisX -= REFRESH_RATE;
        durationMillisY -= REFRESH_RATE;
      }
      _listener?.onAnimationUpdate(_phaseX, _phaseY);
    });
  }

  /// Animates values along the Y axis, in a linear fashion.
  ///
  /// @param durationMillis animation duration
  void animateY1(int durationMillis) {
    animateY2(durationMillis, Easing.Linear);
  }

  /// Animates values along the Y axis.
  ///
  /// @param durationMillis animation duration
  /// @param easing EasingFunction
  void animateY2(int durationMillis, EasingFunction easing) {
    if (_isShowed || _countdownTimer != null || durationMillis < 0) {
      return;
    }
    reset();
    _isShowed = true;
    final double totalTime = durationMillis.toDouble();
    _phaseY = MIN;
    _countdownTimer =
        Timer.periodic(Duration(milliseconds: REFRESH_RATE), (timer) {
      if (durationMillis < 0) {
        _phaseY = MAX;
        _countdownTimer?.cancel();
        _countdownTimer = null;
      } else {
        _phaseY = MAX - easing.getInterpolation(durationMillis / totalTime);
        if (_phaseY >= MAX) {
          _phaseY = MAX;
        }
        durationMillis -= REFRESH_RATE;
      }
      _listener?.onAnimationUpdate(_phaseX, _phaseY);
    });
  }

  /// Gets the Y axis phase of the animation.
  ///
  /// @return double value of {@link #_phaseY}
  double getPhaseY() {
    return _phaseY;
  }

  /// Sets the Y axis phase of the animation.
  ///
  /// @param phase double value between 0 - 1
  void setPhaseY(double phase) {
    if (phase > 1) {
      phase = 1;
    } else if (phase < 0) {
      phase = 0;
    }
    _phaseY = phase;
  }

  /// Gets the X axis phase of the animation.
  ///
  /// @return double value of {@link #_phaseX}
  double getPhaseX() {
    return _phaseX;
  }

  /// Sets the X axis phase of the animation.
  ///
  /// @param phase double value between 0 - 1
  void setPhaseX(double phase) {
    if (phase > 1) {
      phase = 1;
    } else if (phase < 0) {
      phase = 0;
    }
    _phaseX = phase;
  }
}

mixin EasingFunction {
  /// Maps a value representing the elapsed fraction of an animation to a value that represents
  /// the interpolated fraction. This interpolated value is then multiplied by the change in
  /// value of an animation to derive the animated value at the current elapsed animation time.
  ///
  /// @param input A value between 0 and 1.0 indicating our current point
  ///        in the animation where 0 represents the start and 1.0 represents
  ///        the end
  /// @return The interpolation value. This value can be more than 1.0 for
  ///         interpolators which overshoot their targets, or less than 0 for
  ///         interpolators that undershoot their targets.
  double getInterpolation(double input);
}

const double DOUBLE_PI = 2 * pi;

abstract class Easing {
  static const EasingFunction Linear = LinearEasingFunction();
  static const EasingFunction EaseInQuad = EaseInQuadEasingFunction();
  static const EasingFunction EaseOutQuad = EaseOutQuadEasingFunction();
  static const EasingFunction EaseInOutQuad = EaseInOutQuadEasingFunction();
  static const EasingFunction EaseInCubic = EaseInCubicEasingFunction();
  static const EasingFunction EaseOutCubic = EaseOutCubicEasingFunction();
  static const EasingFunction EaseInOutCubic = EaseInOutCubicEasingFunction();
  static const EasingFunction EaseInQuart = EaseInQuartEasingFunction();
  static const EasingFunction EaseOutQuart = EaseOutQuartEasingFunction();
  static const EasingFunction EaseInOutQuart = EaseInOutQuartEasingFunction();
  static const EasingFunction EaseInSine = EaseInSineEasingFunction();
  static const EasingFunction EaseOutSine = EaseOutSineEasingFunction();
  static const EasingFunction EaseInOutSine = EaseInOutSineEasingFunction();
  static const EasingFunction EaseInExpo = EaseInExpoEasingFunction();
  static const EasingFunction EaseOutExpo = EaseOutExpoEasingFunction();
  static const EasingFunction EaseInOutExpo = EaseInOutExpoEasingFunction();
  static const EasingFunction EaseInCirc = EaseInCircEasingFunction();
  static const EasingFunction EaseOutCirc = EaseOutCircEasingFunction();
  static const EasingFunction EaseInOutCirc = EaseInOutCircEasingFunction();
  static const EasingFunction EaseInElastic = EaseInElasticEasingFunction();
  static const EasingFunction EaseOutElastic = EaseOutElasticEasingFunction();
  static const EasingFunction EaseInOutElastic =
      EaseInOutElasticEasingFunction();
  static const EasingFunction EaseInBack = EaseInBackEasingFunction();
  static const EasingFunction EaseOutBack = EaseOutBackEasingFunction();
  static const EasingFunction EaseInOutBack = EaseInOutBackEasingFunction();
  static const EasingFunction EaseInBounce = EaseInBounceEasingFunction();
  static const EasingFunction EaseOutBounce = EaseOutBounceEasingFunction();
  static const EasingFunction EaseInOutBounce = EaseInOutBounceEasingFunction();
}

class EaseInOutBounceEasingFunction implements EasingFunction {
  const EaseInOutBounceEasingFunction();

  @override
  double getInterpolation(double input) {
    if (input < 0.5) {
      return Easing.EaseInBounce.getInterpolation(input * 2) * 0.5;
    }
    return Easing.EaseOutBounce.getInterpolation(input * 2 - 1) * 0.5 + 0.5;
  }
}

class EaseOutBounceEasingFunction implements EasingFunction {
  const EaseOutBounceEasingFunction();

  @override
  double getInterpolation(double input) {
    double s = 7.5625;
    if (input < (1 / 2.75)) {
      return s * input * input;
    } else if (input < (2 / 2.75)) {
      return s * (input -= (1.5 / 2.75)) * input + 0.75;
    } else if (input < (2.5 / 2.75)) {
      return s * (input -= (2.25 / 2.75)) * input + 0.9375;
    }
    return s * (input -= (2.625 / 2.75)) * input + 0.984375;
  }
}

class EaseInBounceEasingFunction implements EasingFunction {
  const EaseInBounceEasingFunction();

  @override
  double getInterpolation(double input) {
    return 1 - Easing.EaseOutBounce.getInterpolation(1 - input);
  }
}

class EaseInOutBackEasingFunction implements EasingFunction {
  const EaseInOutBackEasingFunction();

  @override
  double getInterpolation(double input) {
    double s = 1.70158;
    input *= 2;
    if (input < 1) {
      return 0.5 * (input * input * (((s *= (1.525)) + 1) * input - s));
    }
    return 0.5 *
        ((input -= 2) * input * (((s *= (1.525)) + 1) * input + s) + 2);
  }
}

class EaseOutBackEasingFunction implements EasingFunction {
  const EaseOutBackEasingFunction();

  @override
  double getInterpolation(double input) {
    final double s = 1.70158;
    input--;
    return (input * input * ((s + 1) * input + s) + 1);
  }
}

class EaseInBackEasingFunction implements EasingFunction {
  const EaseInBackEasingFunction();

  @override
  double getInterpolation(double input) {
    final double s = 1.70158;
    return input * input * ((s + 1) * input - s);
  }
}

class EaseInOutElasticEasingFunction implements EasingFunction {
  const EaseInOutElasticEasingFunction();

  @override
  double getInterpolation(double input) {
    if (input == 0) {
      return 0;
    }

    input *= 2;
    if (input == 2) {
      return 1;
    }

    double p = 1 / 0.45;
    double s = 0.45 / DOUBLE_PI * asin(1);
    if (input < 1) {
      return -0.5 *
          (pow(2, 10 * (input -= 1)) * sin((input * 1 - s) * DOUBLE_PI * p));
    }
    return 1 +
        0.5 * pow(2, -10 * (input -= 1)) * sin((input * 1 - s) * DOUBLE_PI * p);
  }
}

class EaseOutElasticEasingFunction implements EasingFunction {
  const EaseOutElasticEasingFunction();

  @override
  double getInterpolation(double input) {
    if (input == 0) {
      return 0;
    } else if (input == 1) {
      return 1;
    }

    double p = 0.3;
    double s = p / DOUBLE_PI * asin(1);
    return 1 + pow(2, -10 * input) * sin((input - s) * DOUBLE_PI / p);
  }
}

class EaseInElasticEasingFunction implements EasingFunction {
  const EaseInElasticEasingFunction();

  @override
  double getInterpolation(double input) {
    if (input == 0) {
      return 0;
    } else if (input == 1) {
      return 1;
    }

    double p = 0.3;
    double s = p / DOUBLE_PI * asin(1);
    return -(pow(2, 10 * (input -= 1)) * sin((input - s) * DOUBLE_PI / p));
  }
}

class EaseInOutCircEasingFunction implements EasingFunction {
  const EaseInOutCircEasingFunction();

  @override
  double getInterpolation(double input) {
    input *= 2;
    if (input < 1) {
      return -0.5 * (sqrt(1 - input * input) - 1);
    }
    return 0.5 * (sqrt(1 - (input -= 2) * input) + 1);
  }
}

class EaseOutCircEasingFunction implements EasingFunction {
  const EaseOutCircEasingFunction();

  @override
  double getInterpolation(double input) {
    input--;
    return sqrt(1 - input * input);
  }
}

class EaseInCircEasingFunction implements EasingFunction {
  const EaseInCircEasingFunction();

  @override
  double getInterpolation(double input) {
    return -(sqrt(1 - input * input) - 1);
  }
}

class EaseInOutExpoEasingFunction implements EasingFunction {
  const EaseInOutExpoEasingFunction();

  @override
  double getInterpolation(double input) {
    if (input == 0) {
      return 0;
    } else if (input == 1) {
      return 1;
    }

    input *= 2;
    if (input < 1) {
      return 0.5 * pow(2, 10 * (input - 1));
    }
    return 0.5 * (-pow(2, -10 * --input) + 2);
  }
}

class EaseOutExpoEasingFunction implements EasingFunction {
  const EaseOutExpoEasingFunction();

  @override
  double getInterpolation(double input) {
    return (input == 1) ? 1 : (-pow(2, -10 * (input + 1)));
  }
}

class EaseInExpoEasingFunction implements EasingFunction {
  const EaseInExpoEasingFunction();

  @override
  double getInterpolation(double input) {
    return (input == 0) ? 0 : pow(2, 10 * (input - 1));
  }
}

class EaseInOutSineEasingFunction implements EasingFunction {
  const EaseInOutSineEasingFunction();

  @override
  double getInterpolation(double input) {
    return -0.5 * (cos(pi * input) - 1.0);
  }
}

class EaseOutSineEasingFunction implements EasingFunction {
  const EaseOutSineEasingFunction();

  @override
  double getInterpolation(double input) {
    return sin(input * (pi / 2.0));
  }
}

class EaseInSineEasingFunction implements EasingFunction {
  const EaseInSineEasingFunction();

  @override
  double getInterpolation(double input) {
    return -cos(input * (pi / 2.0)) + 1.0;
  }
}

class EaseInOutQuartEasingFunction implements EasingFunction {
  const EaseInOutQuartEasingFunction();

  @override
  double getInterpolation(double input) {
    input *= 2.0;
    if (input < 1.0) {
      return 0.5 * pow(input, 4);
    }
    input -= 2.0;
    return -0.5 * (pow(input, 4) - 2.0);
  }
}

class EaseOutQuartEasingFunction implements EasingFunction {
  const EaseOutQuartEasingFunction();

  @override
  double getInterpolation(double input) {
    input--;
    return pow(input, 4) - 1.0;
  }
}

class EaseInQuartEasingFunction implements EasingFunction {
  const EaseInQuartEasingFunction();

  @override
  double getInterpolation(double input) {
    return pow(input, 4);
  }
}

class EaseInOutCubicEasingFunction implements EasingFunction {
  const EaseInOutCubicEasingFunction();

  @override
  double getInterpolation(double input) {
    input *= 2.0;
    if (input < 1.0) {
      return 0.5 * pow(input, 3);
    }
    input -= 2.0;
    return 0.5 * (pow(input, 3) + 2.0);
  }
}

class EaseOutCubicEasingFunction implements EasingFunction {
  const EaseOutCubicEasingFunction();

  @override
  double getInterpolation(double input) {
    input--;
    return pow(input, 3) + 1.0;
  }
}

class EaseInCubicEasingFunction implements EasingFunction {
  const EaseInCubicEasingFunction();

  @override
  double getInterpolation(double input) {
    return pow(input, 3);
  }
}

class EaseInOutQuadEasingFunction implements EasingFunction {
  const EaseInOutQuadEasingFunction();

  @override
  double getInterpolation(double input) {
    input *= 2.0;

    if (input < 1.0) {
      return 0.5 * input * input;
    }

    return -0.5 * ((--input) * (input - 2.0) - 1);
  }
}

class EaseOutQuadEasingFunction implements EasingFunction {
  const EaseOutQuadEasingFunction();

  @override
  double getInterpolation(double input) {
    return -input * (input - 2.0);
  }
}

class EaseInQuadEasingFunction implements EasingFunction {
  const EaseInQuadEasingFunction();

  @override
  double getInterpolation(double input) {
    return input * input;
  }
}

class LinearEasingFunction implements EasingFunction {
  const LinearEasingFunction();

  @override
  double getInterpolation(double input) {
    return input;
  }
}
