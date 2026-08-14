cmake_minimum_required(VERSION 3.20)
project(afterschool_pascal VERSION 0.1.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)

find_package(LLVM REQUIRED CONFIG)
message(STATUS "Afterschool Pascal: using LLVM ${LLVM_PACKAGE_VERSION} from ${LLVM_DIR}")

llvm_map_components_to_libnames(APASCAL_LLVM_LIBS core support irreader passes native)

# ---- Pascal runtime library (linked into every compiled program) ----
add_library(pasrt STATIC runtime/pasrt.c)
target_include_directories(pasrt PUBLIC runtime)

# ---- Stage 0: the compiler written in C++ ----
#
# Named for what it is. `pascalc-s0` only ever had to be good enough to compile
# the Pascal-written compiler once (README's bootstrap plan), and it is long
# past that bar — but the compiler this repository *produces* is `pascalc`
# below, which this one builds. Stage 0 is kept rather than retired, because it
# is the second implementation `selfhost/difftest.sh` compares against and the
# one `verify/` proves; doc/roadmap.md has that trade in full.
add_executable(pascalc-s0
  src/main.cpp
  src/astdump.cpp
  src/diag.cpp
  src/lexer.cpp
  src/parser.cpp
  src/sema.cpp
  src/codegen.cpp
)
target_include_directories(pascalc-s0 PRIVATE src ${LLVM_INCLUDE_DIRS})
target_compile_definitions(pascalc-s0 PRIVATE
  ${LLVM_DEFINITIONS_LIST}
  APASCAL_RUNTIME_DIR="${CMAKE_BINARY_DIR}/lib"
  APASCAL_VERSION="${PROJECT_VERSION}"
)
target_link_libraries(pascalc-s0 PRIVATE ${APASCAL_LLVM_LIBS})
add_dependencies(pascalc-s0 pasrt)

if(NOT LLVM_ENABLE_RTTI)
  target_compile_options(pascalc-s0 PRIVATE -fno-rtti)
endif()

# ---- The compiler: written in Afterschool Pascal, built by the seed ----
#
# `selfhost/compiler.pas` is the only compiler source in this repository, and
# there is no C++ one to translate it (ADR-0085). `seed/pascalc.ll` is a working
# compiler in LLVM IR, committed for exactly this: clang assembles it, and the
# result translates the current source into the compiler that ships.
#
# Two stages, and the second is the point -- what `build/bin/pascalc` is built
# from is the source in the tree, never the seed. The seed only bootstraps.
# seed/README.md has its provenance, its target lock and when to refresh it.
set(APASCAL_SEED_CC ${CMAKE_BINARY_DIR}/bin/pascalc-seed)
set(APASCAL_PASCALC ${CMAKE_BINARY_DIR}/bin/pascalc)

add_custom_command(
  OUTPUT ${APASCAL_SEED_CC}
  # Both binaries, not just this one: if the seed fails to assemble, the rule
  # below never runs, and without this a stale build/bin/pascalc would survive
  # for `ctest` to pass against.
  COMMAND ${CMAKE_COMMAND} -E rm -f ${APASCAL_SEED_CC} ${APASCAL_PASCALC}
  COMMAND clang -Wno-override-module ${CMAKE_SOURCE_DIR}/seed/pascalc.ll
          $<TARGET_FILE:pasrt> -lm -o ${APASCAL_SEED_CC}
  DEPENDS pasrt ${CMAKE_SOURCE_DIR}/seed/pascalc.ll
  COMMENT "Assembling the seed compiler from seed/pascalc.ll"
  VERBATIM
)

# The output is removed first, so a compiler that fails to build leaves nothing
# behind. Without that, `cmake --build` fails and the *previous* binary stays in
# build/bin -- and a `ctest` run afterwards passes against a compiler that no
# longer corresponds to the source. That is how a deliberately broken mutation
# came back green while this was being written.
add_custom_command(
  OUTPUT ${APASCAL_PASCALC}
  COMMAND ${CMAKE_COMMAND} -E rm -f ${APASCAL_PASCALC}
  COMMAND ${APASCAL_SEED_CC} --std=extended
          ${CMAKE_SOURCE_DIR}/selfhost/compiler.pas -o ${CMAKE_BINARY_DIR}/pascalc.ll
  COMMAND clang -Wno-override-module ${CMAKE_BINARY_DIR}/pascalc.ll
          $<TARGET_FILE:pasrt> -lm -o ${APASCAL_PASCALC}
  DEPENDS ${APASCAL_SEED_CC} pasrt
          ${CMAKE_SOURCE_DIR}/selfhost/compiler.pas
          ${CMAKE_SOURCE_DIR}/selfhost/compiler.std
  COMMENT "Building pascalc from selfhost/compiler.pas with the seed compiler"
  VERBATIM
)
add_custom_target(pascalc ALL DEPENDS ${APASCAL_PASCALC})

# ---- Tests ----
enable_testing()

# Every case is compiled by `pascalc` -- the Pascal compiler -- through
# tools/pascalcc, which adds the linking half a Pascal program cannot do. The
# environment is how pascalcc is told which build tree to use, so a fresh
# configure under another name (build-rel/) drives its own compiler and not
# whatever happens to be in build/.
set(APASCAL_TEST_ENV
    PASCALC=${APASCAL_PASCALC}
    AFTERSCHOOL_PASCAL_RUNTIME=${CMAKE_BINARY_DIR}/lib)

# Formal verification of the lowering rules (verify/). Skips rather than fails
# when z3 is absent, so a checkout without it still builds and tests green.
find_package(Python3 COMPONENTS Interpreter QUIET)
if(Python3_FOUND)
  add_test(NAME verify-lowering
           COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/verify/verify.py
                   --pascalc ${CMAKE_SOURCE_DIR}/tools/pascalcc)
  set_tests_properties(verify-lowering PROPERTIES
                       SKIP_RETURN_CODE 77
                       TIMEOUT 900
                       ENVIRONMENT "${APASCAL_TEST_ENV}")
endif()

# Stage 1, checked against stage 0: each Pascal component must produce the same
# output as the C++ one it was ported from, for every Pascal source in the
# tree. The roadmap makes this the checkpoint that comes *before* stage 1 is
# declared working — a disagreement here is bisectable, the same disagreement
# at stage 3 is two binaries differing by a byte.
add_test(NAME selfhost-compiler
         COMMAND ${CMAKE_SOURCE_DIR}/selfhost/difftest.sh
                 $<TARGET_FILE:pascalc-s0>)
set_tests_properties(selfhost-compiler PROPERTIES TIMEOUT 1800)

# The code generator cannot be diffed against the C++ one — LLVM's own printer
# is not a specification — so it is checked by *running* what it produces
# against the same golden output the C++ compiler is held to, and then by
# compiling the compiler with itself twice and requiring the two results to be
# identical. That last comparison is the point of the whole bootstrap
# (ADR-0004, ADR-0025).
add_test(NAME selfhost-codegen
         COMMAND ${CMAKE_SOURCE_DIR}/selfhost/irtest.sh ${APASCAL_SEED_CC})
set_tests_properties(selfhost-codegen PROPERTIES TIMEOUT 1800)

# The product itself. `irtest.sh` builds a stage-1 compiler of its own in a
# temporary directory, so the binary in build/bin could be missing or stale
# with every other test still green — what this checks is the build wiring, not
# the compiler.
add_test(NAME pascalc-product
         COMMAND ${CMAKE_SOURCE_DIR}/selfhost/producttest.sh
                 ${APASCAL_PASCALC} ${CMAKE_BINARY_DIR}/lib)
set_tests_properties(pascalc-product PROPERTIES TIMEOUT 300)

file(GLOB APASCAL_TESTS ${CMAKE_SOURCE_DIR}/tests/*.pas)
foreach(t ${APASCAL_TESTS})
  get_filename_component(name ${t} NAME_WE)
  add_test(NAME ${name}
           COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                   ${CMAKE_SOURCE_DIR}/tools/pascalcc ${t} iso7185)
  set_tests_properties(${name} PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")
endforeach()

# ISO/IEC 10206:1991 cases. They live apart because the standard is a property
# of the source, not of the case: a program using `otherwise` is not a valid
# ISO 7185 program, and the directory is what says so to every harness that
# walks the tree (ADR-0033).
# The error-path corpus. These 157 sources exist to drive the compiler into a
# diagnostic -- one file per parser message, because the parser stops at its
# first (ADR-0023), and thirteen for Sema, which accumulates. Until stage 0 was
# retired they were compared between the two compilers by difftest.sh and had no
# goldens of their own; with one compiler left, "the two agree" is not a
# question any more, so each is pinned against what it reports.
#
# That is a weaker oracle and it is the honest one available: a golden cannot
# disagree with the program that wrote it. What it still catches is a message
# changing without anyone meaning it to, which is most of what these files were
# ever for.
#
# Prefixed by directory: ctest names must be unique and `sets` and `typedfiles`
# already exist under tests/.
foreach(dir badparse badsema)
  file(GLOB APASCAL_${dir}_TESTS ${CMAKE_SOURCE_DIR}/selfhost/${dir}/*.pas)
  foreach(t ${APASCAL_${dir}_TESTS})
    get_filename_component(name ${t} NAME_WE)
    add_test(NAME ${dir}-${name}
             COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                     ${CMAKE_SOURCE_DIR}/tools/pascalcc ${t} iso7185)
    set_tests_properties(${dir}-${name} PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")
  endforeach()
endforeach()

# The lexer's own corpus: deliberately not a valid program, carrying the
# lexical corner cases a valid one never reaches.
add_test(NAME torture
         COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                 ${CMAKE_SOURCE_DIR}/tools/pascalcc
                 ${CMAKE_SOURCE_DIR}/selfhost/torture.pas iso7185)
set_tests_properties(torture PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")

file(GLOB APASCAL_EXTENDED_TESTS ${CMAKE_SOURCE_DIR}/tests/extended/*.pas)
foreach(t ${APASCAL_EXTENDED_TESTS})
  get_filename_component(name ${t} NAME_WE)
  add_test(NAME ${name}
           COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                   ${CMAKE_SOURCE_DIR}/tools/pascalcc ${t} extended)
  set_tests_properties(${name} PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")
endforeach()
