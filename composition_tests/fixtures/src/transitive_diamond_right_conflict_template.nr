use aztec::macros::aztec;
use template_composition::{compose, contract_template};

/// Right template that composes the shared non-conflicting leaf.
/// Used with `transitive_diamond_left_conflict_template` to assert the same method
/// selector conflicts are rejected when it comes from two different templates.
#[contract_template("transitive_diamond_right_conflict_template")]
#[compose("transitive_diamond_leaf")]
#[aztec]
pub contract TransitiveDiamondRightConflictTemplate {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn right_conflict_value() -> u32 {
        800
    }
}
