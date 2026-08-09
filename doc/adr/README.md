# Architecture Decision Records

Each file records one decision, why it was taken, and what it costs. They are
immutable once accepted: a decision that stops being right gets a new record
that supersedes the old one, rather than an edit.

Format is Michael Nygard's: Context, Decision, Consequences, and where useful
the alternatives that were rejected and why.

| # | Decision | Status |
| --- | --- | --- |
| [0001](0001-record-architecture-decisions.md) | Record architecture decisions | Accepted |
| [0002](0002-target-iso-7185-standard-pascal.md) | Target ISO 7185 Standard Pascal | Accepted |
| [0003](0003-llvm-backend-via-cpp-api.md) | Compile through LLVM, driven by the C++ API | Accepted |
| [0004](0004-self-hosting-is-the-near-term-goal.md) | Self-hosting is the near-term goal | Accepted |
| [0005](0005-tag-dispatched-ast-without-cpp-rtti.md) | Tag-dispatched AST instead of C++ RTTI | Accepted |
| [0006](0006-textual-llvm-ir-as-a-first-class-output.md) | Textual LLVM IR is a first-class output | Accepted |
| [0007](0007-c-runtime-library-for-io.md) | Formatted I/O lives in a C runtime library | Accepted |
| [0008](0008-sema-hands-codegen-a-fully-annotated-tree.md) | Sema hands CodeGen a fully annotated tree | Accepted |
| [0009](0009-link-by-invoking-clang.md) | Link by invoking `clang` | Accepted |
| [0010](0010-short-circuit-boolean-operators.md) | Boolean operators short-circuit | Accepted |
| [0011](0011-golden-stdout-tests.md) | Test by comparing program stdout | Accepted |
| [0012](0012-character-strings-for-self-hosting.md) | How the self-hosted source handles strings | Accepted |
| [0013](0013-formal-verification-of-the-lowering.md) | Formal verification of the lowering | Accepted |
| [0014](0014-iso-error-conditions-trap-at-run-time.md) | ISO error conditions trap at run time | Accepted |
| [0015](0015-real-to-integer-conversions-are-range-checked.md) | Real-to-integer conversions are range-checked | Accepted |
| [0016](0016-nested-procedures-use-static-links.md) | Nested procedures use static links | Accepted |
| [0017](0017-structured-types-use-name-equivalence.md) | Structured types are identified by name, and every subscript is checked | Accepted |
| [0018](0018-ordinal-types-and-variant-records.md) | Enumerations and subranges are ordinal types, and variants share storage | Accepted |
| [0019](0019-pointers-and-the-only-forward-reference.md) | Pointers, and the language's only forward reference | Accepted |
| [0020](0020-the-parser-bounds-tree-depth.md) | The parser bounds tree depth, for every walker at once | Accepted |
| [0021](0021-text-files-keep-the-buffer-variable.md) | Text files keep the buffer variable, and program parameters name them | Accepted |
| [0022](0022-the-lexer-port-is-checked-differentially.md) | The lexer port is checked differentially, not by golden output | Accepted |
