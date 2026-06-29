//! Compile-time registry of pre-generated code for contract templates.
//!
//! Populated by `#[contract_template]` while the *template* crate is elaborated (where function
//! bodies are available), and read by the compose hook while the *host* crate is elaborated.
//! Comptime globals are shared across a whole compilation, so the template crate (a dependency of
//! the host) writes here and the host reads it.

use aztec::utils::cmap::CHashMap;

comptime mut global TEMPLATE_MODULES: CHashMap<Field, Module> = CHashMap::new();
comptime mut global TEMPLATE_ID_LABELS: CHashMap<Field, CtString> = CHashMap::new();
comptime mut global TEMPLATE_CONTRACT_LIBRARY_METHODS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();
comptime mut global TEMPLATE_EVENTS_QUOTED: CHashMap<Field, Quoted> = CHashMap::new();

// Per-function pre-generated code, keyed by (template_key, function_signature_key).
comptime mut global TEMPLATE_EXTERNAL_FN_WRAPPERS: CHashMap<(Field, Field), Quoted> = CHashMap::new();
comptime mut global TEMPLATE_EXTERNAL_FN_ABI_EXPORTS: CHashMap<(Field, Field), Quoted> = CHashMap::new();
comptime mut global TEMPLATE_INTERNAL_FN_QUOTED: CHashMap<(Field, Field), Quoted> = CHashMap::new();

// Virtual markers, keyed by (template_key, function_signature_key).
comptime mut global TEMPLATE_VIRTUAL_EXTERNAL_FN_KEYS: CHashMap<(Field, Field), bool> = CHashMap::new();
comptime mut global TEMPLATE_VIRTUAL_INTERNAL_FN_KEYS: CHashMap<(Field, Field), bool> = CHashMap::new();

// Module <-> template key, and the set of template keys a template itself composes (for transitive
// flattening).
comptime mut global TEMPLATE_KEY_BY_MODULE: CHashMap<Module, Field> = CHashMap::new();
comptime mut global TEMPLATE_COMPOSED_KEYS: CHashMap<Field, [Field]> = CHashMap::new();

// Contract-library-method bookkeeping for collision detection.
comptime mut global TEMPLATE_LIBRARY_METHOD_KEYS: CHashMap<Field, [Field]> = CHashMap::new();
comptime mut global TEMPLATE_LIBRARY_METHOD_NAMES: CHashMap<(Field, Field), CtString> = CHashMap::new();

// Human-readable labels for override targets, keyed by (template_key, function_name_key), used only
// for error messages.
comptime mut global OVERRIDE_FUNCTION_LABELS: CHashMap<(Field, Field), CtString> = CHashMap::new();

pub comptime fn template_key(template_id: CtString) -> Field {
    hash_str(template_id.as_quoted_str!())
}

pub comptime fn function_name_key_from_ctstring(name: CtString) -> Field {
    hash_str(name.as_quoted_str!())
}

pub comptime fn function_name_key(name: Quoted) -> Field {
    hash_str(f"{name}".as_quoted_str!())
}

comptime fn hash_str<let N: u32>(value: str<N>) -> Field {
    let bytes = value.as_bytes();
    let mut acc: Field = bytes.len() as Field + 1;
    for i in 0..bytes.len() {
        acc = acc * 16777619 + bytes[i] as Field + 1;
    }
    acc
}

pub comptime fn assert_template_id_available(template_id: CtString) {
    if TEMPLATE_MODULES.get(template_key(template_id)).is_some() {
        let label: str<_> = template_id.as_quoted_str!();
        panic(f"contract_template: duplicate template id '{label}'");
    }
}

pub comptime fn register_template(
    template_id: CtString,
    contract_library_methods: Quoted,
    events: Quoted,
    m: Module,
) {
    let k = template_key(template_id);
    TEMPLATE_MODULES.insert(k, m);
    TEMPLATE_ID_LABELS.insert(k, template_id);
    TEMPLATE_CONTRACT_LIBRARY_METHODS_QUOTED.insert(k, contract_library_methods);
    TEMPLATE_EVENTS_QUOTED.insert(k, events);
    TEMPLATE_KEY_BY_MODULE.insert(m, k);
}

pub comptime fn register_external_function(
    template_key: Field,
    function_key: Field,
    wrapper: Quoted,
    abi_export: Quoted,
    is_virtual: bool,
) {
    TEMPLATE_EXTERNAL_FN_WRAPPERS.insert((template_key, function_key), wrapper);
    TEMPLATE_EXTERNAL_FN_ABI_EXPORTS.insert((template_key, function_key), abi_export);
    if is_virtual {
        TEMPLATE_VIRTUAL_EXTERNAL_FN_KEYS.insert((template_key, function_key), true);
    }
}

pub comptime fn register_internal_function(
    template_key: Field,
    function_key: Field,
    wrapper: Quoted,
    is_virtual: bool,
) {
    TEMPLATE_INTERNAL_FN_QUOTED.insert((template_key, function_key), wrapper);
    if is_virtual {
        TEMPLATE_VIRTUAL_INTERNAL_FN_KEYS.insert((template_key, function_key), true);
    }
}

pub comptime fn register_contract_library_method(
    template_key: Field,
    method_signature_key: Field,
    method_name: CtString,
) {
    TEMPLATE_LIBRARY_METHOD_NAMES.insert((template_key, method_signature_key), method_name);
    let existing = TEMPLATE_LIBRARY_METHOD_KEYS.get(template_key);
    if existing.is_some() {
        TEMPLATE_LIBRARY_METHOD_KEYS.insert(template_key, existing.unwrap().push_back(method_signature_key));
    } else {
        TEMPLATE_LIBRARY_METHOD_KEYS.insert(template_key, @[method_signature_key]);
    }
}

pub comptime fn register_template_composed_keys(template_key: Field, composed_keys: [Field]) {
    TEMPLATE_COMPOSED_KEYS.insert(template_key, composed_keys);
}

pub comptime fn register_override_function_label(template_key: Field, function_key: Field, function_name: CtString) {
    OVERRIDE_FUNCTION_LABELS.insert((template_key, function_key), function_name);
}

pub comptime fn get_template_module(template_key: Field) -> Option<Module> {
    TEMPLATE_MODULES.get(template_key)
}

pub comptime fn get_template_id_label(template_key: Field) -> Option<CtString> {
    TEMPLATE_ID_LABELS.get(template_key)
}

pub comptime fn get_template_key_by_module(m: Module) -> Option<Field> {
    TEMPLATE_KEY_BY_MODULE.get(m)
}

pub comptime fn get_template_composed_keys(template_key: Field) -> Option<[Field]> {
    TEMPLATE_COMPOSED_KEYS.get(template_key)
}

pub comptime fn get_template_contract_library_methods(template_key: Field) -> Option<Quoted> {
    TEMPLATE_CONTRACT_LIBRARY_METHODS_QUOTED.get(template_key)
}

pub comptime fn get_template_events(template_key: Field) -> Option<Quoted> {
    TEMPLATE_EVENTS_QUOTED.get(template_key)
}

pub comptime fn get_template_external_function_wrapper(template_key: Field, function_key: Field) -> Option<Quoted> {
    TEMPLATE_EXTERNAL_FN_WRAPPERS.get((template_key, function_key))
}

pub comptime fn get_template_external_function_abi_export(template_key: Field, function_key: Field) -> Option<Quoted> {
    TEMPLATE_EXTERNAL_FN_ABI_EXPORTS.get((template_key, function_key))
}

pub comptime fn get_template_internal_function(template_key: Field, function_key: Field) -> Option<Quoted> {
    TEMPLATE_INTERNAL_FN_QUOTED.get((template_key, function_key))
}

pub comptime fn get_template_library_method_keys(template_key: Field) -> Option<[Field]> {
    TEMPLATE_LIBRARY_METHOD_KEYS.get(template_key)
}

pub comptime fn get_template_library_method_name(template_key: Field, method_signature_key: Field) -> Option<CtString> {
    TEMPLATE_LIBRARY_METHOD_NAMES.get((template_key, method_signature_key))
}

pub comptime fn get_override_function_label(template_key: Field, function_key: Field) -> Option<CtString> {
    OVERRIDE_FUNCTION_LABELS.get((template_key, function_key))
}

pub comptime fn is_template_external_function_virtual(template_key: Field, function_key: Field) -> bool {
    TEMPLATE_VIRTUAL_EXTERNAL_FN_KEYS.get((template_key, function_key)).is_some()
}

pub comptime fn is_template_internal_function_virtual(template_key: Field, function_key: Field) -> bool {
    TEMPLATE_VIRTUAL_INTERNAL_FN_KEYS.get((template_key, function_key)).is_some()
}
