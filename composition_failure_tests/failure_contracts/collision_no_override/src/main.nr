// Poison contract: EXPECTED to fail compilation.
//
// Composing two templates that both expose non-virtual `foo_value()` triggers inject-time
// selector collision. For `#[template_virtual]` selectors, overriding each colliding template
// skips inject before duplicate detection; here both functions are non-virtual.

use aztec::macros::aztec;
use template_composition::compose;

#[compose("foo_template")]
#[compose("foo_collision")]
#[aztec]
pub contract CollisionHost {
    use aztec::macros::functions::{external, view};
    use template_composition::template_virtual;
}
