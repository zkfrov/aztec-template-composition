//! The host-side attributes (`#[compose]`, `#[override_template]`, `#[override_internal_template]`)
//! and the hook callback that performs the injection.
//!
//! Each attribute is applied to the host contract *above* `#[aztec]`. They record the host's intent
//! in per-module globals and register a single hook with aztec-nr. When `#[aztec]`
//! expands the host, the callback flattens the requested templates, validates overrides and
//! collisions, injects the surviving functions (so they appear in dispatch/interface/ABI), and
//! returns the pre-generated wrappers/ABI/events/library-methods to splice in.

use aztec::macros::pre_generation_hook::register_hook;
use aztec::macros::internals_functions_generation::{external_functions_registry, internal_functions_registry};
use aztec::utils::cmap::CHashMap;

use crate::function_signature_key;
use crate::template_registry;
use crate::validation;

comptime mut global HOST_COMPOSED_KEYS: CHashMap<Module, [Field]> = CHashMap::new();
comptime mut global HOST_OVERRIDES: CHashMap<Module, [(Field, Field)]> = CHashMap::new();
comptime mut global HOST_INTERNAL_OVERRIDES: CHashMap<Module, [(Field, Field)]> = CHashMap::new();
comptime mut global HOST_HOOK_REGISTERED: CHashMap<Module, bool> = CHashMap::new();

/// Composes the named template into the host (or into another template, enabling transitive use).
pub comptime fn compose(m: Module, template_id: CtString) -> Quoted {
    let key = template_registry::template_key(template_id);

    let updated = HOST_COMPOSED_KEYS.get(m).unwrap_or(@[]).push_back(key);
    HOST_COMPOSED_KEYS.insert(m, updated);

    // If the composing module is itself a registered template, record its composed children so a
    // host that later composes it gets them via transitive flattening.
    let self_key = template_registry::get_template_key_by_module(m);
    if self_key.is_some() {
        template_registry::register_template_composed_keys(self_key.unwrap(), updated);
    }

    ensure_hook_registered(m);
    quote {}
}

/// Replaces a composed external function with the host's own implementation of the same signature.
/// The template function must be `#[template_virtual]`.
pub comptime fn override_template(m: Module, template_id: CtString, function_name: CtString) -> Quoted {
    let template_key = template_registry::template_key(template_id);
    let function_key = template_registry::function_name_key_from_ctstring(function_name);
    template_registry::register_override_function_label(template_key, function_key, function_name);

    HOST_OVERRIDES.insert(m, HOST_OVERRIDES.get(m).unwrap_or(@[]).push_back((template_key, function_key)));
    ensure_hook_registered(m);
    quote {}
}

/// Replaces a composed internal function with the host's own implementation of the same signature.
/// The template function must be `#[template_virtual]`.
pub comptime fn override_internal_template(m: Module, template_id: CtString, function_name: CtString) -> Quoted {
    let template_key = template_registry::template_key(template_id);
    let function_key = template_registry::function_name_key_from_ctstring(function_name);
    template_registry::register_override_function_label(template_key, function_key, function_name);

    HOST_INTERNAL_OVERRIDES.insert(
        m,
        HOST_INTERNAL_OVERRIDES.get(m).unwrap_or(@[]).push_back((template_key, function_key)),
    );
    ensure_hook_registered(m);
    quote {}
}

comptime fn ensure_hook_registered(m: Module) {
    if HOST_HOOK_REGISTERED.get(m).is_none() {
        HOST_HOOK_REGISTERED.insert(m, true);
        register_hook(m, inject_composed_templates);
    }
}

comptime fn inject_composed_templates(host: Module) -> Quoted {
    let direct_keys = HOST_COMPOSED_KEYS.get(host).unwrap_or(@[]);
    let overrides = HOST_OVERRIDES.get(host).unwrap_or(@[]);
    let internal_overrides = HOST_INTERNAL_OVERRIDES.get(host).unwrap_or(@[]);

    // Validate + resolve overrides against the directly-composed templates.
    let override_signatures = validation::compute_external_override_signatures(host, direct_keys, overrides);
    let internal_override_signatures =
        validation::compute_internal_override_signatures(host, direct_keys, internal_overrides);

    let flattened_keys = validation::flatten_template_keys(direct_keys);
    validation::validate_library_method_collisions(host, flattened_keys);

    let mut host_external_signatures = CHashMap::<Field, bool>::new();
    for f in validation::own_external_functions(host) {
        host_external_signatures.insert(function_signature_key(f), true);
    }
    let mut host_internal_signatures = CHashMap::<Field, bool>::new();
    for f in validation::own_internal_functions(host) {
        host_internal_signatures.insert(function_signature_key(f), true);
    }

    let mut composed_external_signatures = CHashMap::<Field, bool>::new();
    let mut composed_internal_signatures = CHashMap::<Field, bool>::new();

    let mut injected_items = quote {};

    for template_key in flattened_keys {
        let template_module = template_registry::get_template_module(template_key).unwrap();

        // Auto-replay events from the template.
        let events = template_registry::get_template_events(template_key).unwrap_or(quote {});
        injected_items = quote { $injected_items $events };

        // External functions.
        for f in external_functions_registry::get_own_private_functions(template_module) {
            injected_items = try_inject_external(
                injected_items,
                host,
                template_key,
                f,
                override_signatures,
                &mut host_external_signatures,
                &mut composed_external_signatures,
                |h, fd| external_functions_registry::add_injected_private(h, fd),
            );
        }
        for f in external_functions_registry::get_own_public_functions(template_module) {
            injected_items = try_inject_external(
                injected_items,
                host,
                template_key,
                f,
                override_signatures,
                &mut host_external_signatures,
                &mut composed_external_signatures,
                |h, fd| external_functions_registry::add_injected_public(h, fd),
            );
        }
        for f in external_functions_registry::get_own_utility_functions(template_module) {
            injected_items = try_inject_external(
                injected_items,
                host,
                template_key,
                f,
                override_signatures,
                &mut host_external_signatures,
                &mut composed_external_signatures,
                |h, fd| external_functions_registry::add_injected_utility(h, fd),
            );
        }

        // Internal functions.
        for f in internal_functions_registry::get_own_private_functions(template_module) {
            injected_items = try_inject_internal(
                injected_items,
                host,
                template_key,
                f,
                internal_override_signatures,
                &mut host_internal_signatures,
                &mut composed_internal_signatures,
                |h, fd| internal_functions_registry::add_injected_private(h, fd),
            );
        }
        for f in internal_functions_registry::get_own_public_functions(template_module) {
            injected_items = try_inject_internal(
                injected_items,
                host,
                template_key,
                f,
                internal_override_signatures,
                &mut host_internal_signatures,
                &mut composed_internal_signatures,
                |h, fd| internal_functions_registry::add_injected_public(h, fd),
            );
        }

        // Contract-library-method forwarders.
        let clm = template_registry::get_template_contract_library_methods(template_key).unwrap_or(quote {});
        injected_items = quote { $injected_items $clm };
    }

    injected_items
}

comptime fn try_inject_external(
    acc: Quoted,
    host: Module,
    template_key: Field,
    f: FunctionDefinition,
    override_signatures: [(Field, Field)],
    host_signatures: &mut CHashMap<Field, bool>,
    composed_signatures: &mut CHashMap<Field, bool>,
    register: fn(Module, FunctionDefinition) -> (),
) -> Quoted {
    let signature_key = function_signature_key(f);
    if validation::has_override(template_key, signature_key, override_signatures) {
        acc
    } else {
        if host_signatures.get(signature_key).is_some() {
            panic(
                "compose: host function selector collision; mark template function as #[template_virtual] and declare .override_template(...).",
            );
        }
        if composed_signatures.get(signature_key).is_some() {
            panic("compose: two composed external templates expose the same selector.");
        }
        composed_signatures.insert(signature_key, true);
        register(host, f);

        let wrapper =
            template_registry::get_template_external_function_wrapper(template_key, signature_key).unwrap();
        let abi = template_registry::get_template_external_function_abi_export(template_key, signature_key).unwrap();
        quote { $acc $wrapper $abi }
    }
}

comptime fn try_inject_internal(
    acc: Quoted,
    host: Module,
    template_key: Field,
    f: FunctionDefinition,
    override_signatures: [(Field, Field)],
    host_signatures: &mut CHashMap<Field, bool>,
    composed_signatures: &mut CHashMap<Field, bool>,
    register: fn(Module, FunctionDefinition) -> (),
) -> Quoted {
    let signature_key = function_signature_key(f);
    if validation::has_override(template_key, signature_key, override_signatures) {
        acc
    } else {
        if host_signatures.get(signature_key).is_some() {
            panic(
                "compose: host function selector collision; mark template function as #[template_virtual] and declare .override_internal_template(...).",
            );
        }
        if composed_signatures.get(signature_key).is_some() {
            panic("compose: host function selector collision; two internal templates expose the same selector");
        }
        composed_signatures.insert(signature_key, true);
        register(host, f);

        let wrapper = template_registry::get_template_internal_function(template_key, signature_key).unwrap();
        quote { $acc $wrapper }
    }
}
