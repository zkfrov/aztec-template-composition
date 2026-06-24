# aztec-template-composition

Contract template composition for Aztec, implemented **entirely out-of-tree** as a consumer of the
generic macro-extension hook added to aztec-nr on the `feat/macro-extensions` branch.

No template-specific code lives in aztec-nr. This crate plugs into `#[aztec]` purely through the
public extension API (`aztec::macros::extensions::register_extension`, the `add_injected_*`
registries, and the wrapper generators).

## Usage

Mark a reusable template and compose it into a host:

```noir
// template crate
use aztec::macros::aztec;
use template_composition::contract_template;

#[contract_template("my_template")]
#[aztec]
pub contract MyTemplate { /* externals, internals, library methods, events */ }
```

```noir
// host crate (depends on the template crate)
use aztec::macros::aztec;
use template_composition::{compose, override_template};

#[compose("my_template")]
#[override_template("my_template", "fee_bps")]   // optional; target must be #[template_virtual]
#[aztec]
pub contract MyHost { /* host functions, including the override impl */ }
```

## API ↔ in-repo equivalents

| In-repo (`AztecConfig`) | Here (attributes above `#[aztec]`) |
|---|---|
| `#[contract_template("id")]` | `#[contract_template("id")]` (from this crate) |
| `.compose("id")` | `#[compose("id")]` |
| `.override_template("id", "fn")` | `#[override_template("id", "fn")]` |
| `.override_internal_template("id", "fn")` | `#[override_internal_template("id", "fn")]` |
| `#[template_virtual]` | `#[template_virtual]` (from this crate) |

Composition attributes must be placed **above** `#[aztec]` (Noir applies attributes top-to-bottom).

## Tests

Mirrors the in-repo composition suite:

- `composition_tests/` — happy-path crates (`aztec test`): storage host, multi-compose, transitive,
  diamond dedup, override.
- `composition_failure_tests/` — compile-failure crates asserting exact error substrings.

```bash
scripts/test.sh              # compile + happy-path + failure tests
scripts/test.sh composition  # happy-path only
scripts/test.sh failure      # compile-failure only
```
