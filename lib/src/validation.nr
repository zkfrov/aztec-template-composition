//! Compose-time validation and transitive flattening.
//!
//! Ported from the in-repo composition machinery, but driven by per-host data recorded by the
//! `#[compose]` / `#[override_template]` attributes instead of `AztecConfig`.

use aztec::macros::internals_functions_generation::{external_functions_registry, internal_functions_registry};
use aztec::utils::cmap::CHashMap;

use crate::function_signature_key;
use crate::template_registry;

pub(crate) comptime fn own_external_functions(m: Module) -> [FunctionDefinition] {
    external_functions_registry::get_own_private_functions(m)
        .append(external_functions_registry::get_own_public_functions(m))
        .append(external_functions_registry::get_own_utility_functions(m))
}

pub(crate) comptime fn own_internal_functions(m: Module) -> [FunctionDefinition] {
    internal_functions_registry::get_own_private_functions(m).append(
        internal_functions_registry::get_own_public_functions(m),
    )
}

comptime fn contains_field(values: [Field], value: Field) -> bool {
    let mut found = false;
    for existing in values {
        if existing == value {
            found = true;
        }
    }
    found
}

pub(crate) comptime fn has_override(
    template_key: Field,
    signature_key: Field,
    override_signatures: [(Field, Field)],
) -> bool {
    let mut matched = false;
    for override_signature in override_signatures {
        let (override_template_key, override_sig_key) = override_signature;
        if (override_template_key == template_key) & (override_sig_key == signature_key) {
            matched = true;
            break;
        }
    }
    matched
}

comptime fn is_template_key_composed(template_keys: [Field], template_key: Field) -> bool {
    let mut found = false;
    for configured in template_keys {
        if configured == template_key {
            found = true;
            break;
        }
    }
    found
}

/// Returns all template keys reachable from `template_keys` (transitive), first-seen order, deduped.
pub(crate) comptime fn flatten_template_keys(template_keys: [Field]) -> [Field] {
    let mut pending = template_keys;
    let mut processed = @[];

    let mut index = 0;
    while index < pending.len() {
        let template_key = pending[index];
        assert(
            template_registry::get_template_module(template_key).is_some(),
            "compose: no contract template registered for one of the requested template ids",
        );

        if !contains_field(processed, template_key) {
            processed = processed.push_back(template_key);

            let child_keys = template_registry::get_template_composed_keys(template_key).unwrap_or(@[]);
            for child_key in child_keys {
                if !contains_field(processed, child_key) & !contains_field(pending, child_key) {
                    pending = pending.push_back(child_key);
                }
            }
        }

        index += 1;
    }

    processed
}

/// Validates external override declarations and resolves them to `(template_key, signature_key)`.
pub(crate) comptime fn compute_external_override_signatures(
    host: Module,
    direct_keys: [Field],
    overrides: [(Field, Field)],
) -> [(Field, Field)] {
    let mut host_signature_map = CHashMap::<Field, bool>::new();
    for f in own_external_functions(host) {
        host_signature_map.insert(function_signature_key(f), true);
    }

    let mut seen_overrides = CHashMap::<(Field, Field), bool>::new();
    let mut resolved_overrides = @[];

    for override_decl in overrides {
        let (template_key, target_fn_key) = override_decl;
        let template_id = template_registry::get_template_id_label(template_key);
        let tmpl_label: str<_> = if template_id.is_some() {
            template_id.unwrap().as_quoted_str!()
        } else {
            f"{template_key}".as_quoted_str!()
        };
        let function_name = template_registry::get_override_function_label(template_key, target_fn_key);
        let fn_label: str<_> = if function_name.is_some() {
            function_name.unwrap().as_quoted_str!()
        } else {
            f"{target_fn_key}".as_quoted_str!()
        };

        if !is_template_key_composed(direct_keys, template_key) {
            panic(f"compose: template '{tmpl_label}' not composed; call .compose(...) first.");
        }

        let template_module_opt = template_registry::get_template_module(template_key);
        assert(template_module_opt.is_some(), f"compose: no template registered for '{tmpl_label}'");
        let template_module = template_module_opt.unwrap();

        let mut matched_template_function: Option<FunctionDefinition> = Option::none();
        for template_function in own_external_functions(template_module) {
            if target_fn_key == template_registry::function_name_key(template_function.name()) {
                if matched_template_function.is_some() {
                    panic(f"compose: override '{fn_label}' in '{tmpl_label}' ambiguous; unique names required.");
                }
                matched_template_function = Option::some(template_function);
            }
        }

        if matched_template_function.is_none() {
            panic(f"compose: override target '{fn_label}' not found in template '{tmpl_label}'");
        }

        let override_signature = function_signature_key(matched_template_function.unwrap());
        let override_identity = (template_key, override_signature);

        if seen_overrides.get(override_identity).is_some() {
            panic(f"compose: duplicate override for '{fn_label}' on template '{tmpl_label}'");
        }

        if !template_registry::is_template_external_function_virtual(template_key, override_signature) {
            panic(f"compose: cannot override '{fn_label}' on '{tmpl_label}'; mark with #[template_virtual]");
        }

        if !host_signature_map.get(override_signature).is_some() {
            panic(f"compose: override '{fn_label}' on '{tmpl_label}' requires matching host signature");
        }

        seen_overrides.insert(override_identity, true);
        resolved_overrides = resolved_overrides.push_back(override_identity);
    }

    resolved_overrides
}

/// Validates internal override declarations and resolves them to `(template_key, signature_key)`.
pub(crate) comptime fn compute_internal_override_signatures(
    host: Module,
    direct_keys: [Field],
    overrides: [(Field, Field)],
) -> [(Field, Field)] {
    let mut host_signature_map = CHashMap::<Field, bool>::new();
    for f in own_internal_functions(host) {
        host_signature_map.insert(function_signature_key(f), true);
    }

    let mut seen_overrides = CHashMap::<(Field, Field), bool>::new();
    let mut resolved_overrides = @[];

    for override_decl in overrides {
        let (template_key, target_fn_key) = override_decl;
        let template_id = template_registry::get_template_id_label(template_key);
        let tmpl_label: str<_> = if template_id.is_some() {
            template_id.unwrap().as_quoted_str!()
        } else {
            f"{template_key}".as_quoted_str!()
        };
        let function_name = template_registry::get_override_function_label(template_key, target_fn_key);
        let fn_label: str<_> = if function_name.is_some() {
            function_name.unwrap().as_quoted_str!()
        } else {
            f"{target_fn_key}".as_quoted_str!()
        };

        if !is_template_key_composed(direct_keys, template_key) {
            panic(f"compose: template '{tmpl_label}' not composed; compose it before internal override.");
        }

        let template_module_opt = template_registry::get_template_module(template_key);
        assert(
            template_module_opt.is_some(),
            f"compose: no template registered for internal override target '{tmpl_label}'",
        );
        let template_module = template_module_opt.unwrap();

        let mut matched_template_function: Option<FunctionDefinition> = Option::none();
        for template_function in own_internal_functions(template_module) {
            if target_fn_key == template_registry::function_name_key(template_function.name()) {
                if matched_template_function.is_some() {
                    panic(f"compose: internal override '{fn_label}' in '{tmpl_label}' ambiguous; unique names required.");
                }
                matched_template_function = Option::some(template_function);
            }
        }

        if matched_template_function.is_none() {
            panic(f"compose: internal override target '{fn_label}' not found in template '{tmpl_label}'");
        }

        let override_signature = function_signature_key(matched_template_function.unwrap());
        let override_identity = (template_key, override_signature);

        if seen_overrides.get(override_identity).is_some() {
            panic(f"compose: duplicate internal override for '{fn_label}' on template '{tmpl_label}'");
        }

        if !template_registry::is_template_internal_function_virtual(template_key, override_signature) {
            panic(f"compose: cannot override internal '{fn_label}' on '{tmpl_label}'; mark with #[template_virtual]");
        }

        if !host_signature_map.get(override_signature).is_some() {
            panic(f"compose: internal override '{fn_label}' on '{tmpl_label}' requires matching host signature");
        }

        seen_overrides.insert(override_identity, true);
        resolved_overrides = resolved_overrides.push_back(override_identity);
    }

    resolved_overrides
}

/// Rejects contract-library-method selector collisions between host and templates, and across templates.
pub(crate) comptime fn validate_library_method_collisions(host: Module, flattened_keys: [Field]) {
    let mut host_library_method_signatures = CHashMap::<Field, bool>::new();
    for f in host.functions().filter(|f| aztec::macros::utils::is_fn_contract_library_method(f)) {
        host_library_method_signatures.insert(function_signature_key(f), true);
    }

    let mut composed_library_method_owners = CHashMap::<Field, Field>::new();

    for template_key in flattened_keys {
        let template_id = template_registry::get_template_id_label(template_key);
        let tmpl_label: str<_> = if template_id.is_some() {
            template_id.unwrap().as_quoted_str!()
        } else {
            f"{template_key}".as_quoted_str!()
        };

        let library_method_keys = template_registry::get_template_library_method_keys(template_key).unwrap_or(@[]);

        for method_signature_key in library_method_keys {
            let method_name = template_registry::get_template_library_method_name(template_key, method_signature_key);
            let method_label: str<_> = if method_name.is_some() {
                method_name.unwrap().as_quoted_str!()
            } else {
                f"{method_signature_key}".as_quoted_str!()
            };

            if host_library_method_signatures.get(method_signature_key).is_some() {
                panic(f"compose: template '{tmpl_label}' library method '{method_label}' collides with host");
            }

            if composed_library_method_owners.get(method_signature_key).is_some() {
                let first_template_key = composed_library_method_owners.get(method_signature_key).unwrap();
                let first_template_id = template_registry::get_template_id_label(first_template_key);
                let first_tmpl_label: str<_> = if first_template_id.is_some() {
                    first_template_id.unwrap().as_quoted_str!()
                } else {
                    f"{first_template_key}".as_quoted_str!()
                };
                panic(f"compose: library method '{method_label}' duplicated in '{first_tmpl_label}', '{tmpl_label}'");
            }
            composed_library_method_owners.insert(method_signature_key, template_key);
        }
    }
}
