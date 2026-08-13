// Afterschool Pascal — driver.
//
//   pascalc hello.pas            compile and link to ./hello
//   pascalc -o out hello.pas     choose the executable name
//   pascalc --std=extended hello.pas  ISO/IEC 10206:1991 rather than ISO 7185.
//                                     The two are not nested (ADR-0033), so
//                                     this selects the *language* and not a
//                                     set of extensions.
//   pascalc --emit-llvm hello.pas, -S   write hello.ll and stop
//   pascalc -c hello.pas         write hello.o and stop
//   pascalc -O0 .. -O3           optimisation level; the default is -O2
//   pascalc --keep-temps hello.pas    keep the intermediate object file
//   pascalc --dump-tokens hello.pas   the token stream, for selfhost/difftest.sh
//   pascalc --dump-ast hello.pas      the parse tree, before Sema
//   pascalc --dump-sema hello.pas     the same tree, annotated by Sema
//   pascalc --dump-all hello.pas      all three sections in one run — this is
//                                     the form selfhost/difftest.sh compares
//                                     the Pascal compiler against
//   pascalc -h, --help           write the option list and stop
//
// `usage()` below is the authoritative list; keep the two in step.

#include <cstdio>
#include <cstdlib>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Passes/PassBuilder.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/TargetParser/Host.h"

#include "astdump.h"
#include "codegen.h"
#include "diag.h"
#include "lexer.h"
#include "parser.h"
#include "sema.h"

namespace {

struct Options {
  std::string input;
  std::string output;
  bool emitLLVM = false;
  bool compileOnly = false;
  unsigned optLevel = 2;
  bool keepTemps = false;
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
  ap::Std lang = ap::Std::Iso7185;
  /// ISO/IEC 10206:1991 §6.13's other program-components, already translated.
  /// Each is read for the interfaces its module-headings export and for
  /// nothing else — no code of theirs is emitted here, and where their
  /// variables and procedures *are* is a question answered by name.
  std::vector<std::string> imports;
  /// What to hand the linker beside this component's own object: the objects
  /// the components named by `--import` were translated into.
  std::vector<std::string> linkInputs;
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
               "Afterschool Pascal\n"
               "usage: pascalc [options] file.pas\n"
               "  -o <file>     name of the output file\n"
               "  --emit-llvm, -S\n"
               "                write LLVM IR (.ll) instead of an executable\n"
               "  -c            write an object file (.o) and stop\n"
               "  -O0..-O3      optimisation level (default -O2)\n"
               "  --keep-temps  do not delete the intermediate object file\n"
               "  --dump-tokens write the token stream and stop\n"
               "  --dump-ast    write the parse tree and stop\n"
               "  --dump-sema   write the tree Sema annotated and stop\n"
               "  --dump-all    write all three dumps and stop\n"
               "  --std=<name>  iso7185 (default) or extended\n"
               "  --import <f>  a program-component already translated; its\n"
               "                module-headings supply this one's interfaces\n"
               "  -h, --help    write this list and stop\n");
}

std::string stripExtension(const std::string &path) {
  size_t slash = path.find_last_of('/');
  size_t dot = path.find_last_of('.');
  if (dot == std::string::npos || (slash != std::string::npos && dot < slash))
    return path;
  return path.substr(0, dot);
}

/// Where libpasrt.a lives. The build directory is baked in, but an installed
/// compiler can be pointed elsewhere.
std::string runtimeDir() {
  if (const char *env = std::getenv("AFTERSCHOOL_PASCAL_RUNTIME"))
    return env;
  return APASCAL_RUNTIME_DIR;
}

bool parseArgs(int argc, char **argv, Options &opt) {
  for (int i = 1; i < argc; ++i) {
    std::string a = argv[i];
    if (a == "-o" && i + 1 < argc) {
      opt.output = argv[++i];
    } else if (a == "--emit-llvm" || a == "-S") {
      opt.emitLLVM = true;
    } else if (a == "-c") {
      opt.compileOnly = true;
    } else if (a == "--keep-temps") {
      opt.keepTemps = true;
    } else if (a == "--dump-tokens") {
      opt.dumpTokens = true;
    } else if (a == "--dump-ast") {
      opt.dumpAst = true;
    } else if (a == "--dump-sema") {
      opt.dumpSema = true;
    } else if (a == "--dump-all") {
      opt.dumpTokens = opt.dumpAst = opt.dumpSema = true;
      opt.dumpAll = true;
    } else if (a.size() == 3 && a.rfind("-O", 0) == 0 && a[2] >= '0' &&
               a[2] <= '3') {
      opt.optLevel = static_cast<unsigned>(a[2] - '0');
    } else if (a.rfind("--std=", 0) == 0) {
      std::string name = a.substr(6);
      if (name == "iso7185") {
        opt.lang = ap::Std::Iso7185;
      } else if (name == "extended") {
        opt.lang = ap::Std::Extended;
      } else {
        std::fprintf(stderr,
                     "pascalc: unknown standard '%s'; "
                     "expected iso7185 or extended\n",
                     name.c_str());
        return false;
      }
    } else if (a == "--import" && i + 1 < argc) {
      opt.imports.push_back(argv[++i]);
    } else if (a == "-h" || a == "--help") {
      usage();
      std::exit(0);
    } else if (!a.empty() && a[0] == '-') {
      std::fprintf(stderr, "pascalc: unknown option '%s'\n", a.c_str());
      return false;
    } else if (a.size() > 2 && a.compare(a.size() - 2, 2, ".o") == 0) {
      // An already-translated component, on its way to the linker.
      opt.linkInputs.push_back(a);
    } else if (opt.input.empty()) {
      opt.input = a;
    } else {
      std::fprintf(stderr, "pascalc: more than one input file given\n");
      return false;
    }
  }
  if (opt.input.empty()) {
    usage();
    return false;
  }
  return true;
}

void optimize(llvm::Module &mod, unsigned level) {
  llvm::LoopAnalysisManager lam;
  llvm::FunctionAnalysisManager fam;
  llvm::CGSCCAnalysisManager cgam;
  llvm::ModuleAnalysisManager mam;

  llvm::PassBuilder pb;
  pb.registerModuleAnalyses(mam);
  pb.registerCGSCCAnalyses(cgam);
  pb.registerFunctionAnalyses(fam);
  pb.registerLoopAnalyses(lam);
  pb.crossRegisterProxies(lam, fam, cgam, mam);

  llvm::OptimizationLevel ol;
  switch (level) {
  case 0: ol = llvm::OptimizationLevel::O0; break;
  case 1: ol = llvm::OptimizationLevel::O1; break;
  case 3: ol = llvm::OptimizationLevel::O3; break;
  default: ol = llvm::OptimizationLevel::O2; break;
  }
  llvm::ModulePassManager mpm = pb.buildPerModuleDefaultPipeline(ol);
  mpm.run(mod, mam);
}

/// The target machine is built before code generation, not after it: codegen
/// needs the data layout to know how large a record or an array is, and the
/// optimiser needs it to make anything of the copies that produces.
std::unique_ptr<llvm::TargetMachine> createHostTargetMachine() {
  llvm::InitializeNativeTarget();
  llvm::InitializeNativeTargetAsmPrinter();
  llvm::InitializeNativeTargetAsmParser();

  llvm::Triple triple(llvm::sys::getDefaultTargetTriple());
  std::string err;
  const llvm::Target *target = llvm::TargetRegistry::lookupTarget(triple, err);
  if (!target) {
    std::fprintf(stderr, "pascalc: %s\n", err.c_str());
    return nullptr;
  }

  llvm::TargetOptions options;
  return std::unique_ptr<llvm::TargetMachine>(target->createTargetMachine(
      triple, "generic", "", options, llvm::Reloc::PIC_));
}

bool emitObject(llvm::Module &mod, llvm::TargetMachine &tmRef,
                const std::string &path) {
  llvm::TargetMachine *tm = &tmRef;
  std::error_code ec;
  llvm::raw_fd_ostream dest(path, ec, llvm::sys::fs::OF_None);
  if (ec) {
    std::fprintf(stderr, "pascalc: cannot write %s: %s\n", path.c_str(),
                 ec.message().c_str());
    return false;
  }

  llvm::legacy::PassManager pm;
  if (tm->addPassesToEmitFile(pm, dest, nullptr,
                              llvm::CodeGenFileType::ObjectFile)) {
    std::fprintf(stderr, "pascalc: this target cannot emit object files\n");
    return false;
  }
  pm.run(mod);
  dest.flush();
  return true;
}

/// ISO/IEC 10206:1991 §6.13: read a program-component that has already been
/// translated, and take its module-headings into `into` as the interfaces this
/// component imports.
///
/// The whole of the interface is in the source, because §6.11.1 makes the
/// module-heading declare exactly the exported constants, types, variables and
/// procedure headings — so a separately translated component needs no artefact
/// beside its source, and this compiler defines no format for one. What the
/// heading does *not* say is where anything ended up, which is why nothing
/// numbered may cross the boundary; see `Sema::nameForLinkage`.
bool readTranslatedComponent(
    const std::string &path, ap::Std lang,
    std::vector<std::unique_ptr<ap::ModuleDecl>> &earlier) {
  std::ifstream in(path, std::ios::binary);
  if (!in) {
    std::fprintf(stderr, "pascalc: cannot open %s\n", path.c_str());
    return false;
  }
  std::stringstream buffer;
  buffer << in.rdbuf();

  ap::Diagnostics diags(path);
  ap::Lexer lexer(buffer.str(), diags, lang);
  std::vector<ap::Token> tokens = lexer.tokenize();
  std::unique_ptr<ap::Program> component;
  if (!diags.hasErrors()) {
    try {
      ap::Parser parser(std::move(tokens), diags, lang);
      component = parser.parseProgram();
    } catch (const ap::ParseAbort &) {
    }
  }
  if (diags.hasErrors() || !component) {
    diags.print();
    return false;
  }
  if (component->block) {
    std::fprintf(stderr,
                 "pascalc: %s has a program declaration, so it is not a "
                 "component this one can import\n",
                 path.c_str());
    return false;
  }

  for (auto &m : component->modules) {
    m->compiledElsewhere = true;
    earlier.push_back(std::move(m));
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
    std::fprintf(stderr, "pascalc: cannot open %s\n", opt.input.c_str());
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

  if (diags.hasErrors()) {
    diags.print();
    return 1;
  }

  std::unique_ptr<ap::Program> program;
  try {
    ap::Parser parser(std::move(tokens), diags, opt.lang);
    program = parser.parseProgram();
  } catch (const ap::ParseAbort &) {
    diags.print();
    return 1;
  }
  if (diags.hasErrors()) {
    diags.print();
    return 1;
  }

  // §6.13's other program-components, in front of this one's own modules:
  // §6.2.2.9 puts a module-heading before everything that imports its
  // interface, and one that was translated separately is earlier still.
  if (!opt.imports.empty()) {
    std::vector<std::unique_ptr<ap::ModuleDecl>> earlier;
    for (const std::string &path : opt.imports)
      if (!readTranslatedComponent(path, opt.lang, earlier))
        return 1;
    size_t n = earlier.size();
    program->modules.insert(program->modules.begin(),
                            std::make_move_iterator(earlier.begin()),
                            std::make_move_iterator(earlier.end()));
    program->mainIndex += n;
  }

  ap::Sema sema(diags, opt.lang);
  sema.run(*program);
  if (diags.hasErrors()) {
    diags.print();
    return 1;
  }

  std::unique_ptr<llvm::TargetMachine> tm = createHostTargetMachine();
  if (!tm)
    return 1;

  llvm::LLVMContext ctx;
  ap::CodeGen cg(ctx, sema, opt.input, tm->createDataLayout(),
                 tm->getTargetTriple());
  std::unique_ptr<llvm::Module> mod = cg.run(*program);
  if (!mod) {
    std::fprintf(stderr, "pascalc: internal error: generated invalid IR\n");
    return 1;
  }

  optimize(*mod, opt.optLevel);

  std::string base = stripExtension(opt.input);

  if (opt.emitLLVM) {
    std::string path = opt.output.empty() ? base + ".ll" : opt.output;
    std::error_code ec;
    llvm::raw_fd_ostream out(path, ec, llvm::sys::fs::OF_Text);
    if (ec) {
      std::fprintf(stderr, "pascalc: cannot write %s\n", path.c_str());
      return 1;
    }
    mod->print(out, nullptr);
    return 0;
  }

  // §6.13: a component with no main-program-declaration translates perfectly
  // well and simply cannot be entered, so it is an object and never a program.
  // The message says which component is missing rather than complaining about
  // this one, because nothing about this one is wrong.
  if (!program->block && !opt.compileOnly) {
    std::fprintf(stderr,
                 "pascalc: %s declares no program, so it can be translated "
                 "(-c) but not linked; the program-component holding the "
                 "program declaration is what links it\n",
                 opt.input.c_str());
    return 1;
  }

  std::string exePath = opt.output.empty() ? base : opt.output;
  // The object of a `-c` run is the product and is named after the source (or
  // by `-o`). The one a link run leaves behind is a temporary, and it is named
  // after the *executable* rather than after the source: two concurrent
  // compilations of one source file are ordinary — the two self-hosting
  // harnesses do exactly that — and naming it after the source made them
  // delete each other's object between emitting it and linking it.
  std::string objPath =
      opt.compileOnly ? (opt.output.empty() ? base + ".o" : opt.output)
                      : exePath + ".o";
  if (!emitObject(*mod, *tm, objPath))
    return 1;
  if (opt.compileOnly)
    return 0;

  std::string cmd = "clang '" + objPath + "'";
  for (const std::string &obj : opt.linkInputs)
    cmd += " '" + obj + "'";
  cmd += " -L'" + runtimeDir() + "' -lpasrt -lm -o '" + exePath + "'";
  int rc = std::system(cmd.c_str());
  if (!opt.keepTemps)
    std::remove(objPath.c_str());
  if (rc != 0) {
    std::fprintf(stderr, "pascalc: linking failed\n");
    return 1;
  }
  return 0;
}
