use aztec::macros::aztec;
use template_composition::contract_template;

/// Template for virtual override tests.
///
/// ## Virtual override target
/// Defines `fee_bps()` with `#[template_virtual]` so host contracts can replace its
/// implementation via `.override_template(...)`.
///
/// ## Non-virtual composed external
/// `template_fee_label()` is a non-virtual composed external for override happy-path
/// and collision tests.
#[contract_template("virtual_template")]
#[aztec]
pub contract VirtualTemplate {
    use aztec::macros::functions::{external, view};
    use template_composition::template_virtual;

    /// Default fee basis points, can be overridden by host.
    #[external("public")]
    #[template_virtual]
    #[view]
    fn fee_bps() -> u16 {
        30
    }

    /// Non-virtual template function that should always come from this template.
    #[external("public")]
    #[view]
    fn template_fee_label() -> u16 {
        77
    }
}
