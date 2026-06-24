// Poison contract: EXPECTED to fail compilation.
//
// Hypothesis: two composed templates provide `fee_bps()` (`virtual_fee_override_template`
// and `virtual_template`), and the host overrides only one target.
// A selector collision remains because `virtual_fee_override_template::fee_bps` is not overridden.

use aztec::macros::aztec;
use template_composition::{compose, override_template};

#[compose("virtual_fee_override_template")]
#[compose("virtual_template")]
#[override_template("virtual_template", "fee_bps")]
#[aztec]
pub contract OverrideTransitivePartialOverrideHost {
    use aztec::macros::functions::{external, view};

    #[external("public")]
    #[view]
    fn fee_bps() -> u16 {
        8
    }
}
