use aztec::macros::aztec;
use template_composition::contract_template;

/// Conflicting leaf template used to prove transitive selector collisions.
/// Its external surface intentionally uses the same selector (`leaf_value`) as
/// `transitive_diamond_leaf`, but comes from a different template id.
#[contract_template("transitive_diamond_conflict_leaf")]
#[aztec]
pub contract TransitiveDiamondConflictLeafTemplate {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn leaf_value() -> u32 {
        600
    }
}
