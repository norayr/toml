# toml

`TOML.Mod`, a TOML reader for [voc](https://github.com/vishaps/voc), the one vipak uses. The same
module is used by polpo for its package recipes (arden); it has no imports, so it compiles
unchanged with both.

  * tables `[a.b]` and arrays of tables `[[name]]` (a section each time);
  * bare, quoted and dotted keys (`a.b.c` is the key "a.b.c"), keys before the first table
    in a section named "";
  * basic strings with escapes (`\n`, `\"`, `\uXXXX` as UTF-8 ...), literal strings, and the
    multi-line forms `"""..."""` and `'''...'''`;
  * arrays, over several lines, with comments and a trailing comma: `items` has the elements,
    `value` the elements separated by blanks; nested arrays are flattened;
  * inline tables `{ x = 1, y = "two" }`, as the keys `key.x` and `key.y`;
  * integers, floats and booleans, kept as text with their `kind`; dates as text (`Bare`);
  * errors: `doc.errors`, the first in `doc.error` at `doc.errorLine`; the rest of the line
    is skipped.

Not TOML but still read, for older files: unquoted values up to the end of the line (kind
`Bare`), and other characters in unquoted keys (`src/x.Mod = ...`).

The interface of the first version (`Parse`, `GetSection`, `GetNextSection`, `GetField`,
`Field.key`, `Field.value`) is kept; new are `Find`, `Field.kind`, `Field.items`,
`Field.line` and the error fields of `Doc`.

```
make            # build/TOML.o and TOML.sym
make tests      # build/testTOML: checks on a sample document
build/testTOML file.toml    # what is read: section | key | kind | <value>
```
