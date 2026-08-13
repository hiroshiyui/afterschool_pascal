# 74. A restriction the document invented, and a message that explained nothing

Date: 2026-08-13

## Status

Accepted.

## Context

ADR-0073 wrote `doc/implementation-defined.md` and closed with a list of the
answers no test pins. Two entries on it were worse than unpinned. One was an
answer to a question the standards do not ask, and the document justified it by
citing a clause that says something else. The other was a message this compiler
had been giving since structured types landed, which reports a rule accurately
and explains nothing — and which a golden file has recorded, unremarked, ever
since.

Both were found by reading the clause rather than by running anything, which is
the same route ADR-0071, ADR-0072 and ADR-0073 each took. Neither could have
been found any other way: an oracle compares what a compiler does against what
it did, and both of these were wrong in a way it had always been.

## Decision

**A program-parameter need not possess a file-type.** ISO 7185 §6.10 requires
each program-parameter to have a defining-point as a variable-identifier of the
program-block and then says exactly this about what it is bound to: "The binding
of the variables denoted by the program-parameters to entities external to the
program shall be implementation-dependent, except if the variable possesses a
file-type in which case the binding shall be implementation-defined." A non-file
program-parameter is therefore a program the standard has; the sentence exists
to say how strongly the implementation must document one. ISO/IEC 10206:1991
§6.12 drops the distinction and makes every program-parameter's binding
implementation-defined without mentioning files at all.

This compiler refused one, with a message — "a program parameter must be a file
variable" — asserting a rule neither standard contains.

**The binding chosen is to no external entity.** The variable is an ordinary
variable of the program-block, undefined until the program assigns it, which
§6.12's NOTE 2 ("variables that are program-parameters are not necessarily bound
when the program is activated") is what makes an available answer rather than an
omission. **It consumes no command-line argument**, so the file parameters keep
the positions they would have had without it — that is the half of the answer a
reader cannot guess, and `tests/progparam_nonfile.pas` is what pins it, by
putting a non-file parameter *between* two files and requiring the second still
to be argument two.

**A message that names two types says why they are two.** §6.4.1 of both
standards is the rule — "Each occurrence of a new-type shall denote a type that
is distinct from any other new-type" — so two type-denoters written alike denote
two types. `Type::name()` writes an anonymous type the way the source wrote it,
so both halves of the message then print the same characters:

    cannot assign record x end to a variable of type record x end

`distinctTypeNote` supplies the missing sentence, in two forms. Where both types
are anonymous there is something to do about it and the message says it: declare
one named type and give it to both. Where both are type-*names* that print alike
— a `t` inside a procedure that redefines a `t` from the program — the reason is
identical, but repeating "give it a name" would be no advice, so that half is
left off. It is added to the five messages that name two types: an assignment,
an assignment to a function's result, a relational operator, a var parameter and
a value parameter.

## Consequences

**The document had asserted the restriction was correct, with a citation that
says the opposite.** Its F.10 entry read that Extended Pascal §6.12 "requires a
program-parameter to be bindable, and only a file is bindable". §6.12 requires
no such thing, and §6.5.1 goes the other way: "The variable-identifier shall
possess the bindability denoted by the type-denoter, **unless** the
variable-identifier is a program-parameter or a module-parameter, in which case
the variable-identifier shall possess the bindability that is bindable." Being a
program-parameter *confers* bindability; it does not demand it. ISO/IEC
10206:1991's own introduction names "bindable internal (file and non-file)
[variables]" in as many words.

This is ADR-0072's wrong-citation lesson arriving in the document that clause
5.1 requires, one commit after that document was written — and it is worse
there than in a test comment, because the document is the artefact a reader
consults instead of the source. Four more comments in the compiler and one entry
in `doc/glossary.md` asserted the same invented rule; all five are corrected.

**The note belongs to incompatibility and to nothing else, and one existing
golden proved it.** The first version added the sentence to every complaint a
relational operator makes, and `tests/type_errors.pas` went red — it compares
two alike-looking records, and §6.7.2.5 gives a record no relational operators at
all. Naming the type would not give it any, so the note was offering a cure for
a different disease. Only the *compatible* complaint is one that type identity
can cause; every other word the message can use — numeric, set, boolean,
comparable — names a property of the type's **kind**, which two types written
alike necessarily share. `BadOperands` takes a flag for it rather than deciding
from the word.

That golden file is also the evidence for how invisible the original message
was. `tests/type_errors.err` has recorded

    operator '=' needs comparable operands, found record a, b end and record a,
    b end

since structured types landed. Nothing distinguishes a message that reports a
rule from one that explains it, so `difftest.sh` — the one oracle here that sees
a diagnostic at all — compared two compilers that were unhelpful in the same way
and reported that they agreed.

**The comparison is capped, and both compilers carry the same cap.** The
question is "do these two print alike", and `selfhost/compiler.pas` can only ask
it by rendering both through the `msgBuf` sink, whose capacity is `strMax`. A
longer spelling is a question it cannot answer, so the C++ declines to answer it
either: `kTypeNameCompareLimit` is 255 beside the note in `src/sema.cpp`, and
a diagnostic the two compilers disagree about is worse than one neither gives.
That is the coupling `fileSize` already has with `PAS_FILE_SIZE`. It is checked
rather than asserted — `tests/distincttypes_errors.pas` declares a pair of types
whose spelling is 263 characters, and removing the limit from the C++ alone
fails both that golden and `difftest.sh`.

### What this does not do

**It does not bind a non-file program-parameter to anything.** A program could
plausibly want its `n` filled in from `argv[1]`, and §6.10 leaves an
implementation free to do that. Nothing in either standard says how such a
value would be spelled or what a malformed one would mean, so inventing a
lexis for it here would be an extension rather than an answer, and clause 5.1
g) would then require it to be described as one.

**It does not touch the imported case.** ISO/IEC 10206:1991 §6.12 lets a
program-parameter be "an imported variable-identifier that is a
module-parameter", and says such a one is *not* designated a program-parameter
— its binding is the module-parameter's. This compiler gives it the next
command-line argument, which is a legal implementation-defined answer for a
module-parameter (§6.11.1 makes that binding implementation-defined too), so
nothing here is wrong; but the two clauses reach it by different routes and only
one of them is written down.

**It does not add the note anywhere a message names one type.** "a value of type
vector cannot be written" and its like are unambiguous already, and a message
that named two *lengths* rather than two types needs nothing, because two
different lengths never print alike.
