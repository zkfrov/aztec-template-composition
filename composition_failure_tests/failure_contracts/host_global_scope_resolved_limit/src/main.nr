mod raw_global_template;

use aztec::macros::aztec;
use template_composition::compose;

// Host-level symbol resolution for composed template bodies should fail here.
// The composed template references HOST_MAGIC, but declaring it in the template
// module does not make it available through composition in the host context.
#[compose("raw_global_probe")]
#[aztec]
pub contract HostGlobalProbe {}
