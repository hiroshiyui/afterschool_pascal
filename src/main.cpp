// Afterschool Pascal — driver.
//
//   pascalc hello.pas            compile and link to ./hello
//   pascalc -o out hello.pas     choose the executable name
//   pascalc --emit-llvm hello.pas   write hello.ll and stop
//   pascalc -c hello.pas         write hello.o and stop
//   pascalc --ast hello.pas      (reserved) dump the parse for debugging

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
};

void usage() {
  std::fprintf(stderr,
               "Afterschool Pascal\n"
               "usage: pascalc [options] file.pas\n"
               "  -o <file>     name of the output file\n"
               "  --emit-llvm   write LLVM IR (.ll) instead of an executable\n"
               "  -c            write an object file (.o) and stop\n"
               "  -O0..-O3      optimisation level (default -O2)\n"
               "  --keep-temps  do not delete the intermediate object file\n");
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
    } else if (a.size() == 3 && a.rfind("-O", 0) == 0 && a[2] >= '0' &&
               a[2] <= '3') {
      opt.optLevel = static_cast<unsigned>(a[2] - '0');
    } else if (a == "-h" || a == "--help") {
      usage();
      std::exit(0);
    } else if (!a.empty() && a[0] == '-') {
      std::fprintf(stderr, "pascalc: unknown option '%s'\n", a.c_str());
      return false;
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

bool emitObject(llvm::Module &mod, const std::string &path) {
  llvm::InitializeNativeTarget();
  llvm::InitializeNativeTargetAsmPrinter();
  llvm::InitializeNativeTargetAsmParser();

  llvm::Triple triple(llvm::sys::getDefaultTargetTriple());
  std::string err;
  const llvm::Target *target = llvm::TargetRegistry::lookupTarget(triple, err);
  if (!target) {
    std::fprintf(stderr, "pascalc: %s\n", err.c_str());
    return false;
  }

  llvm::TargetOptions options;
  std::unique_ptr<llvm::TargetMachine> tm(target->createTargetMachine(
      triple, "generic", "", options, llvm::Reloc::PIC_));

  mod.setTargetTriple(triple);
  mod.setDataLayout(tm->createDataLayout());

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
  ap::Lexer lexer(buffer.str(), diags);
  std::vector<ap::Token> tokens = lexer.tokenize();
  if (diags.hasErrors()) {
    diags.print();
    return 1;
  }

  std::unique_ptr<ap::Program> program;
  try {
    ap::Parser parser(std::move(tokens), diags);
    program = parser.parseProgram();
  } catch (const ap::ParseAbort &) {
    diags.print();
    return 1;
  }
  if (diags.hasErrors()) {
    diags.print();
    return 1;
  }

  ap::Sema sema(diags);
  sema.run(*program);
  if (diags.hasErrors()) {
    diags.print();
    return 1;
  }

  llvm::LLVMContext ctx;
  ap::CodeGen cg(ctx, sema, opt.input);
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

  std::string objPath =
      opt.compileOnly ? (opt.output.empty() ? base + ".o" : opt.output)
                      : base + ".o";
  if (!emitObject(*mod, objPath))
    return 1;
  if (opt.compileOnly)
    return 0;

  std::string exePath = opt.output.empty() ? base : opt.output;
  std::string cmd = "clang '" + objPath + "' -L'" + runtimeDir() +
                    "' -lpasrt -lm -o '" + exePath + "'";
  int rc = std::system(cmd.c_str());
  if (!opt.keepTemps)
    std::remove(objPath.c_str());
  if (rc != 0) {
    std::fprintf(stderr, "pascalc: linking failed\n");
    return 1;
  }
  return 0;
}
