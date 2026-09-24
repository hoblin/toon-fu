# toon-fu

[![Spec drift](https://github.com/hoblin/toon-fu/actions/workflows/spec-drift.yml/badge.svg)](https://github.com/hoblin/toon-fu/actions/workflows/spec-drift.yml)

[TOON](https://github.com/toon-format/spec) (Token-Oriented Object Notation) for Ruby: a compact, readable encoding of JSON data for LLM prompts. Written from the specification, with the spec's reference fixtures as the conformance suite.

`toon-spec: 4.1`

## Getting started

```ruby
gem "toon-fu", "~> 4.1.0"
```

```ruby
require "toon_fu"

ToonFu.encode({users: [{id: 1, name: "Ada", role: "admin"}, {id: 2, name: "Bob", role: "user"}]})
```

```
users[2]{id,name,role}:
  1,Ada,admin
  2,Bob,user
```

Arrays of uniform objects become tables that declare their fields once. Everything else reads like YAML:

```ruby
{order: {id: 7, tags: ["new", "paid"], customer: {name: "Ada"}}}.to_toon
```

```
order:
  id: 7
  tags[2]: new,paid
  customer:
    name: Ada
```

`to_toon` is available on Hash, Array, String, Symbol, Integer, Float, `true`, `false`, `nil`, Set, Time and Date once `toon_fu` is loaded.

### Options

- `delimiter:` — `","` (default), `"\t"` or `"|"`. Tab usually costs the fewest tokens.
- `indent_size:` — spaces per nesting level, default `2`.

```ruby
ToonFu.encode(data, delimiter: "\t")
encoder = ToonFu::Encoder.new(delimiter: "|") # reuse for many documents
encoder.encode(data)
```

### Your own objects

Define `as_toon` to return plain data; it wins over every built-in mapping:

```ruby
Money = Struct.new(:cents, :currency) do
  include ToonFu::Encodable # optional: adds #to_toon

  def as_toon = {amount: cents / 100.0, currency:}
end

ToonFu.encode({price: Money.new(1999, "EUR")})
# price:
#   amount: 19.99
#   currency: EUR
```

Anything toon-fu does not know raises `ToonFu::Error` instead of guessing:

```ruby
ToonFu.encode({at: Object.new})
# ToonFu::Error: cannot encode Object; convert it first or define #as_toon
```

For ActiveRecord models, pass `record.as_json` (or define `as_toon`).

## What it accepts

| Ruby value | TOON |
|---|---|
| `Hash` with String, Symbol or Integer keys | object; keys become strings, keys that collide raise |
| `Array`, `Set` | array: inline, table, or list form |
| `String` | string, quoted only when needed; other encodings are transcoded to UTF-8, invalid UTF-8 raises |
| `Symbol` | its name |
| `Integer` | its exact digits, any size |
| `Float`, `BigDecimal` | canonical number; NaN and infinities become `null` |
| `true`, `false`, `nil` | `true`, `false`, `null` |
| `Date` | `2026-05-31` |
| `Time`, `DateTime` | ISO 8601 with its offset: `2026-05-31T10:00:05.25Z` |
| objects with `to_hash`, `to_ary`, `to_str` | the value they convert to |
| objects with `as_toon` | whatever `as_toon` returns, encoded in turn |

Everything else — including `Struct`, `Data` and circular references — raises `ToonFu::Error`.

## Versioning

The gem version tracks the TOON specification it implements:

- `MAJOR.MINOR` is the spec version. `4.1.x` speaks TOON 4.1.
- `PATCH` is the gem's own: fixes and improvements that do not change the dialect.

Pin to the spec line you need: `gem "toon-fu", "~> 4.1.0"`. A daily check turns the badge above red when a newer spec is released.

Release notes: [GitHub releases](https://github.com/hoblin/toon-fu/releases).

## License

MIT
