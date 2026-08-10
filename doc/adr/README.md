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
| [0018](0018-ordinal-types-and-variant-records.md) | Enumerations and subranges are ordinal types, and variants share storage | Accepted (case default retired by 0033) |
| [0019](0019-pointers-and-the-only-forward-reference.md) | Pointers, and the language's only forward reference | Accepted |
| [0020](0020-the-parser-bounds-tree-depth.md) | The parser bounds tree depth, for every walker at once | Accepted |
| [0021](0021-text-files-keep-the-buffer-variable.md) | Text files keep the buffer variable, and program parameters name them | Accepted |
| [0022](0022-the-lexer-port-is-checked-differentially.md) | The lexer port is checked differentially, not by golden output | Accepted |
| [0023](0023-the-ast-is-a-variant-record-and-a-sibling-list.md) | The AST is a variant record and a sibling list, and the parser port is checked the same way | Accepted |
| [0024](0024-the-stage-1-compiler-becomes-one-source-file.md) | The stage-1 compiler becomes one source file, and Sema is checked on the tree it annotates | Accepted |
| [0025](0025-the-code-generator-is-checked-by-running-it.md) | The code generator is checked by running it, and the bootstrap closes | Accepted |
| [0026](0026-a-variant-part-may-contain-a-variant-part.md) | A variant part may contain a variant part | Accepted |
| [0027](0027-new-selects-the-variants-it-allocates.md) | `new` selects the variants it allocates | Accepted |
| [0028](0028-a-set-is-one-256-bit-word.md) | A set is one 256-bit word | Accepted |
| [0029](0029-goto-is-local-and-checked-by-containment.md) | `goto` is local, and where it may land is a containment test | Accepted (completed by 0032) |
| [0030](0030-a-procedural-parameter-is-a-code-and-link-pair.md) | A procedural parameter is a code-and-link pair | Accepted |
| [0031](0031-a-file-of-t-is-a-text-with-two-constants-changed.md) | A `file of T` is a text file with two constants changed | Accepted |
| [0032](0032-a-non-local-goto-is-a-jump-record-in-the-target-frame.md) | A non-local `goto` is a jump record in the target's frame | Accepted |
| [0033](0033-extended-pascal-is-a-second-language-behind-std.md) | Extended Pascal is a second language, selected by `--std` | Accepted |
| [0034](0034-the-variant-part-completer-is-an-arm-with-no-labels.md) | The variant-part-completer is an arm with no labels | Accepted |
| [0035](0035-a-case-range-is-tested-not-enumerated.md) | A case range is tested, not enumerated | Accepted |
