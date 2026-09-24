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

- The spec decides. For any unfamiliar input the first question is what `spec/toon-spec/SPEC.md` says; if the spec does not model it, raise `ToonFu::Error` — no guessing conversions, no behaviour that depends on other gems being loaded. Accepted types are listed on `Encoder#encode` and in the README.
- The fixtures are the primary tests. Unit specs cover only what JSON fixtures cannot express (host types, options validation, Ruby-level errors).
- Ruby-shaped OOP: state lives in objects' ivars, never threaded through method arguments. Split a form into its own class only when complexity grows.
- Prefer Ruby built-ins; take a technique from the inspiration gems (Psych, CSV, json) only when it measurably beats the built-in, and copy structure only when it is Ruby-shaped — older gems mirror their C code.
- Minimal public API mirroring the spec's option names in snake_case: there is no version segment for our own breaking changes.
- No runtime dependencies. `date` (stdlib) is required; `BigDecimal` is accepted but never required.
- Public gem: YARD on every public interface.

## Versioning & Releases

- New spec version → `X.Y.0`; our fixes and additions → patch. The spec-drift workflow fails daily when a newer spec release exists.
- Release: bump `lib/toon_fu/version.rb` in a PR, merge, `git tag vX.Y.Z && git push origin vX.Y.Z`, the maintainer approves the `release` deployment. Release notes are GitHub's generated notes; there is no CHANGELOG.
- Supply chain: actions pinned by full SHA, least-privilege `permissions`, `Gemfile.lock` committed, publishing through trusted publishing only.

Design history: `thoughts/shared/notes/2026-09-24/toon-fu-ruby-toon-gem-decisions.md`.
