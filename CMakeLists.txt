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
# C only. The C++ reference front end went with ADR-0232's conformance modes,
# and with it the last thing here that needed a C++ compiler.
project(afterschool_pascal VERSION 2.1.0 LANGUAGES C)

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

# Warnings, for the runtime -- the only C in this repository. There were none
# set at all when this was written, and `runtime/pasrt.c` was already clean, so
# it costs nothing to keep on.
#
# Not -Werror. doc/sop.md's gates fail a developer's `ctest` before a push, and
# a warning introduced by a *newer* compiler than the one a change was written
# against would fail the build rather than the suite -- which is a different
# thing from a defect and would be met by turning this off again. CI is where
# it would belong if it is ever wanted.
set(APASCAL_WARNINGS -Wall -Wextra)

# ---- Pascal runtime library (linked into every compiled program) ----
# Two translation units, and the split is a decision (ADR-0186): pasrt.c is
# strict ISO C apart from a catalogue of function *names*, and pasrt_posix.c is
# where anything needing a POSIX *type* goes -- a `struct stat` cannot be
# excused by a catalogue that is proved complete by stripping includes and
# requiring what is left to compile.
# Three now, and the third is the one whose correctness is not settled here:
# pasrt_unicode.c is strict ISO C11 over tables generated from the Unicode
# Character Database, and `unicode-conformance` runs the database's own answers
# through it (ADR-0189). Nothing calls it yet -- it is AP 6.4.15's runtime half,
# landed before the language rests on it precisely so that it can be judged on
# its own.
add_library(pasrt STATIC runtime/pasrt.c runtime/pasrt_posix.c
                         runtime/pasrt_unicode.c)
target_include_directories(pasrt PUBLIC runtime)
target_compile_options(pasrt PRIVATE ${APASCAL_WARNINGS})

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
  # `--std=extended` because the *seed* still has the conformance modes:
  # seed/pascalc.ll was generated before ADR-0232 removed them, and Extended
  # Pascal is the language selfhost/compiler.pas is written in. The flag goes
  # when the seed is refreshed, and not before -- it is the one place in this
  # repository where the removed modes are still real (seed/README.md).
  COMMAND ${APASCAL_SEED_CC} --std=extended
          ${CMAKE_SOURCE_DIR}/selfhost/compiler.pas -o ${CMAKE_BINARY_DIR}/pascalc.ll
  COMMAND ${APASCAL_CLANG} -Wno-override-module ${CMAKE_BINARY_DIR}/pascalc.ll
          $<TARGET_FILE:pasrt> -lm -o ${APASCAL_PASCALC}
  DEPENDS ${APASCAL_SEED_CC} pasrt
          ${CMAKE_SOURCE_DIR}/selfhost/compiler.pas
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
endif()


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
  # Two halves since ADR-0229, as buffer-headroom has had since ADR-0148: the
  # *compiler* answers for the case-statements (--dump-dispatch), because it
  # knows which types are enumerations and how many constants each has, and
  # the source is still read for the if-chains. Skips (77) when pascalc has
  # not been built.
  add_test(NAME kind-exhaustive
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/kind_exhaustive.py
                   --build ${CMAKE_BINARY_DIR})
  set_tests_properties(kind-exhaustive PROPERTIES SKIP_RETURN_CODE 77)

  # ADR-0222: the AST is the only variant record here, and a variant record has
  # no member initialisers -- so a pointer field of the arm the tag selects
  # holds whatever new() returned until something writes it. Two things write
  # them, NewNode and the construction site, and which does which is a split
  # nothing checked. This asks that every pointer field is on one side of it.
  add_test(NAME ast-fields
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/ast_fields.py)

  # ADR-0223: ast-fields asks whether a node's fields were *written*; this asks
  # whether they are read through the arm the tag selects. ADR-0118's check
  # was a dialect rule the compiler was not using on itself; ADR-0232 removed
  # the modes, so the guards are in whatever this compiler emits and what is
  # left is the sweep -- compile the compiler with itself, then read the corpus
  # with the result.
  add_test(NAME variant-check
           COMMAND ${CMAKE_SOURCE_DIR}/tests/checks/variant_check.sh
                   ${CMAKE_BINARY_DIR}/bin/pascalc
                   ${CMAKE_BINARY_DIR}/lib/libpasrt.a)


  # ADR-0183: the oracle none of the others can be. Every gate here reads what
  # a program *prints*, and a leak prints nothing -- which is how a handle in
  # an unowned heap record (ADR-0181) and an abandoned chain (ADR-0182) were
  # each found by a measurement taken once, by hand. The runtime counts what
  # `new` made and `dispose` gave back; this compares the balance of every
  # heap-using case against a catalogue, in both directions.
  add_test(NAME heap-balance
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/heap_balance.py
                   --pascalcc ${CMAKE_SOURCE_DIR}/tools/pascalcc)
  set_tests_properties(heap-balance PROPERTIES
                       ENVIRONMENT "${APASCAL_TEST_ENV}"
                       TIMEOUT 900)
endif()

# ADR-0164: a clause number is the one claim here no other oracle can
# contradict. A wrong one compiles, runs, passes every golden, agrees with the
# other front end and is proved correct by verify/ -- ADR-0072 is the record of
# one surviving in four documents and a purpose-written test, and ADR-0163
# found §6.4.3.4 cited about an ISO 7185 program, where that number is
# Set-types. This asks the cheap half: does the number name a clause at all?
# It found one that names nothing in either standard and had stood in seven
# places; ADR-0164 says which. Spelling it here would be a citation of it --
# the gate cannot tell a mention from a claim, and that is the rule rather
# than a limitation. Needs no compiler, so it is outside the guard above.
add_test(NAME clause-citations
         COMMAND ${Python3_EXECUTABLE}
                 ${CMAKE_SOURCE_DIR}/tests/checks/clause_citations.py)

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

# The two opaque struct sizes, against every target a compiler is installed for
# (ADR-0155). Skips with 77 where only the host is available, as the BSI runner
# does without its corpus and verify-lowering does without z3 -- the question it
# exists for cannot be asked with one target.
add_test(NAME target-sizes
         COMMAND ${CMAKE_SOURCE_DIR}/tests/checks/target_sizes.sh)
set_tests_properties(target-sizes PROPERTIES
                     SKIP_RETURN_CODE 77
                     TIMEOUT 600)

# What every type predicate answers about every kind of type (ADR-0194).
#
# `kind-exhaustive` reads every case-statement over an enumeration and cannot
# see a *predicate*, and three defects in three increments lived in one:
# IsMemory asking IsVarString, so a text was taken for a register value and the
# relational operators emitted `icmp` on an aggregate; the code generator's
# comparison dispatch; and EmitAssign choosing the string store with
# IsStringType, so a text target fell through to a schema tuple-comparison and
# stopped the program (ADR-0191, ADR-0193). None is a case-statement, and all
# three were found by writing a program that used the new type.
#
# A prompt rather than a proof: the catalogue records what the answers are, not
# what they should be. What it buys is that adding a kind moves `of N` on all
# 36 rows, so every predicate is looked at once -- partial_cases.txt's
# instrument for partial_cases.txt's reason (ADR-0145).
#
# Two halves, as buffer-headroom has since ADR-0148: the compiler answers
# (--dump-predicates) and the *source* says which predicates exist, so one
# added without a row fails rather than passing unseen.
add_test(NAME predicate-kinds
         COMMAND ${Python3_EXECUTABLE}
                 ${CMAKE_SOURCE_DIR}/tests/checks/predicate_kinds.py
                 --build ${CMAKE_BINARY_DIR})

# The same script's other question, and the reason it is a separate case: the
# gate above passes on a *correct* row. A text is not a string-type, so
# `IsStringType 1 of 22` is right, and the defect was a call site asking
# IsStringType where it meant "does this take the string store?" -- which is a
# guard the new kind falls out of and no catalogue can see (ADR-0198).
#
# `--like` names the predicates that answer differently about two kinds and
# every call site of each. This registers it so that a documented mode has a
# case behind it, ADR-0103 having found four dump flags that no case had ever
# passed. The pair is the one that has been through it: three predicates
# answer yes to a string and no to a text, and a change making the two alike
# everywhere fails here, which is a question worth being asked.
add_test(NAME predicate-kinds-like
         COMMAND ${Python3_EXECUTABLE}
                 ${CMAKE_SOURCE_DIR}/tests/checks/predicate_kinds.py
                 --build ${CMAKE_BINARY_DIR} --like tyString tyText)
set_tests_properties(predicate-kinds-like PROPERTIES
                     PASS_REGULAR_EXPRESSION "IsStringType -- [1-9][0-9]* call sites")

# How far runtime/pasrt.c is from ISO C, which is the whole of what a port to
# another C library has to satisfy. The cross-platform chapter used to answer
# that by assertion; measured, the runtime's entire departure from the standard
# is four names, and this is what keeps it four. It also asks the other half --
# what the *emitted* module declares -- which is `pas_*`, LLVM intrinsics, and
# `_setjmp`.
#
# Skips (77) on a C library that declares POSIX even under __STRICT_ANSI__,
# because there the question cannot be asked at all.
add_test(NAME runtime-isoc
         COMMAND ${CMAKE_SOURCE_DIR}/tests/checks/runtime_isoc.sh)
set_tests_properties(runtime-isoc PROPERTIES
                     SKIP_RETURN_CODE 77
                     TIMEOUT 600
                     ENVIRONMENT "${APASCAL_TEST_ENV}")

# runtime/pasrt_unicode.c against Unicode's own conformance files -- 20 034
# normalisation cases, 766 segmentation cases and a sweep of every code point
# the first does not list. This is the one oracle in this repository, beside the
# BSI suite, that nobody here wrote (ADR-0086, ADR-0189), and AP 6.4.15 rests on
# two properties no reading taken here could be trusted to settle.
#
# It also regenerates the committed tables from the database and diffs them, so
# the header cannot drift from the version it claims.
#
# Skips (77) when the database is absent; it is fetched, never committed
# (runtime/unicode/fetch.sh). UNICODE_CONFORMANCE_REQUIRE is how CI refuses to
# pass by skipping, as TARGET_SIZES_REQUIRE does.
add_test(NAME unicode-conformance
         COMMAND ${CMAKE_SOURCE_DIR}/tests/checks/unicode_conformance.sh)
set_tests_properties(unicode-conformance PROPERTIES
                     SKIP_RETURN_CODE 77
                     TIMEOUT 600)

# Does a record declared here have the layout the C struct it claims to be has?
# ADR-0184 made a record crossable because RecordLayout *is* C's struct rule,
# and registered in doc/sop.md 7 what that leaves open: whether the fields
# declared are the members the real struct has. `struct stat` is 144 bytes with
# two holes, and a hole in the wrong place makes every field after it wrong
# with no diagnostic anywhere. A source states its claim in a comment
# (@cstruct / @cfield), the compiler reports the offsets it computed
# (--dump-layout), and a C compiler holding the real header judges the two
# together (ADR-0185).
#
# Skips (77) with no C compiler, as target-sizes does. A subject marked
# @cplatform is reported as not-checked here rather than failed, which is the
# only honest answer for a declaration that is one platform's.
add_test(NAME foreign-layout
         COMMAND ${Python3_EXECUTABLE}
                 ${CMAKE_SOURCE_DIR}/tests/checks/foreign_layout.py)
set_tests_properties(foreign-layout PROPERTIES
                     SKIP_RETURN_CODE 77
                     TIMEOUT 600
                     ENVIRONMENT "${APASCAL_TEST_ENV}")

# And the other half of the same question: do the targets this compiler admits
# agree about where every field of every frame *sits*? LlSize and LlAlign are
# hand-written and answer with one number for every target (ADR-0028), which is
# only correct while that agreement holds. It needs no cross toolchain -- clang
# folds the offsets for any target it has a backend for -- so unlike
# target-sizes it does not skip.
# Annex B of the dialect specification, made mechanical. It records what each
# conformance mode *says* about each construct the dialect adds -- a
# conformance claim, since ADR-0117's containment is about what the two modes
# accept and ADR-0154's rule is that a dialect feature may still change what
# they say. The annex was a table nothing read until this, and it was wrong:
# it claimed the two modes agree, and ISO 7185's parser stops at the `..` in
# `a[i..j]` where Extended Pascal parses it and Sema refuses it.
#
# Fails in both directions -- a row with no cases, and a `*_refused` case no
# row names, which is the one a sixth dialect feature would trip.
if(Python3_FOUND)
endif()

if(Python3_FOUND)
  add_test(NAME target-layout
           COMMAND ${Python3_EXECUTABLE}
                   ${CMAKE_SOURCE_DIR}/tests/checks/target_layout.py)
  set_tests_properties(target-layout PROPERTIES
                       TIMEOUT 600
                       ENVIRONMENT "${APASCAL_TEST_ENV}")
endif()

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
                   ${CMAKE_SOURCE_DIR}/tools/pascalcc ${t})
  set_tests_properties(${name} PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")
endforeach()

# The Extended Pascal cases. They live apart for a reason ADR-0232 dissolved --
# the directory used to say which standard a source was written in -- and the
# split is kept because the ctest names are what people run by, and because
# `tests/` globs are not recursive: moving them would rename 219 cases and lose
# every reference to them in the documents and the decision records.
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
                     ${CMAKE_SOURCE_DIR}/tools/pascalcc ${t})
    set_tests_properties(${dir}-${name} PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")
  endforeach()
endforeach()

# The lexer's own corpus: deliberately not a valid program, carrying the
# lexical corner cases a valid one never reaches.
add_test(NAME torture
         COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                 ${CMAKE_SOURCE_DIR}/tools/pascalcc
                 ${CMAKE_SOURCE_DIR}/selfhost/torture.pas)
set_tests_properties(torture PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")

file(GLOB APASCAL_EXTENDED_TESTS ${CMAKE_SOURCE_DIR}/tests/extended/*.pas)
foreach(t ${APASCAL_EXTENDED_TESTS})
  get_filename_component(name ${t} NAME_WE)
  add_test(NAME ${name}
           COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                   ${CMAKE_SOURCE_DIR}/tools/pascalcc ${t})
  set_tests_properties(${name} PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}")
endforeach()

# The dialect cases (ADR-0117), globbed separately -- which now buys the
# per-case TIMEOUT below rather than a flag, there being one language since
# ADR-0232.
file(GLOB APASCAL_DIALECT_TESTS ${CMAKE_SOURCE_DIR}/tests/dialect/*.pas)
foreach(t ${APASCAL_DIALECT_TESTS})
  get_filename_component(name ${t} NAME_WE)
  add_test(NAME ${name}
           COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                   ${CMAKE_SOURCE_DIR}/tools/pascalcc ${t})
  # A timeout, which the other two corpora do not need and this one does: a
  # dialect case may open a socket (ADR-0203), and a readiness defect makes a
  # server *block* rather than print the wrong thing (ADR-0205). Every case
  # here runs in well under a second, so 300 is a backstop and not a budget --
  # what it buys is that a hang is reported as a failed case instead of
  # stopping the suite.
  set_tests_properties(${name} PROPERTIES ENVIRONMENT "${APASCAL_TEST_ENV}"
                       TIMEOUT 300)
endforeach()
