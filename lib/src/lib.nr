//! Contract template composition for Aztec, built as a consumer of the aztec-nr macro extension
//! hook (`aztec::macros::extensions`).
//!
//! This crate provides the `#[contract_template]`, `#[compose]` (and override) attributes that let
//! a host contract pull in functions from a separately-compiled template contract, *without any
//! template-specific code living in aztec-nr*. It works purely through the public extension API:
//! `register_extension`, the `add_injected_*` registries, and the wrapper generators.

pub mod template_registry;
pub mod codegen;
pub mod validation;
pub mod contract_template;
pub mod compose;

pub use compose::{compose, override_internal_template, override_template};
pub use contract_template::contract_template;

/// Stable key for a function within a template, derived from its name + parameter types.
pub comptime fn function_signature_key(f: FunctionDefinition) -> Field {
    aztec::macros::utils::compute_fn_selector(f.name(), f.parameters())
}

/// Marks a composed function as overridable by a host. This is a marker attribute only: it is
/// detected via `has_named_attribute("template_virtual")` during composition. Applying it has no
/// effect on the function itself.
pub comptime fn template_virtual(_f: FunctionDefinition) {}
