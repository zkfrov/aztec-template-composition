pub mod test;

use aztec::macros::aztec;
use template_composition::compose;

#[compose("foo_template")]
#[compose("bar_template")]
#[aztec]
pub contract MultiComposeHost {
    use aztec::macros::functions::{external, internal, view};

    /// Uses composed internal helpers from both templates.
    #[external("public")]
    #[view]
    fn combined_internal_markers() -> u32 {
        self.internal._foo_marker() + self.internal._bar_marker()
    }
}
