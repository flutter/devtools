# Coding agreements in DevTools

## ValueListeneble and ValueNotifier

When an object owns and exposes a listenable value,
we declare the related fields always in the same order:

1. Public getter for ValueListeneble
2. Private ValueNotifier
3. Public setter
