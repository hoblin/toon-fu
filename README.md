# toon-fu

[![CI](https://github.com/hoblin/toon-fu/actions/workflows/ci.yml/badge.svg)](https://github.com/hoblin/toon-fu/actions/workflows/ci.yml)
[![Spec drift](https://github.com/hoblin/toon-fu/actions/workflows/spec-drift.yml/badge.svg)](https://github.com/hoblin/toon-fu/actions/workflows/spec-drift.yml)
[![Gem](https://img.shields.io/gem/v/toon-fu)](https://rubygems.org/gems/toon-fu)

[TOON](https://toonformat.dev/) (Token-Oriented Object Notation) codec for Ruby, versioned by the spec it implements: the gem's `MAJOR.MINOR` is the TOON spec version it speaks.

## What is this?

TOON is a compact, readable encoding of the JSON data model for LLM prompts: indentation instead of braces, quotes only where needed, and tables for arrays of uniform objects. toon-fu is written from the [specification](https://github.com/toon-format/spec) and runs the spec's reference fixtures as its conformance suite — every encode and decode fixture of the spec version it implements passes.

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

You get back plain Ruby: `Hash` with String keys, `Array`, `String`, `Integer`, `Float`, `true`, `false`, `nil`.

Quoting decides the type, and an unquoted token is a number only if the spec says it is one:

```ruby
ToonFu.decode("a: 42")      # => {"a" => 42}
ToonFu.decode('a: "42"')    # => {"a" => "42"}
ToonFu.decode("a: 05")      # => {"a" => "05"}
ToonFu.decode("a: +1")      # => {"a" => "+1"}
```

Malformed input raises `ToonFu::Error`:

```ruby
ToonFu.decode("tags[3]: a,b")
# ToonFu::Error: cannot decode 2 values where the header declares 3
```

### Options

- `strict:` — `true` (default) checks everything the spec requires. Pass `false` for the spec's five recoveries and nothing more: a declared length is ignored, a duplicate key takes its last value, a tab indents one level, a blank line inside a table is skipped, and a scope's first line sets its depth. Everything else — a malformed header, a row of the wrong width, a stray over-indented line — raises in either mode.
- `indent_size:` — spaces per nesting level, default `2`.

```ruby
ToonFu.decode(text, strict: false)
decoder = ToonFu::Decoder.new(indent_size: 4) # reuse for many documents
decoder.decode(text)
```

## On the command line

The gem installs a `toon` executable that encodes JSON on stdin — handy for reading a command's output in fewer tokens:

```bash
$ gh api repos/ruby/ruby/pulls --jq '.[0] | {number, title}' | toon
number: 13579
title: Fix a typo
```

Input it cannot encode is passed through unchanged, so putting it at the end of a pipe never costs you the output:

```bash
$ git log --oneline -1 | toon
b08ea2d feat: ship a toon executable
```

## Compared with other Ruby TOON gems

The only one that passes every spec fixture: toon-fu passes all 160 encode and all 404 decode fixtures. The table compares encoding — the 138 encode fixtures that use default options, which every gem can run; none of the others reads TOON back.

| Gem | Spec fixtures passed | Speed vs toon-fu |
|---|---:|---:|
| **toon-fu** | **138 / 138** | **1.00×** |
| sorbet-toon 0.1.0 | 104 / 138 | 0.55× |
| toon-ruby 0.1.1 | 100 / 138 | 0.55× |
| toon_my_json 0.1.0 | 46 / 138 | 1.49× |
| toon-format 0.1.2 | 40 / 138 | 1.11× |

The Ruby TOON encoders with more than 10,000 downloads, measured by [`benchmark/run.rb`](benchmark/run.rb) on Ruby 3.4.11 (2026-10-10). **Spec fixtures** are the spec's own encode fixtures that use default options. **Speed** is the geometric mean of encodes per second over five workloads — tables of 100 and 1000 rows, nested objects, a list of mixed objects, strings needing quotes — relative to toon-fu.

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

This release speaks `toon-spec: 4.4`.

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
