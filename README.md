# toon-fu

[![CI](https://github.com/hoblin/toon-fu/actions/workflows/ci.yml/badge.svg)](https://github.com/hoblin/toon-fu/actions/workflows/ci.yml)
[![Spec drift](https://github.com/hoblin/toon-fu/actions/workflows/spec-drift.yml/badge.svg)](https://github.com/hoblin/toon-fu/actions/workflows/spec-drift.yml)

[TOON](https://toonformat.dev/) (Token-Oriented Object Notation) encoder for Ruby, versioned by the spec it implements.

`toon-spec: 4.1`

## What is this?

TOON is a compact, readable encoding of the JSON data model for LLM prompts: indentation instead of braces, quotes only where needed, and tables for arrays of uniform objects. toon-fu is written from the [specification](https://github.com/toon-format/spec) and runs the spec's reference fixtures as its conformance suite — every encode fixture of TOON 4.1 passes.

## Why?

Every Ruby TOON gem on RubyGems was published in late 2025 and stopped at spec 1.2, three major versions behind. They leave strings starting with `#` or `+` unquoted, which a current reader takes for a comment or a number, and shift dates by a day east of Greenwich. toon-fu tracks the spec: its version is the spec version, and a daily check flags a newer spec.

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

## Development

```bash
git clone --recurse-submodules git@github.com:hoblin/toon-fu.git
cd toon-fu
bundle install
bundle exec rspec        # unit specs + the spec's conformance fixtures
bundle exec standardrb   # lint
```

The TOON spec is a git submodule at `spec/toon-spec`, pinned to its release tag; the fixtures run from there.

## Releasing

1. Bump `lib/toon_fu/version.rb` in a pull request and merge it.
2. `git tag vX.Y.Z && git push origin vX.Y.Z` on `main`.
3. Approve the `release` deployment in Actions.

The [release workflow](.github/workflows/release.yml) checks the tag matches the version, runs CI, and publishes to RubyGems via [trusted publishing](https://guides.rubygems.org/trusted-publishing/).

## License

MIT
