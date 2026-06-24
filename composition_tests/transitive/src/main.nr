pub mod test;

use aztec::macros::aztec;
use template_composition::compose;

#[compose("mid_template")]
#[aztec]
pub contract TransitiveComposeHost {}
