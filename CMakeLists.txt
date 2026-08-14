cmake_minimum_required(VERSION 3.20)
project(afterschool_pascal LANGUAGES C CXX)

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
)
target_link_libraries(pascalc-s0 PRIVATE ${APASCAL_LLVM_LIBS})
add_dependencies(pascalc-s0 pasrt)

if(NOT LLVM_ENABLE_RTTI)
  target_compile_options(pascalc-s0 PRIVATE -fno-rtti)
endif()

# ---- The compiler: written in Afterschool Pascal, built by stage 0 ----
#
# `selfhost/compiler.pas` is the compiler this project is for, and until now it
# was something the test harnesses built for themselves in a temporary
# directory. Building it here makes it the ordinary product of `cmake --build`
# and gives it the name a user reaches for.
#
# It is one source file (ADR-0024) and takes ~3 s, so it is rebuilt whenever
# either the source or stage 0 changes rather than being cached more cleverly.
#
# `--std=extended` because the source is Extended Pascal (ADR-0082), which
# selfhost/compiler.std also says for the shell harnesses. The flag is written
# out here rather than read from that file because CMake would have to read it
# at configure time, and a build system that silently changed language when a
# file changed would be worse than one that says which it means.
set(APASCAL_PASCALC ${CMAKE_BINARY_DIR}/bin/pascalc)
add_custom_command(
  OUTPUT ${APASCAL_PASCALC}
  COMMAND $<TARGET_FILE:pascalc-s0> --std=extended
          ${CMAKE_SOURCE_DIR}/selfhost/compiler.pas -o ${APASCAL_PASCALC}
  DEPENDS pascalc-s0 pasrt ${CMAKE_SOURCE_DIR}/selfhost/compiler.pas
          ${CMAKE_SOURCE_DIR}/selfhost/compiler.std
  COMMENT "Building pascalc from selfhost/compiler.pas with pascalc-s0"
  VERBATIM
)
add_custom_target(pascalc ALL DEPENDS ${APASCAL_PASCALC})

# ---- Tests ----
enable_testing()

# Formal verification of the lowering rules (verify/). Skips rather than fails
# when z3 is absent, so a checkout without it still builds and tests green.
find_package(Python3 COMPONENTS Interpreter QUIET)
if(Python3_FOUND)
  add_test(NAME verify-lowering
           COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/verify/verify.py
                   --pascalc $<TARGET_FILE:pascalc-s0>)
  set_tests_properties(verify-lowering PROPERTIES
                       SKIP_RETURN_CODE 77
                       TIMEOUT 900)
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
         COMMAND ${CMAKE_SOURCE_DIR}/selfhost/irtest.sh
                 $<TARGET_FILE:pascalc-s0>)
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
                   $<TARGET_FILE:pascalc-s0> ${t} iso7185)
endforeach()

# ISO/IEC 10206:1991 cases. They live apart because the standard is a property
# of the source, not of the case: a program using `otherwise` is not a valid
# ISO 7185 program, and the directory is what says so to every harness that
# walks the tree (ADR-0033).
file(GLOB APASCAL_EXTENDED_TESTS ${CMAKE_SOURCE_DIR}/tests/extended/*.pas)
foreach(t ${APASCAL_EXTENDED_TESTS})
  get_filename_component(name ${t} NAME_WE)
  add_test(NAME ${name}
           COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                   $<TARGET_FILE:pascalc-s0> ${t} extended)
endforeach()
