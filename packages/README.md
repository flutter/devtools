# Coding agreements in DevTools

We fully follow [Effective Dart](https://dart.dev/guides/language/effective-dart)
and some items of
[Style guide for Flutter repo](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo):

## Order of getters and setters

When an object owns and exposes a (listenable) value,
more complicated than just public field
we declare the related class members always in the same order,
in compliance with [Flutter repo style guide]( https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#order-other-class-members-in-a-way-that-makes-sense):

1. Public getter
2. Private field
3. Public setter (when needed)

## Naming for function variables

In compliance with [Flutter repo style guide](https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#naming-rules-for-typedefs-and-function-variables) we name:

1. Use Typedefs to define callbacks: `FooCallback`
2. For callback argument/property use: `onFoo`
3. For a method that is passed as a callback: `handleFoo`
