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
| [0036](0036-a-non-decimal-literal-is-lexical-and-nothing-else.md) | A non-decimal literal is lexical and nothing else | Accepted |
| [0037](0037-exponentiation-is-two-operators-and-a-precedence-level.md) | Exponentiation is two operators, and a precedence level of its own | Accepted |
| [0038](0038-a-word-symbol-may-be-two-words.md) | A word-symbol may be two words | Accepted |
| [0039](0039-a-discriminated-schema-produces-an-ordinary-type.md) | A discriminated schema produces an ordinary type | Accepted |
| [0040](0040-a-schematic-formal-parameter-carries-its-discriminants.md) | A schematic formal parameter carries its discriminants beside the address | Accepted |
| [0041](0041-a-discriminant-may-be-evaluated-on-entry.md) | A discriminant may be evaluated when the block is entered | Accepted |
| [0042](0042-a-schematic-assignment-compares-the-tuples.md) | An assignment between two schematic types compares the tuples | Accepted |
| [0043](0043-a-heap-variables-tuple-is-a-header-in-front-of-it.md) | A heap variable's tuple is a header in front of it | Accepted |
| [0044](0044-a-discriminant-may-be-the-variant-selector.md) | A discriminant may be the variant-selector | Accepted |
| [0045](0045-a-record-may-hold-a-dynamic-array-last.md) | A record may hold a dynamically bounded array, last | Accepted |
| [0046](0046-a-protected-parameter-is-a-rule-about-the-body.md) | A protected parameter is a rule about the body | Accepted |
| [0047](0047-a-type-inquiry-hands-back-a-type-that-already-exists.md) | A type-inquiry hands back a type that already exists | Accepted |
| [0048](0048-an-initial-state-belongs-to-the-type-denoter.md) | An initial state belongs to the type-denoter | Accepted |
| [0049](0049-complex-is-a-simple-type-and-therefore-a-vector.md) | `complex` is a simple type, and therefore a vector | Accepted |
| [0050](0050-a-direct-access-file-is-the-sequential-one-plus-a-position.md) | A direct-access file is the sequential one plus a position | Accepted |
| [0051](0051-a-string-value-is-a-pointer-and-a-length.md) | A string value is a pointer and a length | Accepted |
| [0052](0052-binding-is-a-file-name-chosen-while-the-program-runs.md) | Binding is a file name chosen while the program runs | Accepted |
| [0053](0053-a-level-0-activation-record-is-a-global.md) | A level-0 activation record is a global | Accepted |
| [0054](0054-a-constant-expression-is-one-folder-and-every-context-follows.md) | A constant-expression is one folder, and every context follows | Accepted |
| [0055](0055-a-result-that-lives-in-memory-is-the-callers-storage.md) | A result that lives in memory is the caller's storage | Accepted |
| [0056](0056-a-function-access-is-a-parser-change.md) | A function-access is a parser change | Accepted |
| [0057](0057-a-substring-is-a-pointer-a-length-and-an-address.md) | A substring is a pointer, a length, and somewhere to store | Accepted |
| [0058](0058-a-restricted-type-is-a-type-kind.md) | A restricted type is a type kind | Accepted |
| [0059](0059-five-required-things-and-what-each-cost.md) | Five required things, and what each cost | Accepted |
| [0060](0060-readstr-and-writestr-are-a-text-file-made-of-memory.md) | readstr and writestr are a text file made of memory | Accepted |
| [0061](0061-a-structured-value-is-built-not-computed.md) | A structured value is built, not computed | Accepted |
| [0062](0062-a-required-real-constant-is-decimal-text.md) | A required real constant is decimal text | Accepted |
| [0063](0063-a-set-iteration-is-a-walk-over-the-bits.md) | A set-member-iteration is a walk over the bits | Accepted |
| [0064](0064-a-field-width-of-zero-is-three-different-answers.md) | A field width of zero is three different answers | Accepted |
