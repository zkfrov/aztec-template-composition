//! Helpers that re-emit a template's contract-library-methods and event structs as host-local items.
//!
//! These are generated while the template crate is elaborated (so `f.body()`/typed exprs resolve)
//! and stored as `Quoted` in the registry for later splicing into the host.

/// Re-emits a `#[contract_library_method]` as a thin forwarder that calls the original function.
///
/// The host needs a local copy of the method to call it; this forwarder delegates to the template's
/// implementation via its typed-expr reference.
pub comptime fn generate_contract_library_method_quote(f: FunctionDefinition) -> Quoted {
    let name = f.name();
    let visibility = f.visibility();
    let params = f.parameters();
    let parameters = params
        .map(|(param_name, typ): (Quoted, Type)| quote { $param_name: $typ })
        .join(quote {,});
    let arguments = params.map(|(param_name, _): (Quoted, Type)| param_name).join(quote {,});
    let return_type = f.return_type();
    let return_clause = if return_type.is_unit() {
        quote {}
    } else {
        quote { -> $return_type }
    };
    let unconstrained_kw = if f.is_unconstrained() {
        quote { unconstrained }
    } else {
        quote {}
    };
    let function_ref = f.as_typed_expr();

    quote {
        #[contract_library_method]
        $visibility $unconstrained_kw fn $name($parameters)$return_clause {
            $function_ref($arguments)
        }
    }
}

/// Re-emits an `#[event]` struct as a host-local `#[event]` struct with the same fields.
pub comptime fn quote_event_struct(event_struct: TypeDefinition) -> Quoted {
    let struct_name = event_struct.name();
    let fields = event_struct
        .fields_as_written()
        .map(|field| {
            let (name, typ, _) = field;
            quote { $name: $typ }
        })
        .join(quote {,});

    quote {
        #[aztec::macros::events::event]
        struct $struct_name {
            $fields
        }
    }
}
