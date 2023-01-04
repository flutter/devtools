# Coding agreements in DevTools

## Order of getters and setters

When an object owns and exposes a (listenable) value,
more complicated than just public field
we declare the related class members always in the same order:

1. Public getter
2. Private field
3. Public setter (when needed)
