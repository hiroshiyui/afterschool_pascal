# Afterschool Pascal -- an ISO 7185 / ISO/IEC 10206:1991 Pascal compiler.
# Copyright (C) 2026 Hui-Hong You
#
# This program is free software: you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by the Free
# Software Foundation, either version 3 of the License, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License
# for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program.  If not, see <https://www.gnu.org/licenses/>.

cmake_minimum_required(VERSION 3.20)
project(afterschool_pascal VERSION 1.6.0 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_C_STANDARD 11)

set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
# There are no executable *targets* left -- the compiler is produced by custom
# commands -- so nothing else creates bin/, and clang cannot write into a
# directory that is not there. Only a fresh configure ever sees this.
file(MAKE_DIRECTORY ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

# LLVM is not a build dependency any more: nothing here links libLLVM. What is
# needed is `clang` on PATH, to assemble the IR both the seed and the compiler
# emit (ADR-0009, ADR-0085).
find_program(APASCAL_CLANG clang REQUIRED)
message(STATUS "Afterschool Pascal: assembling with ${APASCAL_CLANG}")

# Warnings, for the two targets built from C and C++ here. There were none set
# at all, so the three the compiler had to say went unheard: two functions in
# src/main.cpp left over from when it drove the assembler, and a Sema parameter
# that had stopped being read. All three are gone, and `runtime/pasrt.c` was
# already clean, so this costs nothing to keep on.
#
# Not -Werror. doc/sop.md's gates fail a developer's `ctest` before a push, and
# a warning introduced by a *newer* compiler than the one a change was written
# against would fail the build rather than the suite -- which is a different
# thing from a defect and would be met by turning this off again. CI is where
# it would belong if it is ever wanted.
set(APASCAL_WARNINGS -Wall -Wextra)

# ---- Pascal runtime library (linked into every compiled program) ----
add_library(pasrt STATIC runtime/pasrt.c)
target_include_directories(pasrt PUBLIC runtime)
target_compile_options(pasrt PRIVATE ${APASCAL_WARNINGS})

# ---- The reference front end (ADR-0108) ----
#
# `src/` is a second implementation of the lexer, the parser and Sema, in C++.
# It is NOT the compiler and generates no code: `selfhost/difftest.sh` compares
# the three `--dump` sections, and code generation was never among them (two
# backends' assembler text is not comparable, ADR-0025). So it links no LLVM,
# which is what makes a second implementation affordable to keep.
#
# It exists because a golden agrees with whoever wrote it. It is the only thing
# here that can disagree about the *front end* without being asked a question
# someone here composed.
add_executable(pascalc-s0
  src/lexer.cpp src/parser.cpp src/sema.cpp src/astdump.cpp src/diag.cpp
  src/main.cpp)
target_include_directories(pascalc-s0 PRIVATE src)
target_compile_features(pascalc-s0 PRIVATE cxx_std_20)
target_compile_options(pascalc-s0 PRIVATE ${APASCAL_WARNINGS})
target_compile_definitions(pascalc-s0 PRIVATE
  APASCAL_VERSION="${PROJECT_VERSION}")
set_target_properties(pascalc-s0 PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

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
  COMMAND ${APASCAL_CLANG} -Wno-override-module ${CMAKE_SOURCE_DIR}/seed/pascalc.ll
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
  COMMAND ${APASCAL_CLANG} -Wno-override-module ${CMAKE_BINARY_DIR}/pascalc.ll
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

# Every diagnostic the compiler can write is named by some golden (doc/sop.md
# §5). A ctest case rather than a CI-only job on purpose: it needs no git and
# no network, so it is a check a developer can run before pushing rather than
# one that reports after. It fails in both directions -- a message with no
# golden, and a message listed as unreachable that acquires one.
find_package(Python3 COMPONENTS Interpreter QUIET)
if(Python3_FOUND)
  add_test(NAME diagnostic-coverage
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/diagnostic_coverage.py
                   ${CMAKE_SOURCE_DIR})
endif()

# ...and every procedure of the compiler is entered by some case, or argued not
# to be. The number doc/sop.md §5 could only argue for: an instrumented copy of
# the compiler is built with clang's SanitizerCoverage -- an IR pass, so it
# applies to the textual .ll this compiler emits with no front end and no debug
# info -- and run over the whole corpus. Skips (77) when clang cannot build it.
#
# It fails in both directions, like diagnostic-coverage, and for the same
# reason. It is a ctest case rather than a CI job because it needs no git and
# no network and takes about two seconds.
if(Python3_FOUND)
  add_test(NAME procedure-coverage
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/coverage.py
                   ${CMAKE_SOURCE_DIR} --build ${CMAKE_BINARY_DIR})
  set_tests_properties(procedure-coverage PROPERTIES
                       SKIP_RETURN_CODE 77
                       TIMEOUT 900)
endif()

# ...and the rule no `tests/` case can express: the program-components of one
# program must agree on `--std` (ADR-0119). run_test.sh compiles every
# component of a case with a single standard, so a *mixture* has to be built by
# hand -- four builds of one pair of files, two that must link and two that must
# be refused. It fails in both directions: a mixture that starts linking is as
# loud as a matched pair that stops.
add_test(NAME mixed-mode-link
         COMMAND ${CMAKE_SOURCE_DIR}/tests/checks/mixed_mode_link.sh
                 ${CMAKE_SOURCE_DIR}/tools/pascalcc ${CMAKE_SOURCE_DIR})
set_tests_properties(mixed-mode-link PROPERTIES
                     ENVIRONMENT
                     "PASCALC=${CMAKE_BINARY_DIR}/bin/pascalc;AFTERSCHOOL_PASCAL_RUNTIME=${CMAKE_BINARY_DIR}/lib")

# ADR-0140: the dialect reserves no word-symbol, which is the whole of what
# keeps ADR-0117's containment true -- a reserved word breaks it by
# construction, for every conforming program using that identifier. The corpus
# sweep below sees such a word only where a corpus program happens to use it as
# a name, and reserving `defer` in the dialect leaves all 619 cases green,
# dialect-containment included. This asks the question directly, of every
# spelling the lexer knows, and fails in both directions: a word the dialect
# starts reserving, and a word it starts allowing that Extended Pascal
# reserves, which is the containment broken from the other side.
if(Python3_FOUND)
  add_test(NAME reserved-words
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/reserved_words.py
                   --pascalcc ${CMAKE_SOURCE_DIR}/tools/pascalcc
                   --source ${CMAKE_SOURCE_DIR}/selfhost/compiler.pas)
  set_tests_properties(reserved-words PROPERTIES
                       ENVIRONMENT
                       "PASCALC=${CMAKE_BINARY_DIR}/bin/pascalc;AFTERSCHOOL_PASCAL_RUNTIME=${CMAKE_BINARY_DIR}/lib")
endif()

# ADR-0117's containment, witnessed by the corpus rather than by one program.
# Everything Extended Pascal accepts, --std=afterschool accepts and means the
# same thing -- a claim about every program, asserted until now by a single
# 122-line source. This compiles the whole of tests/extended/ a second way and
# requires the same behaviour, against a catalogue of four argued divergences,
# and fails in both directions. A mutation switching Extended Pascal off for
# the dialect at one site (readstr and writestr, which the single witness never
# writes) leaves all 617 other cases green and is named here in sixteen.
add_test(NAME dialect-containment
         COMMAND ${CMAKE_SOURCE_DIR}/tests/checks/containment.sh
                 ${CMAKE_SOURCE_DIR}/tools/pascalcc ${CMAKE_SOURCE_DIR})
set_tests_properties(dialect-containment PROPERTIES
                     TIMEOUT 600
                     ENVIRONMENT
                     "PASCALC=${CMAKE_BINARY_DIR}/bin/pascalc;AFTERSCHOOL_PASCAL_RUNTIME=${CMAKE_BINARY_DIR}/lib")

# ...and the half of the model-drift gate a local run *can* check. The gate
# itself is CI-only, needing a push range; deciding which range to judge is not,
# and is the half that broke. A force-push reports a base that is a real 40-hex
# SHA and is gone from the repository, `git rev-parse --verify` says yes to one
# of those without looking it up, and the job died in `git diff` (run
# 32131932455). This builds a repository for the purpose and asks resolve_base
# the four questions a push can pose.
if(Python3_FOUND)
  add_test(NAME model-drift-base
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/model_drift_base_test.py)
endif()

# ADR-0121: a program may name a linker symbol, and LLVM's assembler refuses a
# second declaration of any global however identical -- so a foreign name that
# is also one this compiler emits produces an error about a file nobody wrote.
# `ReservedForeignName` turns that into a diagnostic from a list of names, and
# a list is a second copy of what the emitter writes. This compares the two and
# fails in both directions: a name the emitter grows and the predicate lets
# through, and a name the predicate reserves and the emitter has stopped
# writing.
if(Python3_FOUND)
  add_test(NAME foreign-reserved
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/foreign_reserved.py
                   --pascalcc ${CMAKE_SOURCE_DIR}/tools/pascalcc)
  set_tests_properties(foreign-reserved PROPERTIES
                       ENVIRONMENT
                       "PASCALC=${CMAKE_BINARY_DIR}/bin/pascalc;AFTERSCHOOL_PASCAL_RUNTIME=${CMAKE_BINARY_DIR}/lib")
  add_test(NAME kind-exhaustive
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/kind_exhaustive.py)
endif()

# ADR-0146: what a shared predicate permits, it permits everywhere. `Assignable`
# is asked by eighteen routines -- assignment, the relational operators, an
# actual parameter, a set member, a `for` statement's bounds -- and ADR-0058's
# sentence has now cost twice over the same permission: ADR-0139 found the
# relational operators emitting invalid IR for two slices, and ADR-0143 found
# assignment copying one array's contents over another's, silently, at both -O0
# and -O2. This sweeps every position the *source* contains against every type
# `Assignable` refuses outright, and requires the program to be refused. A
# mutation moving the slice arm one line down leaves all 625 cases green.
if(Python3_FOUND)
  add_test(NAME predicate-callers
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/predicate_callers.py
                   --pascalc ${CMAKE_BINARY_DIR}/bin/pascalc)
endif()

# ...and how much of the token array this compiler's own source still leaves
# free. Twice the loud failure of a fixed buffer (ADR-0012) has been the build
# itself -- the array that has to hold this source is the *seed's*, so raising
# the constant here does not raise the one that matters and the only way out is
# to reseed. ADR-0095 did that for the string pool at 74 characters over;
# ADR-0126 for the tokens, found with 107 of 140000 left. ADR-0095 closed with
# "nothing measures the headroom", which is why there was a second time.
# Measures the tokens exactly and the pool not at all -- doc/sop.md §7 says why.
# Skips (77) when pascalc has not been built.
if(Python3_FOUND)
  add_test(NAME buffer-headroom
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/buffer_headroom.py
                   ${CMAKE_SOURCE_DIR} --build ${CMAKE_BINARY_DIR})
  set_tests_properties(buffer-headroom PROPERTIES SKIP_RETURN_CODE 77)
endif()

# ...and the oracle ADR-0085 gave up and ADR-0108 brought back: two independent
# implementations of the front end, compared over every Pascal source in the
# tree. Nothing else here can disagree with the compiler without being asked a
# question someone here composed.
#
# It arrived red on purpose -- 89 of the then 731 files disagreed, the drift the
# C++ never received -- and held that set as a baseline rather than waiting for
# zero, which would have left the 642 agreeing files guarded by nothing for as
# long as the catch-up took. The catch-up is done: the baseline is **empty**, so
# this is an ordinary regression gate and any file it names is one the change
# under review broke. It also checks how many files were compared, because an
# empty disagreement list is what a clean run and a run that compared nothing
# both produce. Skips (77) when either binary is missing.
if(Python3_FOUND)
  add_test(NAME difftest
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/difftest_check.py
                   ${CMAKE_SOURCE_DIR} --build ${CMAKE_BINARY_DIR})
  set_tests_properties(difftest PROPERTIES SKIP_RETURN_CODE 77 TIMEOUT 1800)
endif()

# ...and the finer measurement procedure coverage cannot make: which
# *statements* the corpus runs. This one needs no sanitizer -- the compiler
# instruments itself under --coverage (ADR-0104), so the denominator is the
# statements a human wrote rather than blocks CodeGen generated.
#
# A ratchet rather than an allowlist, and the weaker instrument for it: a
# per-line argument is not writable at this scale. doc/sop.md §7 carries the
# row saying so.
if(Python3_FOUND)
  add_test(NAME line-coverage
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/line_coverage.py
                   ${CMAKE_SOURCE_DIR} --build ${CMAKE_BINARY_DIR})
  set_tests_properties(line-coverage PROPERTIES
                       SKIP_RETURN_CODE 77
                       TIMEOUT 900)
endif()

# The specification suite: scenarios written against clauses of the two
# standards, in a subset of Gherkin (ADR-0105). Every other oracle here starts
# from the compiler and asks whether it still does what it did; this one starts
# from a clause. One case per feature file, so a failure names the clause area.
#
# It drives tools/pascalcc rather than pascalc, because a scenario that says
# "and run" needs a linked program.
file(GLOB APASCAL_SPEC_FEATURES ${CMAKE_SOURCE_DIR}/tests/spec/features/*.feature)
if(Python3_FOUND)
  foreach(f ${APASCAL_SPEC_FEATURES})
    get_filename_component(name ${f} NAME_WE)
    add_test(NAME spec-${name}
             COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/spec/run.py
                     --pascalcc ${CMAKE_SOURCE_DIR}/tools/pascalcc ${f})
    set_tests_properties(spec-${name} PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")
  endforeach()

  # ...and that every clause a scenario cites is one that can carry a scenario
  # (ADR-0106). Needs no compiler: it compares the citations against
  # clauses/triage.tsv and clauses/pending.txt, and fails in both directions --
  # a clause that stops being cited, and a clause cited that the triage calls
  # structural or unimplemented.
  add_test(NAME spec-clause-traceability
           COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/tests/spec/run.py
                   --check-clauses)
endif()

# The --dump flags. Their walkers were entered by no case at all until
# procedure-coverage found it: four documented flags and nothing checking they
# did not crash. A dump case compares what the *compiler* writes to standard
# output, which is why it cannot be a tests/run_test.sh sidecar -- every case
# there compares what the compiled *program* writes.
file(GLOB APASCAL_DUMP_TESTS ${CMAKE_SOURCE_DIR}/tests/dumps/*.pas)
foreach(t ${APASCAL_DUMP_TESTS})
  get_filename_component(name ${t} NAME_WE)
  add_test(NAME dump-${name}
           COMMAND ${CMAKE_SOURCE_DIR}/tests/dumps/run.sh ${APASCAL_PASCALC} ${t})
endforeach()

# Formal verification of the lowering rules (verify/). Skips rather than fails
# when z3 is absent, so a checkout without it still builds and tests green.
if(Python3_FOUND)
  add_test(NAME verify-lowering
           COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/verify/verify.py
                   --pascalc ${CMAKE_SOURCE_DIR}/tools/pascalcc)
  set_tests_properties(verify-lowering PROPERTIES
                       SKIP_RETURN_CODE 77
                       TIMEOUT 900
                       ENVIRONMENT "${APASCAL_TEST_ENV}")
endif()

# The BSI Pascal Validation Suite -- the one oracle here that this project did
# not write. It skips rather than fails when the suite has not been fetched,
# exactly as verify-lowering does without z3, because the suite is not in this
# repository: BSI holds the copyright and grants no redistribution, so
# tests/bsi/fetch.sh puts it in a gitignored directory. See tests/bsi/README.md.
add_test(NAME bsi-validation-suite
         COMMAND ${CMAKE_SOURCE_DIR}/tests/bsi/run.sh
                 ${CMAKE_SOURCE_DIR}/tools/pascalcc)
set_tests_properties(bsi-validation-suite PROPERTIES
                     SKIP_RETURN_CODE 77
                     TIMEOUT 1800
                     ENVIRONMENT "${APASCAL_TEST_ENV}")

# A second backend configuration, and the one thing it can say that
# selfhost-codegen cannot: that the compiler *binary* is not miscompiled. That
# check compiles the compiler with itself twice, but both stages come from one
# binary, so a clang that got a corner of compiler.pas wrong would build a wrong
# compiler that reproduced itself exactly. This builds it a second way and
# requires the two to translate the same source to the same IR.
#
# Skips without llc, as verify-lowering does without z3: llc is LLVM's, and
# ADR-0085's claim is that the build needs nothing of LLVM's.
add_test(NAME llc-second-backend
         COMMAND ${CMAKE_SOURCE_DIR}/tests/checks/llc_check.sh
                 ${CMAKE_BINARY_DIR})
set_tests_properties(llc-second-backend PROPERTIES
                     SKIP_RETURN_CODE 77
                     TIMEOUT 900
                     ENVIRONMENT "${APASCAL_TEST_ENV}")

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

# The dialect (ADR-0117), globbed separately for the same reason tests/extended/
# is: the directory decides the standard, and these are compiled under a flag
# neither of the other two corpora may be given.
file(GLOB APASCAL_DIALECT_TESTS ${CMAKE_SOURCE_DIR}/tests/dialect/*.pas)
foreach(t ${APASCAL_DIALECT_TESTS})
  get_filename_component(name ${t} NAME_WE)
  add_test(NAME ${name}
           COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                   ${CMAKE_SOURCE_DIR}/tools/pascalcc ${t} afterschool)
  set_tests_properties(${name} PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")
endforeach()
