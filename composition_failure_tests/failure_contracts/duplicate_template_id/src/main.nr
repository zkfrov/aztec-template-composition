// Poison contract: EXPECTED to fail compilation.
//
// Two modules in this package register the same contract_template id.
// The second registration must be rejected before mutating the global registry.

mod template_a;
mod template_b;

use aztec::macros::aztec;

#[aztec]
pub contract DuplicateTemplateIdHost {}
