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
| [0022](0022-the-lexer-port-is-checked-differentially.md) | The lexer port is checked differentially, not by golden output | Superseded by [0085](0085-stage-0-is-retired.md) |
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
| [0060](0060-readstr-and-writestr-are-a-text-file-made-of-memory.md) | readstr and writestr are a text file made of memory | Accepted; its parser deviation retired by [0087](0087-a-required-procedure-may-be-declared-away.md) |
| [0061](0061-a-structured-value-is-built-not-computed.md) | A structured value is built, not computed | Accepted |
| [0062](0062-a-required-real-constant-is-decimal-text.md) | A required real constant is decimal text | Accepted |
| [0063](0063-a-set-iteration-is-a-walk-over-the-bits.md) | A set-member-iteration is a walk over the bits | Accepted |
| [0064](0064-a-field-width-of-zero-is-three-different-answers.md) | A field width of zero is three different answers | Accepted |
| [0065](0065-a-time-stamp-is-eight-numbers-and-the-layout-stays-here.md) | A time stamp is eight numbers, and the layout stays here | Accepted |
| [0066](0066-a-set-value-is-told-from-a-subscript-by-the-symbol.md) | A set-value is told from a subscript by the symbol | Accepted |
| [0067](0067-the-transfer-procedures-are-index-arithmetic.md) | The transfer procedures are index arithmetic, and nothing else | Accepted |
| [0068](0068-a-string-constant-is-its-literal-named.md) | A string constant is its literal, named | Accepted |
| [0069](0069-a-constant-access-is-a-designator-over-a-constant.md) | A constant-access is a designator over a constant | Accepted |
| [0070](0070-a-file-need-not-be-an-entire-variable.md) | A file need not be an entire variable | Accepted |
| [0071](0071-five-things-the-grammar-admitted-and-the-compiler-refused.md) | Five things the grammar admitted and the compiler refused | Accepted |
| [0072](0072-three-things-the-compiler-accepted-and-neither-standard-has.md) | Three things the compiler accepted and neither standard has | Accepted; its set-packing deviation retired by [0093](0093-a-set-constructor-has-not-chosen-a-packing.md) |
| [0073](0073-writing-the-required-document-found-two-bugs.md) | Writing the required document found two bugs | Accepted |
| [0074](0074-a-restriction-the-document-invented-and-a-message-that-explained-nothing.md) | A restriction the document invented, and a message that explained nothing | Accepted |
| [0075](0075-a-constant-may-be-nil.md) | A constant may be nil | Accepted |
| [0076](0076-a-read-that-took-too-much-and-two-brackets-never-provided.md) | A read that took too much, and two brackets that were never provided | Accepted |
| [0077](0077-annex-d-is-a-checklist.md) | Annex D is a checklist | Accepted |
| [0078](0078-the-second-annex-d-was-almost-clean.md) | The second Annex D was almost clean | Accepted |
| [0079](0079-an-interface-is-a-set-of-names.md) | An interface is a set of names | Accepted |
| [0080](0080-the-sweep-that-found-nothing.md) | The sweep that found nothing | Accepted |
| [0081](0081-a-program-can-read-its-own-command-line.md) | A program can read its own command line | Accepted |
| [0082](0082-the-stage-1-compiler-is-extended-pascal.md) | The stage-1 compiler is written in Extended Pascal | Accepted |
| [0083](0083-the-compiler-has-a-command-line.md) | The compiler has a command line | Accepted |
| [0084](0084-halt-takes-an-exit-status.md) | `halt` takes an exit status | Accepted |
| [0085](0085-stage-0-is-retired.md) | Stage 0 is retired | Accepted; seed-refresh policy has one exception, [0095](0095-the-string-pool-was-the-ceiling.md) |
| [0086](0086-an-oracle-this-project-did-not-write.md) | An oracle this project did not write | Accepted |
| [0087](0087-a-required-procedure-may-be-declared-away.md) | A required procedure may be declared away | Accepted |
| [0088](0088-a-defining-point-precedes-its-applied-occurrences.md) | A defining-point precedes its applied occurrences | Accepted |
| [0089](0089-a-for-control-variable-may-not-be-threatened.md) | A `for` control-variable may not be threatened | Accepted |
| [0090](0090-a-string-type-is-four-properties-at-once.md) | A string-type is four properties at once | Accepted |
| [0091](0091-four-structural-rules-the-compiler-did-not-enforce.md) | Four structural rules the compiler did not enforce | Accepted |
| [0092](0092-three-rules-about-a-parameter-list.md) | Three rules about a parameter list | Accepted |
| [0093](0093-a-set-constructor-has-not-chosen-a-packing.md) | A set-constructor has not chosen a packing | Accepted |
| [0094](0094-a-goto-lands-in-a-sequence-and-a-result-belongs-to-its-block.md) | A goto lands in a sequence, and a result belongs to its block | Accepted |
| [0095](0095-the-string-pool-was-the-ceiling.md) | The string pool was the ceiling | Accepted |
| [0096](0096-a-variant-part-covers-its-tag-type-exactly.md) | A variant part covers its tag-type exactly | Accepted |
| [0097](0097-the-required-identifiers-are-symbols.md) | The required identifiers are symbols | Accepted |
| [0098](0098-a-record-type-is-a-region.md) | A record type is a region | Accepted |
| [0099](0099-packing-does-not-reach-a-components-components.md) | Packing does not reach a component's components | Accepted |
| [0100](0100-a-procedure-declaration-is-a-declaration.md) | A procedure declaration is a declaration | Accepted |
| [0101](0101-what-an-independent-reading-found.md) | What an independent reading found | Accepted |
| [0102](0102-an-alloca-belongs-where-it-is-claimed-once.md) | An alloca belongs where it is claimed once | Accepted |
| [0103](0103-coverage-is-an-ir-pass-and-a-comment.md) | Coverage is an IR pass and a comment | Accepted |
| [0104](0104-the-compiler-instruments-itself.md) | The compiler instruments itself | Accepted |
| [0105](0105-scenarios-start-from-the-clause.md) | Scenarios start from the clause | Accepted |
| [0106](0106-the-denominator-is-triaged.md) | The denominator is triaged | Accepted |
| [0107](0107-what-the-second-independent-reading-found.md) | What the second independent reading found | Accepted |
| [0108](0108-the-reference-front-end-comes-back.md) | The reference front end comes back | Accepted |
| [0109](0109-the-goal-is-a-practical-pascal.md) | The goal is a practical Pascal | Accepted |
| [0110](0110-a-limit-is-reported-not-applied-in-silence.md) | A limit is reported, not applied in silence | Accepted |
| [0111](0111-a-string-temporary-lives-for-one-statement.md) | A string temporary lives for one statement | Accepted |
| [0112](0112-a-record-is-a-region-at-every-occurrence.md) | A record is a region at every occurrence | Accepted |
| [0113](0113-a-bound-that-is-not-a-constant-is-a-discriminant.md) | A bound that is not a constant is a discriminant | Accepted |
| [0114](0114-the-standard-library-begins-in-what-is-already-conforming.md) | The standard library begins in what is already conforming | Accepted |
| [0115](0115-a-string-value-parameter-is-converted-by-the-callee.md) | A string value parameter is converted by the callee | Accepted |
| [0116](0116-a-container-is-a-pointer-to-a-schema-and-its-allocator-cannot-be-injected.md) | A container is a pointer to a schema, and its allocator cannot be injected | Accepted |
| [0117](0117-the-dialect-is-a-third-std-and-it-is-extended-pascal-plus.md) | The dialect is a third `--std`, and it is Extended Pascal plus | Accepted |
| [0118](0118-a-sum-type-is-a-variant-record-whose-tag-cannot-lie.md) | A sum type is a variant record whose tag cannot lie | Accepted |
| [0119](0119-the-components-of-one-program-agree-on-the-mode.md) | The program-components of one program agree on the mode | Accepted |
| [0120](0120-a-fallible-routine-answers-one-record-and-the-library-has-two-layers.md) | A fallible routine answers one record, and the library has two layers | Accepted |
| [0121](0121-a-foreign-function-is-a-directive-and-the-boundary-is-two-types-wide.md) | A foreign function is a directive, and the boundary is two types wide | Accepted |
| [0122](0122-an-address-crosses-only-as-an-argument-and-its-lifetime-is-the-call.md) | An address crosses only as an argument, and its lifetime is the call | Accepted |
| [0123](0123-an-optional-is-a-type-and-it-is-how-a-pointer-comes-back.md) | An optional is a type, and it is how a pointer comes back | Accepted |
| [0124](0124-every-case-over-a-type-kind-names-every-kind.md) | Every case over a type kind names every kind, and a gate says so | Accepted |
| [0125](0125-a-slice-is-a-parameter-form-and-the-pair-travels-as-two-words.md) | A slice is a parameter form, and the pair travels as two words | Accepted |
| [0126](0126-the-token-array-was-the-ceiling.md) | The token array was the ceiling, and the headroom is measured now | Accepted |
| [0127](0127-a-type-definitions-bounds-belong-to-the-block.md) | A type-definition's bounds belong to the block | Accepted |
| [0128](0128-an-integer-wider-than-the-compilers-own.md) | An integer wider than the compiler's own | Accepted |
| [0129](0129-a-buffer-crosses-as-the-pair-c-already-takes.md) | A buffer crosses as the pair C already takes | Accepted |
| [0130](0130-a-library-that-moves-bytes.md) | A library that moves bytes, and the first increment that found nothing | Accepted |
| [0131](0131-errno-is-a-macro-so-it-belongs-to-the-runtime.md) | `errno` is a macro, so it belongs to the runtime | Accepted |
| [0132](0132-a-returned-pointer-into-the-callers-own-buffer.md) | A returned pointer into the caller's own buffer | Accepted |
| [0133](0133-the-check-at-a-store-reads-the-descriptor.md) | The check at a store reads the descriptor | Accepted |
| [0134](0134-the-register-read-end-to-end.md) | The register, read end to end | Accepted |
| [0135](0135-the-dialect-gets-a-specification.md) | The dialect gets a specification, and it is written against the standard it amends | Accepted |
| [0136](0136-a-constant-cannot-have-the-wide-type.md) | A constant cannot have the wide type, and saying so is a diagnostic rather than a crash | Accepted |
| [0137](0137-a-module-is-mode-locked-by-what-it-exports.md) | A module is mode-locked by what it exports, not by the flag it was translated with | Accepted |
| [0138](0138-containment-is-witnessed-by-the-corpus.md) | Containment is witnessed by the corpus, not by one program | Accepted |
| [0139](0139-two-slices-are-compatible-and-that-is-not-comparable.md) | Two slices are compatible, and that is not permission to compare them | Accepted |
| [0140](0140-the-dialect-reserves-no-word-symbol.md) | The dialect reserves no word-symbol, and what it does instead has a name | Accepted |
| [0141](0141-one-rule-for-saying-a-routine-may-have-failed.md) | One rule for saying a routine may have failed | Accepted |
| [0142](0142-reachability-follows-a-procedural-parameters-own-parameters.md) | Reachability follows a procedural parameter's own parameters | Accepted |
| [0143](0143-a-slice-is-not-a-value-and-cannot-be-named.md) | A slice is not a value, and 6.4.9 could name one | Accepted |
| [0144](0144-the-first-audit-of-the-dialects-specification.md) | The first audit of the dialect's specification | Accepted |
| [0145](0145-every-enumeration-not-only-the-type-kinds.md) | Every enumeration, not only the type kinds | Accepted |
| [0146](0146-what-a-shared-predicate-permits-it-permits-everywhere.md) | What a shared predicate permits, it permits everywhere | Accepted |
| [0147](0147-one-linker-symbol-one-external-declaration.md) | One linker symbol, one `external` declaration | Accepted |
| [0148](0148-the-pools-headroom-needs-a-flag.md) | The pool's headroom needs a flag; the tokens' did not | Accepted |
| [0149](0149-three-near-overlaps-and-what-divides-them.md) | Three near-overlaps, and the ownership question that divides them | Accepted |
| [0150](0150-a-file-inside-a-record-is-still-a-file.md) | A file inside a record is still a file | Accepted |
| [0151](0151-block-scoped-ownership-and-the-fork-is-forced-by-sharing.md) | Block-scoped ownership is the model, and the fork is forced by sharing | Accepted |
| [0152](0152-the-clauses-with-no-titles.md) | The clauses with no titles | Accepted |
| [0153](0153-conformant-array-parameters-and-level-1.md) | Conformant array parameters, and level 1 | Accepted |
| [0154](0154-the-dialect-changes-what-a-mode-says.md) | The dialect changes what a conformance mode says, not what it accepts | Accepted |
| [0155](0155-a-per-target-maximum-not-a-measurement-of-this-one.md) | A per-target maximum, not a measurement of this one | Accepted |
| [0156](0156-the-emitted-target-is-selectable-and-the-list-is-short.md) | The emitted target is selectable, and the list is deliberately short | Accepted |
