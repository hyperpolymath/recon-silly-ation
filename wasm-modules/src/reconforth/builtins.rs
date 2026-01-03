// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ReconForth built-in words - Standard library of native operations

use super::types::{Bundle, Error, PackSpec, Value};
use super::vm::VM;
use sha2::{Digest, Sha256};

/// Register all built-in words with the VM
pub fn register_builtins(vm: &mut VM) {
    // Stack manipulation
    vm.register_native("dup", builtin_dup);
    vm.register_native("drop", builtin_drop);
    vm.register_native("swap", builtin_swap);
    vm.register_native("over", builtin_over);
    vm.register_native("rot", builtin_rot);
    vm.register_native("nip", builtin_nip);
    vm.register_native("tuck", builtin_tuck);
    vm.register_native("depth", builtin_depth);

    // Arithmetic
    vm.register_native("+", builtin_add);
    vm.register_native("-", builtin_sub);
    vm.register_native("*", builtin_mul);
    vm.register_native("/", builtin_div);
    vm.register_native("mod", builtin_mod);
    vm.register_native("abs", builtin_abs);
    vm.register_native("negate", builtin_negate);

    // Comparison
    vm.register_native("=", builtin_eq);
    vm.register_native("<>", builtin_neq);
    vm.register_native("<", builtin_lt);
    vm.register_native(">", builtin_gt);
    vm.register_native("<=", builtin_le);
    vm.register_native(">=", builtin_ge);

    // Logic
    vm.register_native("and", builtin_and);
    vm.register_native("or", builtin_or);
    vm.register_native("not", builtin_not);
    vm.register_native("true", builtin_true);
    vm.register_native("false", builtin_false);
    vm.register_native("nil", builtin_nil);

    // Control flow
    vm.register_native("if", builtin_if);
    vm.register_native("when", builtin_when);
    vm.register_native("unless", builtin_unless);
    vm.register_native("call", builtin_call);

    // String operations
    vm.register_native("str-concat", builtin_str_concat);
    vm.register_native("str-contains?", builtin_str_contains);
    vm.register_native("str-starts?", builtin_str_starts);
    vm.register_native("str-ends?", builtin_str_ends);
    vm.register_native("str-split", builtin_str_split);
    vm.register_native("str-trim", builtin_str_trim);
    vm.register_native("str-upper", builtin_str_upper);
    vm.register_native("str-lower", builtin_str_lower);
    vm.register_native("str-len", builtin_str_len);

    // List operations
    vm.register_native("list-new", builtin_list_new);
    vm.register_native("list-push", builtin_list_push);
    vm.register_native("list-pop", builtin_list_pop);
    vm.register_native("list-get", builtin_list_get);
    vm.register_native("list-len", builtin_list_len);
    vm.register_native("each", builtin_each);
    vm.register_native("map", builtin_map);
    vm.register_native("filter", builtin_filter);
    vm.register_native("reduce", builtin_reduce);

    // Document operations
    vm.register_native("doc-hash", builtin_doc_hash);
    vm.register_native("doc-type", builtin_doc_type);
    vm.register_native("doc-path", builtin_doc_path);
    vm.register_native("doc-content", builtin_doc_content);
    vm.register_native("doc-version", builtin_doc_version);
    vm.register_native("doc-canonical?", builtin_doc_canonical);
    vm.register_native("docs-same-hash?", builtin_docs_same_hash);
    vm.register_native("docs-same-type?", builtin_docs_same_type);

    // Bundle operations
    vm.register_native("bundle-new", builtin_bundle_new);
    vm.register_native("bundle-add", builtin_bundle_add);
    vm.register_native("bundle-docs", builtin_bundle_docs);
    vm.register_native("bundle-count", builtin_bundle_count);
    vm.register_native("bundle-has-type?", builtin_bundle_has_type);
    vm.register_native("bundle-get-type", builtin_bundle_get_type);
    vm.register_native("bundle-validate", builtin_bundle_validate);

    // Pack operations
    vm.register_native("pack-new", builtin_pack_new);
    vm.register_native("pack-require", builtin_pack_require);
    vm.register_native("pack-optional", builtin_pack_optional);
    vm.register_native("pack-rule", builtin_pack_rule);
    vm.register_native("pack-ship", builtin_pack_ship);

    // Enforcement actions
    vm.register_native("error!", builtin_error);
    vm.register_native("warn!", builtin_warn);
    vm.register_native("suggest!", builtin_suggest);
    vm.register_native("require!", builtin_require);

    // Hash operations
    vm.register_native("hash-content", builtin_hash_content);

    // Debug
    vm.register_native(".s", builtin_print_stack);
    vm.register_native(".v", builtin_print_validation);
}

// ============================================================================
// Stack manipulation
// ============================================================================

fn builtin_dup(vm: &mut VM) -> Result<(), Error> {
    let val = vm.pop()?;
    vm.push(val.clone());
    vm.push(val);
    Ok(())
}

fn builtin_drop(vm: &mut VM) -> Result<(), Error> {
    vm.pop()?;
    Ok(())
}

fn builtin_swap(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    let a = vm.pop()?;
    vm.push(b);
    vm.push(a);
    Ok(())
}

fn builtin_over(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    let a = vm.pop()?;
    vm.push(a.clone());
    vm.push(b);
    vm.push(a);
    Ok(())
}

fn builtin_rot(vm: &mut VM) -> Result<(), Error> {
    let c = vm.pop()?;
    let b = vm.pop()?;
    let a = vm.pop()?;
    vm.push(b);
    vm.push(c);
    vm.push(a);
    Ok(())
}

fn builtin_nip(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    vm.pop()?; // discard a
    vm.push(b);
    Ok(())
}

fn builtin_tuck(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    let a = vm.pop()?;
    vm.push(b.clone());
    vm.push(a);
    vm.push(b);
    Ok(())
}

fn builtin_depth(vm: &mut VM) -> Result<(), Error> {
    let d = vm.depth() as i64;
    vm.push(Value::Int(d));
    Ok(())
}

// ============================================================================
// Arithmetic
// ============================================================================

fn builtin_add(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Int(a + b));
    Ok(())
}

fn builtin_sub(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Int(a - b));
    Ok(())
}

fn builtin_mul(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Int(a * b));
    Ok(())
}

fn builtin_div(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    if b == 0 {
        return Err(Error::RuntimeError("Division by zero".to_string()));
    }
    vm.push(Value::Int(a / b));
    Ok(())
}

fn builtin_mod(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    if b == 0 {
        return Err(Error::RuntimeError("Modulo by zero".to_string()));
    }
    vm.push(Value::Int(a % b));
    Ok(())
}

fn builtin_abs(vm: &mut VM) -> Result<(), Error> {
    let a = vm.pop_int()?;
    vm.push(Value::Int(a.abs()));
    Ok(())
}

fn builtin_negate(vm: &mut VM) -> Result<(), Error> {
    let a = vm.pop_int()?;
    vm.push(Value::Int(-a));
    Ok(())
}

// ============================================================================
// Comparison
// ============================================================================

fn builtin_eq(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop()?;
    let a = vm.pop()?;
    let result = match (&a, &b) {
        (Value::Int(x), Value::Int(y)) => x == y,
        (Value::Str(x), Value::Str(y)) => x == y,
        (Value::Bool(x), Value::Bool(y)) => x == y,
        (Value::Hash(x), Value::Hash(y)) => x == y,
        (Value::Nil, Value::Nil) => true,
        _ => false,
    };
    vm.push(Value::Bool(result));
    Ok(())
}

fn builtin_neq(vm: &mut VM) -> Result<(), Error> {
    builtin_eq(vm)?;
    builtin_not(vm)
}

fn builtin_lt(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Bool(a < b));
    Ok(())
}

fn builtin_gt(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Bool(a > b));
    Ok(())
}

fn builtin_le(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Bool(a <= b));
    Ok(())
}

fn builtin_ge(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_int()?;
    let a = vm.pop_int()?;
    vm.push(Value::Bool(a >= b));
    Ok(())
}

// ============================================================================
// Logic
// ============================================================================

fn builtin_and(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_bool()?;
    let a = vm.pop_bool()?;
    vm.push(Value::Bool(a && b));
    Ok(())
}

fn builtin_or(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_bool()?;
    let a = vm.pop_bool()?;
    vm.push(Value::Bool(a || b));
    Ok(())
}

fn builtin_not(vm: &mut VM) -> Result<(), Error> {
    let a = vm.pop_bool()?;
    vm.push(Value::Bool(!a));
    Ok(())
}

fn builtin_true(vm: &mut VM) -> Result<(), Error> {
    vm.push(Value::Bool(true));
    Ok(())
}

fn builtin_false(vm: &mut VM) -> Result<(), Error> {
    vm.push(Value::Bool(false));
    Ok(())
}

fn builtin_nil(vm: &mut VM) -> Result<(), Error> {
    vm.push(Value::Nil);
    Ok(())
}

// ============================================================================
// Control flow
// ============================================================================

fn builtin_if(vm: &mut VM) -> Result<(), Error> {
    let else_branch = vm.pop_quotation()?;
    let then_branch = vm.pop_quotation()?;
    let cond = vm.pop_bool()?;

    if cond {
        vm.call_quotation(&then_branch)?;
    } else {
        vm.call_quotation(&else_branch)?;
    }
    Ok(())
}

fn builtin_when(vm: &mut VM) -> Result<(), Error> {
    let body = vm.pop_quotation()?;
    let cond = vm.pop_bool()?;

    if cond {
        vm.call_quotation(&body)?;
    }
    Ok(())
}

fn builtin_unless(vm: &mut VM) -> Result<(), Error> {
    let body = vm.pop_quotation()?;
    let cond = vm.pop_bool()?;

    if !cond {
        vm.call_quotation(&body)?;
    }
    Ok(())
}

fn builtin_call(vm: &mut VM) -> Result<(), Error> {
    let quotation = vm.pop_quotation()?;
    vm.call_quotation(&quotation)
}

// ============================================================================
// String operations
// ============================================================================

fn builtin_str_concat(vm: &mut VM) -> Result<(), Error> {
    let b = vm.pop_str()?;
    let a = vm.pop_str()?;
    vm.push(Value::Str(format!("{}{}", a, b)));
    Ok(())
}

fn builtin_str_contains(vm: &mut VM) -> Result<(), Error> {
    let needle = vm.pop_str()?;
    let haystack = vm.pop_str()?;
    vm.push(Value::Bool(haystack.contains(&needle)));
    Ok(())
}

fn builtin_str_starts(vm: &mut VM) -> Result<(), Error> {
    let prefix = vm.pop_str()?;
    let s = vm.pop_str()?;
    vm.push(Value::Bool(s.starts_with(&prefix)));
    Ok(())
}

fn builtin_str_ends(vm: &mut VM) -> Result<(), Error> {
    let suffix = vm.pop_str()?;
    let s = vm.pop_str()?;
    vm.push(Value::Bool(s.ends_with(&suffix)));
    Ok(())
}

fn builtin_str_split(vm: &mut VM) -> Result<(), Error> {
    let delim = vm.pop_str()?;
    let s = vm.pop_str()?;
    let parts: Vec<Value> = s
        .split(&delim)
        .map(|p| Value::Str(p.to_string()))
        .collect();
    vm.push(Value::List(parts));
    Ok(())
}

fn builtin_str_trim(vm: &mut VM) -> Result<(), Error> {
    let s = vm.pop_str()?;
    vm.push(Value::Str(s.trim().to_string()));
    Ok(())
}

fn builtin_str_upper(vm: &mut VM) -> Result<(), Error> {
    let s = vm.pop_str()?;
    vm.push(Value::Str(s.to_uppercase()));
    Ok(())
}

fn builtin_str_lower(vm: &mut VM) -> Result<(), Error> {
    let s = vm.pop_str()?;
    vm.push(Value::Str(s.to_lowercase()));
    Ok(())
}

fn builtin_str_len(vm: &mut VM) -> Result<(), Error> {
    let s = vm.pop_str()?;
    vm.push(Value::Int(s.len() as i64));
    Ok(())
}

// ============================================================================
// List operations
// ============================================================================

fn builtin_list_new(vm: &mut VM) -> Result<(), Error> {
    vm.push(Value::List(Vec::new()));
    Ok(())
}

fn builtin_list_push(vm: &mut VM) -> Result<(), Error> {
    let item = vm.pop()?;
    let mut list = vm.pop_list()?;
    list.push(item);
    vm.push(Value::List(list));
    Ok(())
}

fn builtin_list_pop(vm: &mut VM) -> Result<(), Error> {
    let mut list = vm.pop_list()?;
    match list.pop() {
        Some(item) => {
            vm.push(Value::List(list));
            vm.push(item);
        }
        None => {
            vm.push(Value::List(list));
            vm.push(Value::Nil);
        }
    }
    Ok(())
}

fn builtin_list_get(vm: &mut VM) -> Result<(), Error> {
    let idx = vm.pop_int()? as usize;
    let list = vm.pop_list()?;
    match list.get(idx) {
        Some(item) => vm.push(item.clone()),
        None => vm.push(Value::Nil),
    }
    Ok(())
}

fn builtin_list_len(vm: &mut VM) -> Result<(), Error> {
    let list = vm.pop_list()?;
    let len = list.len() as i64;
    vm.push(Value::List(list));
    vm.push(Value::Int(len));
    Ok(())
}

fn builtin_each(vm: &mut VM) -> Result<(), Error> {
    let body = vm.pop_quotation()?;
    let list = vm.pop_list()?;

    for item in list {
        vm.push(item);
        vm.call_quotation(&body)?;
    }
    Ok(())
}

fn builtin_map(vm: &mut VM) -> Result<(), Error> {
    let body = vm.pop_quotation()?;
    let list = vm.pop_list()?;
    let mut result = Vec::new();

    for item in list {
        vm.push(item);
        vm.call_quotation(&body)?;
        result.push(vm.pop()?);
    }

    vm.push(Value::List(result));
    Ok(())
}

fn builtin_filter(vm: &mut VM) -> Result<(), Error> {
    let body = vm.pop_quotation()?;
    let list = vm.pop_list()?;
    let mut result = Vec::new();

    for item in list {
        vm.push(item.clone());
        vm.call_quotation(&body)?;
        if vm.pop_bool()? {
            result.push(item);
        }
    }

    vm.push(Value::List(result));
    Ok(())
}

fn builtin_reduce(vm: &mut VM) -> Result<(), Error> {
    let body = vm.pop_quotation()?;
    let init = vm.pop()?;
    let list = vm.pop_list()?;

    vm.push(init);
    for item in list {
        vm.push(item);
        vm.call_quotation(&body)?;
    }
    Ok(())
}

// ============================================================================
// Document operations
// ============================================================================

fn builtin_doc_hash(vm: &mut VM) -> Result<(), Error> {
    let doc = vm.pop_doc()?;
    vm.push(Value::Hash(doc.hash.clone()));
    Ok(())
}

fn builtin_doc_type(vm: &mut VM) -> Result<(), Error> {
    let doc = vm.pop_doc()?;
    vm.push(Value::Str(doc.metadata.document_type.clone()));
    Ok(())
}

fn builtin_doc_path(vm: &mut VM) -> Result<(), Error> {
    let doc = vm.pop_doc()?;
    vm.push(Value::Str(doc.metadata.path.clone()));
    Ok(())
}

fn builtin_doc_content(vm: &mut VM) -> Result<(), Error> {
    let doc = vm.pop_doc()?;
    vm.push(Value::Str(doc.content.clone()));
    Ok(())
}

fn builtin_doc_version(vm: &mut VM) -> Result<(), Error> {
    let doc = vm.pop_doc()?;
    match &doc.metadata.version {
        Some(v) => vm.push(Value::Str(v.clone())),
        None => vm.push(Value::Nil),
    }
    Ok(())
}

fn builtin_doc_canonical(vm: &mut VM) -> Result<(), Error> {
    let doc = vm.pop_doc()?;
    vm.push(Value::Bool(doc.is_canonical()));
    Ok(())
}

fn builtin_docs_same_hash(vm: &mut VM) -> Result<(), Error> {
    let doc2 = vm.pop_doc()?;
    let doc1 = vm.pop_doc()?;
    vm.push(Value::Bool(doc1.hash == doc2.hash));
    Ok(())
}

fn builtin_docs_same_type(vm: &mut VM) -> Result<(), Error> {
    let doc2 = vm.pop_doc()?;
    let doc1 = vm.pop_doc()?;
    vm.push(Value::Bool(
        doc1.metadata.document_type == doc2.metadata.document_type,
    ));
    Ok(())
}

// ============================================================================
// Bundle operations
// ============================================================================

fn builtin_bundle_new(vm: &mut VM) -> Result<(), Error> {
    vm.push(Value::Bundle(Bundle::new()));
    Ok(())
}

fn builtin_bundle_add(vm: &mut VM) -> Result<(), Error> {
    let doc = vm.pop_doc()?;
    let mut bundle = vm.pop_bundle()?;
    bundle.add(doc);
    vm.push(Value::Bundle(bundle));
    Ok(())
}

fn builtin_bundle_docs(vm: &mut VM) -> Result<(), Error> {
    let bundle = vm.pop_bundle()?;
    let docs: Vec<Value> = bundle.documents.into_iter().map(Value::Doc).collect();
    vm.push(Value::List(docs));
    Ok(())
}

fn builtin_bundle_count(vm: &mut VM) -> Result<(), Error> {
    let bundle = vm.pop_bundle()?;
    let count = bundle.count() as i64;
    vm.push(Value::Bundle(bundle));
    vm.push(Value::Int(count));
    Ok(())
}

fn builtin_bundle_has_type(vm: &mut VM) -> Result<(), Error> {
    let doc_type = vm.pop_str()?;
    let bundle = vm.pop_bundle()?;
    let has = bundle.has_type(&doc_type);
    vm.push(Value::Bundle(bundle));
    vm.push(Value::Bool(has));
    Ok(())
}

fn builtin_bundle_get_type(vm: &mut VM) -> Result<(), Error> {
    let doc_type = vm.pop_str()?;
    let bundle = vm.pop_bundle()?;
    match bundle.get_type(&doc_type).cloned() {
        Some(doc) => {
            vm.push(Value::Bundle(bundle));
            vm.push(Value::Doc(doc));
        }
        None => {
            vm.push(Value::Bundle(bundle));
            vm.push(Value::Nil);
        }
    }
    Ok(())
}

fn builtin_bundle_validate(vm: &mut VM) -> Result<(), Error> {
    let pack = vm.pop_pack()?;
    let bundle = vm.pop_bundle()?;

    vm.reset_validation();

    // Check required documents
    for req in &pack.required {
        if !bundle.has_type(req) {
            vm.report_error(format!("Missing required document: {}", req));
        }
    }

    // Execute custom rules
    for rule in &pack.rules {
        vm.push(Value::Bundle(bundle.clone()));
        if let Err(e) = vm.call_quotation(&rule.body) {
            vm.report_error(format!("Rule '{}' failed: {}", rule.name, e));
        }
        // Pop the bundle that the rule might leave on stack
        let _ = vm.pop();
    }

    let result = vm.get_validation().clone();
    vm.push(Value::Bundle(bundle));
    vm.push(Value::ValidationResult(result));
    Ok(())
}

// ============================================================================
// Pack operations
// ============================================================================

fn builtin_pack_new(vm: &mut VM) -> Result<(), Error> {
    let name = vm.pop_str()?;
    vm.push(Value::Pack(PackSpec::new(name)));
    Ok(())
}

fn builtin_pack_require(vm: &mut VM) -> Result<(), Error> {
    let doc_type = vm.pop_str()?;
    let mut pack = vm.pop_pack()?;
    pack.require(doc_type);
    vm.push(Value::Pack(pack));
    Ok(())
}

fn builtin_pack_optional(vm: &mut VM) -> Result<(), Error> {
    let doc_type = vm.pop_str()?;
    let mut pack = vm.pop_pack()?;
    pack.optional(doc_type);
    vm.push(Value::Pack(pack));
    Ok(())
}

fn builtin_pack_rule(vm: &mut VM) -> Result<(), Error> {
    let body = vm.pop_quotation()?;
    let name = vm.pop_str()?;
    let mut pack = vm.pop_pack()?;
    pack.add_rule(name, body);
    vm.push(Value::Pack(pack));
    Ok(())
}

fn builtin_pack_ship(vm: &mut VM) -> Result<(), Error> {
    // Same as bundle-validate for now
    builtin_bundle_validate(vm)
}

// ============================================================================
// Enforcement actions
// ============================================================================

fn builtin_error(vm: &mut VM) -> Result<(), Error> {
    let msg = vm.pop_str()?;
    vm.report_error(msg);
    Ok(())
}

fn builtin_warn(vm: &mut VM) -> Result<(), Error> {
    let msg = vm.pop_str()?;
    vm.report_warning(msg);
    Ok(())
}

fn builtin_suggest(vm: &mut VM) -> Result<(), Error> {
    let msg = vm.pop_str()?;
    vm.report_suggestion(msg);
    Ok(())
}

fn builtin_require(vm: &mut VM) -> Result<(), Error> {
    let msg = vm.pop_str()?;
    let cond = vm.pop_bool()?;
    if !cond {
        vm.report_error(msg);
    }
    Ok(())
}

// ============================================================================
// Hash operations
// ============================================================================

fn builtin_hash_content(vm: &mut VM) -> Result<(), Error> {
    let content = vm.pop_str()?;
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    let hash = hasher
        .finalize()
        .iter()
        .map(|b| format!("{:02x}", b))
        .collect::<String>();
    vm.push(Value::Hash(hash));
    Ok(())
}

// ============================================================================
// Debug
// ============================================================================

fn builtin_print_stack(vm: &mut VM) -> Result<(), Error> {
    eprintln!("Stack ({} items):", vm.depth());
    // Note: can't iterate stack directly, this is a debug helper
    Ok(())
}

fn builtin_print_validation(vm: &mut VM) -> Result<(), Error> {
    let v = vm.get_validation();
    eprintln!("Validation: success={}", v.success);
    for e in &v.errors {
        eprintln!("  ERROR: {}", e.message);
    }
    for w in &v.warnings {
        eprintln!("  WARN: {}", w.message);
    }
    for s in &v.suggestions {
        eprintln!("  SUGGEST: {}", s.message);
    }
    Ok(())
}
