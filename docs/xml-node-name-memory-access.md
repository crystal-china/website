# Why `XML::Node#name` could read inaccessible memory

PR: https://github.com/crystal-lang/crystal/pull/17648

The fix was merged into `release/1.22`. The key distinction is reading an entire
struct versus reading one field.

## Why the original expression could crash

```crystal
@node.value && @node.value.name
```

`@node` is typed as `Pointer(LibXML::Node)`, but it can actually point to an XML
attribute, whose underlying structure is `LibXML::Attr`.

These structures share an initial layout, including the `name` field, but `Attr`
is smaller than `Node`.

Struct definitions:
https://github.com/crystal-lang/crystal/blob/release/1.22/src/xml/libxml2.cr

The standalone expression `@node.value` dereferences the pointer as a complete
`LibXML::Node`. Evaluating it can therefore read beyond the actual attribute's
allocation:

```text
Actual Attr: [ shared fields, including name ][ attribute fields ]
Node read:   [--------------------------------------------------------]
                                                   ^ beyond allocation
```

If that extra read reaches an inaccessible memory page, the process crashes.
Otherwise, it may appear to work despite the out-of-bounds read.

This is not a pointer-validity check: `.value` already dereferences the pointer.
The resulting struct is always truthy, so the first condition provides no
protection.

## Why accessing the field works

```crystal
@node.value.name
```

Crystal can access the `name` field directly at its known offset without
materializing the entire larger struct. That field lies inside the shared,
valid portion of both structures.

The fix removes the unnecessary whole-struct read:

```crystal
elsif name = @node.value.name
  String.new(name)
```

It does not make an invalid pointer valid. It stops reading more memory than
the actual object contains.

Optimization could previously hide the problem by eliminating the redundant
read, which explains why different build modes could behave differently.
