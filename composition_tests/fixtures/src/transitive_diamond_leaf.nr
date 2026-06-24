use aztec::macros::aztec;
use template_composition::contract_template;

/// Shared leaf template used as a transitive dependency by both
/// `transitive_diamond_left_template` and `transitive_diamond_right_template`.
#[contract_template("transitive_diamond_leaf")]
#[aztec]
pub contract TransitiveDiamondLeafTemplate {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn leaf_value() -> u32 {
        500
    }
}
