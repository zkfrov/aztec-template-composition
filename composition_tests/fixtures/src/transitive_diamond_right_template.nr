use aztec::macros::aztec;
use template_composition::{compose, contract_template};

/// Right-branch template used to validate transitive duplicate-leaf behavior.
/// It imports the same leaf template as `transitive_diamond_left_template`.
#[contract_template("transitive_diamond_right_template")]
#[compose("transitive_diamond_leaf")]
#[aztec]
pub contract TransitiveDiamondRightTemplate {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn right_value() -> u32 {
        200
    }
}
