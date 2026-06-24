use aztec::macros::aztec;
use template_composition::contract_template;

/// A second-layer template with an overriding-sensitive selector collision.
///
/// This template is an alternate virtual fee provider. It intentionally duplicates
/// `fee_bps()` so two template ids can both be overridden by the same host function.
#[contract_template("virtual_fee_override_template")]
#[aztec]
pub contract VirtualMidOverrideChainTemplate {
    use aztec::macros::functions::{external, view};
    use template_composition::template_virtual;

    #[external("public")]
    #[template_virtual]
    #[view]
    fn fee_bps() -> u16 {
        20
    }

    #[external("public")]
    #[view]
    fn virtual_mid_value() -> u16 {
        11
    }
}
