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

**Public API:** `ToonFu.encode(value, **options)` and `ToonFu::Encoder` (`lib/toon_fu/encoder.rb`, options `delimiter:`, `indent_size:`); `ToonFu::Encodable` adds `#to_toon` to core classes (`lib/toon_fu/encodable.rb`); `ToonFu::Error`. Everything else is a `private_constant`.

**Pipeline:** `Encoder#encode` → `Normalizer` (Ruby host types → JSON data model, `as_toon` hook, cycle and encoding checks) → per-call `Writer` (line buffer and indentation in ivars; picks the form: object, inline/list/tabular array, keyed table).

**Helpers:** `Fields` (tabular column classification, §9.3), `StringLiteral` (quoting/escaping per delimiter, §7), `FloatLiteral` / `DecimalLiteral` (canonical numbers, §2).

**Spec:** `spec/toon-spec` is the `toon-format/spec` submodule pinned to its release tag. `spec/conformance/encode_spec.rb` runs every encode fixture keyed on file and index.

## Rules

- The spec decides. For any unfamiliar input the first question is what `spec/toon-spec/SPEC.md` says; if the spec models it, encode it, otherwise raise `ToonFu::Error`. Every conversion is one the spec or the documented list defines, and behaviour depends on the gem alone. Accepted types are listed on `Encoder#encode` and in the README.
- The fixtures are the primary tests. Unit specs cover what JSON fixtures cannot express (host types, options validation, Ruby-level errors) and the gem's own behaviour — Ruby and other libraries test themselves.
- Ruby-shaped OOP: state lives in objects' ivars. Split a form into its own class when complexity grows.
- Prefer Ruby built-ins; take a technique from the inspiration gems (Psych, CSV, json) when it measurably beats the built-in, and copy structure only when it is Ruby-shaped — older gems mirror their C code.
- Keep the public API minimal, with the spec's option names in snake_case: the version number belongs to the spec, so our own API stays stable.
- Runtime dependencies: Ruby's standard library only. `date` is required; `BigDecimal` is accepted when the caller has loaded it.
- Public gem: YARD on every public interface.

## Versioning & Releases

- New spec version → `X.Y.0`; our fixes and additions → patch. The spec-drift workflow fails daily when a newer spec release exists.
- Release: bump `lib/toon_fu/version.rb` in a PR, merge, `git tag vX.Y.Z && git push origin vX.Y.Z`, the maintainer approves the `release` deployment. Release notes are GitHub's generated notes.
- Supply chain: actions pinned by full SHA, least-privilege `permissions`, `Gemfile.lock` committed, publishing through trusted publishing only.

Design history: `thoughts/shared/notes/2026-09-24/toon-fu-ruby-toon-gem-decisions.md`.
