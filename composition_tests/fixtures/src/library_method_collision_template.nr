use aztec::macros::aztec;
use template_composition::contract_template;

/// Collision template that exposes `_foo_magic()` with the same signature as `foo_storage`.
///
/// Used by library-method poison packages to confirm that composing two templates with the
/// same `#[contract_library_method]` selector is rejected at compose time.
#[contract_template("library_method_collision")]
#[aztec]
pub contract LibraryMethodCollisionTemplate {
    /// Same library method name/signature as foo_storage::_foo_magic.
    #[contract_library_method]
    fn _foo_magic() -> u32 {
        77
    }
}
