# Property of nothing

You tried to look up a property of an object, but the object in question was
the special `nothing` not-really-an-object value, so this was impossible.

This is most likely to have happened through mentioning a property of an
object whose identity was stored in a variable, or something similar, but
when that variable had never been set to an actual object and was still
set to `nothing`.
