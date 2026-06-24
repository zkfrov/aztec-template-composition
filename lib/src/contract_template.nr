//! The `#[contract_template("id")]` attribute.
//!
//! Applied to a template contract *above* `#[aztec]`. While the template crate is elaborated, it
//! pre-generates the `__aztec_nr_internals__` wrappers and ABI export structs for the template's
//! functions (using aztec-nr's public generators) and stores them in the registry, so the host can
//! later splice them in without hitting Noir's cross-crate `f.body()` limitation.

use aztec::macros::internals_functions_generation::{
    abi_export::create_fn_abi_export,
    external::{
        private::generate_private_external, public::generate_public_external, utility::generate_utility_external,
    },
    external_functions_registry,
    internal::{generate_private_internal, generate_public_internal},
    internal_functions_registry,
};
use aztec::macros::utils::is_fn_contract_library_method;
use std::meta::ctstring::AsCtString;

use crate::codegen::{generate_contract_library_method_quote, quote_event_struct};
use crate::function_signature_key;
use crate::template_registry;

pub comptime fn contract_template(m: Module, template_id: CtString) -> Quoted {
    template_registry::assert_template_id_available(template_id);
    let template_key = template_registry::template_key(template_id);

    // External wrappers + ABI exports. Own-only getters avoid touching injected functions.
    for f in external_functions_registry::get_own_private_functions(m) {
        template_registry::register_external_function(
            template_key,
            function_signature_key(f),
            generate_private_external(f),
            create_fn_abi_export(f),
            f.has_named_attribute("template_virtual"),
        );
    }
    for f in external_functions_registry::get_own_public_functions(m) {
        template_registry::register_external_function(
            template_key,
            function_signature_key(f),
            generate_public_external(f),
            create_fn_abi_export(f),
            f.has_named_attribute("template_virtual"),
        );
    }
    for f in external_functions_registry::get_own_utility_functions(m) {
        template_registry::register_external_function(
            template_key,
            function_signature_key(f),
            generate_utility_external(f),
            create_fn_abi_export(f),
            f.has_named_attribute("template_virtual"),
        );
    }

    // Internal wrappers.
    for f in internal_functions_registry::get_own_private_functions(m) {
        template_registry::register_internal_function(
            template_key,
            function_signature_key(f),
            generate_private_internal(f),
            f.has_named_attribute("template_virtual"),
        );
    }
    for f in internal_functions_registry::get_own_public_functions(m) {
        template_registry::register_internal_function(
            template_key,
            function_signature_key(f),
            generate_public_internal(f),
            f.has_named_attribute("template_virtual"),
        );
    }

    // Contract-library-method forwarders, plus bookkeeping for collision detection.
    let mut contract_library_methods = quote {};
    for f in m.functions().filter(|f| is_fn_contract_library_method(f)) {
        let generated = generate_contract_library_method_quote(f);
        contract_library_methods = quote { $contract_library_methods $generated };
        let name = f.name();
        template_registry::register_contract_library_method(
            template_key,
            function_signature_key(f),
            f"{name}".as_ctstring(),
        );
    }

    // Event structs.
    let events =
        m.structs().filter(|s| s.has_named_attribute("event")).map(|s| quote_event_struct(s)).join(quote {});

    template_registry::register_template(template_id, contract_library_methods, events, m);
    quote {}
}
