#pragma once
#include "ast.h"

namespace ap {

/// Write the parse tree in the format `selfhost/parser.pas` also writes, so
/// the two parsers can be compared on real input (`selfhost/difftest.sh`).
///
/// The dump carries every decision the *parser* makes — the shape of the tree,
/// the spellings it kept, and the positions it recorded — and nothing a later
/// stage fills in, because it runs before Sema. A disagreement is therefore a
/// disagreement about parsing.
void dumpAst(Program &program);

} // namespace ap
