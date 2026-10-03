# toon-fu

[![CI](https://github.com/hoblin/toon-fu/actions/workflows/ci.yml/badge.svg)](https://github.com/hoblin/toon-fu/actions/workflows/ci.yml)
[![Spec drift](https://github.com/hoblin/toon-fu/actions/workflows/spec-drift.yml/badge.svg)](https://github.com/hoblin/toon-fu/actions/workflows/spec-drift.yml)
[![Gem](https://img.shields.io/gem/v/toon-fu)](https://rubygems.org/gems/toon-fu)

[TOON](https://toonformat.dev/) (Token-Oriented Object Notation) codec for Ruby, versioned by the spec it implements: the gem's `MAJOR.MINOR` is the TOON spec version it speaks.

## What is this?

TOON is a compact, readable encoding of the JSON data model for LLM prompts: indentation instead of braces, quotes only where needed, and tables for arrays of uniform objects. toon-fu is written from the [specification](https://github.com/toon-format/spec) and runs the spec's reference fixtures as its conformance suite — every encode and decode fixture of the spec version it implements passes, and everything the encoder writes reads back unchanged.

## Why?

Every Ruby TOON gem on RubyGems was published in late 2025 and stopped at spec 1.2, three major versions behind. They leave strings starting with `#` or `+` unquoted, which a current reader takes for a comment or a number, and shift dates by a day east of Greenwich. toon-fu tracks the spec: its version is the spec version, and a daily check flags a newer spec.

Yes, we know:

[![xkcd 927: Standards](https://imgs.xkcd.com/comics/standards.png)](https://xkcd.com/927/)

<sub>[xkcd #927 "Standards"](https://xkcd.com/927/) by Randall Munroe, [CC BY-NC 2.5](https://creativecommons.org/licenses/by-nc/2.5/).</sub>

## Getting started

Add it to your Gemfile:

```ruby
gem "toon-fu"
```

In a plain script: `gem install toon-fu` and `require "toon_fu"`. To pin the spec version, see [Versioning](#versioning).

```ruby
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

Any other value raises `ToonFu::Error`:

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

Everything else raises `ToonFu::Error` — including a `Struct` or `Data` without `as_toon`, circular references, and nesting too deep for the stack.

## Reading TOON

```ruby
ToonFu.decode("users[2]{id,name}:\n  1,Ada\n  2,Bob")
# => {"users" => [{"id" => 1, "name" => "Ada"}, {"id" => 2, "name" => "Bob"}]}
```

Decoding returns the JSON data model and nothing else: `Hash` with String keys, `Array`, `String`, `Integer`, `Float`, `true`, `false`, `nil`. Key order is the document's, except in the table forms, where it is the header's field order.

```ruby
ToonFu.decode("hello")  # => "hello"
ToonFu.decode('"42"')   # => "42"
ToonFu.decode("")       # => {}
```

### Options

- `strict:` — `true` (default) enforces the spec's strict mode: declared lengths must match, rows must be as wide as the header, duplicate keys and malformed indentation are errors. With `false` a declared length never truncates a scope, duplicate keys resolve last-write-wins, leading spaces need not be a multiple of `indent_size`, and a tab in indentation counts as one level.
- `indent_size:` — spaces per nesting level, default `2`.

```ruby
ToonFu.decode(text, strict: false)
decoder = ToonFu::Decoder.new(indent_size: 4) # reuse for many documents
decoder.decode(text)
```

### What the grammar decides, not Ruby

A token is a number only when it matches the spec's own grammar, so `.5`, `1.`, `+1`, `05`, `Infinity` and `1_000` decode as strings — and a quoted token stays a string whatever it looks like. Plain digits become an exact `Integer` of any size; a fraction or an exponent goes through `Float`, carrying its 53-bit precision even when the result is integral.

A token the grammar accepts but `Float` cannot hold without losing its magnitude — `1e400`, `1e-400` — raises rather than quietly becoming infinity or zero:

```ruby
ToonFu.decode("1e400")
# ToonFu::Error: cannot decode 1e400 as a Float without losing its magnitude
```

Nesting deeper than 100 levels raises instead of exhausting the stack.

## Compared with other Ruby TOON gems

The only one that passes every spec fixture: toon-fu passes all 179 encode and all 359 decode fixtures. The table below compares encoding only — the 154 encode fixtures that use default options, which every gem can run. None of the other gems decodes, except `rbtoon`, which decodes without unescaping quoted strings and reads numbers through `to_f`/`to_i`, a wider grammar than the spec allows.

| Gem | Spec fixtures passed | Speed vs toon-fu |
|---|---:|---:|
| **toon-fu** | **154 / 154** | **1.00×** |
| sorbet-toon 0.1.0 | 119 / 154 | 0.59× |
| toon-ruby 0.1.1 | 117 / 154 | 0.62× |
| toon_my_json 0.1.0 | 57 / 154 | 1.68× |
| toon-format 0.1.2 | 45 / 154 | 1.18× |

The Ruby TOON encoders with more than 10,000 downloads, measured by [`benchmark/run.rb`](benchmark/run.rb) on Ruby 3.4.10 (2026-09-24). **Spec fixtures** are the spec's own encode fixtures that use default options. **Speed** is the geometric mean of encodes per second over five workloads — tables of 100 and 1000 rows, nested objects, a list of mixed objects, strings needing quotes — relative to toon-fu.

What falls through the gaps:

- **sorbet-toon, toon-ruby** — `#tag` and `+1` go out unquoted, so a current reader sees a comment and a number; arrays of objects with nested columns lose their table form; no keyed tables. Unknown objects slip through instead of raising: toon-ruby writes `null`, sorbet-toon `"#<Foo:0x…>"`. toon-ruby also moves a `Date` a day back east of Greenwich.
- **toon_my_json, toon-format** — output a TOON reader cannot read: the table header on its own line, a `[2,]` length, rows at the wrong depth, nested objects in cells as broken text; toon_my_json also writes `false` as `null`. They do less work, and it shows in both columns.

Rerun it:

```bash
BUNDLE_GEMFILE=benchmark/Gemfile bundle install
BUNDLE_GEMFILE=benchmark/Gemfile bundle exec ruby benchmark/run.rb
```

To see where toon-fu itself spends time and allocates, profile one workload (CPU by stackprof, allocation sites by memory_profiler):

```bash
BUNDLE_GEMFILE=benchmark/Gemfile bundle exec ruby benchmark/profile.rb "table, 1000 rows"
```

## Versioning

The gem version tracks the TOON specification it implements:

- `MAJOR.MINOR` is the spec version: `X.Y.Z` speaks TOON `X.Y`.
- `PATCH` is the gem's own: fixes and improvements within the same dialect.

Pin the spec line with `gem "toon-fu", "~> X.Y.0"`: it takes our fixes and keeps you on the dialect you speak. The gem badge above shows the current release; the spec-drift badge turns red when a newer spec is released and toon-fu has not caught up yet.

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
