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

# ---- The compiler itself ----
add_executable(pascalc
  src/main.cpp
  src/diag.cpp
  src/lexer.cpp
  src/parser.cpp
  src/sema.cpp
  src/codegen.cpp
)
target_include_directories(pascalc PRIVATE src ${LLVM_INCLUDE_DIRS})
target_compile_definitions(pascalc PRIVATE
  ${LLVM_DEFINITIONS_LIST}
  APASCAL_RUNTIME_DIR="${CMAKE_BINARY_DIR}/lib"
)
target_link_libraries(pascalc PRIVATE ${APASCAL_LLVM_LIBS})
add_dependencies(pascalc pasrt)

if(NOT LLVM_ENABLE_RTTI)
  target_compile_options(pascalc PRIVATE -fno-rtti)
endif()

# ---- Tests ----
enable_testing()

# Formal verification of the lowering rules (verify/). Skips rather than fails
# when z3 is absent, so a checkout without it still builds and tests green.
find_package(Python3 COMPONENTS Interpreter QUIET)
if(Python3_FOUND)
  add_test(NAME verify-lowering
           COMMAND ${Python3_EXECUTABLE} ${CMAKE_SOURCE_DIR}/verify/verify.py
                   --pascalc $<TARGET_FILE:pascalc>)
  set_tests_properties(verify-lowering PROPERTIES
                       SKIP_RETURN_CODE 77
                       TIMEOUT 900)
endif()

file(GLOB APASCAL_TESTS ${CMAKE_SOURCE_DIR}/tests/*.pas)
foreach(t ${APASCAL_TESTS})
  get_filename_component(name ${t} NAME_WE)
  add_test(NAME ${name}
           COMMAND ${CMAKE_SOURCE_DIR}/tests/run_test.sh
                   $<TARGET_FILE:pascalc> ${t})
endforeach()
