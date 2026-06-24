pub mod test;

use aztec::macros::aztec;
use template_composition::compose;

/// Host contract that composes the foo_storage template.
///
/// Composes `foo_storage` into a host that declares matching storage fields locally,
/// then exercises composed externals, internals, events, and library methods.
///
/// ## Tests
/// Storage composition, event emission, internal reuse, and library method migration.
///
/// ## Storage declaration
/// Storage fields from FooStorageTemplate must be declared here -- Noir lacks
/// TypeDefinition::add_field, so field injection from templates is not possible (L-4, L-15).
#[compose("foo_storage")]
#[aztec]
pub contract FooStorageHost {
    use aztec::{macros::{functions::{external, view}, storage::storage}, state_vars::PublicMutable};

    #[storage]
    struct Storage<Context> {
        // foo_storage template fields -- must be declared here manually (see L-4, L-15)
        foo_counter: PublicMutable<u32, Context>,
    }

    /// Uses composed internal to drive storage writes from a host-owned entrypoint.
    #[external("public")]
    fn host_set_and_get(value: u32) -> u32 {
        self.internal._foo_set(value);
        self.storage.foo_counter.read()
    }

    /// Calls the library method migrated from the template (constant, no storage).
    /// _foo_magic is a #[contract_library_method] -- free function, not an internal.
    #[view]
    #[external("public")]
    fn host_library_constant() -> u32 {
        _foo_magic()
    }
}
