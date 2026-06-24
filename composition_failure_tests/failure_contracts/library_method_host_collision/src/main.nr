// Poison contract: EXPECTED to fail compilation.
//
// Host defines `_foo_magic()` and also composes `foo_storage`, which migrates the same
// library method from the template. Compose-time dedup should reject the duplicate.

use aztec::macros::aztec;
use template_composition::compose;

#[compose("foo_storage")]
#[aztec]
pub contract LibraryMethodHostCollisionHost {
    #[contract_library_method]
    fn _foo_magic() -> u32 {
        99
    }
}
