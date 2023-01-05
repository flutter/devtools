# Coding agreements in DevTools

## Order of getters and setters

When an object owns and exposes a (listenable) value,
more complicated than just public field
we declare the related class members always in the same order,
in compliance with [Flutter repo style guide]( https://github.com/flutter/flutter/wiki/Style-guide-for-Flutter-repo#order-other-class-members-in-a-way-that-makes-sense):

1. Public getter
2. Private field
3. Public setter (when needed)
