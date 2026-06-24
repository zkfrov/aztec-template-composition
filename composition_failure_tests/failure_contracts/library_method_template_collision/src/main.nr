// Poison contract: EXPECTED to fail compilation.
//
// `foo_storage` and `library_method_collision` both define `_foo_magic()`.
// Compose-time library-method dedup should reject before quotes are merged.

use aztec::macros::aztec;
use template_composition::compose;

#[compose("foo_storage")]
#[compose("library_method_collision")]
#[aztec]
pub contract LibraryMethodTemplateCollisionHost {}
