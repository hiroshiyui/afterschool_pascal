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
project(afterschool_pascal VERSION 1.1.1 LANGUAGES C)

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

# ---- Pascal runtime library (linked into every compiled program) ----
add_library(pasrt STATIC runtime/pasrt.c)
target_include_directories(pasrt PUBLIC runtime)

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
