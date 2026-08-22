// Afterschool Pascal — the reference front end's driver.
//
// This is `pascalc-s0`, and it is **not a compiler**: lexer, parser and Sema,
// no code generator and no LLVM (ADR-0108). The compiler this project produces
// is `pascalc`, built from `selfhost/compiler.pas` by the seed (ADR-0085). This
// binary exists so `selfhost/difftest.sh` has a second implementation of the
// front end to compare the three `--dump` sections against — the only thing
// here that can disagree with the compiler without being asked a question
// someone here composed.
//
// So the only options it has are the ones a front end can honour:
//
//   pascalc-s0 --std=extended hello.pas  ISO/IEC 10206:1991 rather than
//                                     ISO 7185. The two are not nested
//                                     (ADR-0033), so this selects the
//                                     *language* and not a set of extensions.
//   pascalc-s0 --dump-tokens hello.pas  the token stream, for difftest.sh
//   pascalc-s0 --dump-ast hello.pas     the parse tree, before Sema
//   pascalc-s0 --dump-sema hello.pas    the same tree, annotated by Sema
//   pascalc-s0 --dump-all hello.pas     all three sections in one run — this
//                                     is the form selfhost/difftest.sh
//                                     compares the Pascal compiler against
//   pascalc-s0 --version            write the version and stop
//   pascalc-s0 -h, --help           write the option list and stop
//
// It used to accept `-o`, `-S`, `-c`, `-O0..-O3`, `--keep-temps` and
// `--import` as well, from when this *was* the compiler. Every one of them set
// a field nothing read: `pascalc-s0 -o out.txt -S -c hello.pas` exited 0,
// wrote no out.txt and dumped to stdout. They are refused now rather than
// deleted from the parser, because `tools/pascalcc` states the rule they broke
// — "a driver that silently ignored an option would make a harness look like
// it had tested something it had not" — and a refusal says which option and
// why, where an "unknown option" would only say it is gone.
//
// `usage()` below is the authoritative list; keep the two in step.

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>


#include "astdump.h"
#include "diag.h"
#include "lexer.h"
#include "parser.h"
#include "sema.h"

namespace {

struct Options {
  std::string input;
  bool dumpTokens = false;
  bool dumpAst = false;
  bool dumpSema = false;
  /// All three at once, with section headers. This is what
  /// `selfhost/difftest.sh` compares, because the Pascal side is one program
  /// that runs all three stages — ISO 7185 has no include mechanism, so there
  /// is one source file and therefore one binary to ask.
  bool dumpAll = false;
  /// Which standard to accept. ISO 7185 is the default because the corpus,
  /// the proofs and the stage-1 compiler are all written in it, and because
  /// ISO/IEC 10206:1991 reserves words a valid ISO 7185 program may use as
  /// identifiers (ADR-0033).
  // ISO/IEC 10206:1991 is the default, as it is in the Pascal compiler
  // (ADR-0165). difftest passes --std= explicitly on every file, so this
  // default is never what it compares — but the two front ends disagreeing
  // about their own default would be a difference nothing checks.
  ap::Std lang = ap::Std::Extended;
};

/// Diagnostics into the same stream as the dump, and before it. The Pascal
/// side reports as it goes and cannot buffer a tree it never built, so one
/// stream carrying errors first is what the two can be compared on.
/// Each diagnostic is shown once, in the section whose stage produced it —
/// which is how the Pascal side behaves, because it reports as it goes and has
/// nothing to reprint. Returns the new watermark.
size_t dumpDiagnostics(const ap::Diagnostics &diags, size_t from) {
  const std::vector<ap::Diagnostic> &all = diags.all();
  for (size_t i = from; i < all.size(); ++i)
    std::printf("%d %d error %s\n", all[i].line, all[i].col,
                all[i].message.c_str());
  return all.size();
}

/// Write the token stream in the format `selfhost/lexer.pas` also writes, so
/// the two lexers can be compared on real input. The format carries every
/// decision a lexer makes — the kind, the position, and the spelling or value
/// — and nothing else, so a disagreement is a disagreement about lexing.
///
/// A real literal prints as its *source text* rather than its converted value.
/// Comparing converted doubles would be comparing two languages' float
/// formatting, which is not what this is testing.
void dumpTokens(const std::vector<ap::Token> &tokens) {
  // Tokens only: this stage's diagnostics were printed by the caller, through
  // `dumpDiagnostics`, which is where the reason they share stdout is written.
  for (const ap::Token &t : tokens) {
    std::printf("%d %d ", t.line, t.col);
    switch (t.kind) {
    case ap::Tok::Eof:     std::printf("eof\n"); break;
    case ap::Tok::Ident:   std::printf("ident %s\n", t.text.c_str()); break;
    case ap::Tok::IntLit:
      // A literal too large for the integer type has already been reported,
      // and the value left behind is an accident of a 64-bit conversion the
      // Pascal lexer cannot have — it detects the overflow while accumulating,
      // because this compiler traps rather than wrapping. Neither accident is
      // worth comparing, so both sides print the same placeholder.
      if (t.intVal > ap::kMaxInt)
        std::printf("int ?\n");
      else
        std::printf("int %lld\n", t.intVal);
      break;
    case ap::Tok::RealLit: std::printf("real %s\n", t.text.c_str()); break;
    case ap::Tok::StrLit:  std::printf("str [%s]\n", t.text.c_str()); break;
    default: {
      // tokenName spells a reserved word as 'begin' and an operator as ':=';
      // the quotes come off here, and the category says which it was.
      std::string n = ap::tokenName(t.kind);
      if (n.size() >= 2 && n.front() == '\'' && n.back() == '\'')
        n = n.substr(1, n.size() - 2);
      bool word = !n.empty() && n[0] >= 'a' && n[0] <= 'z';
      std::printf("%s %s\n", word ? "kw" : "op", n.c_str());
      break;
    }
    }
  }
}

void usage() {
  std::fprintf(stderr,
               "Afterschool Pascal -- the reference front end\n"
               "usage: pascalc-s0 [options] file.pas\n"
               "\n"
               "It lexes, parses and analyses; it generates no code, so it\n"
               "writes only a dump and its diagnostics (ADR-0108).\n"
               "\n"
               "  --dump-tokens write the token stream and stop\n"
               "  --dump-ast    write the parse tree and stop\n"
               "  --dump-sema   write the tree Sema annotated and stop\n"
               "  --dump-all    write all three dumps and stop\n"
               "  --std=<name>  extended (default) or iso7185\n"
               "  --version     write the version and stop\n"
               "  -h, --help    write this list and stop\n");
}

bool parseArgs(int argc, char **argv, Options &opt) {
  for (int i = 1; i < argc; ++i) {
    std::string a = argv[i];
    // The options this binary cannot honour, named one by one so the message
    // says why rather than "unknown option". Each of them used to be accepted
    // and ignored.
    if (a == "-o" || a == "--emit-llvm" || a == "-S" || a == "-c" ||
        a == "--keep-temps" ||
        (a.size() == 3 && a.rfind("-O", 0) == 0 && a[2] >= '0' &&
         a[2] <= '3')) {
      std::fprintf(stderr,
                   "pascalc-s0: '%s' asks for output this binary does not "
                   "produce; it is a front end and generates no code "
                   "(ADR-0108). Use `pascalc` -- or tools/pascalcc, which "
                   "links.\n",
                   a.c_str());
      return false;
    } else if (a == "--import") {
      // §6.13's components are the one refusal here that is a *gap* rather
      // than a category error: a front end could read a translated component
      // for the interfaces its module-headings export, and this one had the
      // routine to do it and never called it. Refused rather than ignored so
      // that a harness which starts passing --import fails instead of
      // comparing dumps built without the imports. doc/sop.md §7 carries it.
      std::fprintf(stderr,
                   "pascalc-s0: '--import' is not implemented in the reference "
                   "front end, so the interfaces a component exports would be "
                   "missing rather than merely unused\n");
      return false;
    } else if (a == "--dump-tokens") {
      opt.dumpTokens = true;
    } else if (a == "--dump-ast") {
      opt.dumpAst = true;
    } else if (a == "--dump-sema") {
      opt.dumpSema = true;
    } else if (a == "--dump-all") {
      opt.dumpTokens = opt.dumpAst = opt.dumpSema = true;
      opt.dumpAll = true;
    } else if (a.rfind("--std=", 0) == 0) {
      std::string name = a.substr(6);
      if (name == "iso7185") {
        opt.lang = ap::Std::Iso7185;
      } else if (name == "extended") {
        opt.lang = ap::Std::Extended;
      } else {
        std::fprintf(stderr,
                     "pascalc-s0: unknown standard '%s'; "
                     "expected iso7185 or extended\n",
                     name.c_str());
        return false;
      }
    } else if (a == "--version") {
      // A compiler that cannot report its own version makes every bug report
      // worse. The number is the one `project()` carries, so there is a single
      // place it is written down.
      std::printf("pascalc-s0 (Afterschool Pascal) %s\n", APASCAL_VERSION);
      std::exit(0);
    } else if (a == "-h" || a == "--help") {
      usage();
      std::exit(0);
    } else if (!a.empty() && a[0] == '-') {
      std::fprintf(stderr, "pascalc-s0: unknown option '%s'\n", a.c_str());
      return false;
    } else if (opt.input.empty()) {
      opt.input = a;
    } else {
      std::fprintf(stderr, "pascalc-s0: more than one input file given\n");
      return false;
    }
  }
  if (opt.input.empty()) {
    usage();
    return false;
  }
  return true;
}

} // namespace

int main(int argc, char **argv) {
  Options opt;
  if (!parseArgs(argc, argv, opt))
    return 1;

  std::ifstream in(opt.input, std::ios::binary);
  if (!in) {
    std::fprintf(stderr, "pascalc-s0: cannot open %s\n", opt.input.c_str());
    return 1;
  }
  std::stringstream buffer;
  buffer << in.rdbuf();

  ap::Diagnostics diags(opt.input);
  ap::Lexer lexer(buffer.str(), diags, opt.lang);
  std::vector<ap::Token> tokens = lexer.tokenize();
  // The dumps `selfhost/compiler.pas` is compared against. Each section prints
  // the diagnostics known at that point and then its own output, and the
  // output only when there were none — the Pascal side has no exception to
  // unwind with and builds nothing after it gives up, so "diagnostics, or a
  // result, never both" is a rule both can follow. Always exit 0: what is
  // compared is the text, so a non-zero status here means the compiler failed.
  if (opt.dumpTokens || opt.dumpAst || opt.dumpSema) {
    if (opt.dumpAll)
      std::printf("=== tokens\n");
    size_t shown = 0;
    if (opt.dumpTokens) {
      shown = dumpDiagnostics(diags, shown);
      dumpTokens(tokens);
    }

    if (opt.dumpAst || opt.dumpSema) {
      std::unique_ptr<ap::Program> parsed;
      if (!diags.hasErrors()) {
        try {
          ap::Parser parser(std::move(tokens), diags, opt.lang);
          parsed = parser.parseProgram();
        } catch (const ap::ParseAbort &) {
        }
      }
      if (opt.dumpAll)
        std::printf("=== ast\n");
      if (opt.dumpAst) {
        shown = dumpDiagnostics(diags, shown);
        if (parsed && !diags.hasErrors())
          ap::dumpAst(*parsed);
      }
      if (opt.dumpSema) {
        ap::Sema sema(diags, opt.lang);
        if (parsed && !diags.hasErrors())
          sema.run(*parsed);
        if (opt.dumpAll)
          std::printf("=== sema\n");
        shown = dumpDiagnostics(diags, shown);
        if (parsed && !diags.hasErrors())
          ap::dumpSema(*parsed, sema);
      }
    }
    return 0;
  }

  // Since ADR-0108 this binary is a *front end*. It exists to produce the
  // dumps `selfhost/difftest.sh` compares and nothing else, so it links no
  // LLVM and generates no code.
  //
  // That is not a reduction in what the oracle covers: difftest never
  // compared generated code. Two backends' assembler text is not comparable
  // (ADR-0025), so CodeGen was always checked by *running* what it produced.
  // Reviving codegen.cpp would have bought no comparison and would have
  // brought LLVM back as a build dependency for everyone.
  std::fprintf(stderr,
               "pascalc-s0: this is the reference front end; it writes dumps "
               "and nothing else.\n"
               "Use --dump-tokens, --dump-ast, --dump-sema or --dump-all.\n");
  return 2;
}
