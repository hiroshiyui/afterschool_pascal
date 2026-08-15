#pragma once
#include "ast.h"
#include "sema.h"

namespace ap {

/// Write the parse tree in the format `selfhost/compiler.pas` also writes, so
/// the two parsers can be compared on real input (`selfhost/difftest.sh`).
///
/// The dump carries every decision the *parser* makes — the shape of the tree,
/// the spellings it kept, and the positions it recorded — and nothing a later
/// stage fills in, because it runs before Sema. A disagreement is therefore a
/// disagreement about parsing.
void dumpAst(Program &program);

/// The same tree after Sema, plus what Sema alone knows: the activation record
/// of every block, the type of every expression, the symbol every name
/// resolved to, and the layout every record type was given. Sharing one walker
/// with `dumpAst` is deliberate — the shape is then guaranteed to be the same
/// question asked twice, once before annotation and once after.
void dumpSema(Program &program, Sema &sema);

} // namespace ap
