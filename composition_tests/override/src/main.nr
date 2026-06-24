use aztec::macros::aztec;
use template_composition::{compose, override_template};

pub mod test;

#[compose("virtual_template")]
#[override_template("virtual_template", "fee_bps")]
#[aztec]
pub contract VirtualOverrideHost {
    use aztec::macros::functions::{external, view};

    /// Host-specific fee implementation replaces template's fee_bps().
    #[external("public")]
    #[view]
    fn fee_bps() -> u16 {
        5
    }
}
