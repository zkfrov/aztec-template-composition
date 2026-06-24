pub mod test;

use aztec::macros::aztec;
use template_composition::compose;

#[compose("transitive_diamond_left_template")]
#[compose("transitive_diamond_right_template")]
#[aztec]
pub contract TransitiveDiamondSharedLeafHost {}
