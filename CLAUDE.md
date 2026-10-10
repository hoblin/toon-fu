# CLAUDE.md

## Project

Ruby gem encoding Ruby values as TOON, written from the spec. The gem's `MAJOR.MINOR` is the TOON spec version it implements; `PATCH` is its own.

## Commands

```bash
git submodule update --init                       # spec fixtures, required by the suite
bundle exec rspec [spec/path/to_spec.rb[:42]]     # all specs / file / single example
bundle exec standardrb [--fix]
```

## Architecture

**Public API:** `ToonFu.encode(value, **options)` and `ToonFu::Encoder` (`lib/toon_fu/encoder.rb`, options `delimiter:`, `indent_size:`); `ToonFu.decode(text, **options)` and `ToonFu::Decoder` (`lib/toon_fu/decoder.rb`, options `strict:`, `indent_size:`); `ToonFu::Encodable` adds `#to_toon` to core classes (`lib/toon_fu/encodable.rb`); `ToonFu::Error`. Everything else is a `private_constant`.

**Encode pipeline:** `Encoder#encode` → `Normalizer` (Ruby host types → JSON data model, `as_toon` hook, cycle and encoding checks) → per-call `Writer` (line buffer and indentation in ivars; picks the form: object, inline/list/tabular array, keyed table).

**Decode pipeline:** `Decoder#decode` (UTF-8 check) → per-call `Reader` (recursive descent over scopes, current depth in an ivar) reading from `Lines` (the §5.1/§12 pre-pass: BOM, CR, comments, blank lines, indentation → a `Line` carrying content, depth and number). `Reader` picks the form per §5 and §9, `Header` parses a bracket segment and its `FieldList` (§6), and `Token` turns one token into a value (§7.1 unescaping, the §4 number grammar). `Tokens` holds the shared scanning: unquoted positions, delimiter splitting, U+0020 trimming.

**Helpers:** `Fields` (tabular column classification, §9.3), `StringLiteral` (quoting/escaping per delimiter, §7), `FloatLiteral` / `DecimalLiteral` (canonical numbers, §2).

**Spec:** `spec/toon-spec` is the `toon-format/spec` submodule pinned to its release tag. `spec/conformance/encode_spec.rb` and `decode_spec.rb` run every fixture of their direction keyed on file and index.

## Rules

- The spec decides. For any unfamiliar input the first question is what `spec/toon-spec/SPEC.md` says; if the spec models it, encode or decode it, otherwise raise `ToonFu::Error`. Every conversion is one the spec or the documented list defines, and behaviour depends on the gem alone. Accepted types are listed on `Encoder#encode` and in the README.
- Decoding never hands a decision the spec defines to a host parser with a wider grammar (§4): the number grammar is ours, and `Float()`/`Integer()` see only a token already matched against it.
- The fixtures are the primary tests. Unit specs cover what JSON fixtures cannot express (host types, options validation, Ruby-level errors) and the gem's own behaviour — Ruby and other libraries test themselves.
- Ruby-shaped OOP: state lives in objects' ivars. Split a form into its own class when complexity grows.
- Prefer Ruby built-ins; take a technique from the inspiration gems (Psych, CSV, json) when it measurably beats the built-in, and copy structure only when it is Ruby-shaped — older gems mirror their C code.
- Keep the public API minimal, with the spec's option names in snake_case: the version number belongs to the spec, so our own API stays stable.
- Runtime dependencies: Ruby's standard library only. `date` and `strscan` are required, both default gems; `BigDecimal` is accepted when the caller has loaded it.
- Public gem: YARD on every public interface.

## Versioning & Releases

- New spec version → `X.Y.0`; our fixes and additions → patch. The spec-drift workflow fails daily when a newer spec release exists.
- Release: bump `lib/toon_fu/version.rb` in a PR, merge, `git tag vX.Y.Z && git push origin vX.Y.Z`, the maintainer approves the `release` deployment. Release notes are GitHub's generated notes.
- Supply chain: actions pinned by full SHA, least-privilege `permissions`, `Gemfile.lock` committed, publishing through trusted publishing only.

## Spec bump

The spec-drift badge is red: a newer `toon-format/spec` release exists. Precedents: 4.3 in #44/#45, 4.4 in #47/#48.

1. Read what changed: in `spec/toon-spec`, `git fetch --tags`, then the new entries in `CHANGELOG.md`, the `SPEC.md` diff between the tags, and `VERSIONING.md` if it moved. Check `git log vX.Y.0..origin/main`: upstream has tagged before stamping the version or pinning fixtures, and a later re-pin is a patch release.
2. Check out the new tag in the submodule and run `bundle exec rspec spec/conformance`. The failures are the work.
3. Write the issue in the shape of #47: what changed upstream per section, the failing fixtures grouped by the rule they exercise, requirements, why MINOR and not patch. Then `/rpi:feature` from it.
4. Implement by deleting what the spec no longer allows rather than guarding it; the code should read as the spec's own list. Unit specs asserting dropped behaviour go; new unit specs cover only what the fixtures cannot express.
5. Release bits in the same PR: `VERSION` to `X.Y.0`, `bundle install` for `Gemfile.lock`, `Decoder`/`Encoder` YARD, README: the `toon-spec: X.Y` line, the fixture counts (`tests` entries per fixture file), the `strict:` description, and the comparison table re-run with `BUNDLE_GEMFILE=benchmark/Gemfile bundle exec ruby benchmark/run.rb` after the version bump, with its date.
6. Newcomers: `ruby benchmark/newcomers.rb $(gh release view vPREV --json publishedAt --jq .publishedAt)` lists the TOON gems released since our previous release. One that passes the README's cutoff, or claims a spec version at or above the best in the table, joins `benchmark/Gemfile`, `run.rb` and the README table and its gaps list.
7. PR body as #48: summary per encoder/decoder/release with `(§n)` citations, test plan, breaking changes for input no conforming encoder emits.
8. After the release: bump the Ruby row in `docs/ecosystem/implementations.md` from the `hoblin/toon` fork (precedents toon-format/toon#361, #365), and bump the dependency in `linear-toon-mcp` (`~> X.Y.0` in the gemspec and CLAUDE.md, patch version, tag, push with tags).

Design history: `thoughts/shared/notes/2026-09-24/toon-fu-ruby-toon-gem-decisions.md`.
