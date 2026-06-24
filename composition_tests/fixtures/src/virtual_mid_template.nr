use aztec::macros::aztec;
use template_composition::{compose, contract_template};

/// A virtual-function template wrapped behind a second layer.
///
/// ## Purpose
/// Verifies transitive composition and override behavior: host contracts composing only
/// this template still see virtual_template's behavior.
///
/// ## Override requirement
/// Override targets must explicitly compose the overridden template id.
#[contract_template("virtual_mid_template")]
#[compose("virtual_template")]
#[aztec]
pub contract VirtualMidTemplate {
    use aztec::macros::functions::{external, view};

    /// Distinguishes values contributed by this template.
    #[external("public")]
    #[view]
    fn virtual_mid_value() -> u16 {
        11
    }
}
