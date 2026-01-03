// SPDX-License-Identifier: AGPL-3.0-or-later
//
// ReconForth - Stack-based DSL for document reconciliation
// This module provides the interpreter and VM for ReconForth programs.

mod lexer;
mod types;
mod vm;
mod builtins;

pub use lexer::Lexer;
pub use types::{Value, Error, Document, DocumentMetadata, Bundle, PackSpec, Rule, Token, ValidationResult};
pub use vm::VM;
pub use builtins::register_builtins;
