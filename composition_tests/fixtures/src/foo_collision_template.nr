use aztec::macros::aztec;
use template_composition::contract_template;

/// Collision template that deliberately exposes `foo_value()` with the same name as in `foo_template`.
///
/// ## Purpose
/// Used by the `composition_collision_fail` poison package to confirm that composing two
/// templates with an overlapping function name causes a compile error.
///
/// ## Collision behavior
/// Non-virtual selectors shared by two composed templates are rejected at inject time (this fixture).
/// `#[template_virtual]` functions skip inject when the host declares `.override_template(...)` for
/// each colliding template, so duplicate detection applies only to non-overridden selectors.
#[contract_template("foo_collision")]
#[aztec]
pub contract FooCollisionTemplate {
    use aztec::macros::functions::{external, view};
    use template_composition::template_virtual;

    /// Same name as foo_template::foo_value -- triggers collision when both are composed.
    #[external("public")]
    #[view]
    fn foo_value() -> u32 {
        999
    }
}
