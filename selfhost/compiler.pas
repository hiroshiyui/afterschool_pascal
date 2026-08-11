program Compile(output, source, ircode, options);

{ The self-hosted compiler: stage 1, components 1 to 3 -- the lexer, the parser
  and the AST, and Sema.

  ISO 7185 has no include mechanism, so the finished compiler is *one source
  file*, and this is it. Each component is merged in as it is ported rather
  than kept as a program of its own: a second file would need its own copy of
  everything below it, and by Sema that would have been three copies of the
  lexer. What the merge costs is the ability to run one stage alone, which is
  why the program dumps all three stages in one pass and difftest.sh compares
  the lot against `pascalc --dump-all`.

  A port of src/lexer.cpp, src/parser.cpp, src/ast.h, src/sema.cpp and
  src/type.h into the language that compiler accepts, checked by comparing what
  it produces against what they produce, on every file in the tree.

  This is where the bootstrap constraints of ADR-0005 stop being a precaution
  and start paying: the NK tag is a variant record's tag, and as<T>(n) is the
  case statement that reads it. Nothing here needs a dynamic_cast, because the
  C++ side was written to need none either.

  Three shapes are forced by the language rather than chosen:

  * std::vector<ExprPtr> becomes a sibling list. Every node carries `next`,
    and a list is a head pointer; a growable array would be a second data
    structure to write, and the tree only ever walks these in order.

  * The parser's one exception (ParseAbort) becomes a flag. Pascal has no
    exceptions, and this compiler has no goto, so `aborted` is tested by every
    loop and every production instead of unwinding the stack.

  * ISO 7185 6.4.3.3 requires a record's field identifiers to be distinct
    across all variants, so the arms cannot all call their operands `base` and
    `next` the way the C++ structs do. Hence the two-letter prefixes.

  The lexer below is selfhost/lexer.pas with its emitting replaced by filling a
  token table -- the same source, kept identical on purpose, since a merged
  compiler has one copy of it. }

const
  strMax   = 255;    { longest identifier or string literal kept }
  kwWidth  = 9;      { 'procedure', the longest reserved word }
  { The capacity of BindingType.name. ISO/IEC 10206:1991 6.4.3.4 makes the
    field "an implementation-defined variable-string-type" and says nothing
    more, so the number is this compiler's; it is a file name's worth. }
  bindNameCap = 255;
  wordWidth = 12;    { the longest word a diagnostic passes about, padded }
  msgWidth = 16;     { 'packed array [', the longest piece of a type name }
  textWidth = 40;    { the longest fixed part of a runtime-error message }
  { Which noun a diagnostic calls a schema's generic production by. Three
    places ask for one: a parameter form (6.7.3.1), a variable's type
    (6.2.3.2), and a pointer domain (6.4.4). }
  nounParamForm = 0;
  nounVarType = 1;
  nounPointerDomain = 2;
  kwCount  = 40;     { 35 word-symbols of ISO 7185, then ISO 10206's }
  isoKwCount = 35;   { how many of them ISO 7185 reserves }
  nul      = 0;      { what Peek yields past the end, as the C++ lexer does }
  tab      = 9;
  newline  = 10;
  creturn  = 13;
  { Sized for this compiler's own source with room to grow: it is the largest
    Pascal in the tree, and the one that has to keep fitting. Both are frame
    storage, so they are the fixed-buffer limits ADR-0012 predicted -- and both
    fail loudly rather than silently truncating. }
  poolMax  = 400000; { characters of identifier and literal text }
  tokMax   = 90000;
  maxDepth = 1000;   { ADR-0020, and the same number the C++ parser uses }
  { The size of a file variable's storage, which is PAS_FILE_SIZE in
    runtime/pasrt.h. The C++ code generator includes that header so the two
    cannot disagree; ISO 7185 has no include mechanism, so this side repeats
    the number and selfhost/irtest.sh checks that the two still match. }
  fileSize = 96;
  { The storage a block needs to be the target of a non-local `goto`, which is
    PAS_JUMP_SIZE in runtime/pasrt.h -- opaque here for the same reason a file
    variable's is, and checked against that header by selfhost/irtest.sh. }
  jumpSize = 256;
  { Every set is one 256-bit word, so a set's base type must have its values
    in 0..setLimit (ADR-0028). That admits `char` exactly. }
  setLimit = 255;
  setBits  = 256;

type
  strLen = 0..strMax;
  str = record
    len: strLen;
    ch: packed array [1..strMax] of char
  end;
  kwLit = packed array [1..kwWidth] of char;
  wordLit = packed array [1..wordWidth] of char;
  { Two more padded-literal widths, for the pieces a runtime-error message is
    built out of. A trap message is a *string constant in the generated
    program*, so unlike a diagnostic it cannot be written as it is computed --
    it has to be assembled first and emitted afterwards. }
  msgLit = packed array [1..msgWidth] of char;
  textLit = packed array [1..textWidth] of char;

  tokenKind = (
    tkEof, tkIdent, tkInt, tkReal, tkStr,
    tkPlus, tkMinus, tkStar, tkSlash, tkAssign, tkComma, tkSemi, tkColon,
    tkPeriod, tkDotDot, tkLParen, tkRParen, tkLBracket, tkRBracket, tkCaret,
    tkEq, tkNotEq, tkLt, tkLe, tkGt, tkGe,
    tkAnd, tkArray, tkBegin, tkCase, tkConst, tkDiv, tkDo, tkDownto, tkElse,
    tkEnd, tkFile, tkFor, tkFunction, tkGoto, tkIf, tkIn, tkLabel, tkMod,
    tkNil, tkNot, tkOf, tkOr, tkPacked, tkProcedure, tkProgram, tkRecord,
    tkRepeat, tkSet, tkThen, tkTo, tkType, tkUntil, tkVar, tkWhile, tkWith,
    { ISO/IEC 10206:1991 word-symbols, reserved only under the extended
      standard. Under ISO 7185 the scanner yields these spellings as
      identifiers, which is what they are in that language. }
    tkOtherwise, tkPow, tkProtected, tkValue, tkBindable,
    { And the one operator ISO/IEC 10206:1991 spells in symbols. It is scanned
      under both standards and refused under ISO 7185, where no valid program
      can hold two adjacent stars outside a comment or a string anyway. }
    tkStarStar,
    { 6.1.2 spells the short-circuit operators as *two words with a separator
      between them* -- `and then` and `or else` are each one word-symbol, not
      a pair. They reserve nothing new, because both halves are already
      word-symbols of ISO 7185, and the scanner builds them by joining two
      tokens rather than by looking a spelling up. }
    tkAndThen, tkOrElse);

  { Which standard the source is written in. ISO 7185 is the default: the whole
    test corpus, and this compiler's own source, are written in it -- and this
    file has a record field named `value`, which ISO 10206 reserves. Selecting
    the language is a real choice and not a convenience (ADR-0033). }
  stdKind = (stdIso7185, stdExtended);

  token = record
    kind: tokenKind;
    line, col: integer;
    at, len: integer;   { the spelling or value, in the pool }
    intVal: integer;
    { A literal too large for the integer type. The value left behind is an
      accident of whatever conversion detected it, so both dumps print a
      placeholder rather than comparing two accidents. }
    tooBig: boolean
  end;

  { What follows 'expected X' in a message from Expect. The C++ parser passes
    the phrase itself; a padded literal per phrase would cost more than the
    case statement that writes them, so the call site names the place instead
    of spelling it. }
  ctxKind = (
    ctxNone, ctxProgramStart, ctxProgramParams, ctxProgramHeader, ctxFinalEnd,
    ctxAfterFile, ctxAfterSet, ctxSetMembers, ctxSubrangeBounds, ctxEnumConstants, ctxAfterArray,
    ctxSchemaArgs, ctxFormalDisc, ctxTypeInquiry, ctxDirectIndex,
    ctxArrayIndex, ctxRecordEnd, ctxFieldList, ctxVariantTag,
    ctxVariantLabels, ctxVariantOpen, ctxVariantFields, ctxVariantClose,
    ctxConstDef, ctxConstDefEnd, ctxTypeDef, ctxTypeDefEnd, ctxVarDecl,
    ctxVarDeclEnd, ctxParamList, ctxParamListEnd, ctxProcHeading, ctxProcBody,
    ctxCompoundStart, ctxCompoundEnd, ctxIf, ctxWhile, ctxRepeatEnd, ctxFor,
    ctxCaseSelector, ctxCaseLabels, ctxCaseEnd, ctxWith, ctxAssign,
    ctxProcCallArgs, ctxWriteArgs, ctxReadArgs, ctxSubscript, ctxParenExpr,
    ctxCallArgs, ctxAfterGoto, ctxLabelStart, ctxAfterLabel, ctxLabelDecl,
    ctxAfterLabelPart, ctxFuncParamResult);

  { `in` is a relational operator (ISO 7185 6.7.2.4) and sits at the same
    precedence as `=`, which is why it belongs here rather than with the
    adding operators despite taking a set on only one side. }
  { opExp and opPow are ISO/IEC 10206:1991 6.8.3.2's exponentiating operators.
    They differ in more than spelling: `**` converts both operands to real and
    yields a real, while `pow` takes an integer right operand and yields the
    type of its left one -- so `2 pow 3` is the integer 8 and `2 ** 3` is 8.0. }
  { opAndThen and opOrElse are 6.8.3.3's short-circuit operators. This compiler
    already evaluates `and` and `or` that way (ADR-0010), so they lower
    identically -- but the standard only *permits* that for `and` and `or`
    while *requiring* it here, and a tree spelling both as opAnd would have
    thrown away the one fact that says which. }
  binaryOp = (opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
              opExp, opPow, opAndThen, opOrElse,
              opEq, opNe, opLt, opLe, opGt, opGe, opIn);
  unaryOp = (opPos, opNeg, opNot);

  { The tag ADR-0005 has been carrying since the first commit. Expressions and
    statements are the C++ NK enumeration; the rest are the plain structs of
    ast.h, which become nodes here because one arena and one walker is less
    code than five parallel ones. }
  nodeKind = (
    { expressions }
    nkInt, nkReal, nkChar, nkStr, nkNil, nkSet, nkSetMember, nkVar, nkIndex,
    nkField, nkDeref, nkBinary, nkUnary, nkCall,
    { statements }
    nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
    nkFor, nkProcCall, nkWith, nkCase, nkGoto, nkLabeled,
    { the pieces the C++ side keeps in vectors of plain structs }
    nkWriteArg, nkCaseArm, nkVariantArm, nkGroup, nkDeclName,
    { type denoters }
    nkNamed, nkEnum, nkSubrange, nkArray, nkRecord, nkPointer, nkFile,
    nkSetOf,
    { ISO/IEC 10206:1991 6.4.8's discriminated-schema. The only type-denoter
      whose children are expressions rather than denoters. }
    nkSchema,
    { 6.4.9's type-inquiry, `type of x`. The only type-denoter that names a
      *variable*: what it denotes is the type that variable possesses, which is
      why its name is resolved in the ordinary scope rather than among the
      types. }
    nkInquiry,
    { declarations }
    nkConstDecl, nkTypeDecl, nkProcDecl, nkLabelDecl, nkBlock);

  { ------------------------------------------------------- Sema's own types }

  { skProcParam is a procedural or functional parameter (ISO 7185 6.6.3.1).
    Its frame slot holds a *pair*: the code to call, and the static link to
    call it with -- the link of the block the actual procedure was declared
    in, not of the caller. `stype` is the procedural type and its `elem` is
    the result type, nil for a procedural parameter as against a functional
    one. }
  { skSchema is ISO/IEC 10206:1991 6.4.7's schema: a mapping from discriminant
    tuples to types. It is not a type -- nothing possesses it and it has no
    values -- so naming one where a type-denoter is wanted is an error until
    its discriminants are given. }
  { skDisc is one formal discriminant of a *schematic formal parameter*, as
    seen from inside the block (6.7.3.2). It has storage -- the slot of the
    parameter it belongs to holds the address and then the tuple -- but it is
    not a variable: nothing may assign to it, and it is in scope only while
    the parameter's type is being resolved. Afterwards `v.n` is the only way
    to name it, which is what 6.8.4 makes a primary. }
  symKind = (skConst, skType, skVar, skParam, skVarParam, skProcParam, skDisc,
             skProc, skFunc, skSchema);

  { How a file variable reaches something outside the program. ISO 7185 6.10
    makes only a *program parameter* external; every other file variable is a
    scratch file with no name, which is what skInternal means. }
  fileBinding = (fbInternal, fbStdInput, fbStdOutput, fbArgument);

  { tyProc is the type of a procedural or functional parameter. There is no
    way to *write* one outside a formal parameter list -- the type part has no
    procedure type -- so no variable ever has it, and it takes part in no
    operation but being passed on and being called. }
  { ISO/IEC 10206:1991 6.4.2.2 e): "The required type-identifier `complex`
    shall denote the complex-type. The complex-type shall be a
    **simple-type**." Simple is the operative word -- a complex value is
    assigned, passed and returned as a value, so none of the by-address
    machinery touches it, exactly as for a set. }
  typeKind = (tyVoid, tyInteger, tyReal, tyBoolean, tyChar, tyEnum, tySubrange,
              tyArray, tyRecord, tyPointer, tyFile, tySet, tyProc, tyComplex,
              { ISO/IEC 10206:1991 6.4.3.3.3's variable-string-type: a type
                produced from the required schema `string`. Its value is a
                length and that many characters, and the length may be anything
                from zero up to the *capacity* -- the schema's one discriminant.
                `hi` holds the capacity, `hiDisc` the discriminant it came from
                when an actual brought it, and `lo` is 1 because 6.4.3.3.1
                makes every string's index-domain start there.

                The *canonical*-string-type of 6.4.3.3.1 -- the type of `+`,
                `substr` and `trim` -- is this kind with `hi` negative: a value
                with no storage and so no capacity to exceed. }
              tyString);

  { The required functions of ISO 7185, and the standard procedures that are
    not statements of their own. }
  builtinKind = (biNone, biAbs, biSqr, biOdd, biOrd, biChr, biSucc, biPred,
                 biSqrt, biSin, biCos, biLn, biExp, biArcTan, biTrunc, biRound,
                 biEof, biEoln,
                 { 6.7.6.3's constructors and 6.7.6.2's accessors. cmplx and
                   polar are the only way to *write* a complex value -- the
                   standard gives the type no literal -- and re, im and arg are
                   the only way back out to a real. }
                 biCmplx, biPolar, biRe, biIm, biArg,
                 { 6.7.6.6's direct-access position functions and 6.7.6.5's
                   `empty`. All three take a file variable, so they join eof
                   and eoln in taking an *address* rather than a value. }
                 biPosition, biLastPosition, biEmpty,
                 { 6.7.6.7's string functions. The six comparisons are
                   deliberately *not* the operators: NOTE 3 points out that
                   LT(a,b) may be false where a<b is true, because these
                   compare lengths as well as characters and the operators pad
                   with spaces instead. }
                 biLength, biIndex, biSubstr, biTrim,
                 biStrEq, biStrNe, biStrLt, biStrGt, biStrLe, biStrGe,
                 { 6.7.6.8's `binding`, the only required function whose result
                   is a *record*. It is given a hidden frame slot to be built
                   in -- the same mechanism a `with` binding uses -- so that
                   `b := binding(f)` is an ordinary designator. }
                 biBinding);
  { ISO/IEC 10206:1991 6.7.5.2's direct-access procedures join ISO 7185's. The
    three seeks differ only in the mode they leave the file in; update writes
    the buffer variable back without advancing; extend opens for writing at the
    end, and is the one of the five that needs no direct-access file. }
  stdProcKind = (spNone, spNew, spDispose, spReset, spRewrite, spGet, spPut,
                 spSeekRead, spSeekWrite, spSeekUpdate, spUpdate, spExtend,
                 { 6.7.5.6's binding procedures. bind attaches a variable to an
                   entity outside the program and unbind detaches it. }
                 spBind, spUnbind);

  typePtr = ^typeRec;
  symPtr = ^symbol;
  producedPtr = ^producedRec;
  { Forward, because a schema's symbol holds the *syntax* of its body: a
    schema-definition has no type until a tuple gives its discriminants
    values, so what the symbol keeps is a type-denoter (6.4.7). }
  nodePtr = ^node;
  fieldPtr = ^fieldRec;
  variantPtr = ^variantRec;
  numPtr = ^numRec;
  rangePtr = ^rangeRec;
  namePtr = ^nameRec;
  symListPtr = ^symListRec;

  numRec = record value: integer; next: numPtr end;
  { A folded case-constant: the closed interval it denotes. A single
    constant is lo = hi, so every user of a label list works one way and a
    range is never expanded into its members -- `1..maxint` is one of
    these and two billion switch cases if expanded. }
  rangeRec = record lo, hi: integer; next: rangePtr end;
  nameRec = record at, len: integer; next: namePtr end;
  symListRec = record sym: symPtr; next: symListPtr end;

  { One field of a record. `index` is the position in the struct it belongs to,
    which is also the declaration order; `variant` says which struct that is --
    -1 for the fixed part, otherwise the arm. }
  fieldRec = record
    at, len: integer;
    ftype: typePtr;
    index: integer;
    { 6.6: a field's own type-denoter may carry an initial-state-specifier, and
      then the record's initial state has that field bearing that value. }
    initValue: nodePtr;
    { Where the field lives, as a path: nil is the record's fixed part, (0) is
      arm 0 of its variant part, (0, 1) is arm 1 of the variant part inside arm
      0. ISO 7185 6.4.3.3 puts no limit on the nesting, so a single index could
      not say where a field is. }
    variant: numPtr;
    line, col: integer;
    next: fieldPtr
  end;

  { One arm of a variant part. An arm is shaped exactly like a record -- a
    fixed part and an optional variant part of its own -- because that is what
    6.4.3.3 makes it: its field-list is a field-list like any other. }
  variantRec = record
    labels: rangePtr;
    { selected by whatever the other arms leave (Extended Pascal's
      variant-part-completer) }
    isOtherwise: boolean;
    fields, fieldTail: fieldPtr;
    variants, variantTail: variantPtr;
    tagField: integer;
    tagType: typePtr;
    { The nested variant-selector was a discriminant-identifier rather than a
      tag-type (6.4.3.4). See typeRec's discSelector. }
    discSelector: boolean;
    line, col: integer;
    next: variantPtr
  end;

  { A Pascal type. Simple types are shared singletons; every array or record
    *type-denoter* in the source produces one of these. Identity is therefore
    what ISO 7185 6.4.5 calls "the same type" (ADR-0017). }
  typeRec = record
    kind: typeKind;
    { Array: the component type. Pointer: the domain, nil only for `nil`
      itself. File: the component type. Sharing the field is what a variant
      record would do, which is where the C++ one was going. }
    elem, indexType, host, tagType: typePtr;
    isPacked: boolean;
    { File: this is `text`, not a `file of char`. ISO 7185 6.4.3.5 makes them
      different types and gives only the first one lines, so readln, writeln,
      eoln and reading a number all belong to a text file and to nothing
      else. Nothing but this flag distinguishes the two. }
    isText: boolean;
    lo, hi: integer;
    enumNames, enumTail: namePtr;
    fields, fieldTail: fieldPtr;
    variants, variantTail: variantPtr;
    tagField: integer;
    { 6.4.3.4 spells a variant-selector `[tag-field ':'] tag-type |
      discriminant-identifier`, and this says it was the third form. The
      selector is then not a field -- the tuple holds it -- so the *layout* is
      a tagless `case T of` and CodeGen never asks. What it changes is that
      6.7.5.3 requires a tag-type of every variant-part `new(p, c1, ..., cn)`
      selects, so this variant part is not one a tag value may choose. }
    discSelector: boolean;
    aliasAt, aliasLen: integer;
    { 6.4.7 and 6.4.8: the schema this type was produced from and the tuple it
      was produced with, nil and empty for every type written out in full.
      Sema interns by the pair, so "one tuple, one type" needs no rule in
      Assignable -- two productions with equal tuples *are* the same record. }
    schema: symPtr;
    tuple, tupleTail: numPtr;
    { 6.7.3.2 and 6.7.3.3: a bound that is not known until the block is
      entered -- the discriminant the source wrote there, whose value arrives
      with the actual. lo/hi are then not the bound and nothing reads them.
      Nil for every bound written as a constant, which is every bound outside
      a schematic formal parameter. }
    loDisc, hiDisc: symPtr;

    { 10206 6.4.4: this type's tuple is in a header immediately before the
      variable rather than in an activation record -- it is the domain of a
      pointer written as a bare schema-name, and `new` supplied the tuple
      (ADR-0043). descOwner holds its discriminant symbols, because a heap
      variable is reached through `p^` and so has no name to hang them on. }
    heapTuple: boolean;
    descOwner: symPtr
  end;

  symbol = record
    at, len: integer;
    kind: symKind;
    stype: typePtr;
    binding: fileBinding;
    fileArg: integer;
    { The value of a constant, in whichever field its type selects. A real
      constant keeps its *source text* and a sign, not a converted value: the
      one place a real is finally needed is the code generator, and what it
      needs there is a decimal literal to print. See EmitReal. }
    intVal: integer;
    charVal: char;
    boolVal: boolean;
    realAt, realLen: integer;
    realNeg: boolean;
    { The number this procedure's LLVM function is named with. Nesting allows
      two procedures of the same name in different parents, so the name cannot
      be the Pascal one. }
    irId: integer;
    { lexical position: `level` is the nesting depth, and owner/frameIndex say
      which activation record holds this variable and where (ADR-0016) }
    level, frameIndex: integer;
    owner: symPtr;
    params, paramTail: symListPtr;
    frameVars, frameTail: symListPtr;
    frameCount: integer;
    { The ids of this block's labels that a goto in a *nested* block jumps to.
      Non-empty means the activation record carries a jump record after the
      frame variables, and the prologue arms it and dispatches on it -- so it
      is the one thing about a block that its own statements do not decide. }
    nlLabels, nlTail: numPtr;
    resultVar: symPtr;
    defined: boolean;
    { 6.4.7: the type-denoter a schema produces its types from, re-resolved
      once per distinct tuple with the discriminants bound to that tuple's
      values -- which is why a schema keeps its *syntax* and not a type. The
      formal discriminants carry only a name and an ordinal type. }
    schemaBody: nodePtr;
    discs, discTail: symListPtr;
    { 6.7.3.2 and 6.7.3.3: the schema a formal parameter was written as the
      bare name of. Its type is then produced *generically* -- the
      discriminants become skDisc symbols reading this parameter's descriptor
      rather than constants -- so one compiled body serves every tuple an
      actual may bring. discSyms are those symbols, in the schema's order, and
      their storage is inside this parameter's frame slot after the address.
      discIndex is which of them a skDisc is; paramSection is which
      formal-parameter-section declared a parameter, because 6.7.3.3 requires
      every actual in one section to bring the same tuple. }
    descSchema: symPtr;
    discSyms, discSymTail: symListPtr;
    { The actual-discriminant-part of a variable whose discriminants are not
      constants, in order -- the expressions the prologue evaluates on entry
      (6.2.3.2). Nil for a schematic formal parameter, whose tuple the caller
      brings, which is what tells the two apart wherever it matters. }
    discExprs: nodePtr;
    discIndex, paramSection: integer;

    { A skDisc whose storage is not in any activation record: the tuple of a
      variable created by `new` lives in a header immediately before it, so
      this one is read from the object's own address rather than by walking
      the static chain (ADR-0043). }
    heapDisc: boolean;

    { This symbol is a schema's discriminant, bound for as long as the body is
      being resolved -- an skConst in a production with a tuple and an skDisc
      in a generic one. Both forms answer 6.4.3.4's question "is this name in
      the variant-selector a discriminant-identifier?", which the *kind*
      cannot, because an ordinary constant is also an skConst and is not
      one. }
    discBinding: boolean;

    { ISO/IEC 10206:1991 6.7.3.1's `protected`: no statement of the body may
      *threaten* this parameter (6.9.4). It says nothing about how the argument
      travels -- a protected var parameter is still an address -- so it is a
      Sema-only property and CodeGen never reads it. It also rides on the
      hidden binding a `with` makes, because 6.5.1 asks about the
      variable-access's *closest-containing* variable-identifier and a `with`
      is where that name stops being written down. }
    isProtected: boolean;

    { ISO/IEC 10206:1991 6.4.3.3.3's *required* schema `string`. It has no
      body: what it produces is a variable-string-type, whose representation
      the compiler fixes rather than the program's text. The flag is what tells
      ProduceFromSchema to build one instead of resolving a denoter. }
    isStringSchema: boolean;

    { ISO/IEC 10206:1991 6.4.1's `bindable`. 6.7.5.6 makes it a
      dynamic-violation to `bind` a file variable that is not one, and 6.5.1
      makes such a variable totally-undefined until it is bound -- so this is
      the one property of a variable that says something about the world
      outside the program. }
    isBindable: boolean;

    { ISO/IEC 10206:1991 6.6: the value this variable bears when the block that
      declares it is entered. Borrowed from the AST and read only by the
      prologue -- every expression in one is nonvarying (6.8.2), so it is
      emitted where it stands rather than folded. For an skType it is the
      initial state the *type-name* hands on (6.4.1). }
    initValue: nodePtr
  end;

  { Every type produced from a schema, keyed by the schema and the tuple.
    6.4.8 makes a type produced with one tuple distinct from one produced with
    any other and from every type of any other schema -- so this list is the
    whole of that rule, and Assignable needs no case for schemata. }
  producedRec = record
    schema: symPtr;
    tuple: numPtr;
    ty: typePtr;
    next: producedPtr
  end;

  { A name bound in a scope. Kept apart from the symbol it names because the
    same symbol is bound twice -- once where a parameter is declared, and again
    when the procedure's body puts it back in scope. }
  entryPtr = ^entryRec;
  entryRec = record
    at, len: integer;
    depth: integer;
    sym: symPtr;
    prev: entryPtr
  end;

  { A pointer type whose domain named a type not yet defined: ISO 7185 6.4.4
    allows exactly this, and it is the only forward reference in the language
    (ADR-0019). }
  { 6.4.4's schema domains, one type per schema. Not the intern table of
    ADR-0039: that is keyed by (schema, tuple) and these have no tuple. }
  { One discriminant of the tuple `new` is building, before there is a block
    to put it in front of. }
  discValPtr = ^discValRec;
  discValRec = record
    idx: integer;
    value: str;
    next: discValPtr
  end;

  heapTypePtr = ^heapTypeRec;
  heapTypeRec = record
    schema: symPtr;
    ty: typePtr;
    next: heapTypePtr
  end;

  pendingPtr = ^pendingRec;
  pendingRec = record
    ptype: typePtr;
    at, len: integer;
    line, col: integer;
    { Set when the domain is a schema that was still being produced: the
      recursion 6.4.7 permits in a pointer domain, which cannot be resolved
      until that production has finished and can be memoised. }
    schema: symPtr;
    next: pendingPtr
  end;

  { A string constant of the generated program: a runtime-error message, an
    external file's name, or a string literal. A global cannot be written in
    the middle of a function, so it is numbered where it is used and its text
    written after the last one. }
  strConstPtr = ^strConstRec;
  strConstRec = record
    id: integer;
    at, len: integer;
    next: strConstPtr
  end;

  { An argument's operand, held until the whole list is known: the call line
    cannot be written until every argument's instructions have been. }
  opndPtr = ^opndRec;
  opndRec = record
    text: str;
    { How the operand is spelled on the call line. A parameter contributes one
      operand, except a procedural one, which contributes two -- so the type
      travels with the operand rather than being re-derived by walking the
      parameter list a second time. }
    asPtr: boolean;
    otype: typePtr;
    next: opndPtr
  end;

  node = record
    line, col: integer;
    { The sibling list that a std::vector<...Ptr> becomes. }
    next: nodePtr;
    { The type of an expression, or the type a type-denoter resolved to. A node
      is never both, so one field serves -- the same sharing typeRec.elem uses,
      and what the C++ splits over Expr::type and TypeExpr::resolved. }
    ntype: typePtr;
    { ISO/IEC 10206:1991 6.6's initial-state-specifier, `value <expression>`.
      It hangs off the *type-denoter* (6.4.1) rather than the declaration,
      which is why it is here and why `type count = integer value 1` gives the
      initial state to every variable of `count`. It is in the fixed part
      because 6.4.1 offers it to every denoter, whatever kind, and a variant
      field could not be shared across them. nsOk is Sema's: set when the
      specifier passed its checks, so a rejected one cannot reach CodeGen. }
    nsValue: nodePtr;
    nsOk: boolean;
    { ISO/IEC 10206:1991 6.4.1's `bindable`, which precedes the denoter where
      the initial-state-specifier follows it. A variable of a bindable type may
      be bound to an entity outside the program (6.7.5.6), and 6.5.1 makes it
      totally-undefined until it is. }
    nsBindable: boolean;
    case kind: nodeKind of
      nkInt:        (intVal: integer);
      { A real literal is kept as its source text and not converted. The
        comparison is on text for the reason ADR-0022 gives, and an untested
        conversion would be worse than an absent one; it arrives with Sema,
        which is the first stage that needs the value. }
      nkReal:       (rlAt, rlLen: integer);
      nkChar:       (chVal: char);
      nkStr:        (stAt, stLen: integer);
      nkNil:        ();
      { A set constructor and one of its members. A member with no `smHi` is a
        single value and one with it is the range ISO 7185 6.7.1 abbreviates;
        the bounds need not be constant, so a range is not expanded here. }
      nkSet:        (seMembers: nodePtr);
      nkSetMember:  (smLo, smHi: nodePtr);
      nkVar:        (vrAt, vrLen: integer; vrSym: symPtr; vrField: fieldPtr);
      nkIndex:      (ixBase, ixIndex: nodePtr);
      { ISO/IEC 10206:1991 6.8.4's schema-discriminant, `v.n`: the base
        possesses a type produced from a schema and the name is one of that
        schema's formal discriminants. It shares its syntax with a field
        selection and nothing else -- there is no field, and fdResolved stays
        nil. Sema folds it to the tuple's value. }
      nkField:      (fdBase: nodePtr; fdAt, fdLen: integer;
                     fdResolved: fieldPtr;
                     fdIsDisc: boolean; fdDiscValue: integer;
                     { ...unless the base is a schematic formal parameter,
                       whose type was produced with no tuple at all: then the
                       value arrives with the actual and this is the skDisc
                       symbol that reads it out of the descriptor. Exactly one
                       of the two is how a discriminant answers. }
                     fdDiscSym: symPtr);
      nkDeref:      (drBase: nodePtr);
      nkBinary:     (bnOp: binaryOp; bnLhs, bnRhs: nodePtr);
      nkUnary:      (unOp: unaryOp; unArg: nodePtr);
      { clSlot is where binding(f)'s result is built: a hidden frame variable
        of type BindingType, one per call site. 6.7.6.8 makes the result a
        record and this compiler returns no records, so the value needs
        somewhere to live -- and a frame slot is somewhere both backends can
        name without an alloca in the middle of a function. }
      nkCall:       (clAt, clLen: integer; clArgs: nodePtr;
                     clBuiltin: builtinKind; clSym: symPtr; clSlot: symPtr);
      nkEmpty:      ();
      nkAssign:     (asTarget, asValue: nodePtr);
      nkWrite:      (wrArgs, wrFile: nodePtr; wrNewline: boolean);
      nkWriteArg:   (waValue, waWidth, waPrec: nodePtr);
      nkRead:       (rdArgs, rdFile: nodePtr; rdNewline: boolean);
      nkCompound:   (cpBody: nodePtr);
      nkIf:         (ifCond, ifThen, ifElse: nodePtr);
      nkWhile:      (whCond, whBody: nodePtr);
      nkRepeat:     (rpBody, rpCond: nodePtr);
      nkFor:        (frVar, frFrom, frTo, frBody: nodePtr; frDownto: boolean);
      { pcSelect: `new(p, c1, ..., cn)` -- the arms the tag values select,
        outermost first, as indices into the variant part at each level
        (ISO 7185 6.6.5.3). nil for the one-argument form. }
      nkProcCall:   (pcAt, pcLen: integer; pcArgs: nodePtr;
                     pcSym: symPtr; pcStd: stdProcKind; pcSelect: numPtr);
      { The hidden frame slot the record's address is bound to. Sema makes
        it; CodeGen stores through it. }
      nkWith:       (wtRecord, wtBody: nodePtr; wtBinding: symPtr);
      { csHasOtherwise, not `csOtherwise <> nil`: `otherwise` followed by
        nothing is an empty statement -- a legal way to say "and otherwise do
        nothing", which is exactly the case that must not trap. }
      nkCase:       (csSelector, csArms, csOtherwise: nodePtr;
                     csHasOtherwise: boolean);
      { `goto L` and `L: statement`. Sema resolves the number to the labelled
        statement's own id, which is what codegen branches to -- the number is
        not enough, since two blocks may each declare label 1. }
      { gtNonLocal: the label belongs to an *enclosing* block, so reaching
        it abandons every activation between here and that one. A different
        lowering, not a longer one: a branch cannot leave a function. }
      nkGoto:       (gtLabel, gtId: integer; gtNonLocal: boolean;
                     gtOwner: symPtr);
      nkLabeled:    (lbLabel, lbId: integer; lbStmt: nodePtr);
      nkLabelDecl:  (ldNumber: integer);
      nkCaseArm:    (caLabels, caBody: nodePtr;
                     caValues, caValueTail: rangePtr);
      nkDeclName:   (dnAt, dnLen: integer);
      { one type-denoter shared by a list of names: a field group, a variable
        declaration, or a parameter group -- or, when grIsProc, a single
        procedural or functional parameter written as a heading of its own
        (ISO 7185 6.6.3.1), which uses grParams and grResult in place of
        grType and always has exactly one name. }
      nkGroup:      (grNames, grType: nodePtr; grByRef, grIsProtected,
                     grIsProc, grIsFunction: boolean;
                     grParams, grResult: nodePtr);
      nkNamed:      (nmAt, nmLen: integer);
      nkInquiry:    (tqAt, tqLen: integer);
      nkSchema:     (scAt, scLen: integer; scArgs, scArgTail: nodePtr);
      nkPointer:    (ptAt, ptLen: integer);
      nkEnum:       (enConstants: nodePtr);
      nkSubrange:   (sbLo, sbHi: nodePtr);
      nkArray:      (arDims, arElem: nodePtr; arPacked: boolean);
      { ISO/IEC 10206:1991 6.4.3.6: `file [ index-type ] of component-type`.
        The brackets are what make a file direct-access, and nothing else
        does -- so flIndex is the whole of the syntax the feature adds. }
      nkFile:       (flElem, flIndex: nodePtr; flPacked: boolean);
      nkSetOf:      (soElem: nodePtr; soPacked: boolean);
      nkRecord:     (rcFields, rcTagType, rcVariants: nodePtr;
                     rcTagAt, rcTagLen, rcTagLine, rcTagCol: integer;
                     rcPacked: boolean);
      nkVariantArm: (vaLabels, vaFields, vaTagType, vaVariants: nodePtr;
                     vaTagAt, vaTagLen, vaTagLine, vaTagCol: integer;
                     { the variant-part-completer of ISO/IEC 10206:1991: an
                       arm with no labels, selected by whatever the others
                       leave }
                     vaOtherwise: boolean);
      nkConstDecl:  (kdAt, kdLen: integer; kdValue: nodePtr);
      { tdDiscs is 6.4.7's formal-discriminant-part, and is nil for an
        ordinary type-definition: a schema is a type-definition that has not
        been told everything yet. Each entry is an nkGroup whose grType is the
        nkNamed ordinal type the discriminants possess. }
      nkTypeDecl:   (tdAt, tdLen: integer; tdType, tdDiscs, tdDiscTail: nodePtr);
      nkProcDecl:   (pdAt, pdLen: integer;
                     pdParams, pdResult, pdBody: nodePtr;
                     pdIsFunction, pdIsForward: boolean; pdSym: symPtr);
      nkBlock:      (blLabels, blConsts, blTypes, blVars, blProcs,
                     blBody: nodePtr)
  end;

  { The statements containing the one being checked, innermost first. Built by
    pushing a new cell in front of the current head and never mutated, so two
    paths *share* their common suffix -- which is what makes the prefix test in
    ResolveGotos a pointer comparison rather than a walk. }
  stmtPathPtr = ^stmtPathRec;
  stmtPathRec = record
    stmt: nodePtr;
    depth: integer;
    next: stmtPathPtr
  end;

  { One label of one block's label declaration part. ISO 7185 6.1.6 makes a
    label a number rather than a name, so it is not a symbol and does not go in
    a scope: two blocks may both declare label 1, and each means its own.
    `path` is what 6.8.1's restriction is stated over -- a goto may reach a
    label only when every statement containing the label also contains the
    goto. }
  labelInfoPtr = ^labelInfoRec;
  labelInfoRec = record
    number, id: integer;
    isDefined: boolean;
    line, col, defLine, defCol: integer;
    path: stmtPathPtr;
    owner: symPtr;
    next: labelInfoPtr
  end;

  { A goto whose target is not resolved until the whole block has been walked:
    a label may be declared before the statement it labels appears, so a
    forward jump cannot be checked where it is written. }
  pendingGotoPtr = ^pendingGotoRec;
  pendingGotoRec = record
    gnode: nodePtr;
    gpath: stmtPathPtr;
    { True once the goto has been handed outwards because its label belongs to
      an enclosing block. The hand-off is what makes the diagnostic right: a
      nested procedure's body is checked *before* the statements of the block
      containing it, so where the goto is written the label it targets has not
      been seen yet and looks undeclared. }
    fromInner: boolean;
    next: pendingGotoPtr
  end;

  { The block number each label denotes, by the id Sema gave it. Per function,
    since a label belongs to exactly one block. }
  labelBlockPtr = ^labelBlockRec;
  labelBlockRec = record
    lid, blk: integer;
    next: labelBlockPtr
  end;

  labelScopePtr = ^labelScopeRec;
  labelScopeRec = record
    labels, labelTail: labelInfoPtr;
    gotos, gotoTail: pendingGotoPtr;
    outer: labelScopePtr
  end;


var
  source: text;

  { --- the lexer's lookahead window; win[0] is the character it looks at --- }
  win: array [0..2] of char;
  winEof: array [0..2] of boolean;
  line, col: integer;

  kwText: array [1..kwCount] of kwLit;
  kwKind: array [1..kwCount] of tokenKind;

  pool: packed array [1..poolMax] of char;
  poolLen: integer;
  tok: array [1..tokMax] of token;
  tokCount: integer;

  { --- the parser --- }
  pos: integer;
  depth: integer;
  { The two halves of what the C++ parser gets from one exception: `aborted`
    stops every production, and `errorSeen` decides whether there is a tree to
    print at all. }
  aborted, errorSeen: boolean;
  errorCount: integer;

  progAt, progLen: integer;
  progParams, progBlock: nodePtr;

  { --- the character sink (see Put) --- }
  msgOut: boolean;
  msgBuf: str;

  level: integer;   { the dump's indentation }
  { False while the tree is dumped as the parser left it, true while it is
    dumped as Sema left it. One walker, two formats. }
  annotate: boolean;

  { --- Sema --- }
  { The scope stack is one chain of bindings; `depth` is what tells the
    current scope from the ones enclosing it. }
  scopeTop: entryPtr;
  scopeDepth: integer;
  pendingHead, pendingTail: pendingPtr;
  heapTypes: heapTypePtr;
  { The tuple `new` is building, for as long as it has nowhere to live: the
    block it will sit in front of is what the tuple is being used to size.
    Nil everywhere else, and that is what makes it safe for BoundValue to
    consult -- outside `new` a heap variable's bounds are only ever in its
    header. }
  newTuple: discValPtr;
  { The `packed array [1..n] of char` of each length, so two literals of a
    length share one type as ISO 7185 6.4.5 requires. }
  stringCache: array [1..strMax] of typePtr;
  { The bindings of the `with` statements currently open, innermost first. }
  withTop: symListPtr;
  { Every type produced from a schema so far (6.4.8), and the schemata whose
    bodies are being resolved right now -- 6.4.7 forbids a schema-definition
    from naming itself outside the domain of a pointer, and without that guard
    the production recurses until the stack runs out. }
  producedHead: producedPtr;
  producingTop: symListPtr;
  { The variable a discriminated schema is being resolved for, while it is.
    6.2.3.2 allows a discriminant that is not a constant *there* and nowhere
    else, so this is what separates `var s: vector(n)` from every other
    position the same denoter could have been written in. }
  dynamicVarFor: symPtr;
  { True while a field of a *variant part* is being resolved, where 6.5.1 makes
    the initial state conditional on the selector. There is no flag for "this
    position admits a specifier at all": the parser settles that, by stopping
    before the word everywhere but the three positions that do. }
  variantField: boolean;
  { True while a *schema body* is being resolved. 6.4.7 makes one a
    type-denoter, so the word parses there, and a schema definition is spelled
    as a type definition -- so refusing it needs a reason of its own. }
  inSchemaBody: boolean;
  { Not nil while a schema body is being resolved *generically*, for the
    schematic formal parameter it belongs to. It is what tells the subrange
    resolver that a bound naming a discriminant is a bound and not a mistake. }
  genericFor: symPtr;
  programSym, currentProc: symPtr;
  { The standard files, when the program parameters name them. }
  stdInput, stdOutput: symPtr;
  { --- CodeGen --- }
  ircode: text;             { the second program parameter: where the IR goes }
  { The third program parameter: one word, the standard to compile for.
    ISO 7185 gives a program no access to its command line beyond its program
    parameters, and those are *files* -- so the stage-1 compiler cannot take a
    `--std` flag the way the C++ driver does, and reads it from a file instead.
    The language deciding the interface is the same constraint that made
    ADR-0024 put the whole compiler in one source file. }
  options: text;
  langStd: stdKind;
  nextReg, nextBlock: integer;   { SSA values and basic blocks, per function }
  curBlock: integer;             { the block being filled, for a phi's label }
  nextProcId, nextStr: integer;
  irProc: symPtr;                { the procedure being emitted }
  irLevel: integer;
  strHead, strTail: strConstPtr;

  { the predefined types, shared singletons }
  intType, realType, boolType, charType, voidType, nilType, textType: typePtr;
  complexType, canonStringType, bindingType: typePtr;
  emptySetType: typePtr;
  { the label declaration parts of the blocks currently open, innermost first }
  labelScope: labelScopePtr;
  stmtPath: stmtPathPtr;
  nextLabelId: integer;
  labelBlocks: labelBlockPtr;
  stringIndex: integer;   { clearing the string-type cache at start-up }

{ ------------------------------------------------------------------ strings }

procedure StrClear(var s: str);
begin
  s.len := 0
end;

procedure StrAppend(var s: str; c: char);
begin
  if s.len < strMax then begin
    s.len := s.len + 1;
    s.ch[s.len] := c
  end
end;

{ ------------------------------------------------------- the character sink }

{ Where the next character goes. A type name is written by one routine and
  wanted in two places: straight out, as part of a diagnostic, and *into a
  buffer*, as part of a runtime-error message the code generator has to store
  and emit as a string constant. One sink is what keeps a single WriteTypeName
  serving both -- and a second copy of it would be a copy free to drift, which
  is the mistake ADR-0024 was written to stop making. }
procedure Put(c: char);
begin
  if msgOut then StrAppend(msgBuf, c) else write(c)
end;

{ A padded literal, with the padding stripped -- the same convention kwLit and
  wordLit already use, and for the same reason (ADR-0012). }
procedure PutLit(w: msgLit);
var n, k: integer;
begin
  n := msgWidth;
  while (n > 0) and (w[n] = ' ') do
    n := n - 1;
  for k := 1 to n do
    Put(w[k])
end;

{ A padded literal written straight to the IR file. PutLit goes through the Put
  sink, which may be aimed at the message buffer; an instruction never is. }
procedure PutIrLit(w: msgLit);
var n, k: integer;
begin
  n := msgWidth;
  while (n > 0) and (w[n] = ' ') do
    n := n - 1;
  for k := 1 to n do
    write(ircode, w[k])
end;

{ An integer, written the way `v:1` writes it. Spelled out rather than left to
  `write` because the digits may have to land in the buffer instead. }
procedure PutInt(v: integer);
var digits: array [1..12] of char; n, k: integer; negative: boolean;
begin
  negative := v < 0;
  n := 0;
  { -maxint..maxint is symmetric, so negating first cannot overflow. }
  if negative then v := -v;
  if v = 0 then begin
    n := 1;
    digits[1] := '0'
  end;
  while v > 0 do begin
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  end;
  if negative then Put('-');
  for k := n downto 1 do
    Put(digits[k])
end;

{ ------------------------------------------------------- character classes }

function IsDigit(c: char): boolean;
begin
  IsDigit := (c >= '0') and (c <= '9')
end;

function IsAlpha(c: char): boolean;
begin
  IsAlpha := ((c >= 'a') and (c <= 'z')) or ((c >= 'A') and (c <= 'Z'))
end;

function IsAlnum(c: char): boolean;
begin
  IsAlnum := IsAlpha(c) or IsDigit(c)
end;

{ isspace in the C locale: blank, and the five control characters 9..13. }
function IsSpace(c: char): boolean;
begin
  IsSpace := (c = ' ') or ((ord(c) >= tab) and (ord(c) <= creturn))
end;

function Lower(c: char): char;
begin
  if (c >= 'A') and (c <= 'Z') then
    Lower := chr(ord(c) - ord('A') + ord('a'))
  else
    Lower := c
end;

{ ----------------------------------------------------- the character source }

{ One slot of the window, taken from the buffer variable. A text file's line
  marker is not a character the program can see (ISO 7185 6.4.3.5), so it is
  turned back into the newline the lexer counts lines with. }
procedure Refill(k: integer);
begin
  if eof(source) then begin
    win[k] := chr(nul);
    winEof[k] := true
  end
  else if eoln(source) then begin
    win[k] := chr(newline);
    winEof[k] := false;
    readln(source)
  end
  else begin
    win[k] := source^;
    winEof[k] := false;
    get(source)
  end
end;

procedure StartFile;
var k: integer;
begin
  reset(source);
  line := 1;
  col := 1;
  for k := 0 to 2 do
    Refill(k)
end;

function Peek(k: integer): char;
begin
  Peek := win[k]
end;

function AtEof: boolean;
begin
  AtEof := winEof[0]
end;

procedure Advance;
var k: integer;
begin
  if win[0] = chr(newline) then begin
    line := line + 1;
    col := 1
  end
  else
    col := col + 1;
  for k := 0 to 1 do begin
    win[k] := win[k + 1];
    winEof[k] := winEof[k + 1]
  end;
  Refill(2)
end;

{ ------------------------------------------------------------- diagnostics }

procedure ErrorAt(l, c: integer);
begin
  errorSeen := true;
  { Counted as well as flagged: producing a type from a schema needs to know
    whether *its* resolution reported anything, so that the tuple that chose
    it can be named too (6.4.7's domain). }
  errorCount := errorCount + 1;
  write(l:1, ' ', c:1, ' error ')
end;

{ -------------------------------------------------------------- the pool -- }

{ Text is interned once and referred to by (at, len) afterwards. The token
  table would otherwise hold a 255-character buffer per token, which is a
  megabyte of frame for a file of any size. }
function PoolAdd(var s: str): integer;
var k: integer;
begin
  if poolLen + s.len > poolMax then begin
    ErrorAt(line, col);
    writeln('out of string space: this compiler keeps ', poolMax:1,
            ' characters of text');
    PoolAdd := 1
  end
  else begin
    PoolAdd := poolLen + 1;
    for k := 1 to s.len do
      pool[poolLen + k] := s.ch[k];
    poolLen := poolLen + s.len
  end
end;

procedure WritePool(at, len: integer);
var k: integer;
begin
  for k := at to at + len - 1 do
    Put(pool[k])
end;

{ True when a pooled spelling is the given word. The literal is padded because
  a value parameter of a packed array type must have the array's exact length
  (ADR-0012); the padding is stripped here rather than at the call. }
{ ...and the same against a *wider* literal. ISO/IEC 10206:1991 has required
  identifiers longer than the longest ISO 7185 word-symbol -- `seekupdate` is
  ten characters and `lastposition` twelve -- so kwLit cannot spell them. }
function PoolIsWide(at, len: integer; word: msgLit): boolean;
var n, k: integer; same: boolean;
begin
  n := msgWidth;
  while (n > 0) and (word[n] = ' ') do
    n := n - 1;
  if n <> len then
    PoolIsWide := false
  else begin
    same := true;
    for k := 1 to n do
      if pool[at + k - 1] <> word[k] then same := false;
    PoolIsWide := same
  end
end;

function PoolIs(at, len: integer; word: kwLit): boolean;
var n, k: integer; same: boolean;
begin
  n := kwWidth;
  while (n > 0) and (word[n] = ' ') do
    n := n - 1;
  if n <> len then
    PoolIs := false
  else begin
    same := true;
    k := 1;
    while same and (k <= n) do begin
      same := word[k] = pool[at + k - 1];
      k := k + 1
    end;
    PoolIs := same
  end
end;

{ Two pooled spellings, compared. Every name in the compiler is a slice of the
  pool, so this is what "the same identifier" means from here on. }
function PoolSame(a1, l1, a2, l2: integer): boolean;
var k: integer; same: boolean;
begin
  if l1 <> l2 then
    PoolSame := false
  else begin
    same := true;
    k := 0;
    while same and (k < l1) do begin
      same := pool[a1 + k] = pool[a2 + k];
      k := k + 1
    end;
    PoolSame := same
  end
end;

{ A character straight into the pool, for the two names Sema builds rather than
  reads: a function's result slot and a `with` binding. }
procedure PoolPut(c: char);
begin
  if poolLen < poolMax then begin
    poolLen := poolLen + 1;
    pool[poolLen] := c
  end
end;

{ A padded literal interned into the pool, so a name the compiler knows about
  can be compared and printed like one it read from the source. }
procedure InternWord(w: kwLit; var at, len: integer);
var n, k: integer;
begin
  n := kwWidth;
  while (n > 0) and (w[n] = ' ') do n := n - 1;
  at := poolLen + 1;
  len := n;
  for k := 1 to n do PoolPut(w[k])
end;

{ ...and the same for a name longer than the longest ISO 7185 word-symbol.
  `bindingtype` is eleven characters, and kwLit holds nine. }
procedure InternWide(w: msgLit; var at, len: integer);
var n, k: integer;
begin
  n := msgWidth;
  while (n > 0) and (w[n] = ' ') do n := n - 1;
  at := poolLen + 1;
  len := n;
  for k := 1 to n do PoolPut(w[k])
end;

{ The two names Sema builds rather than reads. A function's result slot is
  named after the function; a `with` binding is named after the frame slot it
  occupies, which is unique within the frame and needs no type name -- see the
  note beside Sema::checkWith. }
procedure InternResultName(nameAt, nameLen: integer; var at, len: integer);
var k: integer;
begin
  at := poolLen + 1;
  for k := 0 to nameLen - 1 do PoolPut(pool[nameAt + k]);
  PoolPut('$');
  PoolPut('r'); PoolPut('e'); PoolPut('s'); PoolPut('u');
  PoolPut('l'); PoolPut('t');
  len := nameLen + 7
end;

{ ...and the slot 6.7.6.8's `binding` builds its result in, named the same way
  and for the same reason: it is a frame slot the program cannot name. }
procedure InternBindingName(slot: integer; var at, len: integer);
var digits: array [1..12] of char; n, v, k: integer;
begin
  at := poolLen + 1;
  PoolPut('b'); PoolPut('i'); PoolPut('n'); PoolPut('d'); PoolPut('i');
  PoolPut('n'); PoolPut('g'); PoolPut('$');
  n := 0;
  v := slot;
  repeat
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  until v = 0;
  for k := n downto 1 do PoolPut(digits[k]);
  len := poolLen + 1 - at
end;

procedure InternWithName(slot: integer; var at, len: integer);
var digits: array [1..12] of char; n, v, k: integer;
begin
  at := poolLen + 1;
  PoolPut('w'); PoolPut('i'); PoolPut('t'); PoolPut('h'); PoolPut('$');
  n := 0;
  v := slot;
  repeat
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  until v = 0;
  for k := n downto 1 do PoolPut(digits[k]);
  len := 5 + n
end;

{ ------------------------------------------------------ the token table -- }

function AddToken(k: tokenKind; l, c: integer): integer;
begin
  if tokCount >= tokMax then begin
    ErrorAt(l, c);
    writeln('too many tokens: this compiler accepts ', tokMax:1);
    AddToken := tokCount
  end
  else begin
    tokCount := tokCount + 1;
    tok[tokCount].kind := k;
    tok[tokCount].line := l;
    tok[tokCount].col := c;
    tok[tokCount].at := 0;
    tok[tokCount].len := 0;
    tok[tokCount].intVal := 0;
    tok[tokCount].tooBig := false;
    AddToken := tokCount
  end
end;

procedure AddSimple(l, c: integer; k: tokenKind);
var i: integer;
begin
  i := AddToken(k, l, c)
end;

procedure AddText(l, c: integer; k: tokenKind; at, len: integer);
var i: integer;
begin
  i := AddToken(k, l, c);
  tok[i].at := at;
  tok[i].len := len
end;

procedure AddInt(l, c, v: integer; bad: boolean);
var i: integer;
begin
  i := AddToken(tkInt, l, c);
  tok[i].intVal := v;
  tok[i].tooBig := bad
end;

{ ---------------------------------------------------------- keyword lookup }

procedure DefineKeyword(i: integer; spelling: kwLit; k: tokenKind);
begin
  kwText[i] := spelling;
  kwKind[i] := k
end;

procedure InstallKeywords;
begin
  DefineKeyword( 1, 'and      ', tkAnd);
  DefineKeyword( 2, 'array    ', tkArray);
  DefineKeyword( 3, 'begin    ', tkBegin);
  DefineKeyword( 4, 'case     ', tkCase);
  DefineKeyword( 5, 'const    ', tkConst);
  DefineKeyword( 6, 'div      ', tkDiv);
  DefineKeyword( 7, 'do       ', tkDo);
  DefineKeyword( 8, 'downto   ', tkDownto);
  DefineKeyword( 9, 'else     ', tkElse);
  DefineKeyword(10, 'end      ', tkEnd);
  DefineKeyword(11, 'file     ', tkFile);
  DefineKeyword(12, 'for      ', tkFor);
  DefineKeyword(13, 'function ', tkFunction);
  DefineKeyword(14, 'goto     ', tkGoto);
  DefineKeyword(15, 'if       ', tkIf);
  DefineKeyword(16, 'in       ', tkIn);
  DefineKeyword(17, 'label    ', tkLabel);
  DefineKeyword(18, 'mod      ', tkMod);
  DefineKeyword(19, 'nil      ', tkNil);
  DefineKeyword(20, 'not      ', tkNot);
  DefineKeyword(21, 'of       ', tkOf);
  DefineKeyword(22, 'or       ', tkOr);
  DefineKeyword(23, 'packed   ', tkPacked);
  DefineKeyword(24, 'procedure', tkProcedure);
  DefineKeyword(25, 'program  ', tkProgram);
  DefineKeyword(26, 'record   ', tkRecord);
  DefineKeyword(27, 'repeat   ', tkRepeat);
  DefineKeyword(28, 'set      ', tkSet);
  DefineKeyword(29, 'then     ', tkThen);
  DefineKeyword(30, 'to       ', tkTo);
  DefineKeyword(31, 'type     ', tkType);
  DefineKeyword(32, 'until    ', tkUntil);
  DefineKeyword(33, 'var      ', tkVar);
  DefineKeyword(34, 'while    ', tkWhile);
  DefineKeyword(35, 'with     ', tkWith);
  { Beyond isoKwCount: looked up only under the extended standard. }
  DefineKeyword(36, 'otherwise', tkOtherwise);
  DefineKeyword(37, 'pow      ', tkPow);
  DefineKeyword(38, 'protected', tkProtected);
  DefineKeyword(39, 'value    ', tkValue);
  DefineKeyword(40, 'bindable ', tkBindable)
end;

{ A str against a space-padded literal, which is the comparison LookupKeyword
  does over the keyword table. }
function StrIsLit(var s: str; word: kwLit): boolean;
var n, k: integer; same: boolean;
begin
  n := kwWidth;
  while (n > 0) and (word[n] = ' ') do
    n := n - 1;
  same := s.len = n;
  k := 1;
  while same and (k <= n) do begin
    same := s.ch[k] = word[k];
    k := k + 1
  end;
  StrIsLit := same
end;

{ The standard is the first word of the options file. Anything that is not
  `extended` is ISO 7185, which is the default and what an empty file selects
  -- the file is written by the test harness rather than typed, so there is no
  spelling to get wrong and no branch here that no run reaches. }
procedure ReadOptions;
var word: str; c: char;
begin
  StrClear(word);
  reset(options);
  while (not eof(options)) and (not eoln(options)) do begin
    read(options, c);
    if c <> ' ' then StrAppend(word, c)
  end;
  if StrIsLit(word, 'extended ') then langStd := stdExtended
  else langStd := stdIso7185
end;

procedure WriteKwWord(i: integer);
var n, k: integer;
begin
  n := kwWidth;
  while (n > 0) and (kwText[i][n] = ' ') do n := n - 1;
  for k := 1 to n do write(kwText[i][k])
end;

function LookupKeyword(var s: str): tokenKind;
var i, k, n, limit: integer; found: tokenKind; same: boolean;
begin
  found := tkIdent;
  { Reserving ISO 10206's word-symbols unconditionally would reject valid ISO
    7185 programs -- including this one. }
  if langStd = stdExtended then limit := kwCount else limit := isoKwCount;
  for i := 1 to limit do begin
    n := kwWidth;
    while (n > 0) and (kwText[i][n] = ' ') do
      n := n - 1;
    if n = s.len then begin
      same := true;
      k := 1;
      while same and (k <= n) do begin
        same := kwText[i][k] = s.ch[k];
        k := k + 1
      end;
      if same then
        found := kwKind[i]
    end
  end;
  LookupKeyword := found
end;

{ ------------------------------------------------------------- the scanner }

procedure SkipTriviaAndComments;
var sl, sc: integer; done: boolean;
begin
  done := false;
  while not done do begin
    while (not AtEof) and IsSpace(Peek(0)) do
      Advance;

    if Peek(0) = '{' then begin
      sl := line;
      sc := col;
      Advance;
      while (not AtEof) and (Peek(0) <> '}') do
        Advance;
      if AtEof then begin
        ErrorAt(sl, sc);
        writeln('unterminated comment');
        done := true
      end
      else
        Advance
    end
    else if (Peek(0) = '(') and (Peek(1) = '*') then begin
      sl := line;
      sc := col;
      Advance;
      Advance;
      while (not AtEof) and not ((Peek(0) = '*') and (Peek(1) = ')')) do
        Advance;
      if AtEof then begin
        ErrorAt(sl, sc);
        writeln('unterminated comment');
        done := true
      end
      else begin
        Advance;
        Advance
      end
    end
    else
      done := true
  end
end;

procedure LexIdentOrKeyword;
var sl, sc: integer; text: str; k, joined: tokenKind;
begin
  sl := line;
  sc := col;
  StrClear(text);
  while (not AtEof) and (IsAlnum(Peek(0)) or (Peek(0) = '_')) do begin
    StrAppend(text, Lower(Peek(0)));
    Advance
  end;
  k := LookupKeyword(text);

  { ISO/IEC 10206:1991 6.1.2's two two-word word-symbols. Nothing looks them
    up: `and`, `or`, `then` and `else` are already reserved in both standards,
    so this feature reserves no new spelling at all -- the operator is a *pair*
    of tokens joined here.

    The join is at the token level, so what separates the two words is what
    separates any two tokens. 6.1.10's "no separators shall occur within
    tokens" cannot be read literally against a token whose own reference
    representation contains a space, and the strict reading would forbid a
    line break in the middle of an operator. The leniency is safe rather than
    merely convenient: `and` followed by `then` has no other meaning in either
    language, because `then` cannot begin a factor and `else` cannot begin a
    term. }
  joined := tkEof;
  if tokCount > 0 then begin
    if (tok[tokCount].kind = tkAnd) and (k = tkThen) then
      joined := tkAndThen
    else if (tok[tokCount].kind = tkOr) and (k = tkElse) then
      joined := tkOrElse
  end;

  if joined <> tkEof then begin
    { the operator starts where its first word does, which is where the token
      being rewritten already is }
    tok[tokCount].kind := joined;
    if langStd = stdIso7185 then begin
      ErrorAt(tok[tokCount].line, tok[tokCount].col);
      if joined = tkAndThen then write('''and then''')
      else write('''or else''');
      writeln(' is an Extended Pascal operator; compile with --std=extended')
    end
  end
  else if k = tkIdent then
    AddText(sl, sc, tkIdent, PoolAdd(text), text.len)
  else
    AddSimple(sl, sc, k)
end;

{ The value of an extended digit: ISO/IEC 10206:1991 6.1.5 makes a letter one,
  and letter case is no more significant here than it is in an identifier. -1
  is "not one at all". }
function ExtendedDigit(c: char): integer;
begin
  if IsDigit(c) then
    ExtendedDigit := ord(c) - ord('0')
  else if (c >= 'a') and (c <= 'z') then
    ExtendedDigit := ord(c) - ord('a') + 10
  else if (c >= 'A') and (c <= 'Z') then
    ExtendedDigit := ord(c) - ord('A') + 10
  else
    ExtendedDigit := -1
end;

procedure LexNumber;
var
  sl, sc, digit, digitAt, base, i: integer;
  text, digits: str;
  isReal, overflow, bad: boolean;
  value: integer;
  sign: char;
begin
  sl := line;
  sc := col;
  StrClear(text);
  value := 0;
  overflow := false;

  while (not AtEof) and IsDigit(Peek(0)) do begin
    digit := ord(Peek(0)) - ord('0');
    StrAppend(text, Peek(0));
    Advance;
    { The check has to come before the multiply, not after it: this compiler
      traps on integer overflow (ADR-0014), so the C++ lexer's "convert in a
      wider type, then compare" is not available here. }
    if not overflow then
      if value > (maxint - digit) div 10 then
        overflow := true
      else
        value := value * 10 + digit
  end;

  { ISO/IEC 10206:1991 6.1.5: `base#extended-digits`. The digit sequence just
    scanned was the base, and what follows is never real -- only an
    unsigned-integer has this form. }
  if Peek(0) = '#' then begin
    base := value;
    if overflow then base := 0;
    StrAppend(text, Peek(0));
    Advance;
    if langStd = stdIso7185 then begin
      ErrorAt(sl, sc);
      write('a non-decimal literal is an Extended Pascal feature; ');
      writeln('compile with --std=extended')
    end;
    { The digit sequence is maximal: `16#ffand` is one ill-formed number rather
      than a number and a word-symbol, because an extended digit *is* a
      letter. }
    StrClear(digits);
    while (not AtEof) and IsAlnum(Peek(0)) do begin
      StrAppend(digits, Peek(0));
      StrAppend(text, Peek(0));
      Advance
    end;

    value := 0;
    overflow := false;
    bad := false;
    if (base < 2) or (base > 36) then begin
      ErrorAt(sl, sc);
      write('the base of a non-decimal literal must be between 2 and 36, ');
      writeln('found ', base:1);
      bad := true
    end
    else if digits.len = 0 then begin
      ErrorAt(sl, sc);
      writeln('expected at least one digit after ''#''');
      bad := true
    end;
    i := 1;
    while (i <= digits.len) and not bad do begin
      digit := ExtendedDigit(digits.ch[i]);
      if (digit < 0) or (digit >= base) then begin
        ErrorAt(sl, sc);
        writeln('''', digits.ch[i], ''' is not a digit of base ', base:1);
        bad := true
      end
      else if not overflow then
        { the check before the multiply, as above: this compiler traps on
          integer overflow rather than wrapping (ADR-0014) }
        if value > (maxint - digit) div base then
          overflow := true
        else
          value := value * base + digit;
      i := i + 1
    end;
    if overflow then begin
      ErrorAt(sl, sc);
      write('integer literal out of range (maxint is ', maxint:1, '): ');
      for i := 1 to text.len do
        write(text.ch[i]);
      writeln
    end;
    if bad then value := 0;
    AddInt(sl, sc, value, overflow)
  end
  else begin

  isReal := false;
  { A '.' begins a fraction only when a digit follows; otherwise it is the
    program-terminating period, or the first half of '..'. }
  if (Peek(0) = '.') and IsDigit(Peek(1)) then begin
    isReal := true;
    StrAppend(text, Peek(0));
    Advance;
    while (not AtEof) and IsDigit(Peek(0)) do begin
      StrAppend(text, Peek(0));
      Advance
    end
  end;
  if (Peek(0) = 'e') or (Peek(0) = 'E') then begin
    sign := Peek(1);
    if (sign = '+') or (sign = '-') then
      digitAt := 2
    else
      digitAt := 1;
    { the third character of lookahead, and the reason the window exists }
    if IsDigit(Peek(digitAt)) then begin
      isReal := true;
      StrAppend(text, Peek(0));
      Advance;
      if (sign = '+') or (sign = '-') then begin
        StrAppend(text, Peek(0));
        Advance
      end;
      while (not AtEof) and IsDigit(Peek(0)) do begin
        StrAppend(text, Peek(0));
        Advance
      end
    end
  end;

  if isReal then
    AddText(sl, sc, tkReal, PoolAdd(text), text.len)
  else begin
    if overflow then begin
      ErrorAt(sl, sc);
      write('integer literal out of range (maxint is ', maxint:1, '): ');
      for digit := 1 to text.len do
        write(text.ch[digit]);
      writeln
    end;
    AddInt(sl, sc, value, overflow)
  end

  end
end;

procedure LexString;
var sl, sc: integer; value: str; done, bad: boolean; c: char;
begin
  sl := line;
  sc := col;
  Advance; { the opening quote }
  StrClear(value);
  done := false;
  bad := false;
  while not done do begin
    if AtEof or (Peek(0) = chr(newline)) then begin
      bad := true;
      done := true
    end
    else begin
      c := Peek(0);
      Advance;
      if c = '''' then begin
        { '' inside a literal is one quote }
        if Peek(0) = '''' then begin
          StrAppend(value, Peek(0));
          Advance
        end
        else
          done := true
      end
      else
        StrAppend(value, c)
    end
  end;
  if bad then begin
    ErrorAt(sl, sc);
    writeln('unterminated string literal')
  end;
  AddText(sl, sc, tkStr, PoolAdd(value), value.len)
end;

procedure LexOperator;
var sl, sc: integer; c: char;
begin
  sl := line;
  sc := col;
  c := Peek(0);
  Advance;
  if c = '+' then AddSimple(sl, sc, tkPlus)
  else if c = '-' then AddSimple(sl, sc, tkMinus)
  else if c = '*' then begin
    { A comment has already been consumed by the time we get here, so the only
      way two stars can be adjacent is the exponentiating-operator. }
    if Peek(0) = '*' then begin
      Advance;
      if langStd = stdIso7185 then begin
        ErrorAt(sl, sc);
        writeln('''**'' is an Extended Pascal operator; compile with --std=extended')
      end;
      AddSimple(sl, sc, tkStarStar)
    end
    else AddSimple(sl, sc, tkStar)
  end
  else if c = '/' then AddSimple(sl, sc, tkSlash)
  else if c = ',' then AddSimple(sl, sc, tkComma)
  else if c = ';' then AddSimple(sl, sc, tkSemi)
  else if c = '=' then AddSimple(sl, sc, tkEq)
  else if c = '(' then AddSimple(sl, sc, tkLParen)
  else if c = ')' then AddSimple(sl, sc, tkRParen)
  else if c = '[' then AddSimple(sl, sc, tkLBracket)
  else if c = ']' then AddSimple(sl, sc, tkRBracket)
  else if c = '^' then AddSimple(sl, sc, tkCaret)
  else if c = ':' then begin
    if Peek(0) = '=' then begin Advance; AddSimple(sl, sc, tkAssign) end
    else AddSimple(sl, sc, tkColon)
  end
  else if c = '.' then begin
    if Peek(0) = '.' then begin Advance; AddSimple(sl, sc, tkDotDot) end
    else AddSimple(sl, sc, tkPeriod)
  end
  else if c = '<' then begin
    if Peek(0) = '=' then begin Advance; AddSimple(sl, sc, tkLe) end
    else if Peek(0) = '>' then begin Advance; AddSimple(sl, sc, tkNotEq) end
    else AddSimple(sl, sc, tkLt)
  end
  else if c = '>' then begin
    if Peek(0) = '=' then begin Advance; AddSimple(sl, sc, tkGe) end
    else AddSimple(sl, sc, tkGt)
  end
  else begin
    ErrorAt(sl, sc);
    writeln('unexpected character ''', c, '''')
  end
end;

{ One pass over the file, filling the token table. Where the lexer of
  component 1 emitted, this stores -- that is the whole of the difference. }
procedure Tokenize;
var done: boolean; c: char;
begin
  StartFile;
  done := false;
  while not done do begin
    SkipTriviaAndComments;
    if AtEof then begin
      AddSimple(line, col, tkEof);
      done := true
    end
    else begin
      c := Peek(0);
      if IsAlpha(c) or (c = '_') then
        LexIdentOrKeyword
      else if IsDigit(c) then
        LexNumber
      else if c = '''' then
        LexString
      else
        LexOperator
    end
  end
end;

{ ------------------------------------------------------------ token names }

{ The spellings src/lexer.cpp's tokenName returns, quotes and all -- they are
  part of the messages, so they are part of what is compared. }
procedure WriteTokenName(k: tokenKind);
begin
  case k of
    tkEof:       write('end of file');
    tkIdent:     write('identifier');
    tkInt:       write('integer literal');
    tkReal:      write('real literal');
    tkStr:       write('string literal');
    tkPlus:      write('''+''');
    tkMinus:     write('''-''');
    tkStar:      write('''*''');
    tkSlash:     write('''/''');
    tkAssign:    write(''':=''');
    tkComma:     write(''',''');
    tkSemi:      write(''';''');
    tkColon:     write(''':''');
    tkPeriod:    write('''.''');
    tkDotDot:    write('''..''');
    tkLParen:    write('''(''');
    tkRParen:    write(''')''');
    tkLBracket:  write('''[''');
    tkRBracket:  write(''']''');
    tkCaret:     write('''^''');
    tkEq:        write('''=''');
    tkNotEq:     write('''<>''');
    tkLt:        write('''<''');
    tkLe:        write('''<=''');
    tkGt:        write('''>''');
    tkGe:        write('''>=''');
    tkAnd:       write('''and''');
    tkArray:     write('''array''');
    tkBegin:     write('''begin''');
    tkCase:      write('''case''');
    tkConst:     write('''const''');
    tkDiv:       write('''div''');
    tkDo:        write('''do''');
    tkDownto:    write('''downto''');
    tkElse:      write('''else''');
    tkEnd:       write('''end''');
    tkFile:      write('''file''');
    tkFor:       write('''for''');
    tkFunction:  write('''function''');
    tkGoto:      write('''goto''');
    tkIf:        write('''if''');
    tkIn:        write('''in''');
    tkLabel:     write('''label''');
    tkMod:       write('''mod''');
    tkNil:       write('''nil''');
    tkNot:       write('''not''');
    tkOf:        write('''of''');
    tkOr:        write('''or''');
    tkPacked:    write('''packed''');
    tkProcedure: write('''procedure''');
    tkProgram:   write('''program''');
    tkRecord:    write('''record''');
    tkRepeat:    write('''repeat''');
    tkSet:       write('''set''');
    tkThen:      write('''then''');
    tkTo:        write('''to''');
    tkType:      write('''type''');
    tkUntil:     write('''until''');
    tkVar:       write('''var''');
    tkWhile:     write('''while''');
    tkWith:      write('''with''');
    tkOtherwise: write('''otherwise''');
    tkPow:       write('''pow''');
    tkProtected: write('''protected''');
    tkValue:     write('''value''');
    tkBindable:  write('''bindable''');
    tkStarStar:  write('''**''');
    tkAndThen:   write('''and then''');
    tkOrElse:    write('''or else''')
  end
end;

{ The same spellings WriteTokenName writes, without the quotes: --dump-tokens
  says the category separately, so the quotes would be noise. }
procedure WriteOperator(k: tokenKind);
begin
  case k of
    tkPlus: write('+');       tkMinus: write('-');
    tkStar: write('*');       tkSlash: write('/');
    tkAssign: write(':=');    tkComma: write(',');
    tkSemi: write(';');       tkColon: write(':');
    tkPeriod: write('.');     tkDotDot: write('..');
    tkLParen: write('(');     tkRParen: write(')');
    tkLBracket: write('[');   tkRBracket: write(']');
    tkCaret: write('^');      tkEq: write('=');
    tkNotEq: write('<>');     tkLt: write('<');
    tkLe: write('<=');        tkGt: write('>');
    tkGe: write('>=');    tkStarStar: write('**');
    tkEof, tkIdent, tkInt, tkReal, tkStr, tkAnd, tkArray, tkBegin, tkCase,
    tkConst, tkDiv, tkDo, tkDownto, tkElse, tkEnd, tkFile, tkFor, tkFunction,
    tkGoto, tkIf, tkIn, tkLabel, tkMod, tkNil, tkNot, tkOf, tkOr, tkPacked,
    tkProcedure, tkProgram, tkRecord, tkRepeat, tkSet, tkThen, tkTo, tkType,
    tkUntil, tkVar, tkWhile, tkWith, tkOtherwise, tkPow, tkProtected,
    tkValue, tkBindable,
    tkAndThen, tkOrElse: write('?')
  end
end;

procedure WriteKeyword(k: tokenKind);
var i: integer;
begin
  { the table InstallKeywords filled, read the other way round }
  for i := 1 to kwCount do
    if kwKind[i] = k then WriteKwWord(i)
end;

procedure WriteContext(x: ctxKind);
begin
  case x of
    { the C++ parser passes an empty phrase here, leaving 'expected X , found
      Y' with the space still in it; these call sites cannot fail anyway,
      because each is reached only after the token was checked }
    ctxNone: ;
    ctxProgramStart:   write('at the start of the program');
    ctxProgramParams:  write('after the program parameters');
    ctxProgramHeader:  write('after the program header');
    ctxFinalEnd:       write('after the final ''end''');
    ctxAfterFile:      write('after ''file''');
    ctxAfterSet:       write('after ''set''');
    ctxSetMembers:     write('after the members of a set');
    ctxAfterGoto:      write('after ''goto''');
    ctxLabelStart:     write('at the start of a labelled statement');
    ctxAfterLabel:     write('after a statement label');
    ctxLabelDecl:      write('in a label declaration');
    ctxAfterLabelPart: write('after a label declaration');
    ctxSubrangeBounds: write('between the bounds of a subrange');
    ctxSchemaArgs:     write('after the discriminants of a schema');
    ctxTypeInquiry:    write('after ''type'' in a type-inquiry');
    ctxDirectIndex:    write('after the index type of a direct-access file');
    ctxFormalDisc:     write('in a formal discriminant');
    ctxEnumConstants:  write('after the constants of an enumerated type');
    ctxAfterArray:     write('after ''array''');
    ctxArrayIndex:     write('after the index type of an array');
    ctxRecordEnd:      write('at the end of a record type');
    ctxFieldList:      write('in a record field list');
    ctxVariantTag:     write('after the tag of a variant part');
    ctxVariantLabels:  write('after the labels of a variant');
    ctxVariantOpen:    write('before the fields of a variant');
    ctxVariantFields:  write('in the fields of a variant');
    ctxVariantClose:   write('after the fields of a variant');
    ctxConstDef:       write('in a constant definition');
    ctxConstDefEnd:    write('after a constant definition');
    ctxTypeDef:        write('in a type definition');
    ctxTypeDefEnd:     write('after a type definition');
    ctxVarDecl:        write('in a variable declaration');
    ctxVarDeclEnd:     write('after a variable declaration');
    ctxParamList:      write('in a parameter list');
    ctxParamListEnd:   write('after the parameter list');
    ctxProcHeading:    write('after the heading of a procedure or function');
    ctxProcBody:       write('after the body of a procedure or function');
    ctxCompoundStart:  write('at the start of a compound statement');
    ctxCompoundEnd:    write('at the end of a compound statement');
    ctxIf:             write('in an if statement');
    ctxWhile:          write('in a while statement');
    ctxRepeatEnd:      write('at the end of a repeat statement');
    ctxFor:            write('in a for statement');
    ctxCaseSelector:   write('after the selector of a case statement');
    ctxCaseLabels:     write('after the labels of a case arm');
    ctxCaseEnd:        write('at the end of a case statement');
    ctxWith:           write('in a with statement');
    ctxAssign:         write('in an assignment');
    ctxProcCallArgs:   write('after the arguments of a procedure call');
    ctxWriteArgs:      write('after the arguments of write');
    ctxReadArgs:       write('after the arguments of read');
    ctxSubscript:      write('after a subscript');
    ctxParenExpr:      write('after a parenthesised expression');
    ctxCallArgs:       write('after the arguments of a function call');
    ctxFuncParamResult:
      write('before the result type of a functional parameter')
  end
end;

{ ---------------------------------------------------------- the node arena }

function NewNode(k: nodeKind; l, c: integer): nodePtr;
var n: nodePtr;
begin
  new(n);
  n^.kind := k;
  n^.line := l;
  n^.col := c;
  n^.next := nil;
  n^.ntype := nil;
  n^.nsValue := nil;
  n^.nsOk := false;
  n^.nsBindable := false;
  { What Sema will fill in. A C++ struct gets these from its member
    initialisers; a variant record has none, and the dump reads them whether or
    not Sema ran, so they are cleared where the node is made. }
  case k of
    nkVar: begin n^.vrSym := nil; n^.vrField := nil end;
    nkField: begin
               n^.fdResolved := nil;
               n^.fdIsDisc := false;
               n^.fdDiscValue := 0;
               n^.fdDiscSym := nil
             end;
    nkCall: begin
              n^.clBuiltin := biNone;
              n^.clSym := nil;
              n^.clSlot := nil
            end;
    nkWrite: n^.wrFile := nil;
    nkRead: n^.rdFile := nil;
    nkProcCall: begin
      n^.pcSym := nil;
      n^.pcStd := spNone;
      n^.pcSelect := nil
    end;
    nkCase: begin n^.csOtherwise := nil; n^.csHasOtherwise := false end;
    nkCaseArm: begin n^.caValues := nil; n^.caValueTail := nil end;
    nkGroup: begin
      n^.grIsProc := false;
      n^.grIsFunction := false;
      n^.grParams := nil;
      n^.grResult := nil
    end;
    nkProcDecl: n^.pdSym := nil;
    nkWith: n^.wtBinding := nil;
    nkVariantArm: begin
      n^.vaTagType := nil;
      n^.vaVariants := nil;
      n^.vaTagAt := 0;
      n^.vaTagLen := 0;
      n^.vaTagLine := 0;
      n^.vaTagCol := 0;
      n^.vaOtherwise := false
    end;
    nkGoto:    begin
                 n^.gtId := -1;
                 n^.gtNonLocal := false;
                 n^.gtOwner := nil
               end;
    nkLabeled: n^.lbId := -1;
    nkInt, nkReal, nkChar, nkStr, nkNil, nkSet, nkSetMember, nkIndex, nkDeref,
    nkBinary, nkUnary,
    nkEmpty, nkAssign, nkCompound, nkIf, nkWhile, nkRepeat, nkFor,
    nkWriteArg, nkDeclName, nkNamed, nkEnum,
    nkSubrange, nkArray, nkRecord, nkPointer, nkFile, nkSetOf, nkSchema, nkInquiry,
    nkConstDecl, nkTypeDecl, nkLabelDecl,
    nkBlock: { nothing of Sema's to clear }
  end;
  NewNode := n
end;

{ Appending to a sibling list: the head is what the tree keeps, the tail is
  what makes the append constant time. A vector's push_back, in the one shape
  this AST ever needs. }
procedure Append(var head, tail: nodePtr; n: nodePtr);
begin
  if head = nil then
    head := n
  else
    tail^.next := n;
  tail := n
end;

{ ------------------------------------------------------------- the parser }

procedure Bail;
begin
  aborted := true
end;

function CurLine: integer;
begin
  CurLine := tok[pos].line
end;

function CurCol: integer;
begin
  CurCol := tok[pos].col
end;

procedure ErrorAtCur;
begin
  ErrorAt(CurLine, CurCol)
end;

function Check(k: tokenKind): boolean;
begin
  Check := tok[pos].kind = k
end;

{ The C++ parser clamps a peek past the end to the last token, which is always
  the end-of-file one, so lookahead never falls off. }
function PeekKind(ahead: integer): tokenKind;
var i: integer;
begin
  i := pos + ahead;
  if i > tokCount then
    i := tokCount;
  PeekKind := tok[i].kind
end;

function Accept(k: tokenKind): boolean;
begin
  if (not aborted) and Check(k) then begin
    pos := pos + 1;
    Accept := true
  end
  else
    Accept := false
end;

procedure Expect(k: tokenKind; x: ctxKind);
begin
  if not aborted then
    if Check(k) then
      pos := pos + 1
    else begin
      ErrorAtCur;
      write('expected ');
      WriteTokenName(k);
      write(' ');
      WriteContext(x);
      write(', found ');
      WriteTokenName(tok[pos].kind);
      writeln;
      Bail
    end
end;

{ One level of nesting in the tree under construction (ADR-0020). The bound is
  on the tree, not on this parser's own recursion: the operator and selector
  loops build a spine that is flat here and deep for every later walker, so
  they count each iteration. }
procedure EnterLevel;
begin
  depth := depth + 1;
  if (depth > maxDepth) and not aborted then begin
    ErrorAtCur;
    writeln('nesting is too deep: this compiler accepts ', maxDepth:1,
            ' levels');
    Bail
  end
end;

procedure LeaveLevels(n: integer);
begin
  depth := depth - n
end;

function ParseExpr: nodePtr; forward;
function ParseFactor: nodePtr; forward;
function ParseTypeExpr: nodePtr; forward;
function ParseTypeDenoter: nodePtr; forward;
function ParseStatement: nodePtr; forward;
function ParseBlock: nodePtr; forward;

{ name-list = identifier (',' identifier)*, as a list of nkDeclName. `what`
  names what was expected; the four callers are the four spellings the C++
  parser passes. }
function ParseNameList(what: ctxKind): nodePtr;
var head, tail, n: nodePtr; more: boolean;
begin
  head := nil;
  tail := nil;
  more := true;
  while more and not aborted do begin
    if not Check(tkIdent) then begin
      ErrorAtCur;
      write('expected ');
      case what of
        ctxParamList:     write('a parameter name');
        ctxFieldList:     write('a field name');
        ctxVarDecl:       write('a variable name');
        ctxEnumConstants: write('an enumeration constant');
        ctxFormalDisc:    write('a discriminant name')
      end;
      writeln;
      Bail
    end
    else begin
      n := NewNode(nkDeclName, CurLine, CurCol);
      n^.dnAt := tok[pos].at;
      n^.dnLen := tok[pos].len;
      Append(head, tail, n);
      pos := pos + 1;
      more := Accept(tkComma)
    end
  end;
  ParseNameList := head
end;

{ A constant followed by '..' is a subrange; a bare identifier is a type name.
  The two only diverge at the '..', so this is the one place the type grammar
  needs to look past the current token. }
function LooksLikeSubrange: boolean;
var i: integer; ok: boolean;
begin
  i := pos;
  if (tok[i].kind = tkPlus) or (tok[i].kind = tkMinus) then
    i := i + 1;
  ok := (tok[i].kind = tkIdent) or (tok[i].kind = tkInt) or
        (tok[i].kind = tkStr);
  if ok then begin
    i := i + 1;
    ok := (i <= tokCount) and (tok[i].kind = tkDotDot)
  end;
  LooksLikeSubrange := ok
end;

function ParseEnumType: nodePtr;
var t: nodePtr;
begin
  t := NewNode(nkEnum, CurLine, CurCol);
  Expect(tkLParen, ctxNone);
  t^.enConstants := ParseNameList(ctxEnumConstants);
  Expect(tkRParen, ctxEnumConstants);
  ParseEnumType := t
end;

{ array-type = 'array' '[' ordinal-type (',' ordinal-type)* ']' 'of' type

  The index is a *type*, so `array [1..3]`, `array [color]` and `array [char]`
  are one construct. Several indices are the abbreviation of ISO 7185 6.4.3.2,
  kept in one node here and nested by Sema. }
function ParseArrayType(packed_: boolean): nodePtr;
var t, head, tail: nodePtr; more: boolean;
begin
  t := NewNode(nkArray, CurLine, CurCol);
  t^.arPacked := packed_;
  t^.arDims := nil;
  t^.arElem := nil;
  Expect(tkArray, ctxNone);
  Expect(tkLBracket, ctxAfterArray);

  head := nil;
  tail := nil;
  more := true;
  while more and not aborted do begin
    Append(head, tail, ParseTypeDenoter);
    more := Accept(tkComma)
  end;
  t^.arDims := head;

  Expect(tkRBracket, ctxArrayIndex);
  Expect(tkOf, ctxArrayIndex);
  t^.arElem := ParseTypeDenoter;
  ParseArrayType := t
end;

{ field-list = group (';' group)*, shared by a record's fixed part and by the
  fields of a variant. }
function ParseFieldGroups(closer: tokenKind; inVariant: boolean): nodePtr;
var head, tail, g: nodePtr; more: boolean;
begin
  head := nil;
  tail := nil;
  more := true;
  while more and not aborted and not Check(closer) do begin
    { A variant part ends the field list it belongs to, and the caller parses
      it -- it is last, whether the field list is a record's or an arm's
      (ISO 7185 6.4.3.3). }
    if Check(tkCase) then
      more := false
    else begin
      g := NewNode(nkGroup, CurLine, CurCol);
      g^.grByRef := false;
      g^.grIsProtected := false;
      g^.grNames := ParseNameList(ctxFieldList);
      if inVariant then
        Expect(tkColon, ctxVariantFields)
      else
        Expect(tkColon, ctxFieldList);
      g^.grType := ParseTypeExpr;
      Append(head, tail, g);
      more := Accept(tkSemi)
    end
  end;
  ParseFieldGroups := head
end;

{ variant-part = 'case' (identifier ':')? type-identifier 'of' variant
                 (';' variant)* (';' completer)?
  completer    = 'otherwise' '(' field-list ')'      -- Extended Pascal only

  The tag may be a real field or exist only as a type (ISO 7185 6.4.3.3). The
  two are told apart by the ':' -- `case kind: nodekind of` names a field,
  `case nodekind of` does not. }
{ case-constant-list = case-range (',' case-range)*
  case-range         = case-constant ('..' case-constant)?   -- Extended Pascal

  ISO/IEC 10206:1991 generalised the constant list once, and both the case
  statement (6.8.3.5) and a variant (6.4.3.3) name it -- so a range is legal in
  either, and neither place gets a rule of its own. A case-range and a set
  member are the same pair, so they share the node rather than duplicating it. }
function ParseCaseLabel: nodePtr;
var m: nodePtr;
begin
  m := NewNode(nkSetMember, CurLine, CurCol);
  m^.smLo := nil;
  m^.smHi := nil;
  m^.smLo := ParseExpr;
  if Check(tkDotDot) then begin
    if langStd = stdIso7185 then begin
      ErrorAtCur;
      write('a range of case constants is an Extended Pascal feature; ');
      writeln('compile with --std=extended');
      Bail
    end;
    pos := pos + 1;
    m^.smHi := ParseExpr
  end;
  ParseCaseLabel := m
end;

{ The `case T of ...` of a record or of one arm of a variant part. Both places
  hold the same four pieces, but a variant record cannot share a sub-struct
  between two of its arms (ADR-0023), so the destination is chosen at the end
  rather than passed in. }
procedure ParseVariantPart(n: nodePtr; intoArm: boolean);
var
  head, tail, arm, lh, lt, tagType: nodePtr;
  tagAt, tagLen, tagLine, tagCol: integer;
  more, moreLabels, completer: boolean;
begin
  { A variant part may contain variant parts, so this recurses without going
    back through ParseTypeExpr -- which is where the depth guard usually is. }
  EnterLevel;
  Expect(tkCase, ctxNone);
  tagLine := CurLine;
  tagCol := CurCol;
  tagAt := 0;
  tagLen := 0;
  tagType := nil;

  if Check(tkIdent) and (PeekKind(1) = tkColon) then begin
    tagAt := tok[pos].at;
    tagLen := tok[pos].len;
    pos := pos + 2
  end;
  if not aborted then
    if not Check(tkIdent) then begin
      ErrorAtCur;
      writeln('the tag of a variant part must be a type name');
      Bail
    end;
  tagType := ParseTypeDenoter;
  Expect(tkOf, ctxVariantTag);

  head := nil;
  tail := nil;
  more := true;
  while more and not aborted and not Check(tkEnd) do begin
    arm := NewNode(nkVariantArm, CurLine, CurCol);
    arm^.vaLabels := nil;
    arm^.vaFields := nil;
    { ISO/IEC 10206:1991 6.4.3.3: the variant-list may end with
      `otherwise (field-list)` -- no labels, and no colon, because it names no
      constants. }
    completer := Check(tkOtherwise);
    if completer then begin
      pos := pos + 1;
      arm^.vaOtherwise := true
    end
    else begin
      { Under ISO 7185 `otherwise` is an ordinary identifier and may well name
        the constant a variant is labelled with. What follows parts them: a
        label list is followed by ',' or ':', the completer by '('. }
      if Check(tkIdent) and PoolIs(tok[pos].at, tok[pos].len, 'otherwise') and
         (PeekKind(1) = tkLParen) then begin
        ErrorAtCur;
        write('the ''otherwise'' part of a variant part is an Extended ');
        writeln('Pascal feature; compile with --std=extended');
        Bail
      end;
      lh := nil;
      lt := nil;
      moreLabels := true;
      while moreLabels and not aborted do begin
        Append(lh, lt, ParseCaseLabel);
        moreLabels := Accept(tkComma)
      end;
      arm^.vaLabels := lh;
      Expect(tkColon, ctxVariantLabels)
    end;
    Expect(tkLParen, ctxVariantOpen);
    arm^.vaFields := ParseFieldGroups(tkRParen, true);
    { An arm's field-list may end with a variant part of its own. }
    if not aborted then
      if Check(tkCase) then ParseVariantPart(arm, true);
    Expect(tkRParen, ctxVariantClose);
    Append(head, tail, arm);
    { The completer ends the variant-list, so nothing may follow it -- the same
      shape as the otherwise-part of a case statement. }
    if completer then more := false else more := Accept(tkSemi)
  end;

  if intoArm then begin
    n^.vaTagAt := tagAt;
    n^.vaTagLen := tagLen;
    n^.vaTagLine := tagLine;
    n^.vaTagCol := tagCol;
    n^.vaTagType := tagType;
    n^.vaVariants := head
  end
  else begin
    n^.rcTagAt := tagAt;
    n^.rcTagLen := tagLen;
    n^.rcTagLine := tagLine;
    n^.rcTagCol := tagCol;
    n^.rcTagType := tagType;
    n^.rcVariants := head
  end;
  LeaveLevels(1)
end;

function ParseRecordType(packed_: boolean): nodePtr;
var t: nodePtr;
begin
  t := NewNode(nkRecord, CurLine, CurCol);
  t^.rcPacked := packed_;
  t^.rcFields := nil;
  t^.rcTagType := nil;
  t^.rcVariants := nil;
  t^.rcTagAt := 0;
  t^.rcTagLen := 0;
  t^.rcTagLine := 0;
  t^.rcTagCol := 0;
  Expect(tkRecord, ctxNone);
  t^.rcFields := ParseFieldGroups(tkEnd, false);
  if (not aborted) and Check(tkCase) then
    ParseVariantPart(t, false);
  Expect(tkEnd, ctxRecordEnd);
  ParseRecordType := t
end;

{ ISO 7185 6.1.6: a label is an unsigned integer of at most four digits, so
  `0001` and `1` are the same label and `10000` is not one at all. The value is
  what identifies it -- there is no name here to intern. }
function ParseLabel(ctx: ctxKind): integer;
var v: integer;
begin
  ParseLabel := 0;
  if not Check(tkInt) then begin
    ErrorAtCur;
    write('expected a label ');
    WriteContext(ctx);
    write(', found ');
    WriteTokenName(tok[pos].kind);
    writeln;
    Bail
  end
  else begin
    v := tok[pos].intVal;
    if (v < 0) or (v > 9999) then begin
      ErrorAtCur;
      writeln('a label must be an unsigned integer of at most four digits');
      v := 0
    end;
    pos := pos + 1;
    ParseLabel := v
  end
end;

{ label-declaration-part = 'label' label (',' label)* ';' }
procedure ParseLabelPart(var head, tail: nodePtr);
var d: nodePtr;
begin
  Expect(tkLabel, ctxNone);
  repeat
    d := NewNode(nkLabelDecl, CurLine, CurCol);
    d^.ldNumber := ParseLabel(ctxLabelDecl);
    Append(head, tail, d)
  until not Accept(tkComma) or aborted;
  Expect(tkSemi, ctxAfterLabelPart)
end;

{ type-denoter = 'packed'? structured-type | ordinal-type | type-identifier }
{ type-denoter = ( type-name | new-type | type-inquiry | discriminated-schema )
                  [ initial-state-specifier ]      (ISO/IEC 10206:1991 6.4.1)

  Only the three positions that may carry a specifier call this; every nested
  denoter calls ParseTypeDenoter and stops before the word. That is not a
  shortcut -- it is the only reading that parses. `set of 1..9 value [2]` has
  one place the specifier can attach and the recursion would have taken it for
  the base type, and `array [1..8] of char value '*'` is 6.6 NOTE 3's own
  example of a violation *because* the value belongs to the array. So the
  component stops at the word and the outer denoter takes it, which is what
  turns that example into the type error the note says it is.

  There is no langStd test here, and there cannot be one: `value` is a
  word-symbol Extended Pascal *adds*, so under ISO 7185 the lexer yields an
  identifier and this token never appears. The lexer's decision is the whole of
  the feature's language gating -- unlike `type of`, whose words are reserved
  in both languages and which therefore needs an explicit refusal. }
function ParseTypeExpr;
var t: nodePtr; bindable_: boolean;
begin
  { 6.4.1 puts `bindable` *before* the denoter and the initial-state specifier
    after it, so the two brackets of that production are parsed on either side
    of one call. Like `value`, this word is one Extended Pascal adds, so no
    langStd test is possible: under ISO 7185 the lexer yields an identifier and
    the token never appears. }
  bindable_ := Accept(tkBindable);
  t := ParseTypeDenoter;
  if t <> nil then t^.nsBindable := bindable_;
  if (t <> nil) and not aborted then
    if Accept(tkValue) then
      t^.nsValue := ParseExpr;
  ParseTypeExpr := t
end;

function ParseTypeDenoter;
var t, n: nodePtr; packed_: boolean;
begin
  EnterLevel;
  t := nil;
  if not aborted then begin
    packed_ := Accept(tkPacked);

    { set-type = 'set' 'of' base-type. The base type is an *ordinal* type, so
      this is the same construct as an array's index type and is parsed by the
      same routine (ISO 7185 6.4.3.4). }
    if Check(tkSet) then begin
      t := NewNode(nkSetOf, CurLine, CurCol);
      t^.soPacked := packed_;
      t^.soElem := nil;
      pos := pos + 1;
      Expect(tkOf, ctxAfterSet);
      t^.soElem := ParseTypeDenoter
    end
    else if Check(tkFile) then begin
      t := NewNode(nkFile, CurLine, CurCol);
      t^.flPacked := packed_;
      t^.flElem := nil;
      t^.flIndex := nil;
      pos := pos + 1;
      { ISO/IEC 10206:1991 6.4.3.6: `file [ index-type ] of component-type`.
        The brackets are what make a file direct-access, and nothing else
        does -- so this is the whole of the syntax the feature adds. }
      if Check(tkLBracket) then begin
        if langStd = stdIso7185 then begin
          ErrorAtCur;
          writeln('a direct-access file is an Extended Pascal feature; ',
                  'compile with --std=extended');
          Bail
        end
        else begin
          pos := pos + 1;
          t^.flIndex := ParseTypeDenoter;
          Expect(tkRBracket, ctxDirectIndex)
        end
      end;
      if not aborted then begin
        Expect(tkOf, ctxAfterFile);
        t^.flElem := ParseTypeDenoter
      end
    end
    else if Check(tkArray) then
      t := ParseArrayType(packed_)
    else if Check(tkRecord) then
      t := ParseRecordType(packed_)
    else if packed_ then begin
      ErrorAtCur;
      writeln('''packed'' applies only to an array, record, set or file type');
      Bail
    end
    { pointer-type = '^' type-identifier. ISO 7185 6.4.4 requires a type
      *identifier* rather than a type-denoter, and that restriction is what
      makes a recursive type possible: the name may be one defined later in
      the same type part, so `node = record next: ^node end` closes the loop. }
    else if Check(tkCaret) then begin
      t := NewNode(nkPointer, CurLine, CurCol);
      pos := pos + 1;
      if not Check(tkIdent) then begin
        ErrorAtCur;
        writeln('the domain of a pointer type must be a type name');
        Bail
      end
      else begin
        t^.ptAt := tok[pos].at;
        t^.ptLen := tok[pos].len;
        pos := pos + 1
      end
    end
    { type-inquiry = 'type' 'of' type-inquiry-object (6.4.9). Both words are
      already reserved in ISO 7185, so this feature reserves nothing -- the
      second such after `and then`. There is no ambiguity to resolve either:
      `type` cannot begin a type-denoter in that language at all. }
    else if Check(tkType) then begin
      t := NewNode(nkInquiry, CurLine, CurCol);
      t^.tqAt := 0;
      t^.tqLen := 0;
      if langStd = stdIso7185 then begin
        ErrorAtCur;
        writeln('a type-inquiry is an Extended Pascal feature; compile with ',
                '--std=extended');
        Bail
      end
      else begin
        pos := pos + 1;
        Expect(tkOf, ctxTypeInquiry);
        if not aborted then
          if not Check(tkIdent) then begin
            ErrorAtCur;
            writeln('''type of'' must name a variable or a parameter');
            Bail
          end
          else begin
            t^.tqAt := tok[pos].at;
            t^.tqLen := tok[pos].len;
            pos := pos + 1
          end
      end
    end
    else if Check(tkLParen) then
      t := ParseEnumType
    else if LooksLikeSubrange then begin
      t := NewNode(nkSubrange, CurLine, CurCol);
      t^.sbLo := nil;
      t^.sbHi := nil;
      t^.sbLo := ParseExpr;
      Expect(tkDotDot, ctxSubrangeBounds);
      t^.sbHi := ParseExpr
    end
    else if not Check(tkIdent) then begin
      ErrorAtCur;
      write('expected a type, found ');
      WriteTokenName(tok[pos].kind);
      writeln;
      Bail
    end
    else begin
      t := NewNode(nkNamed, CurLine, CurCol);
      t^.nmAt := tok[pos].at;
      t^.nmLen := tok[pos].len;
      pos := pos + 1;

      { ISO/IEC 10206:1991 6.4.8: a name followed by an actual-discriminant-
        part is a discriminated-schema. Nothing else in a type-denoter
        position can begin with '(' after a name, so no lookahead beyond this
        token is needed -- and the parser does not care whether the name turns
        out to denote a schema, which is Sema's question. }
      if Check(tkLParen) then begin
        if langStd = stdIso7185 then begin
          ErrorAtCur;
          writeln('a discriminated schema is an Extended Pascal feature; ',
                  'compile with --std=extended');
          Bail
        end
        else begin
          n := t;
          t := NewNode(nkSchema, n^.line, n^.col);
          t^.scAt := n^.nmAt;
          t^.scLen := n^.nmLen;
          t^.scArgs := nil;
          t^.scArgTail := nil;
          pos := pos + 1;
          repeat
            Append(t^.scArgs, t^.scArgTail, ParseExpr)
          until not Accept(tkComma);
          Expect(tkRParen, ctxSchemaArgs)
        end
      end
    end
  end;
  LeaveLevels(1);
  ParseTypeExpr := t
end;

{ ------------------------------------------------------------- expressions }

{ designator = name selector*
  selector   = '[' expression (',' expression)* ']' | '.' field-name | '^'

  A selector chain is a spine like an operator chain, built by this loop
  rather than by recursion; each selector wraps the designator one level
  deeper for the tree's walkers, so each counts. }
function ParseSelectors(base: nodePtr): nodePtr;
var levels: integer; done, more: boolean; n: nodePtr;
begin
  levels := 0;
  done := false;
  while not done and not aborted do begin
    if Check(tkLBracket) then begin
      pos := pos + 1;
      more := true;
      while more and not aborted do begin
        levels := levels + 1;
        EnterLevel;
        n := NewNode(nkIndex, CurLine, CurCol);
        n^.ixBase := base;
        n^.ixIndex := ParseExpr;
        base := n;
        more := Accept(tkComma)   { `a[i, j]` is `a[i][j]` }
      end;
      Expect(tkRBracket, ctxSubscript)
    end
    else if Check(tkCaret) then begin
      levels := levels + 1;
      EnterLevel;
      n := NewNode(nkDeref, CurLine, CurCol);
      pos := pos + 1;
      n^.drBase := base;
      base := n
    end
    else if Check(tkPeriod) then begin
      levels := levels + 1;
      EnterLevel;
      n := NewNode(nkField, CurLine, CurCol);
      pos := pos + 1;
      if not Check(tkIdent) then begin
        ErrorAtCur;
        writeln('expected a field name after ''.''');
        Bail
      end
      else begin
        n^.fdBase := base;
        n^.fdAt := tok[pos].at;
        n^.fdLen := tok[pos].len;
        pos := pos + 1;
        base := n
      end
    end
    else
      done := true
  end;
  LeaveLevels(levels);
  ParseSelectors := base
end;

function ParsePrimary: nodePtr;
var e, call, m: nodePtr; head, tail, memberTail: nodePtr; more: boolean;
begin
  { Every way an expression nests inside an expression -- parentheses, `not`,
    a unary sign, a call's arguments -- passes through here exactly once per
    level, so this one guard bounds the whole expression grammar. }
  EnterLevel;
  e := nil;
  if not aborted then begin
    if Check(tkInt) then begin
      e := NewNode(nkInt, CurLine, CurCol);
      e^.intVal := tok[pos].intVal;
      pos := pos + 1
    end
    else if Check(tkReal) then begin
      e := NewNode(nkReal, CurLine, CurCol);
      e^.rlAt := tok[pos].at;
      e^.rlLen := tok[pos].len;
      pos := pos + 1
    end
    else if Check(tkStr) then begin
      { A one-character literal is a char constant in ISO Pascal. }
      if tok[pos].len = 1 then begin
        e := NewNode(nkChar, CurLine, CurCol);
        e^.chVal := pool[tok[pos].at]
      end
      else begin
        e := NewNode(nkStr, CurLine, CurCol);
        e^.stAt := tok[pos].at;
        e^.stLen := tok[pos].len
      end;
      pos := pos + 1
    end
    else if Check(tkNil) then begin
      e := NewNode(nkNil, CurLine, CurCol);
      pos := pos + 1
    end
    else if Check(tkNot) then begin
      { `not` is a primary, not a factor: 6.8.1 gives it the highest precedence
        of all, above `**`, so `not a ** b` exponentiates the negation. Under
        ISO 7185 a factor *is* a primary and nothing moves. }
      e := NewNode(nkUnary, CurLine, CurCol);
      e^.unOp := opNot;
      pos := pos + 1;
      e^.unArg := ParsePrimary
    end
    else if Check(tkMinus) then begin
      { A sign takes a whole factor, so `-3 ** 2` is -(3 ** 2) -- the rule that
        already makes `-7 mod 3` be -(7 mod 3). It matters beyond taste here:
        `**` is an error on a negative left operand, so the other reading turns
        a legal expression into a runtime error. }
      e := NewNode(nkUnary, CurLine, CurCol);
      e^.unOp := opNeg;
      pos := pos + 1;
      e^.unArg := ParseFactor
    end
    else if Check(tkPlus) then begin
      pos := pos + 1;
      e := ParseFactor
    end
    else if Check(tkLParen) then begin
      pos := pos + 1;
      e := ParseExpr;
      Expect(tkRParen, ctxParenExpr)
    end
    { set-constructor = '[' (member (',' member)*)? ']',
      member = expr ('..' expr)?. `[]` is the empty set. A '[' can only start
      a constructor here: a subscript follows a designator, which
      ParseSelectors has already consumed by the time a factor is reached. }
    else if Check(tkLBracket) then begin
      e := NewNode(nkSet, CurLine, CurCol);
      e^.seMembers := nil;
      memberTail := nil;
      pos := pos + 1;
      if not Check(tkRBracket) then
        repeat
          m := NewNode(nkSetMember, CurLine, CurCol);
          m^.smLo := nil;
          m^.smHi := nil;
          m^.smLo := ParseExpr;
          if Accept(tkDotDot) then m^.smHi := ParseExpr;
          Append(e^.seMembers, memberTail, m)
        until not Accept(tkComma);
      Expect(tkRBracket, ctxSetMembers)
    end
    else if Check(tkIdent) then begin
      { `eof` and `eoln` are the only functions ISO 7185 lets a program call
        with no argument list at all -- the file then defaults to `input`
        (6.6.6.5). A bare name is otherwise a variable or a parameterless
        call, so this is decided here, where the absence of '(' is visible. }
      if (PoolIs(tok[pos].at, tok[pos].len, 'eof      ') or
          PoolIs(tok[pos].at, tok[pos].len, 'eoln     ')) and
         (PeekKind(1) <> tkLParen) then begin
        e := NewNode(nkCall, CurLine, CurCol);
        e^.clAt := tok[pos].at;
        e^.clLen := tok[pos].len;
        e^.clArgs := nil;
        pos := pos + 1
      end
      else if PeekKind(1) = tkLParen then begin
        call := NewNode(nkCall, CurLine, CurCol);
        call^.clAt := tok[pos].at;
        call^.clLen := tok[pos].len;
        call^.clArgs := nil;
        pos := pos + 2;
        head := nil;
        tail := nil;
        if not Check(tkRParen) then begin
          more := true;
          while more and not aborted do begin
            Append(head, tail, ParseExpr);
            more := Accept(tkComma)
          end
        end;
        call^.clArgs := head;
        Expect(tkRParen, ctxCallArgs);
        e := call
      end
      else begin
        e := NewNode(nkVar, CurLine, CurCol);
        e^.vrAt := tok[pos].at;
        e^.vrLen := tok[pos].len;
        pos := pos + 1;
        { Only a variable takes selectors: a function result is a simple type
          in ISO 7185 6.6.2, so `f(x)[i]` cannot arise. }
        e := ParseSelectors(e)
      end
    end
    else begin
      ErrorAtCur;
      write('expected an expression, found ');
      WriteTokenName(tok[pos].kind);
      writeln;
      Bail
    end
  end;
  LeaveLevels(1);
  ParsePrimary := e
end;

{ factor = primary [ exponentiating-operator primary ] -- ISO/IEC 10206:1991
  6.8.1's extra precedence level, between `not` and the multiplying operators.
  The syntax admits *one* operator, so `a ** b ** c` is not a sentence of the
  language and is diagnosed rather than associated. Under ISO 7185 neither
  operator can reach here, and a factor is a primary. }
function ParseFactor;
var result, bin: nodePtr; op: binaryOp; isExp: boolean;
begin
  result := ParsePrimary;
  isExp := true;
  if Check(tkStarStar) then op := opExp
  else if Check(tkPow) then op := opPow
  else isExp := false;
  if isExp then begin
    bin := NewNode(nkBinary, CurLine, CurCol);
    pos := pos + 1;
    bin^.bnOp := op;
    bin^.bnLhs := result;
    bin^.bnRhs := ParsePrimary;
    result := bin;
    { 6.8.1 makes operators of one precedence left associative, but the syntax
      of a factor admits only one exponentiating-operator -- so `a ** b ** c`
      has no meaning to fall back on, and saying which parenthesisation is
      wanted is the caller's business rather than this parser's. }
    if Check(tkStarStar) or Check(tkPow) then begin
      ErrorAtCur;
      writeln('an exponentiating operator cannot follow another: write (a ** b) ** c or a ** (b ** c)');
      Bail
    end
  end;
  ParseFactor := result
end;

function ParseTerm: nodePtr;
var result, bin: nodePtr; levels: integer; op: binaryOp; done: boolean;
begin
  { see ParseSimpleExpr: `a*b*c*...` is a spine too }
  levels := 0;
  result := ParseFactor;
  done := false;
  while not done and not aborted do begin
    if Check(tkStar) then op := opMul
    else if Check(tkSlash) then op := opRealDiv
    else if Check(tkDiv) then op := opIntDiv
    else if Check(tkMod) then op := opMod
    else if Check(tkAnd) then op := opAnd
    { 6.8.3.1 puts `and then` among the multiplying-operators, beside `and` }
    else if Check(tkAndThen) then op := opAndThen
    else done := true;
    if not done then begin
      levels := levels + 1;
      EnterLevel;
      bin := NewNode(nkBinary, CurLine, CurCol);
      pos := pos + 1;
      bin^.bnOp := op;
      bin^.bnLhs := result;
      bin^.bnRhs := ParseFactor;
      result := bin
    end
  end;
  LeaveLevels(levels);
  ParseTerm := result
end;

function ParseSimpleExpr: nodePtr;
var result, un, bin: nodePtr; levels: integer; op: binaryOp; done: boolean;
begin
  { The operator loops build a left spine: `a+b+c+...` costs the parser no
    recursion at all, but the tree it leaves is as deep as the chain is long,
    and Sema, CodeGen and dispose all walk down it. Counting each iteration is
    what makes the depth limit a bound on the *tree* (ADR-0020). }
  levels := 0;
  if Check(tkPlus) or Check(tkMinus) then begin
    un := NewNode(nkUnary, CurLine, CurCol);
    if Check(tkMinus) then
      un^.unOp := opNeg
    else
      un^.unOp := opPos;
    pos := pos + 1;
    un^.unArg := ParseTerm;
    result := un
  end
  else
    result := ParseTerm;

  done := false;
  while not done and not aborted do begin
    if Check(tkPlus) then op := opAdd
    else if Check(tkMinus) then op := opSub
    else if Check(tkOr) then op := opOr
    { and `or else` among the adding-operators, beside `or` }
    else if Check(tkOrElse) then op := opOrElse
    else done := true;
    if not done then begin
      levels := levels + 1;
      EnterLevel;
      bin := NewNode(nkBinary, CurLine, CurCol);
      pos := pos + 1;
      bin^.bnOp := op;
      bin^.bnLhs := result;
      bin^.bnRhs := ParseTerm;
      result := bin
    end
  end;
  LeaveLevels(levels);
  ParseSimpleExpr := result
end;

function ParseExpr;
var lhs, bin: nodePtr; op: binaryOp; relational: boolean;
begin
  lhs := ParseSimpleExpr;
  relational := true;
  if Check(tkEq) then op := opEq
  else if Check(tkNotEq) then op := opNe
  else if Check(tkLt) then op := opLt
  else if Check(tkLe) then op := opLe
  else if Check(tkGt) then op := opGt
  else if Check(tkGe) then op := opGe
  else if Check(tkIn) then op := opIn
  else relational := false;

  if relational and not aborted then begin
    bin := NewNode(nkBinary, CurLine, CurCol);
    pos := pos + 1;
    bin^.bnOp := op;
    bin^.bnLhs := lhs;
    bin^.bnRhs := ParseSimpleExpr;
    ParseExpr := bin
  end
  else
    ParseExpr := lhs
end;

{ -------------------------------------------------------------- statements }

function ParseCompound: nodePtr;
var c, head, tail: nodePtr; done: boolean;
begin
  c := NewNode(nkCompound, CurLine, CurCol);
  c^.cpBody := nil;
  Expect(tkBegin, ctxCompoundStart);
  head := nil;
  tail := nil;
  if not Check(tkEnd) then begin
    done := false;
    while not done and not aborted do begin
      Append(head, tail, ParseStatement);
      if not Accept(tkSemi) then
        done := true
      else if Check(tkEnd) then   { trailing semicolon before 'end' }
        done := true
    end
  end;
  c^.cpBody := head;
  Expect(tkEnd, ctxCompoundEnd);
  ParseCompound := c
end;

function ParseIf: nodePtr;
var s: nodePtr;
begin
  s := NewNode(nkIf, CurLine, CurCol);
  s^.ifCond := nil;
  s^.ifThen := nil;
  s^.ifElse := nil;
  Expect(tkIf, ctxNone);
  s^.ifCond := ParseExpr;
  Expect(tkThen, ctxIf);
  s^.ifThen := ParseStatement;
  if Accept(tkElse) then
    s^.ifElse := ParseStatement;
  ParseIf := s
end;

function ParseWhile: nodePtr;
var s: nodePtr;
begin
  s := NewNode(nkWhile, CurLine, CurCol);
  s^.whCond := nil;
  s^.whBody := nil;
  Expect(tkWhile, ctxNone);
  s^.whCond := ParseExpr;
  Expect(tkDo, ctxWhile);
  s^.whBody := ParseStatement;
  ParseWhile := s
end;

function ParseRepeat: nodePtr;
var s, head, tail: nodePtr; done: boolean;
begin
  s := NewNode(nkRepeat, CurLine, CurCol);
  s^.rpBody := nil;
  s^.rpCond := nil;
  Expect(tkRepeat, ctxNone);
  head := nil;
  tail := nil;
  if not Check(tkUntil) then begin
    done := false;
    while not done and not aborted do begin
      Append(head, tail, ParseStatement);
      if not Accept(tkSemi) then
        done := true
      else if Check(tkUntil) then
        done := true
    end
  end;
  s^.rpBody := head;
  Expect(tkUntil, ctxRepeatEnd);
  s^.rpCond := ParseExpr;
  ParseRepeat := s
end;

function ParseFor: nodePtr;
var s, v: nodePtr;
begin
  s := NewNode(nkFor, CurLine, CurCol);
  s^.frVar := nil;
  s^.frFrom := nil;
  s^.frTo := nil;
  s^.frBody := nil;
  s^.frDownto := false;
  Expect(tkFor, ctxNone);
  if not aborted then
    if not Check(tkIdent) then begin
      ErrorAtCur;
      writeln('expected the control variable of the for statement');
      Bail
    end
    else begin
      v := NewNode(nkVar, CurLine, CurCol);
      v^.vrAt := tok[pos].at;
      v^.vrLen := tok[pos].len;
      s^.frVar := v;
      pos := pos + 1
    end;
  Expect(tkAssign, ctxFor);
  s^.frFrom := ParseExpr;
  if Accept(tkDownto) then
    s^.frDownto := true
  else
    Expect(tkTo, ctxFor);
  s^.frTo := ParseExpr;
  Expect(tkDo, ctxFor);
  s^.frBody := ParseStatement;
  ParseFor := s
end;

{ case-statement = 'case' expression 'of' arm (';' arm)* ';'? 'end'

  ISO 7185 6.8.3.5 has no `else` or `otherwise` arm, and none is invented
  here: a selector matching no label is an error the program stops on. }
function ParseCase: nodePtr;
var s, head, tail, arm, lh, lt, oh, ot: nodePtr;
    more, moreLabels, moreStmts: boolean;
begin
  s := NewNode(nkCase, CurLine, CurCol);
  s^.csSelector := nil;
  s^.csArms := nil;
  Expect(tkCase, ctxNone);
  s^.csSelector := ParseExpr;
  Expect(tkOf, ctxCaseSelector);

  head := nil;
  tail := nil;
  more := true;
  while more and not aborted and not Check(tkEnd) do begin
    { ISO/IEC 10206:1991's otherwise-part: what to do when no label matches,
      in place of the trap ISO 7185 leaves. It is last, so nothing follows it
      but `end`. }
    if Check(tkOtherwise) then begin
      pos := pos + 1;
      s^.csHasOtherwise := true;
      oh := nil;
      ot := nil;
      moreStmts := true;
      while moreStmts and not aborted do begin
        Append(oh, ot, ParseStatement);
        moreStmts := Accept(tkSemi)
      end;
      s^.csOtherwise := oh;
      more := false
    end
    else begin
    { Under ISO 7185 `otherwise` is an ordinary identifier, so this reads as a
      case label and fails somewhere unhelpful. It is only the construct if it
      is not being used as a constant -- `otherwise: s` and `otherwise, 2:` are
      a label list naming a constant, and stay one. }
    if Check(tkIdent) and PoolIs(tok[pos].at, tok[pos].len, 'otherwise') and
       (PeekKind(1) <> tkColon) and (PeekKind(1) <> tkComma) and
       (PeekKind(1) <> tkDotDot) then begin
      ErrorAtCur;
      write('the ''otherwise'' part of a case statement is an Extended ');
      writeln('Pascal feature; compile with --std=extended');
      Bail
    end;
    arm := NewNode(nkCaseArm, CurLine, CurCol);
    arm^.caLabels := nil;
    arm^.caBody := nil;
    lh := nil;
    lt := nil;
    moreLabels := true;
    while moreLabels and not aborted do begin
      Append(lh, lt, ParseCaseLabel);
      moreLabels := Accept(tkComma)
    end;
    arm^.caLabels := lh;
    Expect(tkColon, ctxCaseLabels);
    arm^.caBody := ParseStatement;
    Append(head, tail, arm);
    more := Accept(tkSemi)
    end
  end;
  s^.csArms := head;
  Expect(tkEnd, ctxCaseEnd);
  ParseCase := s
end;

{ The C++ parser walks its vector of records backwards to nest these. A
  sibling list has no backwards, so the nesting is built by recursion over the
  list instead -- the same tree, arrived at from the other end. }
function NestWith(r, body: nodePtr; l, c: integer): nodePtr;
var w, rest: nodePtr;
begin
  if r = nil then
    NestWith := body
  else begin
    rest := r^.next;
    r^.next := nil;   { the record is a child now, not a sibling }
    w := NewNode(nkWith, l, c);
    w^.wtRecord := r;
    w^.wtBody := NestWith(rest, body, l, c);
    NestWith := w
  end
end;

{ `with a, b do S` abbreviates `with a do with b do S` (ISO 7185 6.8.3.10), so
  the list is nested here and every later stage sees one record at a time. }
function ParseWith: nodePtr;
var head, tail, ref, body: nodePtr; l, c: integer; more: boolean;
begin
  l := CurLine;
  c := CurCol;
  Expect(tkWith, ctxNone);

  head := nil;
  tail := nil;
  more := true;
  while more and not aborted do begin
    if not Check(tkIdent) then begin
      ErrorAtCur;
      writeln('expected a record variable after ''with''');
      Bail
    end
    else begin
      ref := NewNode(nkVar, CurLine, CurCol);
      ref^.vrAt := tok[pos].at;
      ref^.vrLen := tok[pos].len;
      pos := pos + 1;
      Append(head, tail, ParseSelectors(ref));
      more := Accept(tkComma)
    end
  end;

  Expect(tkDo, ctxWith);
  body := ParseStatement;
  ParseWith := NestWith(head, body, l, c)
end;

function ParseWrite(newlineForm: boolean): nodePtr;
var s, head, tail, a: nodePtr; more: boolean;
begin
  s := NewNode(nkWrite, CurLine, CurCol);
  s^.wrNewline := newlineForm;
  s^.wrArgs := nil;
  pos := pos + 1;   { 'write' / 'writeln' }

  head := nil;
  tail := nil;
  if Accept(tkLParen) then begin
    if not Check(tkRParen) then begin
      more := true;
      while more and not aborted do begin
        a := NewNode(nkWriteArg, CurLine, CurCol);
        a^.waValue := nil;
        a^.waWidth := nil;
        a^.waPrec := nil;
        a^.waValue := ParseExpr;
        if Accept(tkColon) then begin
          a^.waWidth := ParseExpr;
          if Accept(tkColon) then
            a^.waPrec := ParseExpr
        end;
        Append(head, tail, a);
        more := Accept(tkComma)
      end
    end;
    Expect(tkRParen, ctxWriteArgs)
  end;
  s^.wrArgs := head;
  ParseWrite := s
end;

{ read/readln. The arguments are variables to store into, and the first may be
  a file instead -- Sema sorts that out, because telling them apart needs the
  types. `readln` alone, with no list at all, finishes the current line. }
function ParseRead(newlineForm: boolean): nodePtr;
var s, head, tail: nodePtr; more: boolean;
begin
  s := NewNode(nkRead, CurLine, CurCol);
  s^.rdNewline := newlineForm;
  s^.rdArgs := nil;
  pos := pos + 1;   { 'read' / 'readln' }

  head := nil;
  tail := nil;
  if Accept(tkLParen) then begin
    if not Check(tkRParen) then begin
      more := true;
      while more and not aborted do begin
        Append(head, tail, ParseExpr);
        more := Accept(tkComma)
      end
    end;
    Expect(tkRParen, ctxReadArgs)
  end;
  s^.rdArgs := head;
  ParseRead := s
end;

function ParseIdentStatement: nodePtr;
var s, ref, head, tail: nodePtr; l, c, at, len: integer;
    more, handled: boolean; k: tokenKind;
begin
  l := CurLine;
  c := CurCol;
  at := tok[pos].at;
  len := tok[pos].len;
  s := nil;
  handled := true;
  if PoolIs(at, len, 'write    ') then s := ParseWrite(false)
  else if PoolIs(at, len, 'writeln  ') then s := ParseWrite(true)
  else if PoolIs(at, len, 'read     ') then s := ParseRead(false)
  else if PoolIs(at, len, 'readln   ') then s := ParseRead(true)
  else handled := false;

  if not handled then begin
    { A statement starting with a designator is an assignment; one starting
      with a bare name or a name and arguments is a procedure call. The
      selectors are what tell the two apart, because only a designator can
      carry them. }
    k := PeekKind(1);
    if (k = tkAssign) or (k = tkLBracket) or (k = tkPeriod) or
       (k = tkCaret) then begin
      s := NewNode(nkAssign, l, c);
      s^.asTarget := nil;
      s^.asValue := nil;
      ref := NewNode(nkVar, l, c);
      ref^.vrAt := at;
      ref^.vrLen := len;
      pos := pos + 1;
      s^.asTarget := ParseSelectors(ref);
      Expect(tkAssign, ctxAssign);
      s^.asValue := ParseExpr
    end
    else begin
      { Anything else beginning with an identifier is a procedure call. A
        parameterless call is just the name -- Pascal has no empty list. }
      s := NewNode(nkProcCall, l, c);
      s^.pcAt := at;
      s^.pcLen := len;
      s^.pcArgs := nil;
      pos := pos + 1;
      head := nil;
      tail := nil;
      if Accept(tkLParen) then begin
        if not Check(tkRParen) then begin
          more := true;
          while more and not aborted do begin
            Append(head, tail, ParseExpr);
            more := Accept(tkComma)
          end
        end;
        Expect(tkRParen, ctxProcCallArgs)
      end;
      s^.pcArgs := head
    end
  end;
  ParseIdentStatement := s
end;

function ParseStatement;
var s: nodePtr;
begin
  { Every statement-in-statement cycle -- begin/end, if, while, for, with,
    case -- passes through here, so one guard covers them all. }
  EnterLevel;
  s := nil;
  if not aborted then begin
    if Check(tkBegin) then s := ParseCompound
    else if Check(tkIf) then s := ParseIf
    else if Check(tkWhile) then s := ParseWhile
    else if Check(tkRepeat) then s := ParseRepeat
    else if Check(tkFor) then s := ParseFor
    else if Check(tkWith) then s := ParseWith
    else if Check(tkCase) then s := ParseCase
    else if Check(tkIdent) then s := ParseIdentStatement
    { ISO 7185 6.8.1 makes an empty statement a statement, so every token that
      can *follow* one also starts one: ';' and 'end' between statements,
      'else' after a then-branch, 'until' after a repeat body. }
    else if Check(tkEnd) or Check(tkSemi) or Check(tkElse) or Check(tkUntil)
    then
      s := NewNode(nkEmpty, CurLine, CurCol)
    else if Check(tkGoto) then begin
      s := NewNode(nkGoto, CurLine, CurCol);
      pos := pos + 1;
      s^.gtLabel := ParseLabel(ctxAfterGoto)
    end
    { A statement beginning with an unsigned integer can only be a labelled
      one: no expression starts a statement, so the ':' is not in doubt and
      needs no lookahead to find. }
    else if Check(tkInt) then begin
      s := NewNode(nkLabeled, CurLine, CurCol);
      s^.lbStmt := nil;
      s^.lbLabel := ParseLabel(ctxLabelStart);
      Expect(tkColon, ctxAfterLabel);
      s^.lbStmt := ParseStatement
    end
    else begin
      ErrorAtCur;
      write('expected a statement, found ');
      WriteTokenName(tok[pos].kind);
      writeln;
      Bail
    end
  end;
  LeaveLevels(1);
  ParseStatement := s
end;

{ ------------------------------------------------------------ declarations }

{ The three declaration parts append to the block's lists rather than
  replacing them, because the C++ parser's loop accepts a second `const` or
  `var` part and pushes onto the same vector. ISO 7185 6.2.1 permits only one
  of each, but where the two parsers are lenient they have to be lenient in
  the same way. }
procedure ParseConstPart(var head, tail: nodePtr);
var d: nodePtr; more: boolean;
begin
  Expect(tkConst, ctxNone);
  more := true;
  while more and not aborted do begin
    if not Check(tkIdent) then begin
      ErrorAtCur;
      writeln('expected a constant name');
      Bail
    end
    else begin
      d := NewNode(nkConstDecl, CurLine, CurCol);
      d^.kdAt := tok[pos].at;
      d^.kdLen := tok[pos].len;
      d^.kdValue := nil;
      pos := pos + 1;
      Expect(tkEq, ctxConstDef);
      d^.kdValue := ParseExpr;
      Expect(tkSemi, ctxConstDefEnd);
      Append(head, tail, d);
      more := (not aborted) and Check(tkIdent)
    end
  end
end;

{ formal-discriminant-part = '(' discriminant-specification
                              (';' discriminant-specification)* ')'
  discriminant-specification = identifier-list ':' ordinal-type-name

  The separator is ';' as in a formal parameter list, not the ',' of the
  actual-discriminant-part that later selects a type from the schema -- which
  is the standard's own asymmetry (6.4.7 against 6.4.8), and the reason these
  are two routines rather than one. }
procedure ParseFormalDiscriminants(var head, tail: nodePtr);
var g, ty: nodePtr; more: boolean;
begin
  Expect(tkLParen, ctxNone);
  more := true;
  while more and not aborted do begin
    g := NewNode(nkGroup, CurLine, CurCol);
    g^.grNames := nil;
    g^.grType := nil;
    g^.grParams := nil;
    g^.grResult := nil;
    g^.grByRef := false;
    g^.grIsProtected := false;
    g^.grIsProc := false;
    g^.grIsFunction := false;
    g^.grNames := ParseNameList(ctxFormalDisc);
    Expect(tkColon, ctxFormalDisc);
    if not Check(tkIdent) then begin
      ErrorAtCur;
      writeln('the type of a discriminant must be an ordinal type name');
      Bail
    end
    else begin
      ty := NewNode(nkNamed, CurLine, CurCol);
      ty^.nmAt := tok[pos].at;
      ty^.nmLen := tok[pos].len;
      pos := pos + 1;
      g^.grType := ty;
      Append(head, tail, g);
      more := (not aborted) and Accept(tkSemi)
    end
  end;
  Expect(tkRParen, ctxSchemaArgs)
end;

procedure ParseTypePart(var head, tail: nodePtr);
var d: nodePtr; more: boolean;
begin
  Expect(tkType, ctxNone);
  more := true;
  while more and not aborted do begin
    if not Check(tkIdent) then begin
      ErrorAtCur;
      writeln('expected a type name');
      Bail
    end
    else begin
      d := NewNode(nkTypeDecl, CurLine, CurCol);
      d^.tdAt := tok[pos].at;
      d^.tdLen := tok[pos].len;
      d^.tdType := nil;
      d^.tdDiscs := nil;
      d^.tdDiscTail := nil;
      pos := pos + 1;
      { 6.4.7's schema-definition is a type-definition with a
        formal-discriminant-part wedged between the name and the '='. One
        token tells them apart, and it is the same token in both languages. }
      if Check(tkLParen) then
        if langStd = stdIso7185 then begin
          ErrorAtCur;
          writeln('a schema is an Extended Pascal feature; compile with ',
                  '--std=extended');
          Bail
        end
        else
          ParseFormalDiscriminants(d^.tdDiscs, d^.tdDiscTail);
      Expect(tkEq, ctxTypeDef);
      d^.tdType := ParseTypeExpr;
      Expect(tkSemi, ctxTypeDefEnd);
      Append(head, tail, d);
      more := (not aborted) and Check(tkIdent)
    end
  end
end;

procedure ParseVarPart(var head, tail: nodePtr);
var g: nodePtr; more: boolean;
begin
  Expect(tkVar, ctxNone);
  more := true;
  while more and not aborted do begin
    g := NewNode(nkGroup, CurLine, CurCol);
    g^.grByRef := false;
    g^.grIsProtected := false;
    g^.grNames := nil;
    g^.grType := nil;
    g^.grNames := ParseNameList(ctxVarDecl);
    Expect(tkColon, ctxVarDecl);
    g^.grType := ParseTypeExpr;
    Expect(tkSemi, ctxVarDeclEnd);
    Append(head, tail, g);
    more := (not aborted) and Check(tkIdent)
  end
end;

{ formal-parameters = '(' group (';' group)* ')'
  group             = 'var'? ident-list ':' type-denoter
                    | 'procedure' ident formal-parameters?
                    | 'function' ident formal-parameters? ':' type-denoter

  ISO 7185 6.6.3.1 restricts a parameter's type to a type *identifier*, so an
  array parameter needs a named type. That is a real restriction, not an
  omission: it is what makes a formal and an actual parameter the same type
  rather than two structurally identical ones.

  The last two forms are a procedural and a functional parameter, and each is
  spelled as a *heading* rather than as a type -- which is why one group
  declares one name there, and why this production has to recurse. }
function ParseFormalParameters: nodePtr; forward;

procedure ParseProcParam(g: nodePtr; isFunction: boolean);
begin
  g^.grIsProc := true;
  g^.grIsFunction := isFunction;
  pos := pos + 1;   { 'procedure' / 'function' }

  if not Check(tkIdent) then begin
    ErrorAtCur;
    if isFunction then
      writeln('expected the name of the functional parameter')
    else
      writeln('expected the name of the procedural parameter');
    Bail
  end
  else begin
    g^.grNames := NewNode(nkDeclName, CurLine, CurCol);
    g^.grNames^.dnAt := tok[pos].at;
    g^.grNames^.dnLen := tok[pos].len;
    pos := pos + 1
  end;

  if (not aborted) and Check(tkLParen) then
    g^.grParams := ParseFormalParameters;

  { A functional parameter's heading carries its result type, and there is no
    `forward` here to make it optional the way 6.6.1 makes it optional in a
    declaration -- so unlike ParseProcOrFunc this one insists on it. }
  if isFunction and not aborted then begin
    Expect(tkColon, ctxFuncParamResult);
    if not aborted then
      if not Check(tkIdent) then begin
        ErrorAtCur;
        writeln('the result type of a functional parameter must be a type name');
        Bail
      end;
    g^.grResult := ParseTypeDenoter
  end
end;

function ParseFormalParameters;
var head, tail, g: nodePtr; more: boolean;
begin
  head := nil;
  tail := nil;
  Expect(tkLParen, ctxNone);
  more := true;
  while more and not aborted do begin
    g := NewNode(nkGroup, CurLine, CurCol);
    g^.grNames := nil;
    g^.grType := nil;
    g^.grByRef := false;
    g^.grIsProtected := false;
    if Check(tkProcedure) or Check(tkFunction) then
      ParseProcParam(g, Check(tkFunction))
    else begin
      { 6.7.3.1 puts `protected` before the whole specification, so it comes
        before `var` rather than after it: a protected variable parameter is
        `protected var d: integer`. Both orders read alike, and only one
        parses. }
      g^.grIsProtected := Accept(tkProtected);
      g^.grByRef := Accept(tkVar);
      g^.grNames := ParseNameList(ctxParamList);
      Expect(tkColon, ctxParamList);
      { 6.7.3.1: `parameter-form = type-name | schema-name | type-inquiry`, so
        a parameter's type is still not a type-denoter -- it is a name, or one
        of those two other forms. `type` is the only word-symbol that may begin
        one. }
      if not aborted then
        if not (Check(tkIdent) or Check(tkType)) then begin
          ErrorAtCur;
          writeln('a parameter''s type must be a type name');
          Bail
        end;
      g^.grType := ParseTypeDenoter
    end;
    Append(head, tail, g);
    more := Accept(tkSemi)
  end;
  Expect(tkRParen, ctxParamListEnd);
  ParseFormalParameters := head
end;

function ParseProcOrFunc(isFunction: boolean): nodePtr;
var d: nodePtr;
begin
  d := NewNode(nkProcDecl, CurLine, CurCol);
  d^.pdIsFunction := isFunction;
  d^.pdIsForward := false;
  d^.pdParams := nil;
  d^.pdResult := nil;
  d^.pdBody := nil;
  d^.pdAt := 0;
  d^.pdLen := 0;
  pos := pos + 1;   { 'procedure' / 'function' }

  if not Check(tkIdent) then begin
    ErrorAtCur;
    if isFunction then
      writeln('expected the function name')
    else
      writeln('expected the procedure name');
    Bail
  end
  else begin
    d^.pdAt := tok[pos].at;
    d^.pdLen := tok[pos].len;
    pos := pos + 1
  end;

  if (not aborted) and Check(tkLParen) then
    d^.pdParams := ParseFormalParameters;

  { The completion of a forward declaration repeats the name alone (ISO 7185
    6.6.1), so both the parameters and the result type may be absent here. }
  if isFunction and Accept(tkColon) then begin
    if not Check(tkIdent) then begin
      ErrorAtCur;
      writeln('expected the result type of the function');
      Bail
    end;
    d^.pdResult := ParseTypeDenoter
  end;
  Expect(tkSemi, ctxProcHeading);

  { `forward` is not a reserved word; it is an identifier in this position. }
  if (not aborted) and Check(tkIdent) and
     PoolIs(tok[pos].at, tok[pos].len, 'forward  ') then begin
    pos := pos + 1;
    d^.pdIsForward := true
  end
  else
    d^.pdBody := ParseBlock;
  Expect(tkSemi, ctxProcBody);
  ParseProcOrFunc := d
end;

{ block = const-part? type-part? var-part? (procedure | function)*
          statement-part

  The same production serves the program and every procedure, so nesting needs
  no extra machinery here. }
function ParseBlock;
var b, ph, pt, ch, ct, th, tt, vh, vt, lh, lt: nodePtr; done: boolean;
begin
  b := NewNode(nkBlock, CurLine, CurCol);
  b^.blLabels := nil;
  b^.blConsts := nil;
  b^.blTypes := nil;
  b^.blVars := nil;
  b^.blProcs := nil;
  b^.blBody := nil;
  ph := nil; pt := nil;
  ch := nil; ct := nil;
  th := nil; tt := nil;
  vh := nil; vt := nil;
  lh := nil; lt := nil;

  done := false;
  while not done and not aborted do begin
    if Check(tkConst) then
      ParseConstPart(ch, ct)
    else if Check(tkType) then
      ParseTypePart(th, tt)
    else if Check(tkVar) then
      ParseVarPart(vh, vt)
    else if Check(tkProcedure) then
      Append(ph, pt, ParseProcOrFunc(false))
    else if Check(tkFunction) then
      Append(ph, pt, ParseProcOrFunc(true))
    else if Check(tkLabel) then
      ParseLabelPart(lh, lt)
    else
      done := true
  end;
  b^.blLabels := lh;
  b^.blConsts := ch;
  b^.blTypes := th;
  b^.blVars := vh;
  b^.blProcs := ph;

  b^.blBody := ParseCompound;
  ParseBlock := b
end;

procedure ParseProgram;
var head, tail, n: nodePtr; more: boolean;
begin
  progParams := nil;
  progBlock := nil;
  progAt := 0;
  progLen := 0;

  Expect(tkProgram, ctxProgramStart);
  if not aborted then
    if not Check(tkIdent) then begin
      ErrorAtCur;
      writeln('expected the program name');
      Bail
    end
    else begin
      progAt := tok[pos].at;
      progLen := tok[pos].len;
      pos := pos + 1
    end;

  { `input` and `output` name the standard files; any other one must be a file
    variable the block declares, and is bound to a command-line argument
    (ISO 7185 6.10 leaves the binding to the implementation). }
  head := nil;
  tail := nil;
  if Accept(tkLParen) then begin
    more := true;
    while more and not aborted do begin
      if not Check(tkIdent) then begin
        ErrorAtCur;
        writeln('expected a program parameter name');
        Bail
      end
      else begin
        n := NewNode(nkDeclName, CurLine, CurCol);
        n^.dnAt := tok[pos].at;
        n^.dnLen := tok[pos].len;
        Append(head, tail, n);
        pos := pos + 1;
        more := Accept(tkComma)
      end
    end;
    Expect(tkRParen, ctxProgramParams)
  end;
  progParams := head;
  Expect(tkSemi, ctxProgramHeader);

  progBlock := ParseBlock;
  Expect(tkPeriod, ctxFinalEnd);
  if (not aborted) and not Check(tkEof) then begin
    ErrorAtCur;
    writeln('trailing text after the end of the program')
  end
end;

{ ==========================================================================
  Sema: name resolution and type checking.

  A port of src/sema.cpp and src/type.h. What it must leave behind is what
  ADR-0008 promises codegen: every expression with a type, every name resolved
  to a symbol, and every block with an activation record laid out.
  ========================================================================== }

{ ------------------------------------------------------------ the type arena }

function NewType(k: typeKind): typePtr;
var t: typePtr;
begin
  new(t);
  t^.kind := k;
  t^.elem := nil;
  t^.indexType := nil;
  t^.host := nil;
  t^.tagType := nil;
  t^.isPacked := false;
  t^.isText := false;
  t^.lo := 0;
  t^.hi := -1;
  t^.enumNames := nil;
  t^.enumTail := nil;
  t^.fields := nil;
  t^.fieldTail := nil;
  t^.variants := nil;
  t^.variantTail := nil;
  t^.discSelector := false;
  t^.tagField := -1;
  t^.aliasAt := 0;
  t^.aliasLen := 0;
  t^.schema := nil;
  t^.tuple := nil;
  t^.tupleTail := nil;
  t^.loDisc := nil;
  t^.hiDisc := nil;
  t^.heapTuple := false;
  t^.descOwner := nil;
  NewType := t
end;

{ The type a subrange is a subrange of; every other type is its own base.
  Assignment compatibility, arithmetic and the machine representation are all
  decided on the base, which is what makes `1..9` an integer that happens to be
  checked (ISO 7185 6.4.2.4). }
function Base(t: typePtr): typePtr;
begin
  if (t <> nil) and (t^.kind = tySubrange) and (t^.host <> nil) then
    Base := t^.host
  else
    Base := t
end;

{ These ask what a value *is*, so they look through a subrange to its host:
  `1..9` is an integer that happens to be range-checked, and every rule about
  integers applies to it unchanged.

  Note the local in each: ISO 7185 6.5.1 makes a variable-access the only thing
  a selector may follow, so Base(t)^.kind -- which the C++ writes directly --
  is not a thing this language can say. }
function IsInteger(t: typePtr): boolean;
var b: typePtr;
begin
  b := Base(t);
  IsInteger := (b <> nil) and (b^.kind = tyInteger)
end;

function IsReal(t: typePtr): boolean;
begin IsReal := (t <> nil) and (t^.kind = tyReal) end;

function IsComplex(t: typePtr): boolean;
begin IsComplex := (t <> nil) and (t^.kind = tyComplex) end;

{ A type produced from the required schema `string` (6.4.3.3.3), or the
  canonical-string-type that `+` yields. }
function IsVarString(t: typePtr): boolean;
begin IsVarString := (t <> nil) and (t^.kind = tyString) end;

function IsNumeric(t: typePtr): boolean;
begin IsNumeric := IsInteger(t) or IsReal(t) end;

{ Everything the arithmetic operators accept (6.8.3.2, table 3). Kept apart
  from IsNumeric because the *ordering* operators take a numeric type and
  refuse a complex one -- 6.8.3.5 admits only = and <> there, there being no
  order on the complex numbers. }
function IsArith(t: typePtr): boolean;
begin IsArith := IsNumeric(t) or IsComplex(t) end;

function IsBoolean(t: typePtr): boolean;
var b: typePtr;
begin
  b := Base(t);
  IsBoolean := (b <> nil) and (b^.kind = tyBoolean)
end;

function IsChar(t: typePtr): boolean;
var b: typePtr;
begin
  b := Base(t);
  IsChar := (b <> nil) and (b^.kind = tyChar)
end;

function IsEnum(t: typePtr): boolean;
var b: typePtr;
begin
  b := Base(t);
  IsEnum := (b <> nil) and (b^.kind = tyEnum)
end;

function IsArray(t: typePtr): boolean;
begin IsArray := (t <> nil) and (t^.kind = tyArray) end;

function IsRecord(t: typePtr): boolean;
begin IsRecord := (t <> nil) and (t^.kind = tyRecord) end;

function IsPointer(t: typePtr): boolean;
begin IsPointer := (t <> nil) and (t^.kind = tyPointer) end;

function IsFile(t: typePtr): boolean;
begin IsFile := (t <> nil) and (t^.kind = tyFile) end;

{ `text` as against `file of char`: see typeRec.isText. }
function IsTextFile(t: typePtr): boolean;
begin IsTextFile := IsFile(t) and t^.isText end;

{ `nil`, which is a value of every pointer type and of no other. }
function IsNil(t: typePtr): boolean;
begin IsNil := IsPointer(t) and (t^.elem = nil) end;

function IsSet(t: typePtr): boolean;
begin IsSet := (t <> nil) and (t^.kind = tySet) end;

{ The type of a procedural or functional parameter (ISO 7185 6.6.3.1). }
function IsProcType(t: typePtr): boolean;
begin IsProcType := (t <> nil) and (t^.kind = tyProc) end;

{ `[]`, which belongs to every set type -- the set-valued counterpart of nil,
  and elem-less for the same reason: it has no base type of its own. }
function IsEmptySet(t: typePtr): boolean;
begin IsEmptySet := IsSet(t) and (t^.elem = nil) end;

{ Arrays and records live in memory and are copied wholesale. A file is *not*
  structured: it also lives in memory, but it may never be copied, so grouping
  it here would grant it exactly the operations it must not have. }
{ A set is not structured either, and for the opposite reason to a file: it
  *is* a value. Every set is one 256-bit integer, so it is assigned, compared
  and passed exactly as an integer is (ADR-0028). }
function IsStructured(t: typePtr): boolean;
begin IsStructured := IsArray(t) or IsRecord(t) end;

function IsMemory(t: typePtr): boolean;
begin IsMemory := IsStructured(t) or IsFile(t) or IsVarString(t) end;

{ ISO/IEC 10206:1991 6.4.1: a type is protectable unless it is a file or a
  pointer, or is structured and holds one. The standard's own NOTE gives both
  reasons: nearly every operation on a file modifies it, and a pointer *value*
  can be copied out and disposed of -- so protecting the variable would protect
  nothing. Only 6.7.3.1 asks this today. }
function Protectable(t: typePtr): boolean;
var f: fieldPtr; ok: boolean;
begin
  if t = nil then
    Protectable := true
  else if IsFile(t) or IsPointer(t) then
    Protectable := false
  else if IsArray(t) then
    Protectable := Protectable(t^.elem)
  else if IsRecord(t) then begin
    ok := true;
    f := t^.fields;
    while (f <> nil) and ok do begin
      if not Protectable(f^.ftype) then ok := false;
      f := f^.next
    end;
    Protectable := ok
  end
  else
    Protectable := true
end;

function IsOrdinal(t: typePtr): boolean;
var k: typeKind; b: typePtr;
begin
  if t = nil then
    IsOrdinal := false
  else begin
    b := Base(t);
    k := b^.kind;
    IsOrdinal := (k = tyInteger) or (k = tyBoolean) or (k = tyChar) or
                 (k = tyEnum)
  end
end;

{ A `packed array [1..n] of char` -- the type ISO 7185 6.4.3.2 gives a string
  literal, and the only structured type with its own operators. }
function IsCharArray(t: typePtr): boolean;
begin
  IsCharArray := IsArray(t) and t^.isPacked and IsChar(t^.elem)
end;

{ 6.4.3.3.1: "A string-type shall be a fixed-string-type or a
  variable-string-type or the required type designated canonical-string-type."
  A fixed-string-type is 6.4.3.3.2's `packed array [1..n] of char`, which
  ISO 7185 already had and already gave the relational operators. }
function IsStringType(t: typePtr): boolean;
begin IsStringType := IsVarString(t) or IsCharArray(t) end;

{ 6.4.3.3.1 gives the char-type "length 1 and capacity 1", so it stands
  wherever a string does -- in a comparison, a concatenation, an assignment --
  without being one. }
function IsStringOrChar(t: typePtr): boolean;
begin IsStringOrChar := IsStringType(t) or IsChar(t) end;

function EnumCount(t: typePtr): integer;
var p: namePtr; n: integer;
begin
  n := 0;
  p := t^.enumNames;
  while p <> nil do begin
    n := n + 1;
    p := p^.next
  end;
  EnumCount := n
end;

{ The first and last values of an ordinal type -- what succ and pred run out
  at, and what a subrange assignment is checked against. }
function OrdinalLo(t: typePtr): integer;
begin
  if t^.kind = tySubrange then OrdinalLo := t^.lo
  else if t^.kind = tyInteger then OrdinalLo := -maxint
  else OrdinalLo := 0
end;

function OrdinalHi(t: typePtr): integer;
begin
  if t^.kind = tySubrange then OrdinalHi := t^.hi
  else if t^.kind = tyInteger then OrdinalHi := maxint
  else if t^.kind = tyChar then OrdinalHi := 255
  else if t^.kind = tyBoolean then OrdinalHi := 1
  else if t^.kind = tyEnum then OrdinalHi := EnumCount(t) - 1
  else OrdinalHi := 0
end;

function TypeLength(t: typePtr): integer;
begin TypeLength := t^.hi - t^.lo + 1 end;

{ ISO 7185 6.4.3.3 requires every field name in a record to be distinct,
  variants included, so one flat search over all of them is unambiguous. }
{ The k-th arm of one variant part. }
function ArmAtIn(v: variantPtr; k: integer): variantPtr;
begin
  while k > 0 do begin
    v := v^.next;
    k := k - 1
  end;
  ArmAtIn := v
end;

function FindFieldIn(v: variantPtr; at, len: integer): fieldPtr;
var f, found: fieldPtr;
begin
  found := nil;
  while (v <> nil) and (found = nil) do begin
    f := v^.fields;
    while (f <> nil) and (found = nil) do begin
      if PoolSame(f^.at, f^.len, at, len) then found := f;
      f := f^.next
    end;
    if found = nil then found := FindFieldIn(v^.variants, at, len);
    v := v^.next
  end;
  FindFieldIn := found
end;

function FindField(t: typePtr; at, len: integer): fieldPtr;
var f, found: fieldPtr;
begin
  found := nil;
  f := t^.fields;
  while (f <> nil) and (found = nil) do begin
    if PoolSame(f^.at, f^.len, at, len) then found := f;
    f := f^.next
  end;
  if found = nil then found := FindFieldIn(t^.variants, at, len);
  FindField := found
end;

{ ------------------------------------------------------------- type names }

procedure WriteTypeName(t: typePtr); forward;

{ How a value of an ordinal type is written in source: 7, 'a', true, or an
  enumeration constant's own name. }
procedure WriteOrdinalName(t: typePtr; value: integer);
var b: typePtr; p: namePtr; i: integer; done: boolean;
begin
  if t = nil then b := nil else b := Base(t);
  if b = nil then
    PutInt(value)
  { A printable character is written as itself; anything else is written as
    chr(n). Not cosmetic: the C++ prints a diagnostic with %s, so a char of
    value 0 written literally would truncate the message at that point. }
  else if b^.kind = tyChar then
    if (value >= 32) and (value < 127) then begin
      Put('''');
      Put(chr(value));
      Put('''')
    end
    else begin
      PutLit('chr(            ');
      PutInt(value);
      Put(')')
    end
  else if b^.kind = tyBoolean then
    if value <> 0 then PutLit('true            ')
    else PutLit('false           ')
  else if (b^.kind = tyEnum) and (value >= 0) and (value < EnumCount(b)) then
  begin
    p := b^.enumNames;
    i := 0;
    done := false;
    while not done do
      if i = value then begin
        WritePool(p^.at, p^.len);
        done := true
      end
      else begin
        p := p^.next;
        i := i + 1
      end
  end
  else
    PutInt(value)
end;

{ A description for diagnostics. A named type reports its name; an anonymous
  one is spelled out the way the source would have written it. }
{ How a bound is written when it may be dynamic: a constant as itself, and a
  discriminant as its own name. }
procedure WriteBoundName(t: typePtr; disc: symPtr; value: integer);
begin
  if disc = nil then WriteOrdinalName(t, value)
  else WritePool(disc^.at, disc^.len)
end;

procedure WriteTypeName;
var p: namePtr; f: fieldPtr; first: boolean;
begin
  if t = nil then
    Put('?')
  else if t^.aliasLen > 0 then
    WritePool(t^.aliasAt, t^.aliasLen)
  else
    case t^.kind of
      tyInteger: PutLit('integer         ');
      tyReal:    PutLit('real            ');
      tyComplex: PutLit('complex         ');
      tyString:
        if t^.hi < 0 then PutLit('string          ')
        else begin
          PutLit('string(         ');
          PutInt(t^.hi);
          PutLit(')               ')
        end;
      tyBoolean: PutLit('boolean         ');
      tyChar:    PutLit('char            ');
      tyVoid:    PutLit('void            ');
      tyEnum: begin
        Put('(');
        p := t^.enumNames;
        first := true;
        while p <> nil do begin
          if not first then begin PutLit(',               '); Put(' ') end;
          WritePool(p^.at, p^.len);
          first := false;
          p := p^.next
        end;
        Put(')')
      end;
      tySubrange: begin
        WriteBoundName(t^.host, t^.loDisc, t^.lo);
        PutLit('..              ');
        WriteBoundName(t^.host, t^.hiDisc, t^.hi)
      end;
      { ISO 7185 6.4.4 makes a pointer's domain a type *identifier*, so the
        recursion always stops at a name -- which is what lets a type point at
        itself without this looping forever. }
      tyPointer:
        if t^.elem <> nil then begin
          Put('^');
          WriteTypeName(t^.elem)
        end
        else
          PutLit('nil             ');
      { `text` names itself; every other file names its component, because a
        `file of char` is a different type from a text and a diagnostic that
        called them both "text" would be describing the wrong one. }
      { A direct-access file names its index type too (6.4.3.6): it is what
        makes the type direct-access, so a diagnostic that left it out would
        be describing a different type. }
      tyFile:
        if t^.isText then PutLit('text            ')
        else if t^.indexType <> nil then begin
          PutLit('file [          ');
          WriteTypeName(t^.indexType);
          PutLit('] of            ');
          Put(' ');
          WriteTypeName(t^.elem)
        end
        else begin
          PutLit('file of         ');
          Put(' ');
          WriteTypeName(t^.elem)
        end;
      { The type of `[]` names no base type because it has none; it is written
        the way the source writes it. }
      tySet:
        if t^.elem = nil then PutLit('[]              ')
        else begin
          PutLit('set of          ');
          Put(' ');
          WriteTypeName(t^.elem)
        end;
      { Two procedural parameters differ by their *parameter lists*, and ISO
        7185 6.6.3.6 compares those pairwise rather than as a whole; the
        congruity diagnostic names the parameter that failed, so spelling a
        signature out here would say less at more cost. }
      tyProc:
        if t^.elem = nil then PutLit('procedure       ')
        else begin
          PutLit('function        ');
          Put(' ');
          PutLit('returning       ');
          Put(' ');
          WriteTypeName(t^.elem)
        end;
      tyRecord: begin
        { An anonymous record is named by its fields, which is the only thing
          that distinguishes it from any other anonymous record. }
        PutLit('record          ');
        Put(' ');
        f := t^.fields;
        first := true;
        while f <> nil do begin
          if not first then begin PutLit(',               '); Put(' ') end;
          WritePool(f^.at, f^.len);
          first := false;
          f := f^.next
        end;
        PutLit(' end            ')
      end;
      tyArray: begin
        if t^.isPacked then PutLit('packed array [  ')
        else PutLit('array [         ');
        WriteBoundName(t^.indexType, t^.loDisc, t^.lo);
        PutLit('..              ');
        WriteBoundName(t^.indexType, t^.hiDisc, t^.hi);
        PutLit('] of            ');
        Put(' ');
        if t^.elem <> nil then WriteTypeName(t^.elem) else Put('?')
      end
    end
end;

{ ---------------------------------------------------------------- symbols }

function NewSymbol: symPtr;
var s: symPtr;
begin
  new(s);
  s^.at := 0;
  s^.len := 0;
  s^.kind := skVar;
  s^.stype := nil;
  s^.binding := fbInternal;
  s^.fileArg := 0;
  s^.intVal := 0;
  s^.charVal := chr(0);
  s^.boolVal := false;
  s^.realAt := 0;
  s^.realLen := 0;
  s^.realNeg := false;
  s^.irId := 0;
  s^.level := 0;
  s^.frameIndex := -1;
  s^.owner := nil;
  s^.params := nil;
  s^.paramTail := nil;
  s^.frameVars := nil;
  s^.frameTail := nil;
  s^.frameCount := 0;
  s^.nlLabels := nil;
  s^.nlTail := nil;
  s^.resultVar := nil;
  s^.defined := false;
  s^.schemaBody := nil;
  s^.discs := nil;
  s^.discTail := nil;
  s^.descSchema := nil;
  s^.discSyms := nil;
  s^.discSymTail := nil;
  s^.discExprs := nil;
  s^.discIndex := -1;
  s^.heapDisc := false;
  s^.discBinding := false;
  s^.paramSection := 0;
  s^.isProtected := false;
  s^.initValue := nil;
  s^.isStringSchema := false;
  s^.isBindable := false;
  NewSymbol := s
end;

procedure AppendSym(var head, tail: symListPtr; s: symPtr);
var n: symListPtr;
begin
  new(n);
  n^.sym := s;
  n^.next := nil;
  if head = nil then head := n else tail^.next := n;
  tail := n
end;

procedure Bind(at, len: integer; s: symPtr);
var e: entryPtr;
begin
  new(e);
  e^.at := at;
  e^.len := len;
  e^.depth := scopeDepth;
  e^.sym := s;
  e^.prev := scopeTop;
  scopeTop := e
end;

{ Innermost-first lookup, which is what makes an inner declaration shadow an
  outer one of the same name. The scope stack is one chain of bindings, so
  walking it from the top is the search. }
function Lookup(at, len: integer): symPtr;
var e: entryPtr; found: symPtr;
begin
  found := nil;
  e := scopeTop;
  while (e <> nil) and (found = nil) do begin
    if PoolSame(e^.at, e^.len, at, len) then found := e^.sym;
    e := e^.prev
  end;
  Lookup := found
end;

function LookupInScope(at, len: integer): symPtr;
var e: entryPtr; found: symPtr;
begin
  found := nil;
  e := scopeTop;
  while (e <> nil) and (e^.depth = scopeDepth) and (found = nil) do begin
    if PoolSame(e^.at, e^.len, at, len) then found := e^.sym;
    e := e^.prev
  end;
  LookupInScope := found
end;

function Declare(at, len: integer; k: symKind; line, col: integer): symPtr;
var s: symPtr;
begin
  s := LookupInScope(at, len);
  if s <> nil then begin
    ErrorAt(line, col);
    write('''');
    WritePool(at, len);
    writeln(''' is already declared in this block');
    Declare := s
  end
  else begin
    s := NewSymbol;
    s^.at := at;
    s^.len := len;
    s^.kind := k;
    Bind(at, len, s);
    Declare := s
  end
end;

{ Declare a variable, parameter or function result and give it a slot in the
  activation record of `owner` (ADR-0016). }
function AddFrameVar(at, len: integer; k: symKind; t: typePtr; owner: symPtr;
                     line, col: integer): symPtr;
var s: symPtr;
begin
  s := Declare(at, len, k, line, col);
  if s^.stype = nil then begin   { not a duplicate: keep the first }
    s^.stype := t;
    s^.level := owner^.level;
    s^.owner := owner;
    s^.frameIndex := owner^.frameCount;
    AppendSym(owner^.frameVars, owner^.frameTail, s);
    owner^.frameCount := owner^.frameCount + 1
  end;
  AddFrameVar := s
end;

{ A frame slot with no name in any scope -- a function result or a `with`
  binding. It is an ordinary frame variable in every other respect, so it is
  per-invocation and recursion works. }
function AddHiddenVar(at, len: integer; k: symKind; t: typePtr;
                      owner: symPtr): symPtr;
var s: symPtr;
begin
  s := NewSymbol;
  s^.at := at;
  s^.len := len;
  s^.kind := k;
  s^.stype := t;
  s^.level := owner^.level;
  s^.owner := owner;
  s^.frameIndex := owner^.frameCount;
  AppendSym(owner^.frameVars, owner^.frameTail, s);
  owner^.frameCount := owner^.frameCount + 1;
  AddHiddenVar := s
end;

{ Anything a call statement or a function call may name. A procedural
  parameter is deliberately not lumped in with skProc/skFunc elsewhere: those
  two ask whether a symbol *has* a body, which is what forward declarations
  and duplicate checks want. }
{ A declared variable, a value parameter or a var parameter -- what 6.5.1
  calls a variable-identifier. }
function IsVariable(s: symPtr): boolean;
begin
  IsVariable := (s <> nil) and
                ((s^.kind = skVar) or (s^.kind = skParam) or
                 (s^.kind = skVarParam))
end;

function IsInvocable(s: symPtr): boolean;
begin
  IsInvocable := (s <> nil) and
                 ((s^.kind = skProc) or (s^.kind = skFunc) or
                  (s^.kind = skProcParam))
end;

{ The result type of an invocable, nil when it is a procedure. A function
  keeps its result in stype; a functional parameter keeps the procedural type
  there and the result one level in. }
function ResultTypeOf(s: symPtr): typePtr;
begin
  if s = nil then ResultTypeOf := nil
  else if s^.kind = skProcParam then
    if s^.stype = nil then ResultTypeOf := nil else ResultTypeOf := s^.stype^.elem
  else if s^.kind = skFunc then ResultTypeOf := s^.stype
  else ResultTypeOf := nil
end;

{ ISO 7185 6.6.3.6: two parameter lists are *congruous* when they have the
  same number of parameters and each corresponding pair is passed the same way
  and has the same type -- recursively, for a procedural parameter of a
  procedural parameter. Note "the same type", not "assignment compatible":
  nothing is converted on the way through a procedural parameter. }
function Congruous(formal, actual: symPtr): boolean;
var f, a: symListPtr; want, got: typePtr; ok: boolean;
begin
  want := ResultTypeOf(formal);
  got := ResultTypeOf(actual);
  { A procedure and a function are never congruous however alike their
    parameters: one has a result and the other has nowhere to put one. }
  if (want = nil) <> (got = nil) then
    ok := false
  else if (want <> nil) and (want <> got) then
    ok := false
  else begin
    ok := true;
    f := formal^.params;
    a := actual^.params;
    while ok and (f <> nil) and (a <> nil) do begin
      { The passing mode is part of the congruity: a var parameter binds to a
        variable and a value parameter copies one, and the caller emits
        different code for each -- so the two cannot stand in for one
        another. }
      if f^.sym^.kind <> a^.sym^.kind then
        ok := false
      { 6.7.3.6: "Either both contain protected or neither contains
        protected." A body written against a protected parameter may not be
        handed one it is allowed to write, and -- the direction that is easier
        to forget -- a body that writes its parameter may not be passed where a
        protected one was promised. }
      else if f^.sym^.isProtected <> a^.sym^.isProtected then
        ok := false
      else if f^.sym^.kind = skProcParam then
        ok := Congruous(f^.sym, a^.sym)
      { A schematic formal's type belongs to that one parameter and is never
        equal to another's, so congruity asks the question 6.7.3.3 asks: the
        same schema, with the tuple left to the actual as it always is. }
      else if (f^.sym^.descSchema <> nil) or (a^.sym^.descSchema <> nil) then
      begin
        if f^.sym^.descSchema <> a^.sym^.descSchema then ok := false
      end
      else if f^.sym^.stype <> a^.sym^.stype then
        ok := false;
      if ok then begin
        f := f^.next;
        a := a^.next
      end
    end;
    if ok then ok := (f = nil) and (a = nil)
  end;
  Congruous := ok
end;

{ ------------------------------------------------- assignment compatibility }

{ Assignable asks this of a type produced from a schema, and IsGeneric is
  defined with the rest of the schema machinery further down. }
function IsGeneric(t: typePtr): boolean; forward;

{ ISO 7185 6.4.5 makes two structured types the same only when one type
  identifier denotes both, so they compare by identity here. String types are
  the documented exception: packed char arrays of equal length are compatible
  however they were written. }
function Assignable(toT, fromT: typePtr): boolean;
var tb, fb: typePtr;
begin
  if (toT = nil) or (fromT = nil) then
    Assignable := true   { an earlier error already reported }
  { A file is never assignable, not even to itself: 6.8.2.2 excludes a file
    type from assignment and 6.7.2.5 gives it no relational operators either. }
  else if IsFile(toT) or IsFile(fromT) then
    Assignable := false
  { A procedural parameter is not a value either: ISO 7185 gives it no
    assignment and no operators, and the only place one may travel is another
    procedural parameter -- which CheckProcArgument handles without coming
    here. }
  else if IsProcType(toT) or IsProcType(fromT) then
    Assignable := false
  else if toT = fromT then
    Assignable := true
  { 10206 6.4.6 a) is "T1 and T2 are the same type", and 6.4.8 makes one schema
    with one tuple one type -- so wherever both tuples are known the line above
    has already decided this, and two different tuples are two different types.
    What that line cannot decide is a type produced *within an activation*,
    whose tuple is not known until the block is entered. 6.4.6 d) calls a
    mismatch there a dynamic-violation, and 6.1's f) 2) is the permission to
    report it while the program runs -- so the rule is unchanged and only the
    moment of the comparison moves. CodeGen makes it; all that is decided here
    is that both were produced from one schema. }
  { ISO/IEC 10206:1991 6.4.5 d): "T1 is either a string-type or the char-type
    and T2 is either a string-type or the char-type." *All* of them are
    compatible with each other, whatever their capacities -- and 6.4.6 f) then
    makes the assignment legal when the value's length fits, which is a
    question about the value and so a run-time one. That is the whole of the
    divergence from ISO 7185, where two strings had to have the same length.

    It comes before the schema rule below, and must: two capacities are two
    types produced from one schema with different tuples, which 6.4.6 d) would
    otherwise call a dynamic-violation. 6.4.6 f) is the more specific rule and
    the required schema is what it is about. Two chars are not this rule --
    they are the ordinary compatibility further down, and routing them here
    would answer a different question. }
  else if (langStd = stdExtended) and
          (IsStringType(toT) or IsStringType(fromT)) and
          IsStringOrChar(toT) and IsStringOrChar(fromT) then
    Assignable := true
  else if IsGeneric(toT) or IsGeneric(fromT) then
    Assignable := toT^.schema = fromT^.schema
  { ISO 7185 6.4.6 makes set compatibility *structural*, not by name: two set
    types are compatible when their base types are. This is the standard's own
    departure from the name equivalence of 6.4.5, and it is what lets `[]` and
    `['a'..'z']`, which no type definition ever named, be assigned at all. }
  else if IsSet(toT) or IsSet(fromT) then begin
    if not (IsSet(toT) and IsSet(fromT)) then
      Assignable := false
    else if IsEmptySet(toT) or IsEmptySet(fromT) then
      Assignable := true
    else
      Assignable := Base(toT^.elem) = Base(fromT^.elem)
  end
  else if IsStructured(toT) or IsStructured(fromT) then
    Assignable := IsCharArray(toT) and IsCharArray(fromT) and
                  (TypeLength(toT) = TypeLength(fromT))
  { `nil` is a value of every pointer type; two named pointer types are
    otherwise as distinct as any other named types. }
  else if IsPointer(toT) or IsPointer(fromT) then
    Assignable := (IsPointer(toT) and IsNil(fromT)) or
                  (IsPointer(fromT) and IsNil(toT))
  else begin
    tb := Base(toT);
    fb := Base(fromT);
    if tb = fb then
      Assignable := true
    { Two enumerated types are never compatible however alike they look, so
      they must not fall through to the kind comparison below. }
    else if IsEnum(tb) or IsEnum(fb) then
      Assignable := false
    else if tb^.kind = fb^.kind then
      Assignable := true
    { ISO/IEC 10206:1991 6.4.6 c): a complex accepts an integer or a real, and
      "an implicit integer-to-complex conversion or real-to-complex conversion,
      respectively, shall be performed". Written the same way round as the
      real-from-integer widening below it, and for the same reason -- the
      widening is exact and the narrowing does not exist. }
    else if IsComplex(toT) then
      Assignable := IsNumeric(fromT)
    else
      Assignable := IsReal(toT) and IsInteger(fromT)
  end
end;

{ ---------------------------------------------------------- designators -- }

function IsDesignator(e: nodePtr): boolean;
begin
  if e = nil then IsDesignator := false
  else if e^.kind = nkVar then
    IsDesignator := (e^.vrSym <> nil) and
                    ((e^.vrSym^.kind = skVar) or (e^.vrSym^.kind = skParam) or
                     (e^.vrSym^.kind = skVarParam) or (e^.vrField <> nil))
  else if e^.kind = nkIndex then IsDesignator := IsDesignator(e^.ixBase)
  { 6.8.4 makes a schema-discriminant a *primary*, not a variable-access: it
    is the value the type was produced with, and there is nowhere to store
    into. `v.n := 3` would be asking a variable to change its type. }
  else if e^.kind = nkField then
    IsDesignator := (not e^.fdIsDisc) and IsDesignator(e^.fdBase)
  { What a pointer points at is a variable however the pointer was obtained,
    so a dereference is a designator even when its base is not. }
  else if e^.kind = nkDeref then IsDesignator := true
  { 6.7.6.8's binding(f) is built in a hidden frame slot, so it denotes a
    variable -- which is what lets it be copied whole and passed by value. }
  else if e^.kind = nkCall then IsDesignator := e^.clBuiltin = biBinding
  else IsDesignator := false
end;

{ The entire-variable a designator selects from. A subscript and a field
  selection stay inside the same variable and a dereference leaves it, which is
  exactly ISO/IEC 10206:1991 6.5.1's "closest-containing". }
function RootDesignator(e: nodePtr): nodePtr;
begin
  if e = nil then RootDesignator := nil
  else if e^.kind = nkIndex then RootDesignator := RootDesignator(e^.ixBase)
  else if e^.kind = nkField then RootDesignator := RootDesignator(e^.fdBase)
  else RootDesignator := e
end;

{ 6.5.1: "No statement shall threaten a variable-access closest-containing a
  protected variable-identifier." 6.9.4 lists what threatens one, and every
  entry on that list is a place this compiler already had to decide the
  argument was a *variable* -- so each call sits beside an IsDesignator test
  rather than in a walk of its own.

  Nothing is lost by stopping at a dereference: 6.4.1 makes a pointer type
  unprotectable, so a protected parameter can never be one.

  True means the error's opening was written and the caller supplies the rest,
  which is how the one rule keeps one wording across five places. }
function Threatened(e: nodePtr): boolean;
var r: nodePtr; sym: symPtr;
begin
  r := RootDesignator(e);
  sym := nil;
  if r <> nil then
    if r^.kind = nkVar then sym := r^.vrSym;
  if (sym = nil) or not sym^.isProtected then
    Threatened := false
  else begin
    Threatened := true;
    ErrorAt(e^.line, e^.col);
    { A `with` binding is hidden and its name is a frame slot's, not the
      program's -- so naming it would name something the source never wrote.
      The rule is the same one either way; only the wording differs. }
    if r^.vrField <> nil then
      write('the record of an enclosing with statement is a protected ',
            'parameter, so ')
    else begin
      write('''');
      WritePool(sym^.at, sym^.len);
      write(''' is a protected parameter, so ')
    end
  end
end;

{ The field of an enclosing `with` this name refers to, if any. A `with` scope
  sits inside every enclosing one, so its fields are looked at first. }
function LookupWithField(at, len: integer; var f: fieldPtr): symPtr;
var w: symListPtr; found: symPtr; g: fieldPtr;
begin
  found := nil;
  w := withTop;
  while (w <> nil) and (found = nil) do begin
    g := FindField(w^.sym^.stype, at, len);
    if g <> nil then begin
      f := g;
      found := w^.sym
    end;
    w := w^.next
  end;
  LookupWithField := found
end;

{ ------------------------------------------------------- constant folding }

procedure CheckExpr(e: nodePtr); forward;
function ResolveType(d: nodePtr): typePtr; forward;
function InitialStateOf(d: nodePtr): nodePtr; forward;
function ProduceFromSchema(schema, dummy: symPtr; d: nodePtr): typePtr;
  forward;
function GenericFromSchema(schema, param: symPtr; d: nodePtr;
                           noun: integer): typePtr;
  forward;
procedure CheckStmt(s: nodePtr); forward;
procedure CheckBlock(b: nodePtr; owner: symPtr); forward;
procedure CheckGoto(s: nodePtr); forward;
procedure CheckLabeled(s: nodePtr); forward;

{ Pushing is a new cell in front of the current head; popping is restoring the
  saved head, so nothing is ever mutated and two paths share their common
  suffix. PathDepth is stored rather than counted for the same reason. }
function PushStmt(p: stmtPathPtr; n: nodePtr): stmtPathPtr;
var c: stmtPathPtr;
begin
  new(c);
  c^.stmt := n;
  c^.next := p;
  if p = nil then c^.depth := 1 else c^.depth := p^.depth + 1;
  PushStmt := c
end;

function PathDepth(p: stmtPathPtr): integer;
begin
  if p = nil then PathDepth := 0 else PathDepth := p^.depth
end;


function EvalConst(e: nodePtr; var res: symbol): boolean;
var inner: symbol; ok: boolean;
begin
  ok := false;
  if e <> nil then
    case e^.kind of
      nkInt: begin
        res.stype := intType;
        res.intVal := e^.intVal;
        ok := true
      end;
      { A real constant folds, carrying the literal's text rather than a
        converted value. Nothing in Sema reads it; the code generator prints
        it, and printing is all a textual backend ever needed. }
      nkReal: begin
        res.stype := realType;
        res.realAt := e^.rlAt;
        res.realLen := e^.rlLen;
        res.realNeg := false;
        ok := true
      end;
      nkChar: begin
        res.stype := charType;
        res.charVal := e^.chVal;
        ok := true
      end;
      nkVar:
        if (e^.vrSym <> nil) and (e^.vrSym^.kind = skConst) then begin
          res := e^.vrSym^;
          ok := true
        end;
      nkUnary:
        if EvalConst(e^.unArg, inner) then
          case e^.unOp of
            opPos: begin
              res := inner;
              ok := IsNumeric(inner.stype)
            end;
            opNeg: begin
              res := inner;
              if IsInteger(inner.stype) then begin
                res.intVal := -inner.intVal;
                ok := true
              end
              else if IsReal(inner.stype) then begin
                res.realNeg := not inner.realNeg;
                ok := true
              end
              else
                ok := false
            end;
            opNot:
              if IsBoolean(inner.stype) then begin
                res := inner;
                res.boolVal := not inner.boolVal;
                ok := true
              end
          end;
      nkStr, nkNil, nkSet, nkSetMember, nkIndex, nkField, nkDeref, nkBinary,
      nkCall,
      nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
      nkFor, nkProcCall, nkWith, nkCase, nkWriteArg, nkCaseArm, nkVariantArm,
      nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord,
      nkPointer, nkFile, nkSetOf, nkSchema, nkInquiry, nkConstDecl, nkTypeDecl,
      nkProcDecl, nkBlock:
        ok := false
    end;
  EvalConst := ok
end;

{ Evaluate a constant that must be ordinal -- a subrange bound, a case label, a
  variant's tag value. Reports the type it was written as, so a mismatch can be
  named rather than silently coerced. }
function EvalOrdinal(e: nodePtr; var t: typePtr; var value: integer): boolean;
var res: symbol;
begin
  CheckExpr(e);
  res.stype := nil;
  if not EvalConst(e, res) then
    EvalOrdinal := false
  else if not IsOrdinal(res.stype) then
    EvalOrdinal := false
  else begin
    t := res.stype;
    if IsChar(res.stype) then
      value := ord(res.charVal)
    else if IsBoolean(res.stype) then
      if res.boolVal then value := 1 else value := 0
    else
      value := res.intVal;   { integer, and the ordinal of an enum constant }
    EvalOrdinal := true
  end
end;

{ A bound of a schema body being resolved for a schematic formal parameter. It
  is a constant, or one of the discriminants the descriptor holds. There is
  deliberately no third form: ISO 7185 has no constant-expression -- a bound is
  a sign and a number or an identifier, everywhere in the language -- so `n - 1`
  is not something a bound may be here or anywhere else. When 6.3's
  constant-expression lands it will land for every bound at once, and the
  descriptor already holds what such an expression would be computed from. }
function EvalBound(e: nodePtr; var t: typePtr; var value: integer;
                   var disc: symPtr): boolean;
begin
  disc := nil;
  if EvalOrdinal(e, t, value) then
    EvalBound := true
  { EvalOrdinal has checked the expression already, so the name is resolved
    whether or not it folded to a value. }
  else if (e^.kind = nkVar) and (e^.vrSym <> nil) then
    if e^.vrSym^.kind = skDisc then begin
      disc := e^.vrSym;
      t := e^.vrSym^.stype;
      value := 0;
      EvalBound := true
    end
    else EvalBound := false
  else
    EvalBound := false
end;

{ One entry of a case-constant-list, folded to the closed interval it denotes.
  A single constant is [v, v], so a case statement and a variant part read
  their labels the same way whether or not Extended Pascal ranges are in play;
  `forCase` picks the one diagnostic the two constructs spell differently.

  A range is never expanded into its members -- `1..maxint` is two integers
  here and two billion switch cases if expanded, and the code generator tests
  it rather than enumerating it for exactly that reason. }
function EvalLabelRange(lab: nodePtr; forCase: boolean; var ltype: typePtr;
                        var lo, hi: integer): boolean;
var hiType: typePtr; ok: boolean;
begin
  ok := true;
  ltype := nil;
  lo := 0;
  hi := 0;
  if not EvalOrdinal(lab^.smLo, ltype, lo) then begin
    ErrorAt(lab^.smLo^.line, lab^.smLo^.col);
    if forCase then
      writeln('a case label must be an ordinal constant')
    else
      writeln('a variant''s label must be an ordinal constant');
    ok := false
  end
  else begin
    hi := lo;
    if lab^.smHi <> nil then begin
      hiType := nil;
      if not EvalOrdinal(lab^.smHi, hiType, hi) then begin
        ErrorAt(lab^.smHi^.line, lab^.smHi^.col);
        if forCase then
          writeln('a case label must be an ordinal constant')
        else
          writeln('a variant''s label must be an ordinal constant');
        ok := false
      end
      else if (ltype <> nil) and (hiType <> nil) and
              (Base(ltype) <> Base(hiType)) then begin
        ErrorAt(lab^.smHi^.line, lab^.smHi^.col);
        write('the two ends of a range must be of one type, found ');
        WriteTypeName(ltype);
        write(' and ');
        WriteTypeName(hiType);
        writeln;
        ok := false
      end
      { A backwards range denotes no values at all. ISO 7185 6.7.1 says so for
        a set constructor and this compiler honours it there, but a label
        selecting nothing can only be a mistake -- nothing would ever run. }
      else if hi < lo then begin
        ErrorAt(lab^.smLo^.line, lab^.smLo^.col);
        write('this range runs backwards: ');
        WriteOrdinalName(ltype, lo);
        write(' is greater than ');
        WriteOrdinalName(ltype, hi);
        writeln;
        ok := false
      end
    end
  end;
  EvalLabelRange := ok
end;

{ The lowest value a new label shares with the ones already accepted, if any --
  "this label appears twice" is the single-constant case of exactly this
  question, so both constructs ask it in the general form. }
function Overlaps(seen: rangePtr; lo, hi: integer; var at: integer): boolean;
var found: boolean;
begin
  found := false;
  while (seen <> nil) and not found do begin
    if (seen^.lo <= hi) and (lo <= seen^.hi) then begin
      found := true;
      if seen^.lo > lo then at := seen^.lo else at := lo
    end;
    seen := seen^.next
  end;
  Overlaps := found
end;

{ ------------------------------------------------------ type resolution -- }

function StringType(len: integer): typePtr;
var t: typePtr;
begin
  if stringCache[len] <> nil then
    StringType := stringCache[len]
  else begin
    t := NewType(tyArray);
    t^.elem := charType;
    t^.indexType := intType;
    t^.lo := 1;
    t^.hi := len;
    t^.isPacked := true;
    stringCache[len] := t;
    StringType := t
  end
end;

function BuiltinType(at, len: integer): typePtr;
begin
  if PoolIs(at, len, 'integer  ') then BuiltinType := intType
  else if PoolIs(at, len, 'real     ') then BuiltinType := realType
  else if PoolIs(at, len, 'boolean  ') then BuiltinType := boolType
  else if PoolIs(at, len, 'char     ') then BuiltinType := charType
  else if PoolIs(at, len, 'text     ') then BuiltinType := textType
  { A required type-identifier of ISO/IEC 10206:1991 and an ordinary identifier
    of ISO 7185, where a program may define a type called `complex` of its own
    -- which is why this is asked of the standard rather than of the lexer. }
  else if PoolIs(at, len, 'complex  ') and (langStd = stdExtended) then
    BuiltinType := complexType
  else BuiltinType := nil
end;

{ An enumerated type also *declares* its constants, into whatever scope the
  type itself appears in (ISO 7185 6.4.2.3) -- which is why this is done here
  rather than by the declaration part that happens to contain it. }
function ResolveEnum(d: nodePtr): typePtr;
var t: typePtr; n: nodePtr; s: symPtr; e: namePtr;
begin
  { An enumerated type declares its constants into the scope the *type*
    appears in, and a schema's body is resolved once per discriminant tuple --
    so s(1) and s(2) would each want to declare them, into a scope that exists
    only while the type is being produced. 6.4.7 gives no answer to that, and
    silently losing the constants is worse than saying so. }
  if producingTop <> nil then begin
    ErrorAt(d^.line, d^.col);
    writeln('a schema''s type cannot contain an enumerated type: its ',
            'constants would be declared once per set of discriminants')
  end;
  t := NewType(tyEnum);
  n := d^.enConstants;
  while n <> nil do begin
    s := Declare(n^.dnAt, n^.dnLen, skConst, n^.line, n^.col);
    if s^.stype = nil then begin   { already declared: keep the first }
      s^.stype := t;
      s^.intVal := EnumCount(t);
      new(e);
      e^.at := n^.dnAt;
      e^.len := n^.dnLen;
      e^.next := nil;
      if t^.enumNames = nil then t^.enumNames := e else t^.enumTail^.next := e;
      t^.enumTail := e
    end;
    n := n^.next
  end;
  ResolveEnum := t
end;

{ A pointer's domain is a type identifier, and it may be one defined later in
  the same type part -- the language's only forward reference (ADR-0019). }
{ 10206 6.4.4 makes a domain-type a type-name *or* a schema-name, and a bare
  schema-name leaves the tuple to `new` (6.7.5.3). The variable that creates
  has no activation record to keep a descriptor in, so its tuple lives in a
  header immediately before it and its discriminants are read from the
  object's own address -- which is the whole of what heapDisc marks
  (ADR-0043).

  One type per schema, memoised: `^vector` written twice denotes one type, the
  way `vector(3)` written twice does. That is also what stops the recursion,
  since a schema may name itself in a pointer domain and nowhere else. }
function HeapFromSchema(schema: symPtr; d: nodePtr): typePtr;
var t: typePtr; owner: symPtr; l: symListPtr; h: heapTypePtr;
    p, keep, tail: pendingPtr;
begin
  h := heapTypes;
  while (h <> nil) and (h^.schema <> schema) do h := h^.next;
  if h <> nil then
    HeapFromSchema := h^.ty
  else begin
    owner := NewSymbol;
    owner^.kind := skVar;
    owner^.at := schema^.at;
    owner^.len := schema^.len;
    t := GenericFromSchema(schema, owner, d, nounPointerDomain);
    if IsGeneric(t) then begin
      owner^.descSchema := schema;
      l := owner^.discSyms;
      while l <> nil do begin
        l^.sym^.heapDisc := true;
        l := l^.next
      end;
      t^.heapTuple := true;
      t^.descOwner := owner
    end;
    new(h);
    h^.schema := schema;
    h^.ty := t;
    h^.next := heapTypes;
    heapTypes := h;
    { The body may have named this very schema in a pointer domain, and that
      pointer could not be completed while the production was running. It can
      be now, and it has to be here rather than at the end of the type part:
      this production may have been asked for from the variable part, which is
      past that point. }
    keep := nil;
    tail := nil;
    p := pendingHead;
    while p <> nil do begin
      if p^.schema = schema then
        p^.ptype^.elem := t
      else begin
        if keep = nil then keep := p else tail^.next := p;
        tail := p
      end;
      p := p^.next
    end;
    if tail <> nil then tail^.next := nil;
    pendingHead := keep;
    pendingTail := tail;
    HeapFromSchema := t
  end
end;

procedure PendPointer(t: typePtr; d: nodePtr; schema: symPtr);
var p: pendingPtr;
begin
  new(p);
  p^.ptype := t;
  p^.at := d^.ptAt;
  p^.len := d^.ptLen;
  p^.line := d^.line;
  p^.col := d^.col;
  p^.schema := schema;
  p^.next := nil;
  if pendingHead = nil then pendingHead := p else pendingTail^.next := p;
  pendingTail := p
end;

function ResolvePointer(d: nodePtr): typePtr;
var t: typePtr; s: symPtr; busy: boolean; l: symListPtr;
begin
  t := NewType(tyPointer);
  t^.elem := BuiltinType(d^.ptAt, d^.ptLen);
  if t^.elem = nil then begin
    s := Lookup(d^.ptAt, d^.ptLen);
    if (s <> nil) and (s^.kind = skType) then
      t^.elem := s^.stype
    else if (s <> nil) and (s^.kind = skSchema) then begin
      { 6.4.4: a domain-type may be a schema-name. It is resolved here rather
        than deferred, because a pointer written in the *variable* part is past
        the point where deferred domains are completed -- unless the schema is
        the one being produced, which is the recursion 6.4.7 permits in a
        pointer domain and nowhere else. That one waits, and by the time it is
        completed the schema's own type is in the memo. }
      busy := false;
      l := producingTop;
      while l <> nil do begin
        if l^.sym = s then busy := true;
        l := l^.next
      end;
      if busy then PendPointer(t, d, s)
      else t^.elem := HeapFromSchema(s, d)
    end
    else
      { Not yet -- it may arrive before the type part ends. }
      PendPointer(t, d, nil)
  end;
  ResolvePointer := t
end;

procedure ResolvePendingPointers;
var p: pendingPtr; s: symPtr; d: nodePtr;
begin
  { Not a simple walk: resolving a schema domain resolves that schema's body,
    which may itself pend a pointer and rebuild this list. }
  while pendingHead <> nil do begin
    p := pendingHead;
    pendingHead := p^.next;
    if pendingHead = nil then pendingTail := nil;
    s := Lookup(p^.at, p^.len);
    if (s <> nil) and (s^.kind = skType) then
      p^.ptype^.elem := s^.stype
    else if (s <> nil) and (s^.kind = skSchema) then begin
      d := NewNode(nkPointer, p^.line, p^.col);
      d^.ptAt := p^.at;
      d^.ptLen := p^.len;
      p^.ptype^.elem := HeapFromSchema(s, d)
    end
    else begin
      ErrorAt(p^.line, p^.col);
      write('unknown type ''');
      WritePool(p^.at, p^.len);
      writeln(''' as the domain of a pointer');
      p^.ptype^.elem := intType   { keep the tree checkable }
    end
  end;
  pendingHead := nil;
  pendingTail := nil
end;

{ Only a text file is supported: a typed file writes the machine
  representation of a component, which is a decision about an external format
  this compiler has not made and does not need to reach stage 1. }
{ ISO 7185 6.4.3.4: a set type is `set of T` for an ordinal T, and its values
  are the powerset of T's. The standard leaves the size to the implementation,
  and this one fixes it at 256 bits -- so T's values must lie in 0..setLimit.
  That admits `char` exactly, and every enumeration and small subrange; it
  refuses `set of integer` rather than quietly keeping a prefix of it, because
  a set that silently forgets members is worse than one that does not
  compile. }
function ResolveSet(d: nodePtr): typePtr;
var t, baseType: typePtr;
begin
  t := NewType(tySet);
  if d^.soElem <> nil then baseType := ResolveType(d^.soElem)
  else baseType := intType;
  if not IsOrdinal(baseType) then begin
    ErrorAt(d^.line, d^.col);
    write('the base type of a set must be an ordinal type, found ');
    WriteTypeName(baseType);
    writeln;
    baseType := charType
  end
  else if (OrdinalLo(baseType) < 0) or (OrdinalHi(baseType) > setLimit) then begin
    ErrorAt(d^.line, d^.col);
    write('a set base type must lie within 0..', setLimit:1, ', but ');
    WriteTypeName(baseType);
    write(' spans ');
    WriteOrdinalName(baseType, OrdinalLo(baseType));
    write('..');
    WriteOrdinalName(baseType, OrdinalHi(baseType));
    writeln;
    baseType := charType
  end;
  t^.elem := baseType;
  t^.isPacked := d^.soPacked;
  ResolveSet := t
end;

{ ISO 7185 6.4.3.5 bars a file from having a file as a component, at any
  depth: `file of file of char` and `file of record f: text end` are both out.
  The reason is that a file has no value to copy -- the same fact that keeps a
  file out of IsStructured -- so a file inside one could not be read, written,
  or positioned. Nothing else about a component is restricted. }
function ContainsFile(t: typePtr): boolean; forward;

{ A variant's fields are components of the record just as the fixed part's
  are: only one arm exists at a time, but any of them may be the one. }
function ArmsContainFile(v: variantPtr): boolean;
var found: boolean; f: fieldPtr;
begin
  found := false;
  while (v <> nil) and not found do begin
    f := v^.fields;
    while (f <> nil) and not found do begin
      if ContainsFile(f^.ftype) then found := true;
      f := f^.next
    end;
    if not found then
      if ArmsContainFile(v^.variants) then found := true;
    v := v^.next
  end;
  ArmsContainFile := found
end;

function ContainsFile;
var found: boolean; f: fieldPtr;
begin
  found := false;
  if t <> nil then
    if IsFile(t) then found := true
    else if IsArray(t) then found := ContainsFile(t^.elem)
    else if IsRecord(t) then begin
      f := t^.fields;
      while (f <> nil) and not found do begin
        if ContainsFile(f^.ftype) then found := true;
        f := f^.next
      end;
      if not found then found := ArmsContainFile(t^.variants)
    end;
  ContainsFile := found
end;

{ `file of T`. The component may be any type that is not, and does not
  contain, a file. A `text` is *not* what this produces even when T is char:
  6.4.3.5 makes `text` a required type of its own with a line structure, and
  `file of char` a plain sequence of characters with none. }
function ResolveFile(d: nodePtr): typePtr;
var t, component: typePtr;
begin
  t := NewType(tyFile);
  if d^.flElem <> nil then component := ResolveType(d^.flElem)
  else component := charType;
  if ContainsFile(component) then begin
    ErrorAt(d^.line, d^.col);
    write('the component type of a file must not be, or contain, a file, ',
          'found ');
    WriteTypeName(component);
    writeln;
    component := charType
  end;
  t^.elem := component;
  t^.isPacked := d^.flPacked;
  { 6.4.3.6: the index-type is what makes a file direct-access. It is an
    ordinal type, because 6.7.6.6 makes `position` return a value of it and
    6.7.5.2 makes SeekRead's argument assignment-compatible with it. }
  if d^.flIndex <> nil then begin
    t^.indexType := ResolveType(d^.flIndex);
    if not IsOrdinal(t^.indexType) then begin
      ErrorAt(d^.flIndex^.line, d^.flIndex^.col);
      write('the index type of a direct-access file must be an ordinal ',
            'type, found ');
      WriteTypeName(t^.indexType);
      writeln;
      t^.indexType := intType
    end
  end;
  ResolveFile := t
end;

function ResolveSubrange(d: nodePtr): typePtr;
var t, loType, hiType: typePtr; lo, hi: integer; ok, dynamic: boolean;
    loDisc, hiDisc: symPtr;
begin
  loType := nil;
  hiType := nil;
  lo := 0;
  hi := 0;
  loDisc := nil;
  hiDisc := nil;
  dynamic := false;
  { A schematic formal parameter's bounds arrive with the actual, so inside
    one -- and nowhere else -- a bound may name a discriminant. Everything the
    subrange means is otherwise unchanged, which is why this is one call
    swapped for another rather than a second resolver. }
  if genericFor <> nil then begin
    ok := EvalBound(d^.sbLo, loType, lo, loDisc);
    if ok then ok := EvalBound(d^.sbHi, hiType, hi, hiDisc);
    if not ok then begin
      ErrorAt(d^.line, d^.col);
      writeln('the bounds of a subrange in a schematic formal parameter ',
              'must be ordinal constants or discriminants')
    end
    else if Base(loType) <> Base(hiType) then begin
      ErrorAt(d^.line, d^.col);
      write('the bounds of a subrange must have the same type, found ');
      WriteTypeName(loType);
      write(' and ');
      WriteTypeName(hiType);
      writeln;
      ok := false
    end;
    dynamic := ok and ((loDisc <> nil) or (hiDisc <> nil));
    { An empty subrange is still an error, but only where both ends are known.
      Where one is not, the tuple that produced the *actual's* type was checked
      when it was produced -- so a dynamic range cannot be empty, and there is
      nothing left for a run-time check to catch. }
    if ok and (not dynamic) and (hi < lo) then begin
      ErrorAt(d^.line, d^.col);
      write('a subrange cannot be empty: ');
      WriteOrdinalName(loType, hi);
      write(' is below ');
      WriteOrdinalName(loType, lo);
      writeln;
      ok := false
    end;
    t := NewType(tySubrange);
    if ok then begin
      t^.host := Base(loType);
      t^.lo := lo;
      t^.hi := hi;
      t^.loDisc := loDisc;
      t^.hiDisc := hiDisc
    end
    else begin
      t^.host := intType;
      t^.lo := 0;
      t^.hi := 0
    end;
    ResolveSubrange := t
  end
  else begin
  { The C++ writes this as one `||`, which short-circuits: when the lower bound
    is not a constant the upper one is never even checked. Mirrored here,
    because a stage that reports a different number of errors is a stage that
    disagrees. }
  ok := EvalOrdinal(d^.sbLo, loType, lo);
  if ok then ok := EvalOrdinal(d^.sbHi, hiType, hi);
  if not ok then begin
    ErrorAt(d^.line, d^.col);
    writeln('the bounds of a subrange must be ordinal constants')
  end
  else if Base(loType) <> Base(hiType) then begin
    ErrorAt(d^.line, d^.col);
    write('the bounds of a subrange must have the same type, found ');
    WriteTypeName(loType);
    write(' and ');
    WriteTypeName(hiType);
    writeln;
    ok := false
  end
  else if hi < lo then begin
    ErrorAt(d^.line, d^.col);
    write('a subrange cannot be empty: ');
    WriteOrdinalName(loType, hi);
    write(' is below ');
    WriteOrdinalName(loType, lo);
    writeln;
    ok := false
  end;

  t := NewType(tySubrange);
  if ok then begin
    t^.host := Base(loType);
    t^.lo := lo;
    t^.hi := hi
  end
  else begin
    t^.host := intType;
    t^.lo := 0;
    t^.hi := 0
  end;
  ResolveSubrange := t
  end
end;

{ `array [a, b] of T` abbreviates `array [a] of array [b] of T`
  (ISO 7185 6.4.3.2), so dimension `dim` wraps everything after it. }
function ResolveArray(d, dim: nodePtr): typePtr;
var t, index: typePtr;
begin
  index := ResolveType(dim);
  if not IsOrdinal(index) then begin
    ErrorAt(dim^.line, dim^.col);
    write('an array index must be an ordinal type, found ');
    WriteTypeName(index);
    writeln;
    index := NewType(tySubrange);
    index^.host := intType
  end
  { A subscript is lowered to `i - lo` in the integer type, which is sound only
    while that difference is a value of the type. Rejecting the array is what
    makes the rule `accepted-index-selects-the-right-element` true, so this
    bound is load-bearing rather than arbitrary -- see verify/rules.py. }
  { The C++ writes this subtraction in a 64-bit type. Here both bounds are
    integers and their difference need not be one -- the full integer type
    spans 2*maxint -- so the test is rearranged to stay inside the type, the
    same move the lexer's overflow check had to make (ADR-0022). With lo above
    zero the span cannot reach maxint at all; otherwise maxint + lo is in
    range, and hi - lo >= maxint exactly when hi >= maxint + lo. }
  { A dynamic index type has no span to measure here. It does not need one:
    the array the actual brings was produced from constants and checked when it
    was produced, so `i - lo` is a value of the type for every array that can
    reach a schematic formal parameter. }
  else if (index^.loDisc = nil) and (index^.hiDisc = nil) and
          (OrdinalLo(index) <= 0) and
          (OrdinalHi(index) >= maxint + OrdinalLo(index)) then begin
    ErrorAt(dim^.line, dim^.col);
    writeln('this array has too many elements: an index type may span at ',
            'most maxint values');
    index := NewType(tySubrange);
    index^.host := intType
  end;

  t := NewType(tyArray);
  t^.indexType := index;
  t^.lo := OrdinalLo(index);
  t^.hi := OrdinalHi(index);
  { An array is bounded by its index type, dynamically or not, so a dynamic
    bound travels one step outwards here and codegen never looks at the index
    type again. }
  t^.loDisc := index^.loDisc;
  t^.hiDisc := index^.hiDisc;
  t^.isPacked := d^.arPacked;
  if dim^.next <> nil then
    t^.elem := ResolveArray(d, dim^.next)
  else
    t^.elem := ResolveType(d^.arElem);
  ResolveArray := t
end;

procedure AddField(rec: typePtr; var into, tail: fieldPtr; n: nodePtr;
                   t: typePtr; variant: numPtr; index: integer;
                   init: nodePtr);
var f: fieldPtr;
begin
  if FindField(rec, n^.dnAt, n^.dnLen) <> nil then begin
    ErrorAt(n^.line, n^.col);
    write('''');
    WritePool(n^.dnAt, n^.dnLen);
    writeln(''' is already a field of this record')
  end
  else begin
    new(f);
    f^.at := n^.dnAt;
    f^.len := n^.dnLen;
    f^.ftype := t;
    f^.index := index;
    f^.variant := variant;
    f^.line := n^.line;
    f^.col := n^.col;
    f^.initValue := init;
    f^.next := nil;
    if into = nil then into := f else tail^.next := f;
    tail := f
  end
end;

function FieldCount(f: fieldPtr): integer;
var n: integer;
begin
  n := 0;
  while f <> nil do begin
    n := n + 1;
    f := f^.next
  end;
  FieldCount := n
end;

{ Where a field lives, extended by one step. The lists are never changed once
  built, so every field of one field-list shares the same path. }
function PathAppend(path: numPtr; k: integer): numPtr;
var head, tail, n, p: numPtr;
begin
  head := nil;
  tail := nil;
  p := path;
  while p <> nil do begin
    new(n);
    n^.value := p^.value;
    n^.next := nil;
    if head = nil then head := n else tail^.next := n;
    tail := n;
    p := p^.next
  end;
  new(n);
  n^.value := k;
  n^.next := nil;
  if head = nil then head := n else tail^.next := n;
  PathAppend := head
end;

{ 6.4.3.4: the discriminant-identifier a variant-selector names, or nil when
  the selector is a tag-type. A discriminant is only ever in scope while a
  schema body is being resolved, so this answers nil everywhere else without
  needing to ask where it is -- which is what keeps the form out of an ordinary
  record with no rule saying so. }
function DiscSelectorFor(d: nodePtr): symPtr;
var s: symPtr;
begin
  DiscSelectorFor := nil;
  if d^.kind = nkNamed then begin
    s := Lookup(d^.nmAt, d^.nmLen);
    if (s <> nil) and s^.discBinding then DiscSelectorFor := s
  end
end;

{ Resolve one variant part -- a record's, or one nested inside an arm. The
  containers are passed explicitly because both a typeRec and a variantRec have
  them, and `path` says where the container sits so a field can record how to
  reach it (ISO 7185 6.4.3.3 allows any depth of nesting). }
procedure ResolveVariantPart(tagAt, tagLen, tagLine, tagCol: integer;
                             tagDenoter, arms: nodePtr; rec: typePtr;
                             var fields, fieldTail: fieldPtr;
                             var variants, variantTail: variantPtr;
                             var tagField: integer; var tagTypeOut: typePtr;
                             var discSelOut: boolean;
                             path: numPtr);
var
  tag, labelType, fieldType: typePtr;
  arm, label_, g, n, tagName: nodePtr;
  selector: symPtr;
  v, w: variantPtr;
  rg, rseen: rangePtr;
  armPath: numPtr;
  index, lo, hi, at: integer;
  claimed: boolean;
begin
  { 6.4.3.4's third form of variant-selector: a bare name that is one of the
    discriminants the body is being resolved with. It is asked *before* the
    denoter is resolved, because as a type-denoter the name is unknown and
    would report so. The two forms are told apart by the symbol and not by the
    syntax -- `case k of` is a tag-type when k names a type and a
    discriminant-identifier when it names a discriminant, and no third reading
    of it exists. }
  selector := DiscSelectorFor(tagDenoter);
  if selector <> nil then begin
    tag := selector^.stype;
    discSelOut := true;
    { The dump prints the denoter's resolved type, and this one *is* resolved
      -- to the discriminant's type -- even though ResolveType never saw it. }
    tagDenoter^.ntype := tag
  end
  else
    tag := ResolveType(tagDenoter);
  if not IsOrdinal(tag) then begin
    ErrorAt(tagLine, tagCol);
    write('the tag of a variant part must be an ordinal type, found ');
    WriteTypeName(tag);
    writeln
  end
  { 6.4.3.4 offers the tag-field to the tag-type form only: the selector of a
    discriminant-selected variant part *is* the discriminant, and a field would
    be a second place to keep it -- one the program could then assign, which is
    the very thing the section calls a dynamic-violation. }
  else if (selector <> nil) and (tagLen > 0) then begin
    ErrorAt(tagLine, tagCol);
    write('''');
    WritePool(selector^.at, selector^.len);
    writeln(''' is a discriminant, so it is the tag of this variant part ',
            'and cannot also name a field')
  end
  else begin
    tagTypeOut := tag;

    { A named tag is an ordinary field of the field-list it heads; a tagless
      variant part has the type but no storage for it (ISO 7185 6.4.3.3). }
    if tagLen > 0 then begin
      tagField := FieldCount(fields);
      tagName := NewNode(nkDeclName, tagLine, tagCol);
      tagName^.dnAt := tagAt;
      tagName^.dnLen := tagLen;
      AddField(rec, fields, fieldTail, tagName, tag, path, tagField, nil)
    end;

    index := 0;
    arm := arms;
    while arm <> nil do begin
      new(v);
      v^.labels := nil;
      { An otherwise-arm carries no labels, so the loop below runs zero times
        for it. It is still an arm in every other respect -- one struct laid
        over the shared block, numbered like the rest -- which is why the
        layout is unchanged. }
      v^.isOtherwise := arm^.vaOtherwise;
      v^.fields := nil;
      v^.fieldTail := nil;
      v^.variants := nil;
      v^.variantTail := nil;
      v^.tagField := -1;
      v^.tagType := nil;
      v^.discSelector := false;
      v^.line := arm^.line;
      v^.col := arm^.col;
      v^.next := nil;

      label_ := arm^.vaLabels;
      while label_ <> nil do begin
        labelType := nil;
        at := 0;
        if not EvalLabelRange(label_, false, labelType, lo, hi) then begin
          { the diagnostic is EvalLabelRange's; nothing more to say here }
        end
        else if Base(labelType) <> Base(tag) then begin
          ErrorAt(label_^.smLo^.line, label_^.smLo^.col);
          write('this variant''s tag is ');
          WriteTypeName(tag);
          write(', but the label is ');
          WriteTypeName(labelType);
          writeln
        end
        else begin
          { has an earlier arm of *this* variant part already claimed any of
            these values? `v` is not on the list yet, so it is asked apart. }
          claimed := false;
          w := variants;
          while w <> nil do begin
            if not claimed then
              claimed := Overlaps(w^.labels, lo, hi, at);
            w := w^.next
          end;
          if not claimed then
            claimed := Overlaps(v^.labels, lo, hi, at);
          if claimed then begin
            ErrorAt(label_^.smLo^.line, label_^.smLo^.col);
            write('the tag value ');
            WriteOrdinalName(tag, at);
            writeln(' already selects an earlier variant')
          end
          else begin
            new(rg);
            rg^.lo := lo;
            rg^.hi := hi;
            rg^.next := nil;
            if v^.labels = nil then v^.labels := rg
            else begin
              rseen := v^.labels;
              while rseen^.next <> nil do rseen := rseen^.next;
              rseen^.next := rg
            end
          end
        end;
        label_ := label_^.next
      end;

      { The fields are pushed into the arm, so each variant is numbered from
        zero and codegen can index it as a struct of its own. }
      if variants = nil then variants := v else variantTail^.next := v;
      variantTail := v;

      armPath := PathAppend(path, index);
      g := arm^.vaFields;
      while g <> nil do begin
        { A field-list is a field-list (ISO 7185 6.4.3.3), so an arm's fields
          may carry an initial-state-specifier syntactically -- and are told
          why they may not have one here rather than being told it is the wrong
          position. }
        variantField := true;
        fieldType := ResolveType(g^.grType);
        variantField := false;
        n := g^.grNames;
        while n <> nil do begin
          AddField(rec, v^.fields, v^.fieldTail, n, fieldType, armPath,
                   FieldCount(v^.fields), nil);
          n := n^.next
        end;
        g := g^.next
      end;
      { An arm's field-list may end with a variant part of its own, and this is
        the only recursion in a type-denoter that does not go back through
        ResolveType. }
      if arm^.vaTagType <> nil then
        ResolveVariantPart(arm^.vaTagAt, arm^.vaTagLen, arm^.vaTagLine,
                           arm^.vaTagCol, arm^.vaTagType, arm^.vaVariants, rec,
                           v^.fields, v^.fieldTail, v^.variants,
                           v^.variantTail, v^.tagField, v^.tagType,
                           v^.discSelector, armPath);

      index := index + 1;
      arm := arm^.next
    end
  end
end;

function ResolveRecord(d: nodePtr): typePtr;
var t, fieldType: typePtr; g, n, init: nodePtr;
begin
  t := NewType(tyRecord);
  t^.isPacked := d^.rcPacked;
  g := d^.rcFields;
  while g <> nil do begin
    { 6.6: a field's own type-denoter may carry an initial-state-specifier, and
      then the record's initial state has that field bearing that value. The
      offer is made here and nowhere else inside a type-denoter. }
    fieldType := ResolveType(g^.grType);
    init := InitialStateOf(g^.grType);
    n := g^.grNames;
    while n <> nil do begin
      AddField(t, t^.fields, t^.fieldTail, n, fieldType, nil,
               FieldCount(t^.fields), init);
      n := n^.next
    end;
    g := g^.next
  end;
  if d^.rcTagType <> nil then
    ResolveVariantPart(d^.rcTagAt, d^.rcTagLen, d^.rcTagLine, d^.rcTagCol,
                       d^.rcTagType, d^.rcVariants, t, t^.fields, t^.fieldTail,
                       t^.variants, t^.variantTail, t^.tagField, t^.tagType,
                       t^.discSelector, nil);
  ResolveRecord := t
end;


{ ---------------------------------------------- schemata (6.4.7 and 6.4.8) }

{ A shallow copy, so a production whose body is a shared singleton gets a type
  of its own to carry its provenance on. Nothing structural is duplicated: the
  copy is the same type in every way but its identity, which is the one thing
  6.4.8 needs it to have. }
function CopyType(src: typePtr): typePtr;
var t: typePtr;
begin
  t := NewType(src^.kind);
  t^.elem := src^.elem;
  t^.indexType := src^.indexType;
  t^.host := src^.host;
  t^.tagType := src^.tagType;
  t^.isPacked := src^.isPacked;
  t^.isText := src^.isText;
  t^.lo := src^.lo;
  t^.hi := src^.hi;
  t^.enumNames := src^.enumNames;
  t^.enumTail := src^.enumTail;
  t^.fields := src^.fields;
  t^.fieldTail := src^.fieldTail;
  t^.variants := src^.variants;
  t^.variantTail := src^.variantTail;
  t^.tagField := src^.tagField;
  t^.discSelector := src^.discSelector;
  t^.loDisc := src^.loDisc;
  t^.hiDisc := src^.hiDisc;
  CopyType := t
end;

procedure ForgetResolved(d: nodePtr); forward;

{ The sibling chain a std::vector of denoters becomes. }
procedure ForgetList(n: nodePtr);
begin
  while n <> nil do begin
    ForgetResolved(n);
    n := n^.next
  end
end;

procedure ForgetArms(v: nodePtr); forward;

{ Forget every type this denoter and its sub-denoters resolved to, so the next
  production of the same schema resolves them again against a different tuple.
  Without this a schema would produce one type and hand it out for every
  tuple, which is precisely the bug 6.4.8 exists to rule out. }
procedure ForgetResolved;
var g: nodePtr;
begin
  if d <> nil then begin
    d^.ntype := nil;
    case d^.kind of
      nkArray: begin
        ForgetList(d^.arDims);
        ForgetResolved(d^.arElem)
      end;
      nkFile:  begin
        ForgetResolved(d^.flElem);
        ForgetResolved(d^.flIndex)
      end;
      nkSetOf: ForgetResolved(d^.soElem);
      nkRecord: begin
        g := d^.rcFields;
        while g <> nil do begin
          ForgetResolved(g^.grType);
          g := g^.next
        end;
        ForgetResolved(d^.rcTagType);
        ForgetArms(d^.rcVariants)
      end;
      nkSchema: ForgetList(d^.scArgs);
      nkInt, nkReal, nkChar, nkStr, nkNil, nkSet, nkSetMember, nkVar,
      nkIndex, nkField, nkDeref, nkBinary, nkUnary, nkCall, nkEmpty,
      nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat, nkFor,
      nkProcCall, nkWith, nkCase, nkGoto, nkLabeled, nkWriteArg, nkCaseArm,
      nkVariantArm, nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange,
      nkPointer, nkConstDecl, nkTypeDecl, nkProcDecl, nkLabelDecl, nkBlock: ;
    end
  end
end;

{ An arm's field-list is a field-list, so its groups and its own variant part
  are walked exactly as the record's are (ADR-0026). }
procedure ForgetArms;
var g: nodePtr;
begin
  while v <> nil do begin
    g := v^.vaFields;
    while g <> nil do begin
      ForgetResolved(g^.grType);
      g := g^.next
    end;
    ForgetResolved(v^.vaTagType);
    ForgetArms(v^.vaVariants);
    v := v^.next
  end
end;

{ 6.4.7's schema-definition. The formal discriminants are given names and
  ordinal types here and values only when a type is produced, so they are
  symbols that live outside every scope -- a discriminant is not in scope in
  the block, only inside the schema's own body and after a '.' on a variable
  that possesses one of the schema's types. }
procedure DeclareSchema(d: nodePtr);
var s, disc, seen: symPtr; g, n: nodePtr; t: typePtr;
    p: symListPtr; repeated: boolean;
begin
  s := Declare(d^.tdAt, d^.tdLen, skSchema, d^.line, d^.col);
  if s^.schemaBody = nil then begin
    s^.schemaBody := d^.tdType;
    g := d^.tdDiscs;
    while g <> nil do begin
      t := BuiltinType(g^.grType^.nmAt, g^.grType^.nmLen);
      if t = nil then begin
        seen := Lookup(g^.grType^.nmAt, g^.grType^.nmLen);
        if (seen <> nil) and (seen^.kind = skType) then t := seen^.stype
      end;
      if t = nil then begin
        ErrorAt(g^.line, g^.col);
        write('unknown type ''');
        WritePool(g^.grType^.nmAt, g^.grType^.nmLen);
        writeln('''');
        t := intType
      end
      { 6.4.7 requires an ordinal-type-name: a discriminant tuple has to be
        something two types can be compared on, which a real or a record is
        not. }
      else if not IsOrdinal(t) then begin
        ErrorAt(g^.line, g^.col);
        write('the type of a discriminant must be ordinal, found ');
        WriteTypeName(t);
        writeln;
        t := intType
      end;
      n := g^.grNames;
      while n <> nil do begin
        repeated := false;
        p := s^.discs;
        while p <> nil do begin
          if PoolSame(p^.sym^.at, p^.sym^.len, n^.dnAt, n^.dnLen) then
            repeated := true;
          p := p^.next
        end;
        if repeated then begin
          ErrorAt(n^.line, n^.col);
          write('''');
          WritePool(n^.dnAt, n^.dnLen);
          write(''' is already a discriminant of schema ''');
          WritePool(d^.tdAt, d^.tdLen);
          writeln('''')
        end;
        disc := NewSymbol;
        disc^.at := n^.dnAt;
        disc^.len := n^.dnLen;
        disc^.kind := skConst;
        disc^.stype := t;
        AppendSym(s^.discs, s^.discTail, disc);
        n := n^.next
      end;
      g := g^.next
    end;
    if s^.discs = nil then begin
      ErrorAt(d^.line, d^.col);
      write('schema ''');
      WritePool(d^.tdAt, d^.tdLen);
      writeln(''' has no discriminants')
    end
  end
end;

{ True when the two tuples are the same tuple: 6.4.7's "the same number of
  values and equal values in corresponding positions". }
function SameTuple(a, b: numPtr): boolean;
var same: boolean;
begin
  same := true;
  while same and ((a <> nil) or (b <> nil)) do
    if (a = nil) or (b = nil) then same := false
    else if a^.value <> b^.value then same := false
    else begin
      a := a^.next;
      b := b^.next
    end;
  SameTuple := same
end;

procedure AppendNum(var head, tail: numPtr; v: integer);
var n: numPtr;
begin
  new(n);
  n^.value := v;
  n^.next := nil;
  if head = nil then head := n else tail^.next := n;
  tail := n
end;

{ Whether this schema's body is being resolved right now, at any depth. }
function SchemaIsBusy(schema: symPtr): boolean;
var q: symListPtr; busy: boolean;
begin
  busy := false;
  q := producingTop;
  while q <> nil do begin
    if q^.sym = schema then busy := true;
    q := q^.next
  end;
  SchemaIsBusy := busy
end;

{ 6.4.8: the type this schema maps the given actual-discriminant-part to.
  `dummy` is unused and exists so this and ResolveType can be forward-declared
  with signatures the C++ side has no counterpart for. }
function ProduceFromSchema;
var formals: symListPtr; a, arg: nodePtr; t, given: typePtr;
    tuple, tupleTail, tv: numPtr; value, count, want, before: integer;
    ok, repeated, dynamic, savedSchemaBody: boolean;
    pr: producedPtr; mark: entryPtr;
    disc, v: symPtr; p, q, push: symListPtr;
begin
  t := nil;
  formals := schema^.discs;
  want := 0;
  p := formals;
  while p <> nil do begin
    want := want + 1;
    p := p^.next
  end;
  count := 0;
  a := d^.scArgs;
  while a <> nil do begin
    count := count + 1;
    a := a^.next
  end;

  { 6.4.8: the tuple consists of the discriminant-values in textual order. A
    wrong count is reported once and the type is not produced, because a
    partial tuple would name a type the program never asked for. }
  if count <> want then begin
    ErrorAt(d^.line, d^.col);
    write('schema ''');
    WritePool(d^.scAt, d^.scLen);
    write(''' has ', want:1, ' discriminant');
    if want <> 1 then write('s');
    writeln(', found ', count:1);
    a := d^.scArgs;
    while a <> nil do begin
      CheckExpr(a);
      a := a^.next
    end;
    t := intType
  end
  { 6.4.7: outside the domain of a pointer, a schema-definition may not name
    itself. It is checked here rather than at the definition because that is
    where the recursion would actually happen -- and mutual recursion between
    two schemata is the same mistake and is caught by the same test. It comes
    before the tuple because a schema resolved *generically* has discriminants
    that are not constants, and reporting that instead would name a symptom. }
  else if SchemaIsBusy(schema) then begin
    ErrorAt(d^.line, d^.col);
    write('schema ''');
    WritePool(d^.scAt, d^.scLen);
    writeln(''' is defined in terms of itself; only the domain of a ',
            'pointer may name a schema being defined');
    t := intType
  end
  else begin
    tuple := nil;
    tupleTail := nil;
    ok := true;
    { 6.2.3.2 evaluates an actual-discriminant-part when the block is entered,
      so a *variable* may have a discriminant that is not a constant -- and
      then no tuple is known here and the whole denoter goes the dynamic way.
      One argument that is not constant is enough: a tuple is chosen whole. }
    dynamic := false;
    a := d^.scArgs;
    p := formals;
    while a <> nil do begin
      given := nil;
      value := 0;
      if not EvalOrdinal(a, given, value) then begin
        given := a^.ntype;
        if (dynamicVarFor <> nil) and IsOrdinal(given) then
          dynamic := true
        else begin
          { The message says which of the two it is, because "not a constant"
            and "not ordinal" are different mistakes -- and where a variable
            would have been allowed, only the second one is left. }
          ErrorAt(a^.line, a^.col);
          if dynamicVarFor <> nil then begin
            write('the discriminants of a schema must be ordinal; ''');
            WritePool(p^.sym^.at, p^.sym^.len);
            writeln(''' is not')
          end
          else begin
            write('the discriminants of a schema must be ordinal constants ',
                  'here; ''');
            WritePool(p^.sym^.at, p^.sym^.len);
            writeln(''' is not one')
          end;
          ok := false
        end
      end
      else if not Assignable(p^.sym^.stype, given) then begin
        ErrorAt(a^.line, a^.col);
        write('discriminant ''');
        WritePool(p^.sym^.at, p^.sym^.len);
        write(''' of schema ''');
        WritePool(d^.scAt, d^.scLen);
        write(''' is ');
        WriteTypeName(p^.sym^.stype);
        write(', found ');
        WriteTypeName(given);
        writeln;
        ok := false
      end
      { 6.4.7's domain is the tuples *allowed* by the formal-discriminant-part,
        so a value outside the discriminant's own type is not in the domain and
        never reaches a production. A value not known until entry is checked
        there instead, by the store into the descriptor -- the same check, made
        where the value finally is. }
      else if dynamic then
        { checked on entry }
      else if (value < OrdinalLo(p^.sym^.stype))
           or (value > OrdinalHi(p^.sym^.stype)) then begin
        ErrorAt(a^.line, a^.col);
        write('discriminant ''');
        WritePool(p^.sym^.at, p^.sym^.len);
        write(''' is outside ');
        WriteTypeName(p^.sym^.stype);
        writeln;
        ok := false
      end
      else
        AppendNum(tuple, tupleTail, value);
      a := a^.next;
      p := p^.next
    end;

    if not ok then
      t := intType
    { Every position but a variable declaration has already been refused, so
      the tuple is this variable's own and so is the type it produces. }
    else if dynamic then begin
      v := dynamicVarFor;
      dynamicVarFor := nil;   { the body is not a variable declaration }
      t := GenericFromSchema(schema, v, d, nounVarType);
      dynamicVarFor := v;
      if IsGeneric(t) then begin
        v^.descSchema := schema;
        v^.discExprs := d^.scArgs
      end
    end
    else begin
      pr := producedHead;
      while (pr <> nil) and (t = nil) do begin
        if (pr^.schema = schema) and SameTuple(pr^.tuple, tuple) then
          t := pr^.ty;
        pr := pr^.next
      end;

      { 6.4.3.3.3: the required schema has no body to resolve. What it produces
        is a variable-string-type whose capacity is the tuple's one component
        -- "each tuple in the domain of the schema shall have one component
        that is a value of integer-type greater than zero". A capacity of zero
        or less is therefore outside the *domain*. }
      if (t = nil) and schema^.isStringSchema then begin
        if tuple^.value <= 0 then begin
          ErrorAt(d^.line, d^.col);
          writeln('the capacity of a string must be greater than zero, ',
                  'found ', tuple^.value:1);
          t := intType
        end
        else begin
          t := NewType(tyString);
          t^.lo := 1;
          t^.hi := tuple^.value;
          t^.schema := schema;
          t^.tuple := tuple;
          new(pr);
          pr^.schema := schema;
          pr^.tuple := tuple;
          pr^.ty := t;
          pr^.next := producedHead;
          producedHead := pr
        end
      end;

      if t = nil then begin
        begin
          { The discriminants become ordinary constants for as long as the
            body is being resolved, which is what lets `array [1..n] of real`
            reach the existing subrange and array code with nothing added to
            either. }
          mark := scopeTop;
          scopeDepth := scopeDepth + 1;
          p := formals;
          tv := tuple;
          while p <> nil do begin
            repeated := false;
            q := formals;
            while q <> p do begin
              if PoolSame(q^.sym^.at, q^.sym^.len, p^.sym^.at, p^.sym^.len)
                then repeated := true;
              q := q^.next
            end;
            { A discriminant named twice was already reported at the schema;
              binding it again would report it once more at every *use*, and
              point at the tuple rather than at the definition that is wrong. }
            if not repeated then begin
              disc := Declare(p^.sym^.at, p^.sym^.len, skConst, d^.line,
                              d^.col);
              disc^.stype := p^.sym^.stype;
              disc^.discBinding := true;
              disc^.intVal := tv^.value;
              disc^.charVal := chr(tv^.value mod 256);
              disc^.boolVal := tv^.value <> 0
            end;
            p := p^.next;
            tv := tv^.next
          end;

          ForgetResolved(schema^.schemaBody);
          savedSchemaBody := inSchemaBody;
          inSchemaBody := true;
          new(push);
          push^.sym := schema;
          push^.next := producingTop;
          producingTop := push;
          before := errorCount;
          t := ResolveType(schema^.schemaBody);
          inSchemaBody := savedSchemaBody;
          { popped by rebuilding the list without its head }
          producingTop := producingTop^.next;
          scopeTop := mark;
          scopeDepth := scopeDepth - 1;

          { 6.4.7's domain is the tuples for which the body denotes a type at
            all -- NOTE 2 lists an empty subrange among the ways one can fail.
            Whatever the body reported, it reported it against the *schema's*
            text, which is not where the reader chose the tuple; this says
            which choice it was. }
          if errorCount <> before then begin
            ErrorAt(d^.line, d^.col);
            write('no type is produced from schema ''');
            WritePool(d^.scAt, d^.scLen);
            writeln(''' with these discriminants')
          end;

          { A produced type is a type of its own even when the body is a name
            or a simple type, so the provenance goes on a copy rather than on
            the shared singleton `integer` would hand back. }
          if (t^.schema <> nil) or (t = intType) or (t = realType)
             or (t = boolType) or (t = charType) or (t = textType) then
            t := CopyType(t);
          t^.schema := schema;
          t^.tuple := tuple;
          t^.tupleTail := tupleTail;

          { A produced type names itself after the schema and the tuple that
            produced it. Without this, two productions of one schema print
            identically -- and 6.4.8's whole point is that they are different
            types, so a diagnostic spelling `paint(red)` and `paint(green)`
            the same way would report the rule while hiding the reason. }
          msgOut := true;
          StrClear(msgBuf);
          WritePool(schema^.at, schema^.len);
          Put('(');
          p := formals;
          tv := tuple;
          while (p <> nil) and (tv <> nil) do begin
            if p <> formals then begin
              Put(',');
              Put(' ')
            end;
            WriteOrdinalName(p^.sym^.stype, tv^.value);
            p := p^.next;
            tv := tv^.next
          end;
          Put(')');
          msgOut := false;
          t^.aliasAt := PoolAdd(msgBuf);
          t^.aliasLen := msgBuf.len;

          new(pr);
          pr^.schema := schema;
          pr^.tuple := tuple;
          pr^.ty := t;
          pr^.next := producedHead;
          producedHead := pr
        end
      end
    end
  end;
  ProduceFromSchema := t
end;

function StaticThroughout(t: typePtr): boolean; forward;

{ The same question through every arm of a variant part, at every depth. }
function StaticVariants(v: variantPtr): boolean;
var f: fieldPtr; ok: boolean;
begin
  ok := true;
  while v <> nil do begin
    f := v^.fields;
    while f <> nil do begin
      if not StaticThroughout(f^.ftype) then ok := false;
      f := f^.next
    end;
    if not StaticVariants(v^.variants) then ok := false;
    v := v^.next
  end;
  StaticVariants := ok
end;

{ True when no bound anywhere inside this type depends on a discriminant. A
  pointer stops the walk: ISO 7185 6.4.4 makes its domain a type *identifier*,
  which is a type of the enclosing block and never generic. }
function StaticThroughout;
var f: fieldPtr; ok: boolean;
begin
  if t = nil then
    StaticThroughout := true
  else if (t^.loDisc <> nil) or (t^.hiDisc <> nil) then
    StaticThroughout := false
  else
    case t^.kind of
      tyArray:
        StaticThroughout := StaticThroughout(t^.indexType)
                        and StaticThroughout(t^.elem);
      tySet, tyFile: StaticThroughout := StaticThroughout(t^.elem);
      tyRecord: begin
        ok := true;
        f := t^.fields;
        while f <> nil do begin
          if not StaticThroughout(f^.ftype) then ok := false;
          f := f^.next
        end;
        if not StaticVariants(t^.variants) then ok := false;
        StaticThroughout := ok
      end;
      tyVoid, tyInteger, tyReal, tyBoolean, tyChar, tyEnum, tySubrange,
      tyPointer, tyProc, tyComplex: StaticThroughout := true
    end
end;

{ This type's size is not known until the block is entered: an array of
  dynamically-bounded arrays has a dynamic extent at every level. Only arrays
  reach this -- a schematic formal whose dynamic part is anywhere else is
  refused, because a record field after one would sit at an offset nothing
  could compute. }
{ The last field of a field-list, nil when there is none. It is the only
  position a dynamically-sized field may occupy (ADR-0045), so it is the only
  one anything asks for. }
function LastField(f: fieldPtr): fieldPtr;
begin
  LastField := nil;
  while f <> nil do begin
    LastField := f;
    f := f^.next
  end
end;

{ Whether this type's size is not known until run time: its own bounds are
  discriminants, or an array's component reaches one, or a record's **last**
  field does. Only the last, because a field after it would sit at an offset
  nothing could compute -- which is why this reads the last field and not "any
  field". A record with a dynamic field anywhere else is not a type with a
  dynamic extent; it is a type that is refused (ADR-0045). }
function DynamicExtent(t: typePtr): boolean;
var f: fieldPtr;
begin
  if t = nil then DynamicExtent := false
  else if (t^.loDisc <> nil) or (t^.hiDisc <> nil) then DynamicExtent := true
  else if t^.kind = tyArray then DynamicExtent := DynamicExtent(t^.elem)
  else if t^.kind = tyRecord then begin
    f := LastField(t^.fields);
    if f = nil then DynamicExtent := false
    else DynamicExtent := DynamicExtent(f^.ftype)
  end
  else DynamicExtent := false
end;

{ What a descriptor can describe: a type whose *size* may depend on the
  discriminants while every offset *inside* it stays a constant. That is the
  whole of the restriction, and both halves of it are here.

  An array qualifies whatever its bounds, because a component's address is
  computed from the bounds rather than looked up. A record qualifies when the
  dynamic part is its **last** field and it has no variant part -- a field
  after a dynamically-sized one, and the shared block of a variant part, both
  sit at an offset nothing can compute. Everything else is refused: a set and
  a file each have a size the runtime is told once. }
function DynamicTail(t: typePtr): boolean;
var f, last: fieldPtr; ok: boolean;
begin
  if not DynamicExtent(t) then
    DynamicTail := StaticThroughout(t)
  else if t^.kind = tyArray then
    DynamicTail := DynamicTail(t^.elem)
  else if (t^.kind <> tyRecord) or (t^.variants <> nil) or (t^.fields = nil)
  then
    DynamicTail := false
  else begin
    last := LastField(t^.fields);
    ok := true;
    f := t^.fields;
    while f <> last do begin
      if not StaticThroughout(f^.ftype) then ok := false;
      f := f^.next
    end;
    if ok then DynamicTail := DynamicTail(last^.ftype) else DynamicTail := false
  end
end;

{ The type of a schematic formal parameter: produced from a schema, but with no
  tuple -- the tuple arrives with the actual, in the descriptor that travels
  beside its address. A schema with no discriminants is refused, so an empty
  tuple cannot mean anything else. }
function IsGeneric;
begin
  IsGeneric := (t <> nil) and (t^.schema <> nil) and (t^.tuple = nil)
end;

{ 6.7.3.2 and 6.7.3.3's parameter-form written as a bare schema-name. The body
  is resolved once, with each discriminant bound to an skDisc symbol that reads
  this parameter's descriptor rather than to a value -- so `1..n` comes out as
  "the value of n", and one compiled body serves every tuple.

  The result belongs to this one parameter and is deliberately not interned:
  two parameters of one schema read two descriptors, so they cannot share a
  type however alike they look. }
{ The body resolved once with each discriminant bound to an skDisc symbol that
  reads `param`'s descriptor rather than to a value -- so `1..n` comes out as
  "the value of n", and one resolution serves every tuple.

  The result belongs to that one symbol and is deliberately not interned: two
  of them read two descriptors, so they cannot share a type however alike they
  look. `noun` picks the word a diagnostic calls them by: a schematic
  formal parameter and a variable with non-constant discriminants need exactly
  the same thing of this. }
function GenericFromSchema;
var t, comp: typePtr; p, q, push: symListPtr; disc: symPtr;
    mark: entryPtr; before, k: integer; repeated, savedSchemaBody: boolean;
begin
  t := nil;
  { No self-reference guard here. 6.4.7's rule is enforced where the recursion
    would happen -- in the production the body reaches -- and a parameter-form
    is never resolved inside one, so a second copy of the check would be
    unreachable. Mutation testing is what said so. }
  if schema^.discs = nil then
    t := intType      { already reported at the schema-definition }
  else begin
    mark := scopeTop;
    scopeDepth := scopeDepth + 1;
    param^.discSyms := nil;
    param^.discSymTail := nil;
    p := schema^.discs;
    k := 0;
    while p <> nil do begin
      disc := NewSymbol;
      disc^.at := p^.sym^.at;
      disc^.len := p^.sym^.len;
      disc^.kind := skDisc;
      disc^.stype := p^.sym^.stype;
      disc^.discBinding := true;
      { The discriminant lives in the parameter's own frame slot, after the
        address, so it is reached exactly as the parameter is and a recursive
        procedure sees the descriptor of the invocation it is running in. }
      disc^.owner := param^.owner;
      disc^.level := param^.level;
      disc^.frameIndex := param^.frameIndex;
      disc^.discIndex := k;
      AppendSym(param^.discSyms, param^.discSymTail, disc);
      { A discriminant named twice was reported at the schema; binding it again
        here would report it once more at every parameter that names it. }
      repeated := false;
      q := schema^.discs;
      while q <> p do begin
        if PoolSame(q^.sym^.at, q^.sym^.len, p^.sym^.at, p^.sym^.len) then
          repeated := true;
        q := q^.next
      end;
      if not repeated then Bind(disc^.at, disc^.len, disc);
      k := k + 1;
      p := p^.next
    end;

    { 6.4.3.3.3 again: a schematic formal `var s: string` is a string whose
    capacity arrives with the actual, so the bound is the skDisc symbol rather
    than a number -- exactly as `array [1..n]` reaches ADR-0040's descriptor. }
  if schema^.isStringSchema then begin
    scopeTop := mark;
    scopeDepth := scopeDepth - 1;
    t := NewType(tyString);
    t^.lo := 1;
    t^.hi := 0;
    t^.hiDisc := param^.discSyms^.sym;
    t^.schema := schema;
    param^.descSchema := schema;
    GenericFromSchema := t
  end
  else begin
  ForgetResolved(schema^.schemaBody);
    savedSchemaBody := inSchemaBody;
    inSchemaBody := true;
    new(push);
    push^.sym := schema;
    push^.next := producingTop;
    producingTop := push;
    genericFor := param;
    before := errorCount;
    t := ResolveType(schema^.schemaBody);
    inSchemaBody := savedSchemaBody;
    genericFor := nil;
    producingTop := producingTop^.next;
    scopeTop := mark;
    scopeDepth := scopeDepth - 1;

    if errorCount <> before then begin
      ErrorAt(d^.line, d^.col);
      write('no type is produced from schema ''');
      WritePool(schema^.at, schema^.len);
      case noun of
        nounVarType:       writeln(''' for this variable''s type');
        nounParamForm:     writeln(''' for this parameter form');
        nounPointerDomain: writeln(''' for this pointer domain')
      end;
      t := intType
    end
    else begin
      { What a descriptor can describe (ADR-0045). }
      if not DynamicTail(t) then begin
        ErrorAt(d^.line, d^.col);
        write('schema ''');
        WritePool(schema^.at, schema^.len);
        case noun of
          nounVarType:       write(''' cannot be a variable''s type: ');
          nounParamForm:     write(''' cannot be a parameter form: ');
          nounPointerDomain: write(''' cannot be a pointer domain: ')
        end;
        writeln('a discriminant has to bound an array, and a record holding ',
                'one has to hold it last, because a field after it would sit ',
                'at an offset nothing can compute');
        t := intType
      end
      else begin
        { A produced type is a type of its own, so a body that resolved to a
          shared singleton is copied before its provenance is written on it. }
        if (t^.schema <> nil) or (t = intType) or (t = realType)
           or (t = boolType) or (t = charType) or (t = textType) then
          t := CopyType(t);
        t^.schema := schema;
        { no tuple to name it by; the actual brings that }
        t^.aliasAt := schema^.at;
        t^.aliasLen := schema^.len
      end
    end
  end;
  GenericFromSchema := t
  end
end;

{ ISO/IEC 10206:1991 6.4.9: "The type denoted by a type-inquiry shall be the
  type possessed by the variable-identifier or parameter-identifier contained
  by the type-inquiry."

  It is the only type-denoter that names a *variable*, so its name is looked up
  in the ordinary scope rather than among the types -- and the whole feature is
  that one sentence. What comes back is a type some other declaration already
  owns, so nothing downstream can tell the type arrived this way: `var b: type
  of a` makes b the *same* type as a under 6.4.5's name equivalence, not a
  second type that looks like it. }
function ResolveInquiry(d: nodePtr): typePtr;
var s: symPtr; t: typePtr;
begin
  { 6.4.9 also allows the object to be a parameter of the closest-containing
    formal-parameter-list, and that needs nothing added: DeclareProcHeading
    pushes a scope before building the formals, so a parameter declared earlier
    in the same list is already an ordinary lookup by the time a later one's
    type-denoter asks. }
  s := Lookup(d^.tqAt, d^.tqLen);
  if s = nil then begin
    ErrorAt(d^.line, d^.col);
    write('unknown variable ''');
    WritePool(d^.tqAt, d^.tqLen);
    writeln(''' in ''type of''');
    ResolveInquiry := intType
  end
  else if not IsVariable(s) then begin
    ErrorAt(d^.line, d^.col);
    write('''type of'' names a variable or a parameter, and ''');
    WritePool(d^.tqAt, d^.tqLen);
    writeln(''' is not one');
    ResolveInquiry := intType
  end
  else begin
    t := s^.stype;
    if t = nil then
      ResolveInquiry := intType
    { A schematic formal's type has no tuple: its bounds are in a descriptor
      belonging to *that* parameter, and a second name reading them would need
      to share the descriptor rather than the type. 6.7.3.3 says what that
      means and this compiler does not do it yet -- so it is refused rather
      than silently given a type whose bounds it cannot read. }
    else if IsGeneric(t) then begin
      ErrorAt(d^.line, d^.col);
      write('''type of ');
      WritePool(d^.tqAt, d^.tqLen);
      write(''' would need the discriminants that arrive with ''');
      WritePool(d^.tqAt, d^.tqLen);
      writeln(''', which is not supported');
      ResolveInquiry := intType
    end
    else
      ResolveInquiry := t
  end
end;

function SchematicFormal(schema, param: symPtr; d: nodePtr): typePtr;
var t: typePtr;
begin
  t := GenericFromSchema(schema, param, d, nounParamForm);
  if IsGeneric(t) then param^.descSchema := schema;
  SchematicFormal := t
end;

{ ISO/IEC 10206:1991 6.8.2: an expression is *nonvarying* when its value cannot
  change -- literals, constants, and operations on those. That is not the same
  as "the compiler can fold it": 6.6's own examples include `ord(red)` and
  `polar(exp(1.0), pi)`, neither of which this compiler folds, and both of
  which are perfectly good things for a block prologue to compute. So the test
  is over what the expression *reads*, and what survives it is emitted as an
  ordinary expression at block entry.

  A required function is nonvarying with nonvarying arguments; a user-declared
  one is not, because 6.8.2 does not make it so and its body may read
  anything. }
function Nonvarying(e: nodePtr): boolean;
var ok: boolean; m: nodePtr;
begin
  if e = nil then
    Nonvarying := false
  else
    case e^.kind of
      nkInt, nkReal, nkChar, nkStr, nkNil: Nonvarying := true;
      nkVar: Nonvarying := (e^.vrSym <> nil) and (e^.vrSym^.kind = skConst);
      nkUnary: Nonvarying := Nonvarying(e^.unArg);
      nkBinary: Nonvarying := Nonvarying(e^.bnLhs) and Nonvarying(e^.bnRhs);
      nkSet: begin
        ok := true;
        m := e^.seMembers;
        while (m <> nil) and ok do begin
          if not Nonvarying(m^.smLo) then ok := false;
          if m^.smHi <> nil then
            if not Nonvarying(m^.smHi) then ok := false;
          m := m^.next
        end;
        Nonvarying := ok
      end;
      { `eof` and `eoln` read a file, which is what varying means. }
      nkCall: begin
        if (e^.clBuiltin = biNone) or (e^.clBuiltin = biEof) or
           (e^.clBuiltin = biEoln) then
          Nonvarying := false
        else begin
          ok := true;
          m := e^.clArgs;
          while (m <> nil) and ok do begin
            if not Nonvarying(m) then ok := false;
            m := m^.next
          end;
          Nonvarying := ok
        end
      end;
      nkSetMember, nkIndex, nkField, nkDeref, nkWriteArg, nkEmpty, nkAssign,
      nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat, nkFor, nkProcCall,
      nkWith, nkCase, nkGoto, nkLabeled, nkCaseArm, nkVariantArm, nkGroup,
      nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord, nkPointer,
      nkFile, nkSetOf, nkSchema, nkInquiry, nkConstDecl, nkTypeDecl,
      nkProcDecl, nkLabelDecl, nkBlock:
        Nonvarying := false
    end
end;

{ 6.6: "The initial state specified by an initial-state-specifier shall be the
  state bearing the value denoted by the component-value", and "An expression
  contained by the component-value of an initial-state-specifier shall be
  nonvarying."

  Nonvarying is what makes the whole feature cheap: nothing evaluated at entry
  can depend on the order the entry happens in. }
{ There is deliberately no check here that the *position* admits a specifier.
  The parser is the whole of that rule: only the three positions that may carry
  one call ParseTypeExpr, and every nested denoter stops before the word -- so
  a denoter reaching here with a value is by construction in a position that
  allows it. A version of this procedure carrying a "not here" message was
  written, and deleted when nothing could reach it. }
procedure CheckInitialState(d: nodePtr; t: typePtr);
var v: nodePtr;
begin
  v := d^.nsValue;
  if v <> nil then
    { 6.4.7 makes a schema body a type-denoter, so the word parses there -- and
      it is spelled as a type definition, which is why this needs a reason of
      its own rather than the position message below. }
    if inSchemaBody then begin
      ErrorAt(v^.line, v^.col);
      writeln('a schema''s body cannot carry an initial-state specifier: ',
              'every discriminant tuple produces its own type, and the ',
              'value would have to be attributed once for each')
    end
    { 6.5.1 makes the initial state of a *variant* conditional on the
      selector's own initial state selecting it. Nothing here tracks that, so a
      field of a variant part is refused rather than initialised into a variant
      that may not be the live one. }
    else if variantField then begin
      ErrorAt(v^.line, v^.col);
      writeln('a field of a variant part cannot have an initial value, ',
              'because which variant exists is not settled here')
    end
    else begin
      CheckExpr(v);
      if not Nonvarying(v) then begin
        ErrorAt(v^.line, v^.col);
        writeln('the value of an initial-state specifier must not depend on ',
                'a variable')
      end
      { 6.4.3.6 gives a file the initial state totally-undefined, and a file has
        no value to bear in any case. Asked before compatibility, or the
        message would be about the type of the value rather than about the
        file. }
      else if IsFile(t) then begin
        ErrorAt(v^.line, v^.col);
        writeln('a file variable has no initial value')
      end
      else if not Assignable(t, v^.ntype) then begin
        ErrorAt(v^.line, v^.col);
        write('cannot give ');
        if t = nil then write('this') else WriteTypeName(t);
        write(' an initial value of type ');
        if v^.ntype = nil then write('nothing') else WriteTypeName(v^.ntype);
        writeln
      end
      else
        d^.nsOk := true
    end
end;

{ The initial value a declaration of this denoter gives its variables. 6.4.1
  makes the *type-denoter* carry the initial state, so a type-name hands on the
  one its definition wrote -- which is what makes `type count = integer value 1;
  var c: count` initialise c. }
{ ISO/IEC 10206:1991 6.4.1 makes bindability a property the *type-denoter*
  denotes, and a type-name denotes "the type, bindability and initial state" of
  its definition -- so `type btext = bindable text` hands it on, and a parameter
  whose form is that name is bindable. Exactly InitialStateOf's shape, for
  exactly the clause's reason. }
function BindableOf(d: nodePtr): boolean;
var s: symPtr;
begin
  BindableOf := false;
  if d <> nil then
    if d^.nsBindable then
      BindableOf := true
    else if d^.kind = nkNamed then begin
      s := Lookup(d^.nmAt, d^.nmLen);
      if s <> nil then
        if s^.kind = skType then BindableOf := s^.isBindable
    end
end;

function InitialStateOf;
var s: symPtr;
begin
  InitialStateOf := nil;
  if d <> nil then
    if d^.nsOk then
      InitialStateOf := d^.nsValue
    else if d^.kind = nkNamed then begin
      s := Lookup(d^.nmAt, d^.nmLen);
      if s <> nil then
        if s^.kind = skType then InitialStateOf := s^.initValue
    end
end;

function ResolveType;
var t: typePtr; s, savedDynamic: symPtr; n: nodePtr;
begin
  if d^.ntype <> nil then
    ResolveType := d^.ntype
  else begin
    { 6.2.3.2 allows a discriminant that is not a constant in a variable's own
      type-denoter, and there only. A denoter of any other kind is on the way
      to somewhere else -- a component, a field, a domain -- so the offer is
      withdrawn before it recurses, and `array [1..3] of vector(n)` is refused
      exactly as it was. }
    savedDynamic := dynamicVarFor;
    if d^.kind <> nkSchema then dynamicVarFor := nil;
    t := nil;
    case d^.kind of
      nkNamed: begin
        t := BuiltinType(d^.nmAt, d^.nmLen);
        if t = nil then begin
          s := Lookup(d^.nmAt, d^.nmLen);
          if (s <> nil) and (s^.kind = skType) then
            t := s^.stype
          { 6.4.8: a schema denotes a type only once its discriminants are
            given, so the message says what is missing rather than that the
            name is unknown. }
          else if (s <> nil) and (s^.kind = skSchema) then begin
            ErrorAt(d^.line, d^.col);
            write('schema ''');
            WritePool(d^.nmAt, d^.nmLen);
            write(''' needs its discriminants here, as ');
            WritePool(d^.nmAt, d^.nmLen);
            writeln('(...)');
            t := intType
          end
          else begin
            ErrorAt(d^.line, d^.col);
            write('unknown type ''');
            WritePool(d^.nmAt, d^.nmLen);
            writeln('''');
            t := intType
          end
        end
      end;
      nkEnum:     t := ResolveEnum(d);
      nkSubrange: t := ResolveSubrange(d);
      nkArray:    t := ResolveArray(d, d^.arDims);
      nkRecord:   t := ResolveRecord(d);
      nkPointer:  t := ResolvePointer(d);
      nkFile:     t := ResolveFile(d);
      nkSetOf:    t := ResolveSet(d);
      nkInquiry:  t := ResolveInquiry(d);
      nkSchema: begin
        s := Lookup(d^.scAt, d^.scLen);
        if (s = nil) or (s^.kind <> skSchema) then begin
          ErrorAt(d^.line, d^.col);
          write('unknown schema ''');
          WritePool(d^.scAt, d^.scLen);
          writeln('''');
          { The discriminants are still checked, so a mistake in one of them
            is reported in the same run as the name that was not found. }
          n := d^.scArgs;
          while n <> nil do begin
            CheckExpr(n);
            n := n^.next
          end;
          t := intType
        end
        else
          t := ProduceFromSchema(s, nil, d)
      end;
      nkInt, nkReal, nkChar, nkStr, nkNil, nkSet, nkSetMember,
      nkVar, nkIndex, nkField, nkDeref,
      nkBinary, nkUnary, nkCall, nkEmpty, nkAssign, nkWrite, nkRead,
      nkCompound, nkIf, nkWhile, nkRepeat, nkFor, nkProcCall, nkWith, nkCase,
      nkWriteArg, nkCaseArm, nkVariantArm, nkGroup, nkDeclName, nkConstDecl,
      nkTypeDecl, nkProcDecl, nkBlock:
        t := intType
    end;
    dynamicVarFor := savedDynamic;
    CheckInitialState(d, t);
    d^.ntype := t;
    ResolveType := t
  end
end;

{ -------------------------------------------------------- the program file }

{ The file a read or a write acts on when it named none. The reference is
  synthesised rather than left for codegen to work out: ADR-0008 has codegen
  never resolving a name, so the defaulted file arrives as an ordinary resolved
  designator like any other. }
function StandardFileRef(wantInput: boolean; line, col: integer): nodePtr;
var f: symPtr; r: nodePtr;
begin
  if wantInput then f := stdInput else f := stdOutput;
  if f = nil then begin
    ErrorAt(line, col);
    if wantInput then write('''input''') else write('''output''');
    writeln(' must be listed as a program parameter to use it');
    StandardFileRef := nil
  end
  else begin
    r := NewNode(nkVar, line, col);
    r^.vrAt := f^.at;
    r^.vrLen := f^.len;
    r^.vrSym := f;
    r^.ntype := f^.stype;
    StandardFileRef := r
  end
end;

{ Give the program parameters their meaning: `input` and `output` are the
  standard files, and every other one must be a file variable the program block
  declares, bound to a command-line argument. }
procedure BindProgramParameters;
var p: nodePtr; s: symPtr; argIndex: integer;
begin
  { argv[0] is the program itself, so the first file parameter is argv[1]. }
  argIndex := 1;
  p := progParams;
  while p <> nil do begin
    s := Lookup(p^.dnAt, p^.dnLen);
    if (s = nil) or not ((s^.kind = skVar) or (s^.kind = skParam) or
                         (s^.kind = skVarParam)) then begin
      ErrorAt(p^.line, p^.col);
      write('the program parameter ''');
      WritePool(p^.dnAt, p^.dnLen);
      writeln(''' is not declared as a variable in the program block')
    end
    { `input` and `output` are bound by the header itself. The C++ writes this
      as a `continue`, which Pascal has no equivalent of; an empty statement
      before the `else` is the nearest thing, and ISO 7185 6.8.1 says it is a
      statement. (This compiler used to reject it, so the condition had to be
      folded into the next test instead.) }
    else if (s = stdInput) or (s = stdOutput) then
    else if not IsFile(s^.stype) then begin
      ErrorAt(p^.line, p^.col);
      write('a program parameter must be a file variable, but ''');
      WritePool(p^.dnAt, p^.dnLen);
      write(''' is ');
      if s^.stype = nil then write('untyped') else WriteTypeName(s^.stype);
      writeln
    end
    else begin
      s^.binding := fbArgument;
      s^.fileArg := argIndex;
      argIndex := argIndex + 1
    end;
    p := p^.next
  end
end;

function LookupBuiltin(at, len: integer): builtinKind; forward;

{ The names ISO 7185 6.6.5 and 6.6.6 reserve for the required procedures and
  functions. They are not symbols -- the compiler knows them by name -- so a
  program that tries to pass one gets "undeclared identifier" unless it is
  recognised here, which would be a baffling way to report 6.6.3.7. }
function IsRequiredName(at, len: integer): boolean;
begin
  IsRequiredName :=
    PoolIs(at, len, 'new      ') or PoolIs(at, len, 'dispose  ') or
    PoolIs(at, len, 'reset    ') or PoolIs(at, len, 'rewrite  ') or
    PoolIs(at, len, 'get      ') or PoolIs(at, len, 'put      ') or
    PoolIs(at, len, 'read     ') or PoolIs(at, len, 'readln   ') or
    PoolIs(at, len, 'write    ') or PoolIs(at, len, 'writeln  ') or
    PoolIs(at, len, 'pack     ') or PoolIs(at, len, 'unpack   ') or
    (LookupBuiltin(at, len) <> biNone)
end;

{ Bind the actual parameter of a procedural or functional parameter. It is a
  procedure *identifier* rather than an expression, so it is resolved here
  instead of through CheckExpr -- which would read `f` as a call of it. }
procedure CheckProcArgument(formal: symPtr; a: nodePtr; callee: symPtr;
                            at: integer);
var sym: symPtr;
begin
  { Whatever happens below, the argument leaves here with the formal's type:
    codegen reads vrSym, and a nil type would break the contract that every
    expression has one. }
  a^.ntype := formal^.stype;
  if a^.kind <> nkVar then begin
    ErrorAt(a^.line, a^.col);
    write('argument ', at:1, ' of ''');
    WritePool(callee^.at, callee^.len);
    writeln(''' must be the name of a procedure or function')
  end
  else begin
    sym := Lookup(a^.vrAt, a^.vrLen);
    if sym = nil then begin
      ErrorAt(a^.line, a^.col);
      { ISO 7185 6.6.3.7: the actual parameter shall not denote a required
        procedure or function. There is nothing to pass -- `write` takes a
        variable number of arguments of types no parameter list can spell,
        and `abs` is an instruction rather than a body with an address. }
      if IsRequiredName(a^.vrAt, a^.vrLen) then begin
        write('''');
        WritePool(a^.vrAt, a^.vrLen);
        write(''' is a required procedure or function and ');
        writeln('cannot be passed as a parameter')
      end
      else begin
        write('undeclared identifier ''');
        WritePool(a^.vrAt, a^.vrLen);
        writeln('''')
      end
    end
    else if not IsInvocable(sym) then begin
      ErrorAt(a^.line, a^.col);
      write('argument ', at:1, ' of ''');
      WritePool(callee^.at, callee^.len);
      write(''' must be the name of a procedure or function, but ''');
      WritePool(a^.vrAt, a^.vrLen);
      writeln(''' is not one')
    end
    else begin
      a^.vrSym := sym;
      { ISO 7185 6.6.3.6. The lists are compared rather than the types,
        because a procedural parameter has no type to write down: the heading
        *is* the type. }
      if not Congruous(formal, sym) then begin
        ErrorAt(a^.line, a^.col);
        write('''');
        WritePool(a^.vrAt, a^.vrLen);
        write(''' does not match the parameter list of ');
        if ResultTypeOf(formal) <> nil then write('functional')
        else write('procedural');
        write(' parameter ''');
        WritePool(formal^.at, formal^.len);
        writeln('''')
      end
    end
  end
end;

procedure CheckArguments(callee: symPtr; args: nodePtr; line, col: integer);
var a, b: nodePtr; p, q: symListPtr; n, given, i: integer;
begin
  { Checked against the parameter rather than on its own, because an actual
    procedural parameter is an identifier and not an expression: `f` there
    denotes the function, where CheckExpr would read it as a call of it. The
    arity is only tested afterwards, so a wrong count still reports whatever
    is wrong *inside* each argument as well. }
  a := args;
  p := callee^.params;
  i := 1;
  while a <> nil do begin
    if p <> nil then
      if p^.sym^.kind = skProcParam then
        CheckProcArgument(p^.sym, a, callee, i)
      else
        CheckExpr(a)
    else
      CheckExpr(a);
    if p <> nil then p := p^.next;
    i := i + 1;
    a := a^.next
  end;

  given := 0;
  a := args;
  while a <> nil do begin
    given := given + 1;
    a := a^.next
  end;
  n := 0;
  p := callee^.params;
  while p <> nil do begin
    n := n + 1;
    p := p^.next
  end;

  if given <> n then begin
    ErrorAt(line, col);
    write('''');
    WritePool(callee^.at, callee^.len);
    writeln(''' takes ', n:1, ' argument(s), but ', given:1, ' were given')
  end
  else begin
    a := args;
    p := callee^.params;
    i := 1;
    while a <> nil do begin
      if p^.sym^.kind = skProcParam then
        { already bound, above }
      { 6.7.3.2 and 6.7.3.3: a schematic formal parameter's type is decided by
        the actual, so the actual has only to be produced from the same schema
        -- whatever tuple it was produced with. It must be a variable either
        way, because a value parameter of a size not known until now is copied
        out of one rather than evaluated into one. }
      else if p^.sym^.descSchema <> nil then begin
        if not IsDesignator(a) then begin
          ErrorAt(a^.line, a^.col);
          write('argument ', i:1, ' of ''');
          WritePool(callee^.at, callee^.len);
          write(''' needs a variable produced from schema ''');
          WritePool(p^.sym^.descSchema^.at, p^.sym^.descSchema^.len);
          writeln('''')
        end
        else if (a^.ntype = nil) or (a^.ntype^.schema <> p^.sym^.descSchema)
        then begin
          ErrorAt(a^.line, a^.col);
          write('argument ', i:1, ' of ''');
          WritePool(callee^.at, callee^.len);
          write(''' must be produced from schema ''');
          WritePool(p^.sym^.descSchema^.at, p^.sym^.descSchema^.len);
          write(''', but the argument is ');
          WriteTypeName(a^.ntype);
          writeln
        end
      end
      else if p^.sym^.kind = skVarParam then begin
        if not IsDesignator(a) then begin
          ErrorAt(a^.line, a^.col);
          write('argument ', i:1, ' of ''');
          WritePool(callee^.at, callee^.len);
          writeln(''' is a var parameter and needs a variable')
        end
        else begin
        { 6.9.4 b) threatens an actual var parameter only when the *formal* is
          not itself protected -- which is what lets a protected parameter be
          handed on, and is the base case that makes the rule usable at all. }
        if not p^.sym^.isProtected then
          if Threatened(a) then begin
            write('it cannot be passed to the var parameter ''');
            WritePool(p^.sym^.at, p^.sym^.len);
            write(''' of ''');
            WritePool(callee^.at, callee^.len);
            writeln('''')
          end;
        { No implicit conversion is possible through a reference, so the types
          must be the same rather than merely assignment-compatible. }
        if (a^.ntype <> nil) and (p^.sym^.stype <> nil) and
                (a^.ntype <> p^.sym^.stype) then begin
          ErrorAt(a^.line, a^.col);
          write('var parameter ''');
          WritePool(p^.sym^.at, p^.sym^.len);
          write(''' is ');
          WriteTypeName(p^.sym^.stype);
          write(', but the argument is ');
          WriteTypeName(a^.ntype);
          writeln
        end
        end
      end
      { ISO/IEC 10206:1991 6.4.5 d) made every string type compatible with
        every other, and 6.4.6 pads the shorter -- but a value parameter is
        copied *bytewise*, so a shorter actual would be read past its end. The
        padding needs somewhere to build the conversion, which is the same
        thing a variable-string value parameter needs and does not have
        (ADR-0052), so the lengths must agree until it does. }
      else if IsCharArray(p^.sym^.stype) and (a^.ntype <> nil) and
              IsStringOrChar(a^.ntype) and
              (p^.sym^.stype^.loDisc = nil) and
              (p^.sym^.stype^.hiDisc = nil) and
              (not IsCharArray(a^.ntype) or (a^.ntype^.loDisc <> nil) or
               (a^.ntype^.hiDisc <> nil) or
               (TypeLength(a^.ntype) <> TypeLength(p^.sym^.stype))) then begin
        ErrorAt(a^.line, a^.col);
        write('argument ', i:1, ' of ''');
        WritePool(callee^.at, callee^.len);
        write(''' is ');
        WriteTypeName(p^.sym^.stype);
        writeln(', and a value parameter is copied rather than padded; ',
                'so the argument must have the same length')
      end
      { A structured value parameter is a copy, so it needs something to copy
        from: a designator, or a string literal. }
      else if IsStructured(p^.sym^.stype) and not IsDesignator(a) and
              (a^.kind <> nkStr) then begin
        ErrorAt(a^.line, a^.col);
        write('argument ', i:1, ' of ''');
        WritePool(callee^.at, callee^.len);
        write(''' is ');
        WriteTypeName(p^.sym^.stype);
        writeln(' and needs a variable')
      end
      else if not Assignable(p^.sym^.stype, a^.ntype) then begin
        ErrorAt(a^.line, a^.col);
        write('argument ', i:1, ' of ''');
        WritePool(callee^.at, callee^.len);
        write(''' is ');
        WriteTypeName(p^.sym^.stype);
        write(', but the value is ');
        WriteTypeName(a^.ntype);
        writeln
      end;
      i := i + 1;
      p := p^.next;
      a := a^.next
    end;

    { 6.7.3.3: one formal-parameter-section is one parameter-form, so every
      actual corresponding to it brings the same tuple -- `var a, b: vector`
      takes two vectors of one length, not two vectors. The standard calls a
      mismatch a dynamic-violation; every tuple this compiler can write is
      already known here, so it is reported before the program runs. }
    a := args;
    p := callee^.params;
    while a <> nil do begin
      if p^.sym^.descSchema <> nil then
        if (a^.ntype <> nil) and not IsGeneric(a^.ntype) then begin
          b := args;
          q := callee^.params;
          while b <> a do begin
            if (q^.sym^.descSchema = p^.sym^.descSchema) and
               (q^.sym^.paramSection = p^.sym^.paramSection) and
               (b^.ntype <> nil) then
              if not IsGeneric(b^.ntype) and (b^.ntype <> a^.ntype) then begin
                ErrorAt(a^.line, a^.col);
                write('''');
                WritePool(q^.sym^.at, q^.sym^.len);
                write(''' and ''');
                WritePool(p^.sym^.at, p^.sym^.len);
                write(''' are one parameter form, so their arguments are one ',
                      'type: found ');
                WriteTypeName(b^.ntype);
                write(' and ');
                WriteTypeName(a^.ntype);
                writeln
              end;
            b := b^.next;
            q := q^.next
          end
        end;
      p := p^.next;
      a := a^.next
    end
  end
end;

{ ------------------------------------------------------------ expressions }

procedure WriteOpName(op: binaryOp);
begin
  case op of
    opAdd:     write('+');
    opSub:     write('-');
    opMul:     write('*');
    opRealDiv: write('/');
    opIntDiv:  write('div');
    opMod:     write('mod');
    opAnd:     write('and');
    opOr:      write('or');
    opExp:     write('**');
    opPow:     write('pow');
    opAndThen: write('and then');
    opOrElse:  write('or else');
    opEq:      write('=');
    opNe:      write('<>');
    opLt:      write('<');
    opLe:      write('<=');
    opGt:      write('>');
    opGe:      write('>=');
    opIn:      write('in')
  end
end;

{ A padded literal, written without its padding. ADR-0012's record is for text
  that is *stored*; a word that is only ever written needs nothing but this. }
procedure WriteWord(w: wordLit);
var n, k: integer;
begin
  n := wordWidth;
  while (n > 0) and (w[n] = ' ') do n := n - 1;
  for k := 1 to n do write(w[k])
end;

procedure BadOperands(b: nodePtr; l, r: typePtr; want: wordLit);
begin
  ErrorAt(b^.line, b^.col);
  write('operator ''');
  WriteOpName(b^.bnOp);
  write(''' needs ');
  WriteWord(want);
  write(' operands, found ');
  WriteTypeName(l);
  write(' and ');
  WriteTypeName(r);
  writeln
end;

{ ISO 7185 6.7.1: the members of a set constructor are expressions of a single
  ordinal type, and `a..b` abbreviates every value from a to b -- an empty
  range when b precedes a. The constructor's type is a set of that ordinal
  type; `[]` has no members to say what it is a set of, so it gets the one set
  type compatible with all of them.

  The members need not be constants, so nothing is folded here: whether a value
  lies in the base type of whatever this is finally assigned to is a run-time
  question, and codegen asks it. }
procedure CheckSetMember(e: nodePtr; var baseType: typePtr);
begin
  if (e <> nil) and (e^.ntype <> nil) then
    if not IsOrdinal(e^.ntype) then begin
      ErrorAt(e^.line, e^.col);
      write('a set member must have an ordinal type, found ');
      WriteTypeName(e^.ntype);
      writeln
    end
    else if baseType = nil then
      { The base is the member's own base type, so `['a'..'z']` is a set of
        char rather than a set of some anonymous subrange of it. }
      baseType := Base(e^.ntype)
    else if not Assignable(baseType, e^.ntype) and
            not Assignable(e^.ntype, baseType) then begin
      ErrorAt(e^.line, e^.col);
      write('the members of a set must all have one type: this one is ');
      WriteTypeName(e^.ntype);
      write(', not ');
      WriteTypeName(baseType);
      writeln
    end
end;

procedure CheckSetExpr(e: nodePtr);
var m: nodePtr; baseType, t: typePtr;
begin
  baseType := nil;
  m := e^.seMembers;
  while m <> nil do begin
    CheckExpr(m^.smLo);
    if m^.smHi <> nil then CheckExpr(m^.smHi);
    CheckSetMember(m^.smLo, baseType);
    if m^.smHi <> nil then CheckSetMember(m^.smHi, baseType);
    m := m^.next
  end;
  if baseType = nil then
    e^.ntype := emptySetType
  else begin
    t := NewType(tySet);
    t^.elem := baseType;
    e^.ntype := t
  end
end;

procedure CheckBinary(b: nodePtr);
var l, r: typePtr;
begin
  CheckExpr(b^.bnLhs);
  CheckExpr(b^.bnRhs);
  l := b^.bnLhs^.ntype;
  r := b^.bnRhs^.ntype;
  if (l = nil) or (r = nil) then
    b^.ntype := intType
  { ISO 7185 6.7.2.3 gives +, - and * a second meaning on sets -- union,
    difference and intersection -- so the set case is taken before the numeric
    one rather than after it, where "numeric operands" would already have been
    reported. }
  else if (IsSet(l) or IsSet(r)) and
          ((b^.bnOp = opAdd) or (b^.bnOp = opSub) or (b^.bnOp = opMul)) then
  begin
    if not Assignable(l, r) and not Assignable(r, l) then begin
      BadOperands(b, l, r, 'compatible  ');
      if IsSet(l) then b^.ntype := l else b^.ntype := r
    end
    { The result is a set of the operands' common base type, which is whichever
      of them has one: `s + []` is still a set of s's base. }
    else if IsEmptySet(l) then b^.ntype := r
    else b^.ntype := l
  end
  else
    case b^.bnOp of
      { 6.7.2.4: the left operand is a value of the right's base type, and the
        result says whether it is a member. A value outside the base type is
        not an error -- it is simply not in the set. }
      opIn: begin
        if not IsSet(r) then begin
          ErrorAt(b^.line, b^.col);
          write('the right operand of ''in'' must be a set, found ');
          WriteTypeName(r);
          writeln
        end
        else if not IsOrdinal(l) then begin
          ErrorAt(b^.line, b^.col);
          write('the left operand of ''in'' must have an ordinal type, ');
          write('found ');
          WriteTypeName(l);
          writeln
        end
        else if not IsEmptySet(r) and not Assignable(r^.elem, l) and
                not Assignable(l, r^.elem) then begin
          ErrorAt(b^.line, b^.col);
          write('this set has base type ');
          WriteTypeName(r^.elem);
          write(', but the value tested is ');
          WriteTypeName(l);
          writeln
        end;
        b^.ntype := boolType
      end;

      { ISO/IEC 10206:1991 6.8.3.2, table 3: `+ - * /` take an integer, a real
        or a complex, and the result is complex if either operand is. The
        widening is 6.4.6 c)'s implicit conversion, which is why the operand
        check is the *same* assignability question asked everywhere else. }
      { 6.8.3.6 gives `+` a second meaning again -- string concatenation -- so
        it is taken before the numeric case, exactly as the set case is. "a + b
        shall denote a value of the canonical-string-type whose length shall be
        equal to the sum of the length of a and the length of b." }
      opAdd, opSub, opMul:
        if (b^.bnOp = opAdd) and (langStd = stdExtended) and
           IsStringOrChar(l) and IsStringOrChar(r) and
           not (IsChar(l) and IsChar(r)) then
          b^.ntype := canonStringType
        else if not IsArith(l) or not IsArith(r) then begin
          BadOperands(b, l, r, 'numeric     ');
          b^.ntype := intType
        end
        else if IsComplex(l) or IsComplex(r) then b^.ntype := complexType
        else if IsReal(l) or IsReal(r) then b^.ntype := realType
        else b^.ntype := intType;

      opRealDiv: begin
        if not IsArith(l) or not IsArith(r) then
          BadOperands(b, l, r, 'numeric     ');
        if IsComplex(l) or IsComplex(r) then b^.ntype := complexType
        else b^.ntype := realType
      end;

      opIntDiv, opMod: begin
        if not IsInteger(l) or not IsInteger(r) then
          BadOperands(b, l, r, 'integer     ');
        b^.ntype := intType
      end;

      { 6.8.3.3 gives all four the same operands and the same result; they
        part company only over whether the right one is *evaluated*. }
      opAnd, opOr, opAndThen, opOrElse: begin
        if not IsBoolean(l) or not IsBoolean(r) then
          BadOperands(b, l, r, 'boolean     ');
        b^.ntype := boolType
      end;

      { ISO/IEC 10206:1991 6.8.3.2, table 3. `**` is "exponentiation to a real
        power": an integer operand stands for a real approximation to its
        value, so the result is real however it was written. `pow` is
        "exponentiation to an integer power", and its result has the type of
        its *left* operand -- which is the whole reason the standard has two
        operators rather than one. }
      { Table 3 gives `**` a complex *left* operand and a numeric right one,
        and the result is complex exactly when the left operand is -- the same
        rule `pow` has, which is why both ask one question about the left. }
      opExp: begin
        if not IsArith(l) or not IsNumeric(r) then
          BadOperands(b, l, r, 'numeric     ');
        if IsComplex(l) then b^.ntype := complexType
        else b^.ntype := realType
      end;

      opPow:
        if not IsArith(l) then begin
          BadOperands(b, l, r, 'numeric     ');
          b^.ntype := intType
        end
        else begin
          if not IsInteger(r) then begin
            ErrorAt(b^.line, b^.col);
            write('the right operand of ''pow'' must be an integer, found ');
            WriteTypeName(r);
            writeln(' (use ** for a real exponent)')
          end;
          if IsComplex(l) then b^.ntype := complexType
          else if IsReal(l) then b^.ntype := realType
          else b^.ntype := intType
        end;

      opEq, opNe, opLt, opLe, opGt, opGe: begin
        { ISO 7185 6.7.2.5 gives the string types the full set of relational
          operators, comparing character by character; every other structured
          type has none at all. }
        { 6.8.3.5: the relational operators over compatible string-types, where
          the shorter operand is padded with spaces. Under ISO 7185 the lengths
          had to be equal and this compiler said so; that check now applies
          only to the language that has the rule. }
        if (langStd = stdExtended) and IsStringOrChar(l) and
           IsStringOrChar(r) and not (IsChar(l) and IsChar(r)) then
          { padded comparison: nothing to check }
        else if IsCharArray(l) and IsCharArray(r) then begin
          { A length that is a discriminant is not known here, so the
            requirement that the two agree is made where the values are.
            TypeLength would answer with arithmetic on the placeholder bounds,
            which is a number and so not visibly wrong. }
          if DynamicExtent(l) or DynamicExtent(r) then
            { checked when the program runs }
          else if TypeLength(l) <> TypeLength(r) then begin
            ErrorAt(b^.line, b^.col);
            write('strings of different lengths cannot be compared: ');
            WriteTypeName(l);
            write(' and ');
            WriteTypeName(r);
            writeln
          end
        end
        { 6.7.2.5: pointers compare only for equality. There is no ordering on
          them -- a heap address is not a value the program may reason about
          beyond identity. }
        else if IsPointer(l) or IsPointer(r) then begin
          if (b^.bnOp <> opEq) and (b^.bnOp <> opNe) then begin
            ErrorAt(b^.line, b^.col);
            write('pointers can only be compared with = and <>, not with ''');
            WriteOpName(b^.bnOp);
            writeln('''')
          end
          else if not Assignable(l, r) and not Assignable(r, l) then
            BadOperands(b, l, r, 'compatible  ');
        end
        else if IsSet(l) or IsSet(r) then begin
          { 6.7.2.5: <= and >= on sets are inclusion, not order, and there is
            no < or > at all -- a proper subset is not a primitive. }
          if (b^.bnOp = opLt) or (b^.bnOp = opGt) then begin
            ErrorAt(b^.line, b^.col);
            write('sets have no ''');
            WriteOpName(b^.bnOp);
            writeln(''': use <= and >= for inclusion')
          end
          else if not Assignable(l, r) and not Assignable(r, l) then
            BadOperands(b, l, r, 'compatible  ')
        end
        else if IsFile(l) or IsFile(r) then begin
          { 6.7.2.5 gives a file no relational operators at all, and naming the
            types would just repeat "text and text" back at the programmer. }
          ErrorAt(b^.line, b^.col);
          writeln('file variables cannot be compared')
        end
        else if IsMemory(l) or IsMemory(r) then
          BadOperands(b, l, r, 'comparable  ')
        { 6.8.3.5, table 6: `=` and `<>` accept any simple type, and the four
          ordering operators accept "any simple-type **except complex-type**".
          There is no order on the complex numbers, so this is the standard
          declining to invent one rather than an omission. }
        else if IsComplex(l) or IsComplex(r) then begin
          if (b^.bnOp <> opEq) and (b^.bnOp <> opNe) then begin
            ErrorAt(b^.line, b^.col);
            write('complex values can only be compared with = and <>, ',
                  'not with ''');
            WriteOpName(b^.bnOp);
            writeln(''': there is no order on the complex numbers')
          end
          else if not IsArith(l) or not IsArith(r) then
            BadOperands(b, l, r, 'compatible  ')
        end
        else if not (IsNumeric(l) and IsNumeric(r)) and
                not Assignable(l, r) and not Assignable(r, l) then
          { Compatibility is decided the same way it is for assignment, so a
            subrange compares with its host type and with its siblings. }
          BadOperands(b, l, r, 'compatible  ');
        b^.ntype := boolType
      end
    end
end;

function LookupBuiltin;
begin
  if PoolIs(at, len, 'abs      ') then LookupBuiltin := biAbs
  else if PoolIs(at, len, 'sqr      ') then LookupBuiltin := biSqr
  else if PoolIs(at, len, 'odd      ') then LookupBuiltin := biOdd
  else if PoolIs(at, len, 'ord      ') then LookupBuiltin := biOrd
  else if PoolIs(at, len, 'chr      ') then LookupBuiltin := biChr
  else if PoolIs(at, len, 'succ     ') then LookupBuiltin := biSucc
  else if PoolIs(at, len, 'pred     ') then LookupBuiltin := biPred
  else if PoolIs(at, len, 'sqrt     ') then LookupBuiltin := biSqrt
  else if PoolIs(at, len, 'sin      ') then LookupBuiltin := biSin
  else if PoolIs(at, len, 'cos      ') then LookupBuiltin := biCos
  else if PoolIs(at, len, 'ln       ') then LookupBuiltin := biLn
  else if PoolIs(at, len, 'exp      ') then LookupBuiltin := biExp
  else if PoolIs(at, len, 'arctan   ') then LookupBuiltin := biArcTan
  else if PoolIs(at, len, 'trunc    ') then LookupBuiltin := biTrunc
  else if PoolIs(at, len, 'round    ') then LookupBuiltin := biRound
  else if PoolIs(at, len, 'eof      ') then LookupBuiltin := biEof
  else if PoolIs(at, len, 'eoln     ') then LookupBuiltin := biEoln
  { 6.7.6.2 and 6.7.6.3. Looked up under both standards and refused under
    ISO 7185 where the call is checked: a valid ISO 7185 program may declare a
    function called `re`, so the *name* is not reserved. }
  else if PoolIs(at, len, 'cmplx    ') then LookupBuiltin := biCmplx
  else if PoolIs(at, len, 'polar    ') then LookupBuiltin := biPolar
  else if PoolIs(at, len, 're       ') then LookupBuiltin := biRe
  else if PoolIs(at, len, 'im       ') then LookupBuiltin := biIm
  else if PoolIs(at, len, 'arg      ') then LookupBuiltin := biArg
  { 6.7.6.6 and 6.7.6.5. Required identifiers like the complex ones, so a
    declaration of the same name wins and ISO 7185 refuses them. }
  else if PoolIsWide(at, len, 'position        ') then
    LookupBuiltin := biPosition
  else if PoolIsWide(at, len, 'lastposition    ') then
    LookupBuiltin := biLastPosition
  else if PoolIsWide(at, len, 'empty           ') then
    LookupBuiltin := biEmpty
  { 6.7.6.7. Required identifiers, so a program may declare its own. }
  else if PoolIsWide(at, len, 'length          ') then LookupBuiltin := biLength
  else if PoolIsWide(at, len, 'index           ') then LookupBuiltin := biIndex
  else if PoolIsWide(at, len, 'substr          ') then LookupBuiltin := biSubstr
  else if PoolIsWide(at, len, 'trim            ') then LookupBuiltin := biTrim
  else if PoolIsWide(at, len, 'eq              ') then LookupBuiltin := biStrEq
  else if PoolIsWide(at, len, 'ne              ') then LookupBuiltin := biStrNe
  else if PoolIsWide(at, len, 'lt              ') then LookupBuiltin := biStrLt
  else if PoolIsWide(at, len, 'gt              ') then LookupBuiltin := biStrGt
  else if PoolIsWide(at, len, 'le              ') then LookupBuiltin := biStrLe
  else if PoolIsWide(at, len, 'ge              ') then LookupBuiltin := biStrGe
  { 6.7.6.8's one. }
  else if PoolIsWide(at, len, 'binding         ') then
    LookupBuiltin := biBinding
  else LookupBuiltin := biNone
end;

{ The five required functions ISO/IEC 10206:1991 adds for the complex type.
  They are grouped because every question anyone asks about them is the same
  one: does this standard have them? }
function IsComplexBuiltin(b: builtinKind): boolean;
begin
  IsComplexBuiltin := (b = biCmplx) or (b = biPolar) or (b = biRe) or
                      (b = biIm) or (b = biArg)
end;

{ 6.7.6.6's two and 6.7.6.5's one. Grouped for the same reason the complex ones
  are: the only question anyone asks is whether this standard has them. }
function IsFileEnquiry(b: builtinKind): boolean;
begin
  IsFileEnquiry := (b = biPosition) or (b = biLastPosition) or (b = biEmpty)
end;

{ 6.7.6.7's ten, grouped for the same reason as the rest: the only question
  asked of them together is whether this standard has them. }
function IsStringBuiltin(b: builtinKind): boolean;
begin
  IsStringBuiltin := (b = biLength) or (b = biIndex) or (b = biSubstr) or
                     (b = biTrim) or (b = biStrEq) or (b = biStrNe) or
                     (b = biStrLt) or (b = biStrGt) or (b = biStrLe) or
                     (b = biStrGe)
end;

{ The six comparison functions of 6.7.6.7, which take two operands where the
  other four take one or three. }
{ 6.7.6.8's one. Grouped with the rest for the same reason: the only question
  asked of it alone is whether this standard has it. }
function IsBindingBuiltin(b: builtinKind): boolean;
begin IsBindingBuiltin := b = biBinding end;

function IsStringCompare(b: builtinKind): boolean;
begin
  IsStringCompare := (b = biStrEq) or (b = biStrNe) or (b = biStrLt) or
                     (b = biStrGt) or (b = biStrLe) or (b = biStrGe)
end;

{ Every argument of a 6.7.6.7 function that is meant to be a string: "the
  expressions s1 and s2 shall each be of char-type or a string-type". Only the
  first argument of `substr` is one, which is why the caller says how many. }
procedure CheckStringArgs(c, first: nodePtr);
var a: nodePtr; k: integer;
begin
  a := first;
  k := 0;
  while (a <> nil) and (k < 2) do begin
    if a^.ntype <> nil then
      if not IsStringOrChar(a^.ntype) then begin
        ErrorAt(a^.line, a^.col);
        write('''');
        WritePool(c^.clAt, c^.clLen);
        write(''' needs a string or a char, found ');
        WriteTypeName(a^.ntype);
        writeln
      end;
    if c^.clBuiltin = biSubstr then k := 2 else k := k + 1;
    a := a^.next
  end
end;

procedure RequireArg(c: nodePtr; ok: boolean; want: wordLit; a: typePtr);
begin
  if not ok then begin
    ErrorAt(c^.line, c^.col);
    write('''');
    WritePool(c^.clAt, c^.clLen);
    write(''' needs ');
    WriteWord(want);
    write(' argument, found ');
    WriteTypeName(a);
    writeln
  end
end;

procedure CheckCall(c: nodePtr);
var sym: symPtr; a, def, last, root: nodePtr; t: typePtr;
    n, at2, len2: integer; bad: boolean;
begin
  { A user-defined function shadows nothing built in: names are resolved in the
    scope chain first, so a local `abs` would win. }
  sym := Lookup(c^.clAt, c^.clLen);
  if IsInvocable(sym) and (ResultTypeOf(sym) <> nil) then begin
    c^.clSym := sym;
    c^.ntype := ResultTypeOf(sym);
    CheckArguments(sym, c^.clArgs, c^.line, c^.col)
  end
  else if IsInvocable(sym) then begin
    ErrorAt(c^.line, c^.col);
    write('''');
    WritePool(c^.clAt, c^.clLen);
    writeln(''' is a procedure and returns no value');
    c^.ntype := intType
  end
  else begin
    c^.clBuiltin := LookupBuiltin(c^.clAt, c^.clLen);
    { The complex functions are ISO/IEC 10206:1991's, and their names are not
      reserved in either language -- a valid ISO 7185 program may declare a
      function called `re`. So they are recognised only when nothing else of
      that name was found, and only under the standard that has them; the
      message then says the feature is missing rather than that the name is. }
    if (langStd = stdIso7185) and
       (IsComplexBuiltin(c^.clBuiltin) or IsFileEnquiry(c^.clBuiltin) or
        IsStringBuiltin(c^.clBuiltin) or
        IsBindingBuiltin(c^.clBuiltin)) then begin
      ErrorAt(c^.line, c^.col);
      write('''');
      WritePool(c^.clAt, c^.clLen);
      writeln(''' is an Extended Pascal function; compile with ',
              '--std=extended');
      c^.ntype := intType
    end
    else if c^.clBuiltin = biNone then begin
      ErrorAt(c^.line, c^.col);
      write('unknown function ''');
      WritePool(c^.clAt, c^.clLen);
      writeln('''');
      c^.ntype := intType
    end
    else begin
      a := c^.clArgs;
      while a <> nil do begin
        CheckExpr(a);
        a := a^.next
      end;
      n := 0;
      a := c^.clArgs;
      last := nil;
      while a <> nil do begin
        n := n + 1;
        last := a;
        a := a^.next
      end;

      { `eof` and `eoln` are the only required functions whose argument may be
        left out, and the only ones taking a file (ISO 7185 6.6.6.5). The
        default is supplied here rather than in codegen, so that by the time
        the tree is handed on, both forms look the same. }
      { 6.7.6.8: binding(f) returns a BindingType -- the only required function
        whose result is a record. This compiler returns no records, so the
        value is built in a hidden frame slot and the call *is* that
        designator, which is what makes `b := binding(f)` need no case. }
      if c^.clBuiltin = biBinding then begin
        c^.ntype := bindingType;
        if n <> 1 then begin
          ErrorAt(c^.line, c^.col);
          writeln('''binding'' takes one bindable variable')
        end
        else begin
          a := c^.clArgs;
          if not IsDesignator(a) or
             ((a^.ntype <> nil) and not IsFile(a^.ntype)) then begin
            ErrorAt(a^.line, a^.col);
            write('''binding'' needs a file variable');
            if a^.ntype <> nil then begin
              write(', found ');
              WriteTypeName(a^.ntype)
            end;
            writeln
          end
          else begin
            root := RootDesignator(a);
            bad := false;
            if root <> nil then
              if root^.kind = nkVar then
                if root^.vrSym <> nil then
                  if not root^.vrSym^.isBindable then begin
                    bad := true;
                    ErrorAt(a^.line, a^.col);
                    write('''');
                    WritePool(root^.vrSym^.at, root^.vrSym^.len);
                    writeln(''' is not bindable; only a variable of a ',
                            'bindable type can be bound to something outside ',
                            'the program')
                  end;
            if not bad then begin
              InternBindingName(currentProc^.frameCount, at2, len2);
              c^.clSlot := AddHiddenVar(at2, len2, skVar, bindingType,
                                        currentProc)
            end
          end
        end
      end
      else if IsStringBuiltin(c^.clBuiltin) then begin
        if IsStringCompare(c^.clBuiltin) then begin
          c^.ntype := boolType;
          if n <> 2 then begin
            ErrorAt(c^.line, c^.col);
            write('''');
            WritePool(c^.clAt, c^.clLen);
            writeln(''' takes two strings')
          end
          else
            CheckStringArgs(c, c^.clArgs)
        end
        else if c^.clBuiltin = biIndex then begin
          c^.ntype := intType;
          if n <> 2 then begin
            ErrorAt(c^.line, c^.col);
            writeln('''index'' takes two strings')
          end
          else
            CheckStringArgs(c, c^.clArgs)
        end
        else if c^.clBuiltin = biLength then begin
          c^.ntype := intType;
          if n <> 1 then begin
            ErrorAt(c^.line, c^.col);
            writeln('''length'' takes one string')
          end
          else
            CheckStringArgs(c, c^.clArgs)
        end
        { 6.7.6.7: trim and substr "return a result of the
          canonical-string-type" -- a value with no capacity, because it has no
          storage. What it may be assigned to is decided by its *length*, where
          the value finally is. }
        else if c^.clBuiltin = biTrim then begin
          c^.ntype := canonStringType;
          if n <> 1 then begin
            ErrorAt(c^.line, c^.col);
            writeln('''trim'' takes one string')
          end
          else
            CheckStringArgs(c, c^.clArgs)
        end
        else begin
          c^.ntype := canonStringType;
          if (n <> 2) and (n <> 3) then begin
            ErrorAt(c^.line, c^.col);
            writeln('''substr'' takes a string and one or two positions')
          end
          else begin
            CheckStringArgs(c, c^.clArgs);
            a := c^.clArgs^.next;
            while a <> nil do begin
              if a^.ntype <> nil then
                if not IsInteger(a^.ntype) then begin
                  ErrorAt(a^.line, a^.col);
                  write('the positions of ''substr'' are integers, found ');
                  WriteTypeName(a^.ntype);
                  writeln
                end;
              a := a^.next
            end
          end
        end
      end
      { 6.7.6.5 and 6.7.6.6: empty, position and LastPosition take a file
        variable and nothing else -- no default, unlike eof, because there is
        no standard direct-access file to default to. }
      else if IsFileEnquiry(c^.clBuiltin) then begin
        if c^.clBuiltin = biEmpty then c^.ntype := boolType
        else c^.ntype := intType;
        if n <> 1 then begin
          ErrorAt(c^.line, c^.col);
          write('''');
          WritePool(c^.clAt, c^.clLen);
          writeln(''' takes exactly one file variable')
        end
        else begin
          a := c^.clArgs;
          if not IsDesignator(a) or
             ((a^.ntype <> nil) and not IsFile(a^.ntype)) then begin
            ErrorAt(a^.line, a^.col);
            write('''');
            WritePool(c^.clAt, c^.clLen);
            write(''' needs a file variable');
            if a^.ntype <> nil then begin
              write(', found ');
              WriteTypeName(a^.ntype)
            end;
            writeln
          end
          else if (a^.ntype <> nil) and (a^.ntype^.indexType = nil) then begin
            ErrorAt(a^.line, a^.col);
            write('''');
            WritePool(c^.clAt, c^.clLen);
            write(''' needs a direct-access file, and ');
            WriteTypeName(a^.ntype);
            writeln(' has no index type')
          end
          { 6.7.6.6: "shall return a result of type T" -- the *index* type, not
            an integer. That is the whole reason the index-type is kept on the
            type. }
          else if (a^.ntype <> nil) and (c^.clBuiltin <> biEmpty) then
            c^.ntype := a^.ntype^.indexType
        end
      end
      else if (c^.clBuiltin = biEof) or (c^.clBuiltin = biEoln) then begin
        c^.ntype := boolType;
        if n = 0 then begin
          def := StandardFileRef(true, c^.line, c^.col);
          if def <> nil then c^.clArgs := def
        end
        else if n <> 1 then begin
          ErrorAt(c^.line, c^.col);
          write('''');
          WritePool(c^.clAt, c^.clLen);
          writeln(''' takes one file, or none at all')
        end
        else begin
          a := c^.clArgs;
          if not IsDesignator(a) or
             ((a^.ntype <> nil) and not IsFile(a^.ntype)) then begin
            ErrorAt(a^.line, a^.col);
            write('''');
            WritePool(c^.clAt, c^.clLen);
            write(''' needs a file variable');
            if a^.ntype <> nil then begin
              write(', found ');
              WriteTypeName(a^.ntype)
            end;
            writeln
          end
          { `eof` asks a question every file can answer; `eoln` asks about a
            line, and only a text file has those (6.6.6.5). }
          else if (c^.clBuiltin = biEoln) and (a^.ntype <> nil) and
                  not IsTextFile(a^.ntype) then begin
            ErrorAt(a^.line, a^.col);
            write('''eoln'' needs a text file, but ');
            WriteTypeName(a^.ntype);
            writeln(' has no lines')
          end
        end
      end
      { 6.7.6.3: cmplx(x, y) and polar(r, t) are the two-argument required
        functions, and the only way to write a complex value at all -- the
        standard gives the type no literal. }
      else if (c^.clBuiltin = biCmplx) or (c^.clBuiltin = biPolar) then begin
        c^.ntype := complexType;
        if n <> 2 then begin
          ErrorAt(c^.line, c^.col);
          write('''');
          WritePool(c^.clAt, c^.clLen);
          writeln(''' takes two real arguments')
        end
        else begin
          a := c^.clArgs;
          while a <> nil do begin
            if a^.ntype <> nil then
              if not IsNumeric(a^.ntype) then begin
                ErrorAt(a^.line, a^.col);
                write('''');
                WritePool(c^.clAt, c^.clLen);
                write(''' needs real arguments, found ');
                WriteTypeName(a^.ntype);
                writeln
              end;
            a := a^.next
          end
        end
      end
      else if n <> 1 then begin
        ErrorAt(c^.line, c^.col);
        write('''');
        WritePool(c^.clAt, c^.clLen);
        writeln(''' takes exactly one argument');
        c^.ntype := intType
      end
      else begin
        t := c^.clArgs^.ntype;
        case c^.clBuiltin of
          { 6.7.6.2, table 2 footnote 5: `abs` of a complex is its *magnitude*,
            and so a real -- the one function in the table whose result kind
            changes rather than following its operand. `sqr` keeps its
            operand's type, complex included. }
          biAbs: begin
            RequireArg(c, IsArith(t), 'a numeric   ', t);
            if IsComplex(t) or IsReal(t) then c^.ntype := realType
            else c^.ntype := intType
          end;
          biSqr: begin
            RequireArg(c, IsArith(t), 'a numeric   ', t);
            if IsComplex(t) then c^.ntype := complexType
            else if IsReal(t) then c^.ntype := realType
            else c^.ntype := intType
          end;
          { 6.7.6.2: re, im and arg take a complex and yield a real. }
          biRe, biIm, biArg: begin
            RequireArg(c, IsComplex(t), 'a complex   ', t);
            c^.ntype := realType
          end;
          biOdd: begin
            RequireArg(c, IsInteger(t), 'an integer  ', t);
            c^.ntype := boolType
          end;
          biOrd: begin
            RequireArg(c, IsOrdinal(t), 'an ordinal  ', t);
            c^.ntype := intType
          end;
          biChr: begin
            RequireArg(c, IsInteger(t), 'an integer  ', t);
            c^.ntype := charType
          end;
          { ISO 7185 6.6.6.4 defines succ over any ordinal type and gives the
            result that same type, so succ runs out at the end of *this* type
            -- at `blue` for an enumeration, at 9 for a subrange 1..9. }
          biSucc, biPred: begin
            RequireArg(c, IsOrdinal(t), 'an ordinal  ', t);
            c^.ntype := t
          end;
          biTrunc, biRound: begin
            RequireArg(c, IsNumeric(t), 'a real      ', t);
            c^.ntype := intType
          end;
          { 6.7.6.2: sin cos exp ln sqrt arctan take an integer, a real or a
            complex, and the result is "real if the operand is of integer-type,
            otherwise the type of the operand" -- so a complex operand gives a
            complex result and everything else gives a real. }
          biNone, biSqrt, biSin, biCos, biLn, biExp, biArcTan, biEof,
          biEoln, biCmplx, biPolar, biPosition, biLastPosition, biEmpty:
          begin
            RequireArg(c, IsArith(t), 'a numeric   ', t);
            if IsComplex(t) then c^.ntype := complexType
            else c^.ntype := realType
          end
        end
      end
    end
  end
end;

procedure CheckExpr;
var t, b: typePtr; f: fieldPtr; binding: symPtr;
    p, ds: symListPtr; tv: numPtr; found: boolean;
begin
  if e <> nil then
    case e^.kind of
      nkInt:  e^.ntype := intType;
      nkReal: e^.ntype := realType;
      nkChar: e^.ntype := charType;
      nkNil:  e^.ntype := nilType;
      nkSet:  CheckSetExpr(e);

      { ISO 7185 6.4.3.2: a string literal *is* a packed array of char. Giving
        it that type rather than one of its own is what makes assignment,
        comparison and parameter passing work with no special cases. }
      { ISO/IEC 10206:1991 6.1.9 spells a character-string with *zero or more*
        string-elements, so `''` denotes the null-string 6.4.3.3.1 names.
        ISO 7185's grammar has one element before the repetition, which is why
        the two languages differ over two apostrophes and nothing else. }
      nkStr:
        if e^.stLen = 0 then begin
          if langStd = stdIso7185 then begin
            ErrorAt(e^.line, e^.col);
            writeln('a string literal cannot be empty');
            e^.ntype := StringType(1)
          end
          else
            e^.ntype := canonStringType
        end
        else
          e^.ntype := StringType(e^.stLen);

      nkIndex: begin
        CheckExpr(e^.ixBase);
        CheckExpr(e^.ixIndex);
        b := e^.ixBase^.ntype;
        { 6.4.3.3.3 NOTE 1: a variable-string is indexed as an array, and every
          component is a char. 6.5.3.2 makes the subscript an *integer* -- not
          a value of an index type, because a string's index-domain is
          1..length and no type names it. }
        if IsVarString(b) then begin
          if e^.ixIndex^.ntype <> nil then
            if not IsInteger(e^.ixIndex^.ntype) then begin
              ErrorAt(e^.ixIndex^.line, e^.ixIndex^.col);
              write('a string is indexed by an integer, but the subscript ',
                    'is ');
              WriteTypeName(e^.ixIndex^.ntype);
              writeln
            end;
          e^.ntype := charType
        end
        else if not IsArray(b) then begin
          if b <> nil then begin
            ErrorAt(e^.line, e^.col);
            write('cannot subscript a value of type ');
            WriteTypeName(b);
            writeln
          end;
          e^.ntype := intType
        end
        else begin
          if (e^.ixIndex^.ntype <> nil) and
             not Assignable(b^.indexType, e^.ixIndex^.ntype) then begin
            ErrorAt(e^.ixIndex^.line, e^.ixIndex^.col);
            write('this array is indexed by ');
            WriteTypeName(b^.indexType);
            write(', but the subscript is ');
            WriteTypeName(e^.ixIndex^.ntype);
            writeln
          end;
          e^.ntype := b^.elem
        end
      end;

      nkDeref: begin
        CheckExpr(e^.drBase);
        b := e^.drBase^.ntype;
        { `f^` on a file is the buffer variable (ISO 7185 6.5.5), not a
          dereference: one component of the file, which for a text file is the
          character it is positioned at. The syntax is shared, so this is the
          one place the two meanings part. }
        if IsFile(b) then begin
          if b^.elem <> nil then e^.ntype := b^.elem else e^.ntype := charType
        end
        else if not IsPointer(b) or IsNil(b) then begin
          if b <> nil then begin
            ErrorAt(e^.line, e^.col);
            write('only a pointer can be dereferenced, found ');
            WriteTypeName(b);
            writeln
          end;
          e^.ntype := intType
        end
        else
          e^.ntype := b^.elem
      end;

      nkField: begin
        CheckExpr(e^.fdBase);
        b := e^.fdBase^.ntype;
        { 6.8.4: `v.d` where v possesses a type produced from a schema and d
          is one of that schema's formal discriminants. Looked for before the
          fields, because a record produced from a schema has both and the
          discriminant is not one of them -- the name is in no scope, and this
          is the only place it can be written. }
        found := false;
        if (b <> nil) and (b^.schema <> nil) then begin
          { A schematic formal parameter has no tuple: its discriminants are in
            the descriptor the actual brought, and the parameter is what says
            which descriptor. Everything else has folded them already. }
          { A heap variable's tuple travels with the variable, so the symbol
            holding its discriminants is on the *type* -- there is no name to
            ask, since `p^` is not one. }
          if b^.heapTuple then
            ds := b^.descOwner^.discSyms
          else if IsGeneric(b) and (e^.fdBase^.kind = nkVar) then
            ds := e^.fdBase^.vrSym^.discSyms
          else
            ds := nil;
          p := b^.schema^.discs;
          tv := b^.tuple;
          while (p <> nil) and not found do begin
            if PoolSame(p^.sym^.at, p^.sym^.len, e^.fdAt, e^.fdLen) then
              if IsGeneric(b) then begin
                if ds <> nil then begin
                  found := true;
                  e^.fdIsDisc := true;
                  e^.fdDiscSym := ds^.sym;
                  e^.ntype := p^.sym^.stype
                end;
                p := nil
              end
              else if tv <> nil then begin
                found := true;
                e^.fdIsDisc := true;
                e^.fdDiscValue := tv^.value;
                e^.ntype := p^.sym^.stype
              end;
            if p <> nil then begin
              p := p^.next;
              if tv <> nil then tv := tv^.next;
              if ds <> nil then ds := ds^.next
            end
          end
        end;
        if found then
          { the discriminant answered, and e^.ntype is already set }
        else
        if not IsRecord(b) then begin
          if (b <> nil) and (b^.schema <> nil) then begin
            { The dot after a schematic variable may select a field or a
              discriminant, so saying only that the type has no fields would
              describe the wrong half of what was tried. }
            ErrorAt(e^.line, e^.col);
            write('''');
            WritePool(e^.fdAt, e^.fdLen);
            write(''' is not a discriminant of schema ''');
            WritePool(b^.schema^.at, b^.schema^.len);
            writeln('''')
          end
          else if b <> nil then begin
            ErrorAt(e^.line, e^.col);
            write('cannot select a field of a value of type ');
            WriteTypeName(b);
            writeln
          end;
          e^.ntype := intType
        end
        else begin
          f := FindField(b, e^.fdAt, e^.fdLen);
          if f = nil then begin
            ErrorAt(e^.line, e^.col);
            write('''');
            WritePool(e^.fdAt, e^.fdLen);
            write(''' is not a field of ');
            WriteTypeName(b);
            writeln;
            e^.ntype := intType
          end
          else begin
            e^.fdResolved := f;
            e^.ntype := f^.ftype
          end
        end
      end;

      nkVar: begin
        { A `with` scope is inside every enclosing one, so its fields win. }
        binding := LookupWithField(e^.vrAt, e^.vrLen, e^.vrField);
        if binding <> nil then begin
          e^.vrSym := binding;
          e^.ntype := e^.vrField^.ftype
        end
        else begin
          e^.vrSym := Lookup(e^.vrAt, e^.vrLen);
          if e^.vrSym = nil then begin
            ErrorAt(e^.line, e^.col);
            write('undeclared identifier ''');
            WritePool(e^.vrAt, e^.vrLen);
            writeln('''');
            e^.ntype := intType
          end
          { 6.2.3.2 evaluates a variable's actual-discriminant-part when the
            block is entered, which is before that variable has a size or a
            value -- so it cannot be one of the discriminants that decide
            them. Its name is in scope by then, which is exactly why this has
            to be said. }
          else if (dynamicVarFor <> nil) and (e^.vrSym = dynamicVarFor) then
          begin
            ErrorAt(e^.line, e^.col);
            write('''');
            WritePool(e^.vrAt, e^.vrLen);
            writeln(''' cannot be one of its own discriminants');
            e^.ntype := intType
          end
          else if IsInvocable(e^.vrSym) and
                  (ResultTypeOf(e^.vrSym) = nil) then begin
            ErrorAt(e^.line, e^.col);
            write('''');
            WritePool(e^.vrAt, e^.vrLen);
            writeln(''' is a procedure and has no value');
            e^.ntype := intType
          end
          else if e^.vrSym^.kind = skType then begin
            ErrorAt(e^.line, e^.col);
            write('''');
            WritePool(e^.vrAt, e^.vrLen);
            writeln(''' is a type and has no value');
            e^.ntype := intType
          end
          { A function name used as a value is a call with no arguments --
            Pascal has no empty argument list, and inside the function's own
            body this is the recursive call rather than a way to read the
            result (ISO 7185 6.8.2.2). }
          else if IsInvocable(e^.vrSym) and (e^.vrSym^.params = nil) then
            e^.ntype := ResultTypeOf(e^.vrSym)
          else if IsInvocable(e^.vrSym) then begin
            ErrorAt(e^.line, e^.col);
            write('''');
            WritePool(e^.vrAt, e^.vrLen);
            writeln(''' needs arguments')
          end
          else
            e^.ntype := e^.vrSym^.stype
        end
      end;

      nkUnary: begin
        CheckExpr(e^.unArg);
        t := e^.unArg^.ntype;
        if e^.unOp = opNot then begin
          if (t <> nil) and not IsBoolean(t) then begin
            ErrorAt(e^.line, e^.col);
            write('''not'' needs a boolean operand, found ');
            WriteTypeName(t);
            writeln
          end;
          e^.ntype := boolType
        end
        else begin
          if (t <> nil) and not IsNumeric(t) then begin
            ErrorAt(e^.line, e^.col);
            write('unary sign needs a numeric operand, found ');
            WriteTypeName(t);
            writeln
          end;
          if IsReal(t) then e^.ntype := realType else e^.ntype := intType
        end
      end;

      nkBinary: CheckBinary(e);
      nkCall:   CheckCall(e);

      nkSetMember,
      nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
      nkFor, nkProcCall, nkWith, nkCase, nkWriteArg, nkCaseArm, nkVariantArm,
      nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord,
      nkPointer, nkFile, nkSetOf, nkSchema, nkInquiry, nkConstDecl, nkTypeDecl,
      nkProcDecl, nkBlock:
        { not an expression }
    end
end;

{ -------------------------------------------------------------- statements }

{ ISO 7185 6.9.3 lets the first argument be a file variable, which says where
  to write rather than what to write; without one the file is `output`. A width
  never follows a file, so the leading argument is a file exactly when it has a
  file type and no width -- and if a program does write `f:8`, the file falls
  through to the value list and is rejected there as unwritable. }
procedure CheckWrite(w: nodePtr);
var a: nodePtr; t, wf: typePtr;
begin
  a := w^.wrArgs;
  while a <> nil do begin
    CheckExpr(a^.waValue);
    if a^.waWidth <> nil then CheckExpr(a^.waWidth);
    if a^.waPrec <> nil then CheckExpr(a^.waPrec);
    a := a^.next
  end;

  if (w^.wrArgs <> nil) and (w^.wrArgs^.waWidth = nil) and
     IsFile(w^.wrArgs^.waValue^.ntype) then begin
    if not IsDesignator(w^.wrArgs^.waValue) then begin
      ErrorAt(w^.wrArgs^.waValue^.line, w^.wrArgs^.waValue^.col);
      writeln('the file written to must be a variable')
    end;
    w^.wrFile := w^.wrArgs^.waValue;
    w^.wrArgs := w^.wrArgs^.next
  end
  else
    w^.wrFile := StandardFileRef(false, w^.line, w^.col);

  if (w^.wrArgs = nil) and not w^.wrNewline then begin
    ErrorAt(w^.line, w^.col);
    writeln('write needs something to write')
  end;

  { 6.9.3 is the *text* form of write, and everything it says -- the field
    width, the external representation of a number, the line `writeln`
    finishes -- belongs to a text file. On any other file 6.6.5.2's definition
    applies instead: `write(f, e)` is `f^ := e; put(f)`, one component of the
    file's own type and nothing to format. }
  wf := nil;
  if w^.wrFile <> nil then wf := w^.wrFile^.ntype;
  if (wf <> nil) and not IsTextFile(wf) then begin
    if w^.wrNewline then begin
      ErrorAt(w^.line, w^.col);
      write('writeln needs a text file, but ');
      WriteTypeName(wf);
      writeln(' has no lines')
    end;
    a := w^.wrArgs;
    while a <> nil do begin
      if a^.waWidth <> nil then begin
        ErrorAt(a^.waWidth^.line, a^.waWidth^.col);
        writeln('a field width is only for a text file')
      end;
      if not Assignable(wf^.elem, a^.waValue^.ntype) then begin
        ErrorAt(a^.waValue^.line, a^.waValue^.col);
        write('a value of type ');
        WriteTypeName(a^.waValue^.ntype);
        write(' cannot be written to a ');
        WriteTypeName(wf);
        writeln
      end;
      a := a^.next
    end
  end
  else begin
  a := w^.wrArgs;
  while a <> nil do begin
    t := a^.waValue^.ntype;
    { ISO 7185 6.9.3 lists exactly what write accepts: an integer, a real, a
      boolean, a char, or a packed array of char. An enumeration is not on the
      list -- the standard gives no spelling for its constants at run time --
      and neither is any other structured type. ISO/IEC 10206:1991 6.10.3.1
      has the same list with "a string-type" in place of the packed char
      array, so a variable-string and a canonical value join it. }
    if (t <> nil) and not (IsInteger(t) or IsReal(t) or IsBoolean(t) or
                           IsChar(t) or IsStringType(t)) then begin
      ErrorAt(a^.waValue^.line, a^.waValue^.col);
      write('a value of type ');
      WriteTypeName(t);
      writeln(' cannot be written')
    end;
    if a^.waWidth <> nil then
      if (a^.waWidth^.ntype <> nil) and not IsInteger(a^.waWidth^.ntype) then
      begin
        ErrorAt(a^.waWidth^.line, a^.waWidth^.col);
        writeln('a field width must be an integer')
      end;
    if a^.waPrec <> nil then begin
      if (a^.waPrec^.ntype <> nil) and not IsInteger(a^.waPrec^.ntype) then
      begin
        ErrorAt(a^.waPrec^.line, a^.waPrec^.col);
        writeln('a fraction length must be an integer')
      end;
      if (t <> nil) and not IsReal(t) then begin
        ErrorAt(a^.waPrec^.line, a^.waPrec^.col);
        writeln('only real values take a fraction length')
      end
    end;
    a := a^.next
  end
  end
end;

{ ISO 7185 6.9.1. Like write, the first argument may be the file; every other
  one is a *variable* to store into, so each has to be a designator. }
procedure CheckRead(r: nodePtr);
var a: nodePtr; t, rf: typePtr; text: boolean;
begin
  a := r^.rdArgs;
  while a <> nil do begin
    CheckExpr(a);
    a := a^.next
  end;

  if (r^.rdArgs <> nil) and IsFile(r^.rdArgs^.ntype) then begin
    if not IsDesignator(r^.rdArgs) then begin
      ErrorAt(r^.rdArgs^.line, r^.rdArgs^.col);
      writeln('the file read from must be a variable')
    end;
    r^.rdFile := r^.rdArgs;
    r^.rdArgs := r^.rdArgs^.next;
    r^.rdFile^.next := nil
  end
  else
    r^.rdFile := StandardFileRef(true, r^.line, r^.col);

  { `read` must be given somewhere to put what it reads; `readln` may be
    written alone, and then it only finishes the line. }
  if (r^.rdArgs = nil) and not r^.rdNewline then begin
    ErrorAt(r^.line, r^.col);
    writeln('read needs a variable to read into')
  end;

  { The counterpart of write's split: on a file that is not a text, 6.6.5.2
    makes `read(f, v)` mean `v := f^; get(f)`, so the variable takes the file's
    component type and there is no external representation to parse. }
  rf := nil;
  if r^.rdFile <> nil then rf := r^.rdFile^.ntype;
  text := (rf = nil) or IsTextFile(rf);
  if not text and r^.rdNewline then begin
    ErrorAt(r^.line, r^.col);
    write('readln needs a text file, but ');
    WriteTypeName(rf);
    writeln(' has no lines')
  end;

  a := r^.rdArgs;
  while a <> nil do begin
    if not IsDesignator(a) then begin
      ErrorAt(a^.line, a^.col);
      writeln('read needs a variable, not a value')
    end
    { 6.9.4 c): read and readln threaten every variable they read into. }
    else if Threatened(a) then
      writeln('it cannot be read into')
    else if not text then begin
      if not Assignable(a^.ntype, rf^.elem) then begin
        ErrorAt(a^.line, a^.col);
        write('a variable of type ');
        WriteTypeName(a^.ntype);
        write(' cannot be read from a ');
        WriteTypeName(rf);
        writeln
      end
    end
    else begin
      t := a^.ntype;
      if (t <> nil) and not (IsInteger(t) or IsReal(t) or IsChar(t)) then begin
        ErrorAt(a^.line, a^.col);
        write('a value of type ');
        WriteTypeName(t);
        writeln(' cannot be read')
      end
    end;
    a := a^.next
  end
end;

{ `new(p)` and `dispose(p)` bind a pointer variable to fresh storage and give
  it back. Both take the pointer itself -- not what it points at -- so the
  argument has to be a variable. The file primitives are here too: ISO 7185
  6.6.5.2 defines read and write in terms of get, put and the buffer variable,
  and this compiler keeps them rather than providing only the derived forms. }
{ 10206 6.7.5.3's tuple form of `new`: the arguments are the discriminants the
  created variable's type is produced with. Unlike 6.4.8's
  actual-discriminant-part these need not be constants -- the tuple is chosen
  when `new` runs, which is the whole reason the header exists. }
procedure CheckNewTuple(p: nodePtr; domain: typePtr; n: integer);
var d: symListPtr; value: nodePtr; count: integer;
begin
  if p^.pcStd = spDispose then begin
    ErrorAt(p^.pcArgs^.next^.line, p^.pcArgs^.next^.col);
    writeln('''dispose'' takes no discriminants: they belong to the ',
            'variable, which already has them')
  end
  else begin
    count := 0;
    d := domain^.schema^.discs;
    while d <> nil do begin
      count := count + 1;
      d := d^.next
    end;
    if n - 1 <> count then begin
      ErrorAt(p^.pcArgs^.next^.line, p^.pcArgs^.next^.col);
      write('schema ''');
      WritePool(domain^.schema^.at, domain^.schema^.len);
      write(''' has ', count:1, ' discriminant');
      if count <> 1 then write('s');
      writeln(', found ', n - 1:1)
    end
    else begin
      { 6.7.5.3: the type of each expression shall be compatible with the type
        of the corresponding formal discriminant. }
      d := domain^.schema^.discs;
      value := p^.pcArgs^.next;
      while (d <> nil) and (value <> nil) do begin
        if (value^.ntype = nil) or not Assignable(d^.sym^.stype, value^.ntype)
        then begin
          ErrorAt(value^.line, value^.col);
          write('discriminant ''');
          WritePool(d^.sym^.at, d^.sym^.len);
          write(''' of schema ''');
          WritePool(domain^.schema^.at, domain^.schema^.len);
          write(''' is ');
          WriteTypeName(d^.sym^.stype);
          write(', but the value is ');
          if value^.ntype = nil then write('untyped')
          else WriteTypeName(value^.ntype);
          writeln
        end;
        d := d^.next;
        value := value^.next
      end
    end
  end
end;

{ ISO/IEC 10206:1991 6.7.5.2's five. They are required *identifiers* like the
  complex functions, not word-symbols, so a valid ISO 7185 program may declare
  a procedure called `update` -- which is why they are recognised only under
  the standard that has them and only when no declaration was found. }
function IsDirectAccessProc(at, len: integer): boolean;
begin
  IsDirectAccessProc := PoolIsWide(at, len, 'bind            ') or
                        PoolIsWide(at, len, 'unbind          ') or
                        PoolIsWide(at, len, 'seekread        ') or
                        PoolIsWide(at, len, 'seekwrite       ') or
                        PoolIsWide(at, len, 'seekupdate      ') or
                        PoolIsWide(at, len, 'update          ') or
                        PoolIsWide(at, len, 'extend          ')
end;

procedure CheckStdProc(p: nodePtr);
var
  a, value: nodePtr;
  n, v, k, chosen: integer;
  domain, tag, valueType: typePtr;
  arms, w: variantPtr;
  lbl: rangePtr;
  want: integer;
  root: nodePtr;
  stop, discSel, seeks: boolean;
begin
  if PoolIs(p^.pcAt, p^.pcLen, 'reset    ') then p^.pcStd := spReset
  else if PoolIs(p^.pcAt, p^.pcLen, 'rewrite  ') then p^.pcStd := spRewrite
  else if PoolIs(p^.pcAt, p^.pcLen, 'get      ') then p^.pcStd := spGet
  else if PoolIs(p^.pcAt, p^.pcLen, 'put      ') then p^.pcStd := spPut
  else if PoolIsWide(p^.pcAt, p^.pcLen, 'seekread        ') then
    p^.pcStd := spSeekRead
  else if PoolIsWide(p^.pcAt, p^.pcLen, 'seekwrite       ') then
    p^.pcStd := spSeekWrite
  else if PoolIsWide(p^.pcAt, p^.pcLen, 'seekupdate      ') then
    p^.pcStd := spSeekUpdate
  else if PoolIsWide(p^.pcAt, p^.pcLen, 'update          ') then
    p^.pcStd := spUpdate
  else if PoolIsWide(p^.pcAt, p^.pcLen, 'extend          ') then
    p^.pcStd := spExtend
  else if PoolIsWide(p^.pcAt, p^.pcLen, 'bind            ') then
    p^.pcStd := spBind
  else if PoolIsWide(p^.pcAt, p^.pcLen, 'unbind          ') then
    p^.pcStd := spUnbind
  else if PoolIs(p^.pcAt, p^.pcLen, 'new      ') then p^.pcStd := spNew
  else p^.pcStd := spDispose;

  a := p^.pcArgs;
  while a <> nil do begin
    CheckExpr(a);
    a := a^.next
  end;
  n := 0;
  a := p^.pcArgs;
  while a <> nil do begin
    n := n + 1;
    a := a^.next
  end;

  { 6.7.5.2: SeekRead(f, n), SeekWrite(f, n) and SeekUpdate(f, n) take a
    direct-access file and a position; update(f) and extend(f) take a file
    alone. Only extend works on a sequential one. }
  { 6.7.5.6: bind(f, b) takes a variable-access and a BindingType value;
    unbind(f) takes the variable alone. Both are dynamic-violations on a file
    variable that is not `bindable`, and this compiler restricts them to file
    variables -- the only external entity it has a meaning for. }
  if (p^.pcStd = spBind) or (p^.pcStd = spUnbind) then begin
    if p^.pcStd = spBind then want := 2 else want := 1;
    if n <> want then begin
      ErrorAt(p^.line, p^.col);
      write('''');
      WritePool(p^.pcAt, p^.pcLen);
      write(''' takes a bindable variable');
      if want = 2 then writeln(' and a BindingType value') else writeln
    end
    else begin
      a := p^.pcArgs;
      if not IsDesignator(a) or
         ((a^.ntype <> nil) and not IsFile(a^.ntype)) then begin
        ErrorAt(a^.line, a^.col);
        write('''');
        WritePool(p^.pcAt, p^.pcLen);
        write(''' needs a file variable');
        if a^.ntype <> nil then begin
          write(', found ');
          WriteTypeName(a^.ntype)
        end;
        writeln
      end
      else begin
        root := RootDesignator(a);
        if root <> nil then
          if root^.kind = nkVar then
            if root^.vrSym <> nil then
              if not root^.vrSym^.isBindable then begin
                ErrorAt(a^.line, a^.col);
                write('''');
                WritePool(root^.vrSym^.at, root^.vrSym^.len);
                writeln(''' is not bindable; only a variable of a bindable ',
                        'type can be bound to something outside the program')
              end;
        if p^.pcStd = spBind then
          if a^.next^.ntype <> nil then
            if a^.next^.ntype <> bindingType then begin
              ErrorAt(a^.next^.line, a^.next^.col);
              write('the second argument of ''bind'' is a BindingType, ',
                    'found ');
              WriteTypeName(a^.next^.ntype);
              writeln
            end
      end
    end
  end
  else if (p^.pcStd = spSeekRead) or (p^.pcStd = spSeekWrite) or
     (p^.pcStd = spSeekUpdate) or (p^.pcStd = spUpdate) or
     (p^.pcStd = spExtend) then begin
    seeks := (p^.pcStd = spSeekRead) or (p^.pcStd = spSeekWrite) or
             (p^.pcStd = spSeekUpdate);
    if seeks then want := 2 else want := 1;
    if n <> want then begin
      ErrorAt(p^.line, p^.col);
      write('''');
      WritePool(p^.pcAt, p^.pcLen);
      write(''' takes a file variable');
      if seeks then writeln(' and a position') else writeln
    end
    else begin
      a := p^.pcArgs;
      if not IsDesignator(a) or
         ((a^.ntype <> nil) and not IsFile(a^.ntype)) then begin
        ErrorAt(a^.line, a^.col);
        write('''');
        WritePool(p^.pcAt, p^.pcLen);
        write(''' needs a file variable');
        if a^.ntype <> nil then begin
          write(', found ');
          WriteTypeName(a^.ntype)
        end;
        writeln
      end
      { 6.4.3.6 gives only a file-type with an index-type a position at all,
        and `text` never has one. `extend` is the exception: appending is a
        sequential operation and 6.7.5.2 asks nothing of the file-type. }
      else if (p^.pcStd <> spExtend) and (a^.ntype <> nil) and
              (a^.ntype^.indexType = nil) then begin
        ErrorAt(a^.line, a^.col);
        write('''');
        WritePool(p^.pcAt, p^.pcLen);
        write(''' needs a direct-access file, and ');
        WriteTypeName(a^.ntype);
        writeln(' has no index type')
      end
      else if seeks then
        if (a^.next^.ntype <> nil) and (a^.ntype <> nil) then
          if not Assignable(a^.ntype^.indexType, a^.next^.ntype) then begin
            ErrorAt(a^.next^.line, a^.next^.col);
            write('the position must be a value of the index type ');
            WriteTypeName(a^.ntype^.indexType);
            write(', found ');
            WriteTypeName(a^.next^.ntype);
            writeln
          end
    end
  end
  else if (p^.pcStd = spReset) or (p^.pcStd = spRewrite) or
          (p^.pcStd = spGet) or (p^.pcStd = spPut) then begin
    if n <> 1 then begin
      ErrorAt(p^.line, p^.col);
      write('''');
      WritePool(p^.pcAt, p^.pcLen);
      writeln(''' takes exactly one file variable')
    end
    else begin
      a := p^.pcArgs;
      if not IsDesignator(a) or
         ((a^.ntype <> nil) and not IsFile(a^.ntype)) then begin
        ErrorAt(a^.line, a^.col);
        write('''');
        WritePool(p^.pcAt, p^.pcLen);
        write(''' needs a file variable');
        if a^.ntype <> nil then begin
          write(', found ');
          WriteTypeName(a^.ntype)
        end;
        writeln
      end
    end
  end
  else if n = 0 then begin
    ErrorAt(p^.line, p^.col);
    write('''');
    WritePool(p^.pcAt, p^.pcLen);
    writeln(''' needs a pointer variable')
  end
  else begin
    a := p^.pcArgs;
    if not IsDesignator(a) then begin
      ErrorAt(a^.line, a^.col);
      write('''');
      WritePool(p^.pcAt, p^.pcLen);
      writeln(''' needs a pointer variable')
    end
    else if (a^.ntype <> nil) and (not IsPointer(a^.ntype) or
                                   IsNil(a^.ntype)) then begin
      ErrorAt(a^.line, a^.col);
      write('''');
      WritePool(p^.pcAt, p^.pcLen);
      write(''' needs a pointer variable, found ');
      WriteTypeName(a^.ntype);
      writeln
    end
    { 6.7.5.3's `new(p)` gives the created variable the domain type, and a
      schema domain has no type until a tuple names one. `dispose(q)` is the
      opposite: the variable it removes already has its tuple. }
    else if (n = 1) and (p^.pcStd = spNew) and (a^.ntype <> nil) and
            (a^.ntype^.elem <> nil) and a^.ntype^.elem^.heapTuple then begin
      ErrorAt(p^.line, p^.col);
      write('''new'' needs the discriminants of schema ''');
      WritePool(a^.ntype^.elem^.schema^.at, a^.ntype^.elem^.schema^.len);
      writeln(''' here, as new(p, ...): a schema denotes a type only once ',
              'its discriminants are given')
    end
    { ISO 7185 6.6.5.3: `new(p, c1, ..., cn)` creates a variable with the
      variants those tag values select, one value per nested variant part,
      outermost first. `dispose` takes the same list. }
    else if n > 1 then begin
      if a^.ntype = nil then domain := nil else domain := a^.ntype^.elem;
      { 10206 6.7.5.3 gives `new(p, d1, ..., ds)` a second meaning: where the
        domain-type is a schema-name, the arguments are the *tuple* the
        created variable's type is produced with, not tag values selecting
        variants. The two forms are told apart by the domain and by nothing
        else -- a record with a variant part takes the first, a schema domain
        the second. }
      if (domain <> nil) and domain^.heapTuple then
        CheckNewTuple(p, domain, n)
      else if not IsRecord(domain) then begin
        ErrorAt(a^.next^.line, a^.next^.col);
        writeln('tag values are only for a pointer to a record with a ',
                'variant part')
      end
      else begin
        arms := domain^.variants;
        tag := domain^.tagType;
        discSel := domain^.discSelector;
        value := a^.next;
        stop := false;
        while (value <> nil) and not stop do begin
          { 6.7.5.3: every variant-part a tag value selects "shall
            closest-contain a tag-type". A discriminant-selected one does not
            -- its selector was fixed by the tuple the type was produced with,
            and this list would be a second, disagreeing answer. }
          if discSel then begin
            ErrorAt(value^.line, value^.col);
            writeln('this variant part is selected by a discriminant, so its ',
                    'variant was chosen when the type was produced');
            stop := true
          end
          else if arms = nil then begin
            ErrorAt(value^.line, value^.col);
            if value = a^.next then
              writeln('this record has no variant part')
            else
              writeln('this record has no more nested variant parts to ',
                      'select');
            stop := true
          end
          else begin
            valueType := nil;
            v := 0;
            if not EvalOrdinal(value, valueType, v) then begin
              ErrorAt(value^.line, value^.col);
              write('a tag value for ''');
              WritePool(p^.pcAt, p^.pcLen);
              writeln(''' must be an ordinal constant');
              stop := true
            end
            else if (tag <> nil) and (valueType <> nil) and
                    (Base(valueType) <> Base(tag)) then begin
              ErrorAt(value^.line, value^.col);
              write('this variant part''s tag is ');
              WriteTypeName(tag);
              write(', but the value is ');
              WriteTypeName(valueType);
              writeln;
              stop := true
            end
            else begin
              chosen := -1;
              k := 0;
              w := arms;
              while w <> nil do begin
                lbl := w^.labels;
                while lbl <> nil do begin
                  if (lbl^.lo <= v) and (v <= lbl^.hi) and (chosen < 0) then
                    chosen := k;
                  lbl := lbl^.next
                end;
                k := k + 1;
                w := w^.next
              end;
              { An otherwise-arm is what every unclaimed value selects, so it
                answers here too -- the value is a value of the tag type, and
                that is all the completer asks of it. }
              k := 0;
              w := arms;
              while w <> nil do begin
                if w^.isOtherwise and (chosen < 0) then chosen := k;
                k := k + 1;
                w := w^.next
              end;
              if chosen < 0 then begin
                ErrorAt(value^.line, value^.col);
                write('no variant is selected by ');
                WriteOrdinalName(tag, v);
                writeln;
                stop := true
              end
              else begin
                p^.pcSelect := PathAppend(p^.pcSelect, chosen);
                w := ArmAtIn(arms, chosen);
                tag := w^.tagType;
                discSel := w^.discSelector;
                arms := w^.variants
              end
            end
          end;
          if not stop then value := value^.next
        end
      end
    end
  end
end;

procedure CheckCase(c: nodePtr);
var
  sel, labelType, named: typePtr;
  arm, label_: nodePtr;
  saved: stmtPathPtr;
  seenHead, seenTail, r: rangePtr;
  lo, hi, at: integer;
  seen: boolean;
begin
  CheckExpr(c^.csSelector);
  { The otherwise-part is a statement-sequence like any other; nothing about it
    depends on the selector, because it is what runs when *no* label does. }
  arm := c^.csOtherwise;
  while arm <> nil do begin
    CheckStmt(arm);
    arm := arm^.next
  end;
  sel := c^.csSelector^.ntype;
  if (sel <> nil) and not IsOrdinal(sel) then begin
    ErrorAt(c^.csSelector^.line, c^.csSelector^.col);
    write('the selector of a case statement must be an ordinal type, found ');
    WriteTypeName(sel);
    writeln;
    sel := nil
  end;

  seenHead := nil;
  seenTail := nil;
  arm := c^.csArms;
  while arm <> nil do begin
    label_ := arm^.caLabels;
    while label_ <> nil do begin
      labelType := nil;
      at := 0;
      if not EvalLabelRange(label_, true, labelType, lo, hi) then begin
        { the diagnostic is EvalLabelRange's; nothing more to say here }
      end
      else if (sel <> nil) and not Assignable(sel, labelType) then begin
        ErrorAt(label_^.smLo^.line, label_^.smLo^.col);
        write('this case selects on ');
        WriteTypeName(sel);
        write(', but the label is ');
        WriteTypeName(labelType);
        writeln
      end
      else begin
        seen := Overlaps(seenHead, lo, hi, at);
        if seen then begin
          ErrorAt(label_^.smLo^.line, label_^.smLo^.col);
          write('the label ');
          if sel <> nil then named := sel else named := labelType;
          WriteOrdinalName(named, at);
          writeln(' appears twice in this case statement')
        end
        else begin
          new(r);
          r^.lo := lo;
          r^.hi := hi;
          r^.next := nil;
          if seenHead = nil then seenHead := r else seenTail^.next := r;
          seenTail := r;
          new(r);
          r^.lo := lo;
          r^.hi := hi;
          r^.next := nil;
          if arm^.caValues = nil then arm^.caValues := r
          else arm^.caValueTail^.next := r;
          arm^.caValueTail := r
        end
      end;
      label_ := label_^.next
    end;
    saved := stmtPath;
    stmtPath := PushStmt(stmtPath, c);
    CheckStmt(arm^.caBody);
    stmtPath := saved;
    arm := arm^.next
  end
end;

{ `with r do S` makes the fields of r visible as bare names throughout S. The
  record is designated once, so the binding holds its address and any subscripts
  in the designator are evaluated a single time. }
procedure CheckWith(w: nodePtr);
var t: typePtr; at, len: integer; entry: symListPtr; saved: stmtPathPtr;
    root: nodePtr;
begin
  CheckExpr(w^.wtRecord);
  t := w^.wtRecord^.ntype;
  saved := stmtPath;

  if not IsDesignator(w^.wtRecord) then begin
    ErrorAt(w^.wtRecord^.line, w^.wtRecord^.col);
    writeln('''with'' needs a record variable');
    stmtPath := PushStmt(stmtPath, w);
    CheckStmt(w^.wtBody);
    stmtPath := saved
  end
  else if not IsRecord(t) then begin
    ErrorAt(w^.wtRecord^.line, w^.wtRecord^.col);
    write('''with'' needs a record variable, found ');
    if t = nil then write('nothing') else WriteTypeName(t);
    writeln;
    stmtPath := PushStmt(stmtPath, w);
    CheckStmt(w^.wtBody);
    stmtPath := saved
  end
  else begin
    { The binding is a frame slot holding a pointer -- the same shape as a
      `var` parameter -- so a `with` inside a recursive procedure binds the
      record of the invocation it is running in. }
    InternWithName(currentProc^.frameCount, at, len);
    new(entry);
    entry^.sym := AddHiddenVar(at, len, skVarParam, t, currentProc);
    { 6.9.4 i): a `with` is where a protected variable's name stops being
      written down, so the protection has to travel onto the binding or
      `with p do f := 1` would slip past a rule `p.f := 1` obeys. }
    root := RootDesignator(w^.wtRecord);
    if root <> nil then
      if root^.kind = nkVar then
        if root^.vrSym <> nil then
          entry^.sym^.isProtected := root^.vrSym^.isProtected;
    w^.wtBinding := entry^.sym;
    entry^.next := withTop;
    withTop := entry;
    stmtPath := PushStmt(stmtPath, w);
    CheckStmt(w^.wtBody);
    stmtPath := saved;
    withTop := withTop^.next
  end
end;

procedure CheckStmt;
var sub: nodePtr; sym, named: symPtr; saved: stmtPathPtr;
begin
  if s <> nil then
    case s^.kind of
      nkEmpty: ;

      { A compound statement is a statement-sequence, and 6.8.1 is stated over
        those -- so it joins the path like any other statement that contains
        one, and a goto into a `begin ... end` from outside it is refused. }
      nkCompound: begin
        saved := stmtPath;
        stmtPath := PushStmt(stmtPath, s);
        sub := s^.cpBody;
        while sub <> nil do begin
          CheckStmt(sub);
          sub := sub^.next
        end;
        stmtPath := saved
      end;

      nkGoto:    CheckGoto(s);
      nkLabeled: CheckLabeled(s);

      nkAssign: begin
        { Assigning to a function's own name sets its result (ISO 7185
          6.8.2.2), so it is redirected before the target is otherwise
          resolved. Reading the name is a recursive call -- see CheckExpr.
          Only a bare name can mean this; a function result has no fields. }
        named := nil;
        if s^.asTarget^.kind = nkVar then begin
          named := Lookup(s^.asTarget^.vrAt, s^.asTarget^.vrLen);
          if (named <> nil) and (named^.kind <> skFunc) then named := nil
        end;
        if named <> nil then begin
          s^.asTarget^.vrSym := named^.resultVar;
          s^.asTarget^.ntype := named^.stype;
          CheckExpr(s^.asValue);
          if named^.resultVar = nil then begin
            ErrorAt(s^.line, s^.col);
            write('''');
            WritePool(s^.asTarget^.vrAt, s^.asTarget^.vrLen);
            writeln(''' is not a function with a result')
          end
          else if not Assignable(s^.asTarget^.ntype, s^.asValue^.ntype) then
          begin
            ErrorAt(s^.line, s^.col);
            write('cannot assign ');
            WriteTypeName(s^.asValue^.ntype);
            write(' to a result of type ');
            WriteTypeName(s^.asTarget^.ntype);
            writeln
          end
        end
        else begin
          CheckExpr(s^.asTarget);
          CheckExpr(s^.asValue);
          { 6.9.4 a): an assignment-statement threatens its target. }
          if Threatened(s^.asTarget) then
            writeln('it cannot be assigned to');
          if not IsDesignator(s^.asTarget) then begin
            ErrorAt(s^.asTarget^.line, s^.asTarget^.col);
            writeln('the left side of an assignment must be a variable')
          end
          { Without this the message would read "cannot assign text to a
            variable of type text", which describes the rule accurately and
            explains nothing. }
          else if IsFile(s^.asTarget^.ntype) then begin
            ErrorAt(s^.line, s^.col);
            writeln('a file variable cannot be assigned to; use reset, ',
                    'rewrite and the buffer variable')
          end
          else if not Assignable(s^.asTarget^.ntype, s^.asValue^.ntype) then
          begin
            ErrorAt(s^.line, s^.col);
            write('cannot assign ');
            WriteTypeName(s^.asValue^.ntype);
            write(' to a variable of type ');
            WriteTypeName(s^.asTarget^.ntype);
            writeln
          end
        end
      end;

      nkWith:  CheckWith(s);
      nkCase:  CheckCase(s);
      nkWrite: CheckWrite(s);
      nkRead:  CheckRead(s);

      nkProcCall: begin
        sym := Lookup(s^.pcAt, s^.pcLen);
        { A user-declared procedure of the same name wins, exactly as it does
          for the required functions in CheckCall. }
        if (sym = nil) and
           (PoolIs(s^.pcAt, s^.pcLen, 'new      ') or
            PoolIs(s^.pcAt, s^.pcLen, 'dispose  ') or
            PoolIs(s^.pcAt, s^.pcLen, 'reset    ') or
            PoolIs(s^.pcAt, s^.pcLen, 'rewrite  ') or
            PoolIs(s^.pcAt, s^.pcLen, 'get      ') or
            PoolIs(s^.pcAt, s^.pcLen, 'put      ') or
            ((langStd = stdExtended) and
             IsDirectAccessProc(s^.pcAt, s^.pcLen))) then
          CheckStdProc(s)
        else if sym = nil then begin
          ErrorAt(s^.line, s^.col);
          write('unknown procedure ''');
          WritePool(s^.pcAt, s^.pcLen);
          writeln('''')
        end
        else if not IsInvocable(sym) or (ResultTypeOf(sym) <> nil) then begin
          ErrorAt(s^.line, s^.col);
          write('''');
          WritePool(s^.pcAt, s^.pcLen);
          writeln(''' is not a procedure')
        end
        else begin
          s^.pcSym := sym;
          CheckArguments(sym, s^.pcArgs, s^.line, s^.col)
        end
      end;

      nkIf: begin
        CheckExpr(s^.ifCond);
        if (s^.ifCond^.ntype <> nil) and not IsBoolean(s^.ifCond^.ntype) then
        begin
          ErrorAt(s^.ifCond^.line, s^.ifCond^.col);
          writeln('the condition of an if statement must be boolean')
        end;
        saved := stmtPath;
        stmtPath := PushStmt(stmtPath, s);
        CheckStmt(s^.ifThen);
        CheckStmt(s^.ifElse);
        stmtPath := saved
      end;

      nkWhile: begin
        CheckExpr(s^.whCond);
        if (s^.whCond^.ntype <> nil) and not IsBoolean(s^.whCond^.ntype) then
        begin
          ErrorAt(s^.whCond^.line, s^.whCond^.col);
          writeln('the condition of a while statement must be boolean')
        end;
        saved := stmtPath;
        stmtPath := PushStmt(stmtPath, s);
        CheckStmt(s^.whBody);
        stmtPath := saved
      end;

      nkRepeat: begin
        saved := stmtPath;
        stmtPath := PushStmt(stmtPath, s);
        sub := s^.rpBody;
        while sub <> nil do begin
          CheckStmt(sub);
          sub := sub^.next
        end;
        stmtPath := saved;
        CheckExpr(s^.rpCond);
        if (s^.rpCond^.ntype <> nil) and not IsBoolean(s^.rpCond^.ntype) then
        begin
          ErrorAt(s^.rpCond^.line, s^.rpCond^.col);
          writeln('the condition of a repeat statement must be boolean')
        end
      end;

      nkFor: begin
        CheckExpr(s^.frVar);
        { ISO 7185 6.8.3.9 requires an entire variable declared in this block,
          so a field reached through an enclosing `with` will not do either. }
        if s^.frVar^.vrField <> nil then begin
          ErrorAt(s^.frVar^.line, s^.frVar^.col);
          writeln('the control variable of a for statement cannot be a field ',
                  'of a with statement')
        end
        else if (s^.frVar^.vrSym <> nil) and
                (s^.frVar^.vrSym^.kind <> skVar) then begin
          ErrorAt(s^.frVar^.line, s^.frVar^.col);
          writeln('the control variable of a for statement must be a variable')
        end;
        if (s^.frVar^.ntype <> nil) and not IsOrdinal(s^.frVar^.ntype) then
        begin
          ErrorAt(s^.frVar^.line, s^.frVar^.col);
          writeln('the control variable of a for statement must be an ',
                  'ordinal type')
        end;
        CheckExpr(s^.frFrom);
        CheckExpr(s^.frTo);
        if not Assignable(s^.frVar^.ntype, s^.frFrom^.ntype) or
           not Assignable(s^.frVar^.ntype, s^.frTo^.ntype) then begin
          ErrorAt(s^.line, s^.col);
          writeln('the bounds of a for statement must match the type of the ',
                  'control variable')
        end;
        saved := stmtPath;
        stmtPath := PushStmt(stmtPath, s);
        CheckStmt(s^.frBody);
        stmtPath := saved
      end;

      nkInt, nkReal, nkChar, nkStr, nkNil, nkSet, nkSetMember, nkVar, nkIndex,
      nkField, nkDeref,
      nkBinary, nkUnary, nkCall, nkWriteArg, nkCaseArm, nkVariantArm, nkGroup,
      nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord, nkPointer,
      nkFile, nkSetOf, nkSchema, nkInquiry, nkConstDecl, nkTypeDecl, nkProcDecl,
      nkBlock:
        { not a statement }
    end
end;

{ ------------------------------------------------------------ declarations }

{ Build the parameter symbols of one formal parameter list. A top-level one
  is a variable of the procedure's own frame; one belonging to a *procedural*
  parameter is a descriptor only -- it says how the argument travels and what
  type it has, and the frame it will occupy is the frame of whatever procedure
  is eventually passed. Hence `frame` being nil for those. }
procedure BuildFormals(groups: nodePtr; into, frame: symPtr);
var g, n: nodePtr; t: typePtr; ps, schema, named: symPtr; section: integer;
begin
  g := groups;
  section := 0;
  while g <> nil do begin
    section := section + 1;
    if g^.grIsProc then begin
      { ISO 7185 6.6.3.1 spells a procedural parameter as a heading, so it
        declares exactly one name and the parser guarantees it is there. }
      t := NewType(tyProc);
      if g^.grIsFunction then begin
        if g^.grResult = nil then t^.elem := intType
        else t^.elem := ResolveType(g^.grResult);
        { 6.6.2 restricts a function's result type, and a functional
          parameter's heading is a function heading -- the same rule, so the
          same message. }
        if not IsOrdinal(t^.elem) and not IsReal(t^.elem) and
           not IsComplex(t^.elem) and not IsPointer(t^.elem) then begin
          ErrorAt(g^.grNames^.line, g^.grNames^.col);
          write('a function cannot return ');
          WriteTypeName(t^.elem);
          writeln('; use a var parameter');
          t^.elem := intType
        end
      end;
      n := g^.grNames;
      if frame <> nil then
        ps := AddFrameVar(n^.dnAt, n^.dnLen, skProcParam, t, frame, n^.line,
                          n^.col)
      else begin
        ps := NewSymbol;
        ps^.at := n^.dnAt;
        ps^.len := n^.dnLen;
        ps^.kind := skProcParam;
        ps^.stype := t
      end;
      { Its own parameters name no frame and are never looked up: the actual
        procedure supplies the names its body uses, and these exist only to be
        compared against that procedure's. Two of them sharing a spelling
        therefore cannot be ambiguous, so no scope is opened to catch it. }
      BuildFormals(g^.grParams, ps, nil);
      AppendSym(into^.params, into^.paramTail, ps)
    end
    else begin
      { 6.7.3.2 and 6.7.3.3: a parameter-form may be a bare schema-name, and
        then the type is not one type -- the tuple arrives with the actual.
        Each name needs its symbol *first*, because the discriminants are
        resolved against the descriptor that symbol's frame slot holds. }
      schema := nil;
      if g^.grType <> nil then
        if g^.grType^.kind = nkNamed then begin
          named := Lookup(g^.grType^.nmAt, g^.grType^.nmLen);
          if named <> nil then
            if named^.kind = skSchema then schema := named
        end;
      if schema <> nil then begin
        n := g^.grNames;
        while n <> nil do begin
          if frame <> nil then
            if g^.grByRef then
              ps := AddFrameVar(n^.dnAt, n^.dnLen, skVarParam, intType, frame,
                                n^.line, n^.col)
            else
              ps := AddFrameVar(n^.dnAt, n^.dnLen, skParam, intType, frame,
                                n^.line, n^.col)
          else begin
            ps := NewSymbol;
            ps^.at := n^.dnAt;
            ps^.len := n^.dnLen;
            if g^.grByRef then ps^.kind := skVarParam
            else ps^.kind := skParam;
            ps^.stype := intType
          end;
          ps^.paramSection := section;
          ps^.isProtected := g^.grIsProtected;
          ps^.stype := SchematicFormal(schema, ps, g^.grType);
          { 6.7.3.1 asks the question of "every type possessed by" the name,
            and a schematic formal possesses one per tuple -- but they all come
            from one body, so the produced type answers for every one of
            them. }
          if g^.grIsProtected and not Protectable(ps^.stype) then begin
            ErrorAt(n^.line, n^.col);
            write('''');
            WritePool(n^.dnAt, n^.dnLen);
            write(''' cannot be protected: ');
            WriteTypeName(ps^.stype);
            writeln(' is not a protectable type')
          end;
          { The denoter keeps the last of them, the way a schema body keeps its
            last production (ADR-0039): one parameter-form has as many types as
            it has names, and showing one of them says more than showing
            none. }
          g^.grType^.ntype := ps^.stype;
          AppendSym(into^.params, into^.paramTail, ps);
          n := n^.next
        end
      end
      else begin
      { 6.7.3.1: "The parameter-form ... shall not contain an applied
        occurrence of the parameter-identifier", so `x: type of x` is refused
        -- and it has to be refused *before* the names are declared, or the
        name would find itself. }
      if g^.grType <> nil then
        if g^.grType^.kind = nkInquiry then begin
          n := g^.grNames;
          while n <> nil do begin
            if PoolSame(n^.dnAt, n^.dnLen, g^.grType^.tqAt, g^.grType^.tqLen)
            then begin
              ErrorAt(g^.grType^.line, g^.grType^.col);
              write('''type of ');
              WritePool(n^.dnAt, n^.dnLen);
              writeln(''' names the very parameter it is the type of')
            end;
            n := n^.next
          end
        end;
      t := ResolveType(g^.grType);
      { ISO 7185 6.6.3.3: a file may only be passed by reference. A value
        parameter is a copy, and a file has no copy -- the position, the buffer
        and the operating system's handle are one object, not a value. }
      if IsFile(t) and not g^.grByRef and (g^.grNames <> nil) then begin
        ErrorAt(g^.grNames^.line, g^.grNames^.col);
        writeln('a file parameter must be a var parameter')
      end;
      { A variable-string value parameter would have to be *converted* at the
        call -- 6.4.6 pads or refuses by length, and the actual may be a
        literal, a fixed string or a string of another capacity -- and a
        conversion needs somewhere to build the result that the caller can
        name. Until it has one, such a parameter is refused rather than copied
        bytewise from whatever the actual happened to be (ADR-0052). }
      if IsVarString(t) and not g^.grByRef and (g^.grNames <> nil) then begin
        ErrorAt(g^.grNames^.line, g^.grNames^.col);
        writeln('a string parameter must be a var parameter; a value ',
                'parameter would have to convert the argument, and there is ',
                'nowhere yet to build the conversion')
      end;
      { 6.4.1: a file or a pointer is not protectable, and neither is anything
        holding one. The standard's own reason is that protecting either would
        protect nothing -- a file is modified by nearly every operation on it,
        and a pointer's *value* can be copied out of the protected variable and
        disposed of through the copy. }
      if g^.grIsProtected and (g^.grNames <> nil) and not Protectable(t) then
      begin
        ErrorAt(g^.grNames^.line, g^.grNames^.col);
        write('''');
        WritePool(g^.grNames^.dnAt, g^.grNames^.dnLen);
        write(''' cannot be protected: ');
        WriteTypeName(t);
        writeln(' is not a protectable type')
      end;
      n := g^.grNames;
      while n <> nil do begin
        if frame <> nil then
          if g^.grByRef then
            ps := AddFrameVar(n^.dnAt, n^.dnLen, skVarParam, t, frame, n^.line,
                              n^.col)
          else
            ps := AddFrameVar(n^.dnAt, n^.dnLen, skParam, t, frame, n^.line,
                              n^.col)
        else begin
          ps := NewSymbol;
          ps^.at := n^.dnAt;
          ps^.len := n^.dnLen;
          if g^.grByRef then ps^.kind := skVarParam else ps^.kind := skParam;
          ps^.stype := t
        end;
        ps^.paramSection := section;
        ps^.isProtected := g^.grIsProtected;
        { 6.7.3.3: a var parameter's form is a type-name, and 6.4.1 makes a
          type-name denote the bindability of its definition -- so a parameter
          of a bindable type is bindable and one of `text` is not. }
        ps^.isBindable := BindableOf(g^.grType);
        AppendSym(into^.params, into^.paramTail, ps);
        n := n^.next
      end
      end
    end;
    g := g^.next
  end
end;

procedure DeclareProcHeading(d: nodePtr; owner: symPtr);
var existing, sym: symPtr; mark: entryPtr; at, len: integer;
begin
  existing := LookupInScope(d^.pdAt, d^.pdLen);
  if existing <> nil then
    if not ((existing^.kind = skProc) or (existing^.kind = skFunc)) or
       existing^.defined then
      existing := nil;

  if existing <> nil then begin
    { ISO 7185 6.6.1: the full declaration of a forward-declared procedure
      repeats the name only, so the parameters are already known. }
    if (d^.pdParams <> nil) or (d^.pdResult <> nil) then begin
      ErrorAt(d^.line, d^.col);
      write('the parameters of ''');
      WritePool(d^.pdAt, d^.pdLen);
      writeln(''' were already given in its forward declaration')
    end;
    d^.pdSym := existing
  end
  else begin
    if d^.pdIsFunction then
      sym := Declare(d^.pdAt, d^.pdLen, skFunc, d^.line, d^.col)
    else
      sym := Declare(d^.pdAt, d^.pdLen, skProc, d^.line, d^.col);
    sym^.level := owner^.level + 1;
    sym^.owner := owner;
    d^.pdSym := sym;

    if d^.pdIsFunction then
      if d^.pdResult = nil then begin
        ErrorAt(d^.line, d^.col);
        write('function ''');
        WritePool(d^.pdAt, d^.pdLen);
        writeln(''' needs a result type');
        sym^.stype := intType
      end
      else begin
        sym^.stype := ResolveType(d^.pdResult);
        { ISO 7185 6.6.2: a function's result type is a *simple* type or a
          pointer type. Stated the standard's way round rather than as "not
          something that lives in memory", because a set lives in a register
          and would pass that test while still not being a result type the
          language allows. }
        { ISO 7185 6.6.2 restricts a function's result to a simple type or a
          pointer type, and ISO/IEC 10206:1991 6.4.2.2 adds `complex` to the
          simple types -- so this list grew by one word rather than by a rule. }
        if not IsOrdinal(sym^.stype) and not IsReal(sym^.stype) and
           not IsComplex(sym^.stype) and not IsPointer(sym^.stype) then begin
          ErrorAt(d^.line, d^.col);
          write('a function cannot return ');
          WriteTypeName(sym^.stype);
          writeln('; use a var parameter');
          sym^.stype := intType
        end
      end;

    { Parameters belong to the procedure's own frame, so they are created here
      but only made visible once its body is entered. }
    mark := scopeTop;
    scopeDepth := scopeDepth + 1;
    BuildFormals(d^.pdParams, sym, sym);
    if sym^.kind = skFunc then begin
      { The result lives in the frame like a local; assigning to the function
        name writes here, and the epilogue returns it. }
      InternResultName(d^.pdAt, d^.pdLen, at, len);
      sym^.resultVar := AddHiddenVar(at, len, skVar, sym^.stype, sym)
    end;
    scopeDepth := scopeDepth - 1;
    scopeTop := mark
  end
end;

procedure CheckProcBody(d: nodePtr);
var sym, outer: symPtr; p: symListPtr; mark: entryPtr;
begin
  sym := d^.pdSym;
  if sym <> nil then
    if sym^.defined then begin
      ErrorAt(d^.line, d^.col);
      write('''');
      WritePool(d^.pdAt, d^.pdLen);
      writeln(''' already has a body')
    end
    else begin
      sym^.defined := true;
      outer := currentProc;
      currentProc := sym;

      mark := scopeTop;
      scopeDepth := scopeDepth + 1;
      p := sym^.params;
      while p <> nil do begin
        Bind(p^.sym^.at, p^.sym^.len, p^.sym);
        p := p^.next
      end;
      CheckBlock(d^.pdBody, sym);
      scopeDepth := scopeDepth - 1;
      scopeTop := mark;

      currentProc := outer
    end
end;

{ A block is the declaration part followed by the statement part, and is the
  same shape for the program and for every procedure. The caller has already
  pushed the scope the declarations go into. }
{ ------------------------------------------------------------------ labels }

{ The label declaration part. Every label a block declares must be labelling a
  statement of that same block by the time it is finished -- 6.1.6 declares
  them and 6.8.1 requires each to be used, and a label declared and never
  placed is the mistake that would otherwise leave a goto with nowhere to land
  and no message about it. }
procedure CheckLabelPart(b: nodePtr; owner: symPtr);
var sc: labelScopePtr; d: nodePtr; info, seen: labelInfoPtr;
    duplicate: boolean;
begin
  new(sc);
  sc^.labels := nil;
  sc^.labelTail := nil;
  sc^.gotos := nil;
  sc^.gotoTail := nil;
  sc^.outer := labelScope;
  labelScope := sc;

  d := b^.blLabels;
  while d <> nil do begin
    duplicate := false;
    seen := sc^.labels;
    while seen <> nil do begin
      if seen^.number = d^.ldNumber then duplicate := true;
      seen := seen^.next
    end;
    if duplicate then begin
      ErrorAt(d^.line, d^.col);
      writeln('label ', d^.ldNumber:1, ' is declared twice in this block')
    end
    else begin
      new(info);
      info^.number := d^.ldNumber;
      info^.id := nextLabelId;
      nextLabelId := nextLabelId + 1;
      info^.isDefined := false;
      info^.line := d^.line;
      info^.col := d^.col;
      info^.defLine := 0;
      info^.defCol := 0;
      info^.path := nil;
      info^.owner := owner;
      info^.next := nil;
      if sc^.labels = nil then sc^.labels := info
      else sc^.labelTail^.next := info;
      sc^.labelTail := info
    end;
    d := d^.next
  end
end;

{ A label is legal on a statement only where it was declared, so this is
  checked against the innermost block's declarations alone. }
procedure CheckLabeled;
var found: labelInfoPtr; saved: stmtPathPtr;
begin
  found := nil;
  if labelScope <> nil then begin
    found := labelScope^.labels;
    while (found <> nil) and (found^.number <> s^.lbLabel) do
      found := found^.next
  end;

  if found = nil then begin
    ErrorAt(s^.line, s^.col);
    writeln('label ', s^.lbLabel:1, ' is not declared in this block')
  end
  else if found^.isDefined then begin
    ErrorAt(s^.line, s^.col);
    writeln('label ', s^.lbLabel:1,
            ' already labels a statement at line ', found^.defLine:1)
  end
  else begin
    found^.isDefined := true;
    found^.defLine := s^.line;
    found^.defCol := s^.col;
    found^.path := stmtPath;
    s^.lbId := found^.id
  end;

  saved := stmtPath;
  stmtPath := PushStmt(stmtPath, s);
  CheckStmt(s^.lbStmt);
  stmtPath := saved
end;

{ The target is not looked for here: a label may be declared before the
  statement it labels is written, so a forward jump can only be resolved once
  the whole block has been walked. }
procedure CheckGoto;
var g: pendingGotoPtr;
begin
  if labelScope <> nil then begin
    new(g);
    g^.gnode := s;
    g^.gpath := stmtPath;
    g^.fromInner := false;
    g^.next := nil;
    if labelScope^.gotos = nil then labelScope^.gotos := g
    else labelScope^.gotoTail^.next := g;
    labelScope^.gotoTail := g
  end
end;

{ ISO 7185 6.8.1 restricts where a goto may land, and the restriction is what
  makes the lowering possible as much as what the standard says: a jump *into*
  a structured statement would arrive past the loop's initialisation or the
  `with` binding it depends on.

    - to a label of the same block, the statements containing the label must
      all contain the goto -- so a jump outward or sideways within one level is
      allowed and a jump inward is not;
    - to a label of an enclosing block, the label must be at the top level of
      that block's statement part, which is the only place a frame that is
      still alive could be re-entered. }
procedure ResolveGotos;
var pending, moved: pendingGotoPtr; found, info: labelInfoPtr;
    sc, home: labelScopePtr; p: stmtPathPtr; reachable, known: boolean;
    target: symPtr; num: numPtr;
begin
  pending := labelScope^.gotos;
  while pending <> nil do begin
    found := nil;
    home := nil;
    sc := labelScope;
    while (sc <> nil) and (found = nil) do begin
      info := sc^.labels;
      while (info <> nil) and (info^.number <> pending^.gnode^.gtLabel) do
        info := info^.next;
      if info <> nil then begin
        found := info;
        home := sc
      end;
      sc := sc^.outer
    end;

    if found = nil then begin
      ErrorAt(pending^.gnode^.line, pending^.gnode^.col);
      writeln('label ', pending^.gnode^.gtLabel:1,
              ' is not declared in this block or any enclosing one')
    end
    { The label is somewhere outside: hand the goto to the block that declared
      it, whose statements have not been walked yet. }
    else if home <> labelScope then begin
      new(moved);
      moved^.gnode := pending^.gnode;
      moved^.gpath := pending^.gpath;
      moved^.fromInner := true;
      moved^.next := nil;
      if home^.gotos = nil then home^.gotos := moved
      else home^.gotoTail^.next := moved;
      home^.gotoTail := moved
    end
    else if not found^.isDefined then begin
      ErrorAt(pending^.gnode^.line, pending^.gnode^.col);
      writeln('label ', pending^.gnode^.gtLabel:1,
              ' is declared but labels no statement')
    end
    else if not pending^.fromInner then begin
      p := pending^.gpath;
      while PathDepth(p) > PathDepth(found^.path) do
        p := p^.next;
      reachable := p = found^.path;
      if not reachable then begin
        ErrorAt(pending^.gnode^.line, pending^.gnode^.col);
        writeln('label ', pending^.gnode^.gtLabel:1, ' is inside a statement ',
                'this goto is not: a goto may leave a structured statement ',
                'but not enter one')
      end
      else begin
        pending^.gnode^.gtId := found^.id;
        pending^.gnode^.gtOwner := found^.owner
      end
    end
    else if found^.path <> nil then begin
      ErrorAt(pending^.gnode^.line, pending^.gnode^.col);
      writeln('label ', pending^.gnode^.gtLabel:1, ' is in an enclosing ',
              'block, so it must label a statement of that block''s ',
              'statement part and not one inside a statement of it')
    end
    else begin
      { A legal non-local goto. The *target* block is what has work to do -- it
        carries the jump record and dispatches to the label on arrival -- and
        it learns of it here, from a goto in a block nested inside it that has
        already been walked (ADR-0032). }
      pending^.gnode^.gtId := found^.id;
      pending^.gnode^.gtOwner := found^.owner;
      pending^.gnode^.gtNonLocal := true;
      target := found^.owner;
      num := target^.nlLabels;
      known := false;
      while num <> nil do begin
        if num^.value = found^.id then known := true;
        num := num^.next
      end;
      if not known then begin
        new(num);
        num^.value := found^.id;
        num^.next := nil;
        if target^.nlLabels = nil then target^.nlLabels := num
        else target^.nlTail^.next := num;
        target^.nlTail := num
      end
    end;
    pending := pending^.next
  end;

  info := labelScope^.labels;
  while info <> nil do begin
    if not info^.isDefined then begin
      ErrorAt(info^.line, info^.col);
      writeln('label ', info^.number:1,
              ' is declared but labels no statement of this block')
    end;
    info := info^.next
  end;

  labelScope := labelScope^.outer
end;

procedure CheckBlock;
var d, g, n, init: nodePtr; s, schema, named, first: symPtr; t: typePtr;
    value: symbol; outerPath: stmtPathPtr;
begin
  CheckLabelPart(b, owner);
  d := b^.blConsts;
  while d <> nil do begin
    CheckExpr(d^.kdValue);
    value.stype := nil;
    if not EvalConst(d^.kdValue, value) then begin
      ErrorAt(d^.line, d^.col);
      write('the value of constant ''');
      WritePool(d^.kdAt, d^.kdLen);
      writeln(''' is not a compile-time constant')
    end
    else begin
      s := Declare(d^.kdAt, d^.kdLen, skConst, d^.line, d^.col);
      s^.stype := value.stype;
      s^.intVal := value.intVal;
      s^.charVal := value.charVal;
      s^.boolVal := value.boolVal;
      s^.realAt := value.realAt;
      s^.realLen := value.realLen;
      s^.realNeg := value.realNeg
    end;
    d := d^.next
  end;

  { A type name is visible to the definitions after it, so each is declared as
    it is resolved rather than all at the end. }
  d := b^.blTypes;
  while d <> nil do begin
    { 6.4.7: a schema-definition declares a schema, not a type. Its body is
      *not* resolved here -- it has no discriminant values yet, and resolving
      it once would produce the one type every use then shared. }
    if d^.tdDiscs <> nil then
      DeclareSchema(d)
    else begin
    t := ResolveType(d^.tdType);
    s := Declare(d^.tdAt, d^.tdLen, skType, d^.line, d^.col);
    if s^.stype = nil then begin   { a duplicate: keep the first definition }
      s^.stype := t;
      { 6.4.1: a type-name denotes "the type, bindability and initial state"
        its definition denoted, so the initial state travels with the name and
        every variable of it is initialised. }
      s^.initValue := InitialStateOf(d^.tdType);
      s^.isBindable := BindableOf(d^.tdType);
      if t^.aliasLen = 0 then begin
        t^.aliasAt := d^.tdAt;
        t^.aliasLen := d^.tdLen
      end
    end
    end;
    d := d^.next
  end;
  { Every name in the type part is now visible, so the pointers that named one
    before it existed can be completed. }
  ResolvePendingPointers;

  g := b^.blVars;
  while g <> nil do begin
    { 6.2.3.2: a discriminated schema is the one denoter whose discriminants
      may be variables, and only here. The first name is resolved with itself
      offered as the variable they would belong to; if they turned out to be
      constants the type is an ordinary one and the group shares it, exactly
      as before. }
    schema := nil;
    if g^.grType^.kind = nkSchema then begin
      named := Lookup(g^.grType^.nmAt, g^.grType^.nmLen);
      if named <> nil then
        if named^.kind = skSchema then schema := named
    end;
    if (schema <> nil) and (g^.grNames <> nil) then begin
      n := g^.grNames;
      first := AddFrameVar(n^.dnAt, n^.dnLen, skVar, intType, owner, n^.line,
                           n^.col);
      dynamicVarFor := first;
      first^.stype := ResolveType(g^.grType);
      dynamicVarFor := nil;
      n := n^.next;
      while n <> nil do begin
        s := AddFrameVar(n^.dnAt, n^.dnLen, skVar, first^.stype, owner,
                         n^.line, n^.col);
        { Each name has its own descriptor, so each needs its own type -- but
          one actual-discriminant-part, evaluated once per variable on entry
          from the one tree the group shares. }
        if IsGeneric(first^.stype) then begin
          s^.stype := GenericFromSchema(schema, s, g^.grType, nounVarType);
          s^.descSchema := first^.descSchema;
          s^.discExprs := first^.discExprs
        end;
        n := n^.next
      end
    end
    else begin
      { One denoter for the whole group, so `a, b: array [1..3] of integer`
        makes a and b the same type and lets `a := b` through. }
      t := ResolveType(g^.grType);
      init := InitialStateOf(g^.grType);
      n := g^.grNames;
      while n <> nil do begin
        s := AddFrameVar(n^.dnAt, n^.dnLen, skVar, t, owner, n^.line, n^.col);
        { 6.2.3.5 creates each local "in its initial state" on entry, so the
          whole group shares one value as it shares one type. }
        s^.initValue := init;
        { 6.4.1's `bindable` belongs to the type-denoter, like the initial
          state -- so the group shares it, and 6.5.1 makes such a variable
          totally-undefined until something binds it. }
        s^.isBindable := BindableOf(g^.grType);
        n := n^.next
      end
    end;
    g := g^.next
  end;

  { The variables exist now, so the program header's parameters can be matched
    against them -- before the statements, so a use of an unbound file is
    reported after the reason it is unbound rather than before it. }
  if owner = programSym then
    BindProgramParameters;

  { Headings first, then bodies. Declaring every heading in this block before
    checking any body would let a procedure call one declared after it without
    `forward`, so headings are declared one at a time, in order, and each body
    is checked as it is reached. }
  d := b^.blProcs;
  while d <> nil do begin
    DeclareProcHeading(d, owner);
    if d^.pdBody <> nil then CheckProcBody(d);
    d := d^.next
  end;

  d := b^.blProcs;
  while d <> nil do begin
    if d^.pdSym <> nil then
      if not d^.pdSym^.defined then begin
        ErrorAt(d^.line, d^.col);
        write('''');
        WritePool(d^.pdAt, d^.pdLen);
        writeln(''' was declared forward but never given a body')
      end;
    d := d^.next
  end;

  { The statement part *is* the block's outermost statement-sequence, so it is
    walked without joining the path -- a label at the top of it has no
    containing statement, which is what 6.8.1 requires of the target of a goto
    from a nested block. A `begin ... end` written *inside* it is an ordinary
    statement and does join. The path is per block, since a goto in a nested
    procedure is not inside the enclosing block's statements. }
  outerPath := stmtPath;
  stmtPath := nil;
  if b^.blBody <> nil then begin
    d := b^.blBody^.cpBody;
    while d <> nil do begin
      CheckStmt(d);
      d := d^.next
    end
  end;
  stmtPath := outerPath;
  ResolveGotos
end;

procedure InstallPredefined;
var s, cap: symPtr; at, len: integer;
    nameType: typePtr; fld: fieldPtr;
begin
  InternWord('true     ', at, len);
  s := Declare(at, len, skConst, 0, 0);
  s^.stype := boolType;
  s^.boolVal := true;

  InternWord('false    ', at, len);
  s := Declare(at, len, skConst, 0, 0);
  s^.stype := boolType;
  s^.boolVal := false;

  InternWord('maxint   ', at, len);
  s := Declare(at, len, skConst, 0, 0);
  s^.stype := intType;
  s^.intVal := maxint;

  { ISO/IEC 10206:1991 6.4.3.3.3: "There shall be a schema that is denoted by
    the required schema-identifier `string`. The schema `string` shall have one
    formal discriminant denoted by the required discriminant-identifier
    `capacity`, which shall possess the integer-type."

    It is declared like any other required identifier -- in the outermost
    scope, where a program may shadow it -- and not as a word-symbol, because
    6.4.3.3.3 makes it an identifier and a valid ISO 7185 program may define a
    type of that name. }
  if langStd = stdExtended then begin
    { 6.4.3.4: "There shall be a record-type designated packed and denoted by
      the required type-identifier `BindingType`. For each of the required
      field-identifiers `name` and `bound`, there shall be an associated
      required field ... an implementation-defined variable-string-type and a
      type denoted by the type-denoter Boolean, respectively."

      The capacity of `name` is the implementation-defined part, and it is what
      made this feature wait for the string type: there was no
      variable-string-type to give the field until 6.4.3.3 landed. }
    bindingType := NewType(tyRecord);
    bindingType^.isPacked := true;
    nameType := NewType(tyString);
    nameType^.lo := 1;
    nameType^.hi := bindNameCap;
    new(fld);
    InternWord('name     ', fld^.at, fld^.len);
    fld^.ftype := nameType;
    fld^.index := 0;
    fld^.variant := nil;
    fld^.line := 0;
    fld^.col := 0;
    fld^.initValue := nil;
    fld^.next := nil;
    bindingType^.fields := fld;
    bindingType^.fieldTail := fld;
    new(fld);
    InternWord('bound    ', fld^.at, fld^.len);
    fld^.ftype := boolType;
    fld^.index := 1;
    fld^.variant := nil;
    fld^.line := 0;
    fld^.col := 0;
    fld^.initValue := nil;
    fld^.next := nil;
    bindingType^.fieldTail^.next := fld;
    bindingType^.fieldTail := fld;
    InternWide('bindingtype     ', at, len);
    s := Declare(at, len, skType, 0, 0);
    s^.stype := bindingType;
    { The name is folded for lookup, as every identifier is, but a diagnostic
      spells it the way 6.4.3.4 does -- so the alias is interned separately in
      the standard's own capitals. Nothing ever looks that copy up. }
    InternWide('BindingType     ', at, len);
    bindingType^.aliasAt := at;
    bindingType^.aliasLen := len;

    InternWord('string   ', at, len);
    s := Declare(at, len, skSchema, 0, 0);
    s^.isStringSchema := true;
    cap := NewSymbol;
    InternWord('capacity ', at, len);
    cap^.at := at;
    cap^.len := len;
    cap^.kind := skConst;
    cap^.stype := intType;
    AppendSym(s^.discs, s^.discTail, cap)
  end
end;

procedure RunSema;
var p: nodePtr;
begin
  intType := NewType(tyInteger);
  realType := NewType(tyReal);
  complexType := NewType(tyComplex);
  { ISO/IEC 10206:1991 6.4.3.3.1's canonical-string-type: the type of every
    string *value* -- a literal's, `+`'s, `substr`'s and `trim`'s. It has no
    capacity (hi is negative) because it has no storage: a value is only ever
    on its way into something that does, and 6.4.6 checks it against *that*
    capacity. No type-denoter produces one, so no variable has it. }
  canonStringType := NewType(tyString);
  canonStringType^.lo := 1;
  canonStringType^.hi := -1;
  boolType := NewType(tyBoolean);
  charType := NewType(tyChar);
  voidType := NewType(tyVoid);
  { The type of `nil`: a pointer with no domain, assignable to any pointer. }
  nilType := NewType(tyPointer);
  { And the type of `[]`: a set with no base type, and a value of every set
    type. Unlike nil this is not an exception to name equivalence but the
    ordinary rule of 6.4.6 with nothing to compare. }
  emptySetType := NewType(tySet);
  labelScope := nil;
  stmtPath := nil;
  nextLabelId := 0;
  { `text`, the predefined file of char (ISO 7185 6.4.3.5). A singleton like
    the other predefined types, so every variable declared `text` has the same
    type -- a `file of char` written out longhand is a different one, exactly
    as ADR-0017's name equivalence says it should be. }
  textType := NewType(tyFile);
  textType^.elem := charType;
  textType^.isText := true;
  InternWord('text     ', textType^.aliasAt, textType^.aliasLen);

  scopeTop := nil;
  scopeDepth := 0;
  { the predefined identifiers live in their own outermost scope }
  InstallPredefined;

  programSym := NewSymbol;
  programSym^.at := progAt;
  programSym^.len := progLen;
  programSym^.kind := skProc;
  programSym^.level := 0;
  programSym^.defined := true;
  currentProc := programSym;

  scopeDepth := scopeDepth + 1;
  { `input` and `output` are declared by the program header rather than by the
    block, so they exist before the declarations are seen. Declaring them only
    when they are listed is what makes using `write` without `output` in the
    header the error ISO 7185 6.10 says it is. }
  p := progParams;
  while p <> nil do begin
    if PoolIs(p^.dnAt, p^.dnLen, 'input    ') and (stdInput = nil) then begin
      stdInput := AddFrameVar(p^.dnAt, p^.dnLen, skVar, textType, programSym,
                              p^.line, p^.col);
      stdInput^.binding := fbStdInput
    end
    else if PoolIs(p^.dnAt, p^.dnLen, 'output   ') and (stdOutput = nil) then
    begin
      stdOutput := AddFrameVar(p^.dnAt, p^.dnLen, skVar, textType, programSym,
                               p^.line, p^.col);
      stdOutput^.binding := fbStdOutput
    end;
    p := p^.next
  end;
  CheckBlock(progBlock, programSym)
end;

{ ---------------------------------------------------------------- the dump }

procedure Pad;
var i: integer;
begin
  for i := 1 to level do
    write('  ')
end;

procedure At(l, c: integer);
begin
  writeln(' @', l:1, ':', c:1)
end;

{ The same position, without ending the line: an annotated node has more to
  say after it. }
procedure WritePos(l, c: integer);
begin
  write(' @', l:1, ':', c:1)
end;

{ What a name resolved to. A variable is named by the frame that holds it and
  its slot in it, because that pair is what codegen actually uses -- printing
  the spelling again would compare nothing Sema decided. }
procedure WriteSymRef(s: symPtr);
begin
  if s = nil then
    write('?')
  else
    case s^.kind of
      { A constant prints its value, which is how constant folding is compared.
        A real one prints only its type: comparing converted reals would
        compare two languages' float formatting (ADR-0022). }
      skConst:
        if s^.stype = nil then write('const ?')
        else if IsReal(s^.stype) then write('const real')
        else if IsChar(s^.stype) then write('const ', ord(s^.charVal):1)
        else if IsBoolean(s^.stype) then
          if s^.boolVal then write('const true') else write('const false')
        else write('const ', s^.intVal:1);
      skType: write('type');
      skProc: begin
        write('proc ');
        WritePool(s^.at, s^.len)
      end;
      skFunc: begin
        write('func ');
        WritePool(s^.at, s^.len)
      end;
      skVar, skParam, skVarParam, skProcParam: begin
        if s^.owner = nil then write('?') else WritePool(s^.owner^.at, s^.owner^.len);
        write('/', s^.frameIndex:1)
      end;
      { A discriminant has no slot of its own: it is one field of the
        descriptor in the slot of the parameter it belongs to, so it is named
        by that slot and its position in the tuple. }
      skDisc: begin
        if s^.owner = nil then write('?') else WritePool(s^.owner^.at, s^.owner^.len);
        write('/', s^.frameIndex:1, '#', s^.discIndex:1)
      end;
      skSchema: write('schema')
    end
end;

{ The end of an expression's line: its type, when the tree has been through
  Sema. }
procedure ExprEnd(e: nodePtr);
begin
  if annotate then begin
    write(' : ');
    WriteTypeName(e^.ntype)
  end;
  writeln
end;

{ The end of a type-denoter's line: the type it produced. }
procedure TypeEnd(d: nodePtr);
begin
  if annotate then begin
    write(' = ');
    WriteTypeName(d^.ntype)
  end;
  writeln
end;

procedure WriteBinOp(op: binaryOp);
begin
  case op of
    opAdd:     write('add');
    opSub:     write('sub');
    opMul:     write('mul');
    opRealDiv: write('rdiv');
    opIntDiv:  write('idiv');
    opMod:     write('mod');
    opAnd:     write('and');
    opOr:      write('or');
    opExp:     write('exp');
    opPow:     write('pow');
    opAndThen: write('andthen');
    opOrElse:  write('orelse');
    opEq:      write('eq');
    opNe:      write('ne');
    opLt:      write('lt');
    opLe:      write('le');
    opGt:      write('gt');
    opGe:      write('ge');
    opIn:      write('in')
  end
end;

procedure WriteUnOp(op: unaryOp);
begin
  case op of
    opPos: write('pos');
    opNeg: write('neg');
    opNot: write('not')
  end
end;

procedure DumpExpr(n: nodePtr); forward;
procedure DumpStmt(n: nodePtr); forward;
procedure DumpTypeExpr(n: nodePtr); forward;
procedure DumpBlock(n: nodePtr); forward;

{ A child Sema may or may not have supplied -- the file of a read or a write.
  The marker says which, so "absent" and "present" cannot be confused. }
procedure DumpOptional(e: nodePtr);
begin
  Pad;
  if e = nil then
    writeln('no-file')
  else begin
    writeln('file');
    level := level + 1;
    DumpExpr(e);
    level := level - 1
  end
end;

{ Where a field lives: '-' is the record's fixed part, '0' is arm 0 of its
  variant part, '0.1' is arm 1 of the variant part inside arm 0. }
procedure WriteVariantRef(path: numPtr);
var first: boolean;
begin
  if path = nil then
    write('-')
  else begin
    first := true;
    while path <> nil do begin
      if not first then write('.');
      write(path^.value:1);
      first := false;
      path := path^.next
    end
  end
end;

procedure DumpField(f: fieldPtr);
begin
  Pad;
  write('field ');
  WritePool(f^.at, f^.len);
  write(' #', f^.index:1, '/');
  WriteVariantRef(f^.variant);
  write(' : ');
  WriteTypeName(f^.ftype);
  writeln
end;

{ The layout Sema gave a record: which struct each field lives in and at what
  position, and which tag values select each variant. Codegen indexes by
  exactly these numbers, so they are what a record type *is*. }
procedure DumpFieldList(f: fieldPtr);
begin
  while f <> nil do begin
    DumpField(f);
    f := f^.next
  end
end;

{ One level of arms and everything nested in them. The name of an arm is its
  path, which is also what a field of it prints as its variant. }
procedure DumpArmList(v: variantPtr; prefix: numPtr);
var lbl: rangePtr; here: numPtr; i: integer;
begin
  i := 0;
  while v <> nil do begin
    here := PathAppend(prefix, i);
    Pad;
    write('variant ');
    WriteVariantRef(here);
    if v^.isOtherwise then
      writeln(' otherwise')
    else begin
      write(' labels');
      lbl := v^.labels;
      while lbl <> nil do begin
        if lbl^.lo = lbl^.hi then
          write(' ', lbl^.lo:1)
        else
          write(' ', lbl^.lo:1, '..', lbl^.hi:1);
        lbl := lbl^.next
      end;
      writeln
    end;
    level := level + 1;
    DumpFieldList(v^.fields);
    if v^.tagField >= 0 then begin
      Pad;
      writeln('tagfield #', v^.tagField:1)
    end;
    DumpArmList(v^.variants, here);
    level := level - 1;
    i := i + 1;
    v := v^.next
  end
end;

{ The layout Sema gave a record: which struct each field lives in and at what
  position, and which tag values select each variant. Codegen indexes by
  exactly these numbers, so they are what a record type *is*. }
procedure DumpRecordLayout(r: typePtr);
begin
  Pad;
  writeln('layout');
  level := level + 1;
  DumpFieldList(r^.fields);
  if r^.tagField >= 0 then begin
    Pad;
    writeln('tagfield #', r^.tagField:1)
  end;
  DumpArmList(r^.variants, nil);
  level := level - 1
end;

procedure WriteSymKind(k: symKind);
begin
  case k of
    skConst:    write('const');
    skType:     write('type');
    skVar:      write('var');
    skParam:    write('param');
    skVarParam: write('varparam');
    skProcParam: write('procparam');
    skDisc:     write('disc');
    skProc:     write('proc');
    skFunc:     write('func');
    skSchema:   write('schema')
  end
end;

procedure WriteBinding(b: fileBinding);
begin
  case b of
    fbInternal:  write('internal');
    fbStdInput:  write('stdin');
    fbStdOutput: write('stdout');
    fbArgument:  write('arg')
  end
end;

{ One activation record: what ADR-0016 says codegen lays out, in the order it
  lays it out. The slot numbers are the whole point -- a name resolving to the
  right symbol but the wrong slot is a bug this catches. }
procedure DumpFrame(s: symPtr);
var v: symListPtr;
begin
  Pad;
  if s = nil then
    writeln('frame ?')
  else begin
    write('frame ');
    WritePool(s^.at, s^.len);
    writeln(' level ', s^.level:1);
    level := level + 1;
    v := s^.frameVars;
    while v <> nil do begin
      Pad;
      WriteSymKind(v^.sym^.kind);
      write(' ');
      WritePool(v^.sym^.at, v^.sym^.len);
      write(' #', v^.sym^.frameIndex:1, ' : ');
      WriteTypeName(v^.sym^.stype);
      { How a file reaches the world outside the program (ISO 7185 6.10). }
      if IsFile(v^.sym^.stype) then begin
        write(' (');
        WriteBinding(v^.sym^.binding);
        write(' ', v^.sym^.fileArg:1, ')')
      end;
      writeln;
      v := v^.next
    end;
    level := level - 1
  end
end;

procedure DumpFrames(b: nodePtr);
var d: nodePtr;
begin
  d := b^.blProcs;
  while d <> nil do begin
    DumpFrame(d^.pdSym);
    if d^.pdBody <> nil then DumpFrames(d^.pdBody);
    d := d^.next
  end
end;

procedure DumpExprList(n: nodePtr);
var p: nodePtr;
begin
  p := n;
  while p <> nil do begin
    DumpExpr(p);
    p := p^.next
  end
end;

{ A case-constant-list, in a case statement or in a variant. A single constant
  prints as the expression itself and a range wraps its two ends, so the shape
  says which without a tag -- the same way a set member does. }
procedure DumpCaseLabels(n: nodePtr);
var p: nodePtr;
begin
  p := n;
  while p <> nil do begin
    if p^.smHi = nil then
      DumpExpr(p^.smLo)
    else begin
      Pad;
      writeln('range');
      level := level + 1;
      DumpExpr(p^.smLo);
      DumpExpr(p^.smHi);
      level := level - 1
    end;
    p := p^.next
  end
end;

procedure DumpExpr;
var a: nodePtr;
begin
  Pad;
  case n^.kind of
    nkInt: begin
      write('int ', n^.intVal:1);
      WritePos(n^.line, n^.col);
      ExprEnd(n)
    end;
    nkReal: begin
      write('real ');
      WritePool(n^.rlAt, n^.rlLen);
      WritePos(n^.line, n^.col);
      ExprEnd(n)
    end;
    nkChar: begin
      write('char ', ord(n^.chVal):1);
      WritePos(n^.line, n^.col);
      ExprEnd(n)
    end;
    nkStr: begin
      write('str [');
      WritePool(n^.stAt, n^.stLen);
      write(']');
      WritePos(n^.line, n^.col);
      ExprEnd(n)
    end;
    nkNil: begin
      write('nil');
      WritePos(n^.line, n^.col);
      ExprEnd(n)
    end;
    nkSet: begin
      write('set');
      WritePos(n^.line, n^.col);
      ExprEnd(n);
      level := level + 1;
      a := n^.seMembers;
      DumpExprList(a);
      level := level - 1
    end;
    { A member with a second child is a range and one with a single child is a
      value, so the two tags are what keeps `[a, b]` and `[a..b]` from dumping
      identically. A member has no type of its own, so no position and no
      ExprEnd: the tree records neither. }
    nkSetMember: begin
      if n^.smHi = nil then writeln('member') else writeln('range');
      level := level + 1;
      DumpExpr(n^.smLo);
      if n^.smHi <> nil then DumpExpr(n^.smHi);
      level := level - 1
    end;
    nkVar: begin
      write('var ');
      WritePool(n^.vrAt, n^.vrLen);
      WritePos(n^.line, n^.col);
      if annotate then begin
        write(' -> ');
        WriteSymRef(n^.vrSym);
        { A name reached through an open `with` resolves to the hidden binding
          *plus* the field it selects, so both halves are printed. }
        if n^.vrField <> nil then
        begin
          write(' field #', n^.vrField^.index:1, '/');
          WriteVariantRef(n^.vrField^.variant)
        end
      end;
      ExprEnd(n)
    end;
    nkIndex: begin
      write('index');
      WritePos(n^.line, n^.col);
      ExprEnd(n);
      level := level + 1;
      DumpExpr(n^.ixBase);
      DumpExpr(n^.ixIndex);
      level := level - 1
    end;
    nkField: begin
      { A schema-discriminant shares this node with a field selection and
        resolves to neither a field nor an address, so it prints as what it
        is: the value the base's type was produced with. }
      if n^.fdIsDisc then write('discriminant ') else write('field ');
      WritePool(n^.fdAt, n^.fdLen);
      WritePos(n^.line, n^.col);
      if annotate then
        if n^.fdIsDisc then
          if n^.fdDiscSym <> nil then begin
            write(' -> ');
            WriteSymRef(n^.fdDiscSym)
          end
          else
            write(' -> = ', n^.fdDiscValue:1)
        else if n^.fdResolved <> nil then begin
          write(' -> #', n^.fdResolved^.index:1, '/');
          WriteVariantRef(n^.fdResolved^.variant)
        end
        else
          write(' -> ?');
      ExprEnd(n);
      level := level + 1;
      DumpExpr(n^.fdBase);
      level := level - 1
    end;
    nkDeref: begin
      write('deref');
      WritePos(n^.line, n^.col);
      ExprEnd(n);
      level := level + 1;
      DumpExpr(n^.drBase);
      level := level - 1
    end;
    nkBinary: begin
      write('binary ');
      WriteBinOp(n^.bnOp);
      WritePos(n^.line, n^.col);
      ExprEnd(n);
      level := level + 1;
      DumpExpr(n^.bnLhs);
      DumpExpr(n^.bnRhs);
      level := level - 1
    end;
    nkUnary: begin
      write('unary ');
      WriteUnOp(n^.unOp);
      WritePos(n^.line, n^.col);
      ExprEnd(n);
      level := level + 1;
      DumpExpr(n^.unArg);
      level := level - 1
    end;
    nkCall: begin
      write('call ');
      WritePool(n^.clAt, n^.clLen);
      WritePos(n^.line, n^.col);
      { Sema decides whether a call is a required function or a user one; the
        two are told apart here because nothing else in the tree says which. }
      if annotate then
        if n^.clBuiltin <> biNone then
          write(' -> builtin ', ord(n^.clBuiltin):1)
        else begin
          write(' -> ');
          WriteSymRef(n^.clSym)
        end;
      ExprEnd(n);
      level := level + 1;
      Pad;
      writeln('args');
      level := level + 1;
      a := n^.clArgs;
      DumpExprList(a);
      level := level - 2
    end
  end
end;

procedure DumpStmtList(n: nodePtr);
var p: nodePtr;
begin
  p := n;
  while p <> nil do begin
    DumpStmt(p);
    p := p^.next
  end
end;

procedure DumpStmt;
var p: nodePtr; rng: rangePtr;
begin
  Pad;
  case n^.kind of
    nkEmpty: begin
      write('empty');
      At(n^.line, n^.col)
    end;
    { A goto prints the id Sema resolved it to as well as the number: the
      number alone does not say which label, since two blocks may each declare
      label 1. }
    nkGoto: begin
      write('goto ', n^.gtLabel:1);
      WritePos(n^.line, n^.col);
      if annotate then begin
        write(' -> #', n^.gtId:1);
        if n^.gtNonLocal then write(' nonlocal')
      end;
      writeln
    end;
    nkLabeled: begin
      write('label ', n^.lbLabel:1);
      WritePos(n^.line, n^.col);
      if annotate then write(' -> #', n^.lbId:1);
      writeln;
      level := level + 1;
      DumpStmt(n^.lbStmt);
      level := level - 1
    end;
    nkAssign: begin
      write('assign');
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.asTarget);
      DumpExpr(n^.asValue);
      level := level - 1
    end;
    nkWrite: begin
      if n^.wrNewline then
        write('writeln')
      else
        write('write');
      At(n^.line, n^.col);
      level := level + 1;
      { Sema moves a leading file argument out of the list and supplies
        `output` when there was none, so after it the tree has a shape the
        parser never built. That change is the thing worth comparing. }
      if annotate then DumpOptional(n^.wrFile);
      p := n^.wrArgs;
      while p <> nil do begin
        { The flags say which optional parts follow, so a missing width and a
          missing precision cannot be confused for each other. }
        Pad;
        write('arg ');
        if p^.waWidth <> nil then write('w') else write('-');
        write(' ');
        if p^.waPrec <> nil then writeln('p') else writeln('-');
        level := level + 1;
        DumpExpr(p^.waValue);
        if p^.waWidth <> nil then
          DumpExpr(p^.waWidth);
        if p^.waPrec <> nil then
          DumpExpr(p^.waPrec);
        level := level - 1;
        p := p^.next
      end;
      level := level - 1
    end;
    nkRead: begin
      if n^.rdNewline then
        write('readln')
      else
        write('read');
      At(n^.line, n^.col);
      level := level + 1;
      if annotate then DumpOptional(n^.rdFile);
      Pad;
      writeln('args');
      level := level + 1;
      DumpExprList(n^.rdArgs);
      level := level - 2
    end;
    nkCompound: begin
      write('compound');
      At(n^.line, n^.col);
      level := level + 1;
      DumpStmtList(n^.cpBody);
      level := level - 1
    end;
    nkIf: begin
      write('if');
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.ifCond);
      DumpStmt(n^.ifThen);
      if n^.ifElse <> nil then begin
        Pad;
        writeln('else');
        DumpStmt(n^.ifElse)
      end;
      level := level - 1
    end;
    nkWhile: begin
      write('while');
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.whCond);
      DumpStmt(n^.whBody);
      level := level - 1
    end;
    nkRepeat: begin
      write('repeat');
      At(n^.line, n^.col);
      level := level + 1;
      Pad;
      writeln('body');
      level := level + 1;
      DumpStmtList(n^.rpBody);
      level := level - 1;
      Pad;
      writeln('until');
      level := level + 1;
      DumpExpr(n^.rpCond);
      level := level - 2
    end;
    nkFor: begin
      if n^.frDownto then
        write('for downto')
      else
        write('for to');
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.frVar);
      DumpExpr(n^.frFrom);
      DumpExpr(n^.frTo);
      DumpStmt(n^.frBody);
      level := level - 1
    end;
    nkWith: begin
      write('with');
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.wtRecord);
      DumpStmt(n^.wtBody);
      level := level - 1
    end;
    nkCase: begin
      write('case');
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.csSelector);
      p := n^.csArms;
      while p <> nil do begin
        Pad;
        write('arm');
        At(p^.line, p^.col);
        level := level + 1;
        Pad;
        writeln('labels');
        level := level + 1;
        DumpCaseLabels(p^.caLabels);
        level := level - 1;
        { The folded label values: this is where constant folding of an ordinal
          is compared, and a label the checker rejected leaves a gap. }
        if annotate then begin
          Pad;
          write('values');
          rng := p^.caValues;
          while rng <> nil do begin
            if rng^.lo = rng^.hi then
              write(' ', rng^.lo:1)
            else
              write(' ', rng^.lo:1, '..', rng^.hi:1);
            rng := rng^.next
          end;
          writeln
        end;
        Pad;
        writeln('body');
        level := level + 1;
        DumpStmt(p^.caBody);
        level := level - 2;
        p := p^.next
      end;
      { Present but empty is not the same as absent: `otherwise` with nothing
        after it says "and otherwise do nothing", which does not trap. }
      if n^.csHasOtherwise then begin
        Pad;
        writeln('otherwise');
        level := level + 1;
        p := n^.csOtherwise;
        while p <> nil do begin
          DumpStmt(p);
          p := p^.next
        end;
        level := level - 1
      end;
      level := level - 1
    end;
    nkProcCall: begin
      write('proccall ');
      WritePool(n^.pcAt, n^.pcLen);
      if annotate then begin
        if n^.pcStd <> spNone then
          write(' -> standard ', ord(n^.pcStd):1)
        else begin
          write(' -> ');
          WriteSymRef(n^.pcSym)
        end;
        { The arms `new(p, c1, ...)` selects, which is what Sema folded the tag
          values down to and what decides how much is allocated. }
        if n^.pcSelect <> nil then begin
          write(' variants ');
          WriteVariantRef(n^.pcSelect)
        end
      end;
      At(n^.line, n^.col);
      level := level + 1;
      Pad;
      writeln('args');
      level := level + 1;
      DumpExprList(n^.pcArgs);
      level := level - 2
    end
  end
end;

procedure DumpNames(n: nodePtr);
var p: nodePtr;
begin
  Pad;
  writeln('names');
  level := level + 1;
  p := n;
  while p <> nil do begin
    Pad;
    write('name ');
    WritePool(p^.dnAt, p^.dnLen);
    At(p^.line, p^.col);
    p := p^.next
  end;
  level := level - 1
end;

{ A group of names sharing one type-denoter -- record fields, variables and
  parameters are all this shape, and they share it in the AST because they
  share it in the source (ISO 7185 6.4.5). }
procedure DumpGroupList(n: nodePtr; asVar: boolean); forward;

{ A procedural or functional parameter is a heading rather than a
  type-denoter (ISO 7185 6.6.3.1), so it prints its own parameter list --
  which is the recursion the grammar has. }
procedure DumpGroup(g: nodePtr; asVar: boolean);
begin
  Pad;
  if g^.grIsProc then begin
    if g^.grIsFunction then write('funcparam ') else write('procparam ');
    WritePool(g^.grNames^.dnAt, g^.grNames^.dnLen);
    At(g^.grNames^.line, g^.grNames^.col);
    level := level + 1;
    Pad;
    writeln('params');
    level := level + 1;
    DumpGroupList(g^.grParams, false);
    level := level - 1;
    if g^.grResult <> nil then begin
      Pad;
      writeln('result');
      level := level + 1;
      DumpTypeExpr(g^.grResult);
      level := level - 1
    end;
    level := level - 1
  end
  else begin
  if asVar then
    writeln('var')
  { The tag spells the specification back: `protected` precedes `var` in the
    source (ISO/IEC 10206:1991 6.7.3.1) and precedes it here. }
  else if g^.grIsProtected and g^.grByRef then
    writeln('group protected var')
  else if g^.grIsProtected then
    writeln('group protected')
  else if g^.grByRef then
    writeln('group var')
  else
    writeln('group');
  level := level + 1;
  DumpNames(g^.grNames);
  Pad;
  writeln('type');
  level := level + 1;
  DumpTypeExpr(g^.grType);
  level := level - 2
  end
end;

procedure DumpGroupList;
var p: nodePtr;
begin
  p := n;
  while p <> nil do begin
    DumpGroup(p, asVar);
    p := p^.next
  end
end;

{ A variant part as the parser built it: the tag, and one `arm` per variant.
  An arm's field-list is a field-list like any other, so it may end with a
  variant part of its own and this recurses into it. }
procedure DumpVariantPart(tagAt, tagLen, tagLine, tagCol: integer;
                          tagType, arms: nodePtr);
var p: nodePtr;
begin
  { An empty tag name is the `case T of` form, where the tag exists as a type
    but not as a field (ISO 7185 6.4.3.3); '-' says so, and no field could be
    spelled that. }
  Pad;
  write('tag ');
  if tagLen = 0 then
    write('-')
  else
    WritePool(tagAt, tagLen);
  At(tagLine, tagCol);
  level := level + 1;
  DumpTypeExpr(tagType);
  p := arms;
  while p <> nil do begin
    Pad;
    write('arm');
    At(p^.line, p^.col);
    level := level + 1;
    Pad;
    if p^.vaOtherwise then writeln('otherwise') else writeln('labels');
    level := level + 1;
    DumpCaseLabels(p^.vaLabels);
    level := level - 1;
    Pad;
    writeln('fields');
    level := level + 1;
    DumpGroupList(p^.vaFields, false);
    level := level - 1;
    if p^.vaTagType <> nil then
      DumpVariantPart(p^.vaTagAt, p^.vaTagLen, p^.vaTagLine, p^.vaTagCol,
                      p^.vaTagType, p^.vaVariants);
    level := level - 1;
    p := p^.next
  end;
  level := level - 1
end;

procedure DumpTypeExpr;
var p: nodePtr;
begin
  Pad;
  case n^.kind of
    nkNamed: begin
      write('named ');
      WritePool(n^.nmAt, n^.nmLen);
      WritePos(n^.line, n^.col);
      TypeEnd(n)
    end;
    { A discriminated-schema's children are *expressions*, not denoters: it is
      the only type-denoter whose subtree holds values rather than types. }
    nkSchema: begin
      write('schema ');
      WritePool(n^.scAt, n^.scLen);
      WritePos(n^.line, n^.col);
      TypeEnd(n);
      level := level + 1;
      DumpExprList(n^.scArgs);
      level := level - 1
    end;
    nkPointer: begin
      write('pointer ');
      WritePool(n^.ptAt, n^.ptLen);
      WritePos(n^.line, n^.col);
      TypeEnd(n)
    end;
    { A type-inquiry names a *variable*, so it prints like `named` and means
      something else entirely -- which is why it gets its own tag rather than
      being folded into one. }
    nkInquiry: begin
      write('typeof ');
      WritePool(n^.tqAt, n^.tqLen);
      WritePos(n^.line, n^.col);
      TypeEnd(n)
    end;
    nkEnum: begin
      write('enum');
      WritePos(n^.line, n^.col);
      TypeEnd(n);
      level := level + 1;
      DumpNames(n^.enConstants);
      level := level - 1
    end;
    nkSubrange: begin
      write('subrange');
      WritePos(n^.line, n^.col);
      TypeEnd(n);
      level := level + 1;
      DumpExpr(n^.sbLo);
      DumpExpr(n^.sbHi);
      level := level - 1
    end;
    nkFile: begin
      write('file');
      if n^.flPacked then write(' packed');
      WritePos(n^.line, n^.col);
      TypeEnd(n);
      level := level + 1;
      DumpTypeExpr(n^.flElem);
      level := level - 1
    end;
    nkSetOf: begin
      write('set');
      if n^.soPacked then write(' packed');
      WritePos(n^.line, n^.col);
      TypeEnd(n);
      level := level + 1;
      DumpTypeExpr(n^.soElem);
      level := level - 1
    end;
    nkArray: begin
      write('array');
      if n^.arPacked then write(' packed');
      WritePos(n^.line, n^.col);
      TypeEnd(n);
      level := level + 1;
      Pad;
      writeln('dims');
      level := level + 1;
      p := n^.arDims;
      while p <> nil do begin
        DumpTypeExpr(p);
        p := p^.next
      end;
      level := level - 1;
      Pad;
      writeln('elem');
      level := level + 1;
      DumpTypeExpr(n^.arElem);
      level := level - 2
    end;
    nkRecord: begin
      write('record');
      if n^.rcPacked then write(' packed');
      WritePos(n^.line, n^.col);
      TypeEnd(n);
      level := level + 1;
      if annotate then
        if IsRecord(n^.ntype) then
          DumpRecordLayout(n^.ntype);
      Pad;
      writeln('fields');
      level := level + 1;
      DumpGroupList(n^.rcFields, false);
      level := level - 1;
      if n^.rcTagType <> nil then
        DumpVariantPart(n^.rcTagAt, n^.rcTagLen, n^.rcTagLine, n^.rcTagCol,
                        n^.rcTagType, n^.rcVariants);
      level := level - 1
    end
  end
end;

procedure DumpProc(d: nodePtr);
begin
  Pad;
  if d^.pdIsFunction then
    write('func ')
  else
    write('proc ');
  WritePool(d^.pdAt, d^.pdLen);
  At(d^.line, d^.col);
  level := level + 1;
  Pad;
  writeln('params');
  level := level + 1;
  DumpGroupList(d^.pdParams, false);
  level := level - 1;
  if d^.pdResult <> nil then begin
    Pad;
    writeln('result');
    level := level + 1;
    DumpTypeExpr(d^.pdResult);
    level := level - 1
  end;
  { A forward declaration has no body, and the completion that follows it
    repeats neither the parameters nor the result type (ISO 7185 6.6.1). }
  if d^.pdIsForward then begin
    Pad;
    writeln('forward')
  end
  else
    DumpBlock(d^.pdBody);
  level := level - 1
end;

procedure DumpBlock;
var p, g: nodePtr;
begin
  Pad;
  writeln('block');
  level := level + 1;
  Pad;
  writeln('labels');
  level := level + 1;
  p := n^.blLabels;
  while p <> nil do begin
    Pad;
    write('label ', p^.ldNumber:1);
    At(p^.line, p^.col);
    p := p^.next
  end;
  level := level - 1;
  Pad;
  writeln('consts');
  level := level + 1;
  p := n^.blConsts;
  while p <> nil do begin
    Pad;
    write('const ');
    WritePool(p^.kdAt, p^.kdLen);
    At(p^.line, p^.col);
    level := level + 1;
    DumpExpr(p^.kdValue);
    level := level - 1;
    p := p^.next
  end;
  level := level - 1;
  Pad;
  writeln('types');
  level := level + 1;
  p := n^.blTypes;
  while p <> nil do begin
    Pad;
    if p^.tdDiscs = nil then write('type ') else write('schema ');
    WritePool(p^.tdAt, p^.tdLen);
    At(p^.line, p^.col);
    level := level + 1;
    { The formal discriminants come first, in the order that fixes the tuple's
      positions -- which is the only thing about them a reader could need. }
    g := p^.tdDiscs;
    while g <> nil do begin
      Pad;
      write('discriminant ');
      WritePool(g^.grType^.nmAt, g^.grType^.nmLen);
      writeln;
      level := level + 1;
      DumpNames(g^.grNames);
      level := level - 1;
      g := g^.next
    end;
    DumpTypeExpr(p^.tdType);
    level := level - 1;
    p := p^.next
  end;
  level := level - 1;
  Pad;
  writeln('vars');
  level := level + 1;
  DumpGroupList(n^.blVars, true);
  level := level - 1;
  Pad;
  writeln('procs');
  level := level + 1;
  p := n^.blProcs;
  while p <> nil do begin
    DumpProc(p);
    p := p^.next
  end;
  level := level - 1;
  Pad;
  writeln('body');
  level := level + 1;
  DumpStmt(n^.blBody);
  level := level - 2
end;

{ The token stream, in the format `pascalc --dump-tokens` writes. The lexer of
  component 1 emitted these as it scanned; here they are read back out of the
  table the parser was given, which is the same stream by another route. }
procedure DumpTokens;
var i: integer;
begin
  for i := 1 to tokCount do begin
    write(tok[i].line:1, ' ', tok[i].col:1, ' ');
    case tok[i].kind of
      tkEof: writeln('eof');
      tkIdent: begin
        write('ident ');
        WritePool(tok[i].at, tok[i].len);
        writeln
      end;
      tkInt:
        { A literal that does not fit was rejected, and printing whatever the
          conversion left behind would compare two accidents. }
        if tok[i].tooBig then writeln('int ?')
        else writeln('int ', tok[i].intVal:1);
      tkReal: begin
        write('real ');
        WritePool(tok[i].at, tok[i].len);
        writeln
      end;
      tkStr: begin
        write('str [');
        WritePool(tok[i].at, tok[i].len);
        writeln(']')
      end;
      tkPlus, tkMinus, tkStar, tkSlash, tkAssign, tkComma, tkSemi, tkColon,
      tkPeriod, tkDotDot, tkLParen, tkRParen, tkLBracket, tkRBracket, tkCaret,
      tkEq, tkNotEq, tkLt, tkLe, tkGt, tkGe, tkStarStar: begin
        write('op ');
        WriteOperator(tok[i].kind);
        writeln
      end;
      tkAnd, tkArray, tkBegin, tkCase, tkConst, tkDiv, tkDo, tkDownto, tkElse,
      tkEnd, tkFile, tkFor, tkFunction, tkGoto, tkIf, tkIn, tkLabel, tkMod,
      tkNil, tkNot, tkOf, tkOr, tkPacked, tkProcedure, tkProgram, tkRecord,
      tkRepeat, tkSet, tkThen, tkTo, tkType, tkUntil, tkVar, tkWhile,
      tkWith, tkOtherwise, tkPow, tkProtected, tkValue, tkBindable: begin
        write('kw ');
        WriteKeyword(tok[i].kind);
        writeln
      end;
      { the two-word word-symbols are in no keyword table -- nothing looks
        them up -- so their spelling is written out here }
      tkAndThen: writeln('kw and then');
      tkOrElse: writeln('kw or else')
    end
  end
end;

procedure DumpProgram;
var p: nodePtr;
begin
  write('program ');
  WritePool(progAt, progLen);
  writeln;
  level := 1;
  Pad;
  writeln('params');
  level := 2;
  p := progParams;
  while p <> nil do begin
    Pad;
    write('name ');
    WritePool(p^.dnAt, p^.dnLen);
    At(p^.line, p^.col);
    p := p^.next
  end;
  if annotate then begin
    level := 1;
    Pad;
    writeln('frames');
    level := 2;
    { The program's own frame first: at level 0 it holds what another language
      would call the globals, which is ADR-0016's point. }
    DumpFrame(programSym);
    DumpFrames(progBlock)
  end;
  level := 1;
  DumpBlock(progBlock)
end;

{ Every stage, in one pass, with a header before each. There is one program
  because there is one source file, so there is no mode to select: what the
  C++ driver does with --dump-all, this does by running.

  Each section reports what its own stage found and then shows its result, and
  only when nothing was found -- a stage that failed has nothing to show, and
  the stages after it do not run. }
{ ========================================================================== }
{ CodeGen -- the annotated tree, written out as textual LLVM IR.

  ADR-0006 kept the textual backend a first-class output precisely so that this
  component could exist: a compiler written in Pascal cannot call LLVM's C++
  API, so what survives the rewrite is the assembler text.

  Three things follow from writing text instead of building a module.

  * The emitter is *sequential*. It works because the C++ builder never returns
    to a basic block it has left: every SetInsertPoint moves to a block that is
    then filled to its terminator. So the order the C++ emits instructions in
    is exactly the order they can be printed in, and no instruction list is
    needed here at all.

  * A global cannot be written in the middle of a function, so the string
    constants a program needs -- every runtime-error message, every file name,
    every string literal -- are given a number when they are used and their
    text is written after the last function. LLVM resolves the forward
    reference.

  * Types are printed structurally, inline. A Pascal type can only contain
    itself through a pointer, and opaque pointers make every pointer `ptr`, so
    nothing here is recursive and no named type is needed. The activation
    records are the exception -- one is printed at every variable access, and a
    frame with forty slots would be forty slots of text each time -- so those
    get a name apiece, emitted before any function that uses one. }
{ ========================================================================== }

{ --------------------------------------------------------- the data layout }

{ The C++ asks LLVM's DataLayout; there is no one to ask here, so the rules are
  written out. They are only needed in two places -- the length of a whole-
  variable copy and the size `new` allocates -- because a getelementptr names
  the type it indexes and LLVM does the arithmetic. }

function RoundUp(n, a: integer): integer;
begin
  RoundUp := ((n + a - 1) div a) * a
end;

function LlSize(t: typePtr): integer; forward;
function LlAlign(t: typePtr): integer; forward;
procedure ArmLayoutAt(rec: typePtr; path: numPtr;
                      var size, align: integer); forward;
procedure VariantStorageAt(rec: typePtr; path: numPtr;
                           var size, align: integer); forward;

{ The arm a path names. Each step selects an arm of the variant part it is in;
  a further step goes into the variant part nested inside that arm. }
function ArmAt(rec: typePtr; path: numPtr): variantPtr;
var v: variantPtr; k: integer;
begin
  v := rec^.variants;
  while path <> nil do begin
    k := 0;
    while k < path^.value do begin
      v := v^.next;
      k := k + 1
    end;
    if path^.next <> nil then v := v^.variants;
    path := path^.next
  end;
  ArmAt := v
end;

{ The arms of the variant part at `path`, and the fields of the field-list
  there. An empty path is the record itself; an arm's field-list is a
  field-list like any other (ISO 7185 6.4.3.3), which is what makes one pair of
  functions serve both. }
function ArmsAt(rec: typePtr; path: numPtr): variantPtr;
var a: variantPtr;
begin
  if path = nil then
    ArmsAt := rec^.variants
  else begin
    a := ArmAt(rec, path);
    ArmsAt := a^.variants
  end
end;

function FieldsAt(rec: typePtr; path: numPtr): fieldPtr;
var a: variantPtr;
begin
  if path = nil then
    FieldsAt := rec^.fields
  else begin
    a := ArmAt(rec, path);
    FieldsAt := a^.fields
  end
end;

{ The struct a field-list is: its own fields, and -- when it ends with a
  variant part -- the shared storage for that part as a last member. The record
  and every arm are laid out by this one routine, because they have the same
  shape. }
procedure ArmLayoutAt;
var f: fieldPtr; a, ssize, salign: integer;
begin
  size := 0;
  align := 1;
  f := FieldsAt(rec, path);
  while f <> nil do begin
    a := LlAlign(f^.ftype);
    size := RoundUp(size, a) + LlSize(f^.ftype);
    if a > align then align := a;
    f := f^.next
  end;
  if ArmsAt(rec, path) <> nil then begin
    VariantStorageAt(rec, path, ssize, salign);
    size := RoundUp(size, salign) + ssize;
    if salign > align then align := salign
  end;
  size := RoundUp(size, align)
end;

{ The shared storage every arm at `path` is laid over: big enough for the
  largest and aligned for the strictest. }
procedure VariantStorageAt;
var v: variantPtr; s, a, i: integer; sub: numPtr;
begin
  size := 0;
  align := 1;
  v := ArmsAt(rec, path);
  i := 0;
  while v <> nil do begin
    sub := PathAppend(path, i);
    ArmLayoutAt(rec, sub, s, a);
    if s > size then size := s;
    if a > align then align := a;
    i := i + 1;
    v := v^.next
  end;
  if size = 0 then align := 1 else size := RoundUp(size, align)
end;

procedure RecordLayout(t: typePtr; var size, align: integer);
begin
  ArmLayoutAt(t, nil, size, align)
end;

{ The bytes a record needs when only the arms `selection` names can be stored
  in it -- `new(p, c1, ..., cn)`. The offsets are the full type's, so every
  selected field still lies where the full layout puts it; only the tail, which
  the unselected (possibly larger) arms would have needed, is trimmed off. }
function SelectedSize(rec: typePtr; path, selection: numPtr): integer;
var f: fieldPtr; size, align, a, ssize, salign: integer;
begin
  if (selection = nil) or (ArmsAt(rec, path) = nil) then begin
    { nothing left to select, or nothing to select from: the whole struct,
      shared storage and all }
    ArmLayoutAt(rec, path, size, align);
    SelectedSize := size
  end
  else begin
    size := 0;
    align := 1;
    f := FieldsAt(rec, path);
    while f <> nil do begin
      a := LlAlign(f^.ftype);
      size := RoundUp(size, a) + LlSize(f^.ftype);
      if a > align then align := a;
      f := f^.next
    end;
    { the storage starts where the full layout puts it, so the fields before it
      keep their offsets }
    VariantStorageAt(rec, path, ssize, salign);
    size := RoundUp(size, salign);
    SelectedSize := size +
        SelectedSize(rec, PathAppend(path, selection^.value), selection^.next)
  end
end;

function LlAlign;
var b: typePtr; s, a: integer;
begin
  b := Base(t);
  if b = nil then
    LlAlign := 1
  else
    case b^.kind of
      tyVoid, tyBoolean, tyChar, tySubrange: LlAlign := 1;
      tyInteger, tyEnum: LlAlign := 4;
      tyReal, tyPointer, tyFile: LlAlign := 8;
      { <2 x double>: two doubles, and the target aligns a vector to its whole
        size. }
      tyComplex: LlAlign := 16;
      tyString: LlAlign := 4;
      { LLVM aligns an i256 to 16: the datalayout names no alignment for it, so
        it takes the largest one that is named, which is i128's. }
      tySet: LlAlign := 16;
      { A procedural parameter is a pair of pointers: the code, and the static
        link to call it with. }
      tyProc: LlAlign := 8;
      tyArray: LlAlign := LlAlign(b^.elem);
      tyRecord: begin
        RecordLayout(b, s, a);
        LlAlign := a
      end
    end
end;

function LlSize;
var b: typePtr; s, a: integer;
begin
  b := Base(t);
  if b = nil then
    LlSize := 0
  else
    case b^.kind of
      tyVoid, tySubrange: LlSize := 0;
      tyBoolean, tyChar: LlSize := 1;
      tyInteger, tyEnum: LlSize := 4;
      tyReal, tyPointer: LlSize := 8;
      tyComplex: LlSize := 16;
      { A length beside a buffer: the shape ADR-0045 made expressible. Rounded
        to the alignment like every other type, and it has to be -- a record
        holding one puts its next field after the *rounded* size, so a short
        answer here leaves that field outside a whole-record copy. }
      tyString:
        if b^.hi > 0 then LlSize := RoundUp(4 + b^.hi, 4) else LlSize := 4;
      tyFile: LlSize := fileSize;
      tySet: LlSize := setBits div 8;
      tyProc: LlSize := 16;
      tyArray: LlSize := TypeLength(b) * LlSize(b^.elem);
      tyRecord: begin
        RecordLayout(b, s, a);
        LlSize := s
      end
    end
end;

{ ------------------------------------------------------------- LLVM types }

procedure PutLlType(t: typePtr); forward;
procedure PutStructAt(rec: typePtr; path: numPtr); forward;

{ LLVM has no union, so the variant part is one block of storage. The element
  type is what carries the alignment: [k x i64] is 8-aligned where [n x i8]
  would be 1-aligned and would misalign a real inside a variant. }
procedure PutStorageTypeAt(rec: typePtr; path: numPtr);
var size, align: integer;
begin
  VariantStorageAt(rec, path, size, align);
  if size = 0 then
    write(ircode, '[0 x i8]')
  else
    write(ircode, '[', size div align:1, ' x i', align * 8:1, ']')
end;

procedure PutStructAt;
var f: fieldPtr; first: boolean;
begin
  write(ircode, '{ ');
  first := true;
  f := FieldsAt(rec, path);
  while f <> nil do begin
    if not first then write(ircode, ', ');
    PutLlType(f^.ftype);
    first := false;
    f := f^.next
  end;
  if ArmsAt(rec, path) <> nil then begin
    if not first then write(ircode, ', ');
    PutStorageTypeAt(rec, path)
  end;
  write(ircode, ' }')
end;

procedure PutLlType;
var b: typePtr;
begin
  b := Base(t);
  if b = nil then
    write(ircode, 'void')
  else
    case b^.kind of
      tyVoid, tySubrange: write(ircode, 'void');
      { An enumeration is its ordinal number; a subrange is represented exactly
        as its host, which is what Base already looked through to. }
      tyInteger, tyEnum: write(ircode, 'i32');
      tyReal: write(ircode, 'double');
      tyBoolean: write(ircode, 'i1');
      tyChar: write(ircode, 'i8');
      tyPointer: write(ircode, 'ptr');
      { A file variable is an opaque block of storage the runtime owns; all the
        compiler needs is its size, and i64 elements give it the alignment a
        struct full of pointers needs. }
      tyFile: write(ircode, '[', fileSize div 8:1, ' x i64]');
      { Every set is the same 256-bit integer whatever its base type: one bit
        per possible member, which is what makes the operators single
        instructions and keeps a set a *value* (ADR-0028). }
      tySet: write(ircode, 'i', setBits:1);
      { A procedural parameter is a pair: the code to call, and the static link
        to call it with. Both halves are needed because a procedure passed as
        an argument carries the scope it was *declared* in, not the one it is
        called from -- which is the whole difficulty of the feature. }
      tyProc: write(ircode, '{ ptr, ptr }');
      { ISO/IEC 10206:1991 6.4.2.2 e) makes `complex` a *simple* type, so it
        must be a value and not a thing reached through its address. A
        two-element vector is the one shape that is both: LLVM lowers it in
        registers, and neither backend has to hold an opinion about how a
        struct is passed -- which is the constraint ADR-0030 named and settled
        the same way. }
      tyComplex: write(ircode, '<2 x double>');
      { 6.4.3.3.3: a variable-string-type's value is a length and that many
        characters. The layout is ADR-0045's -- a length beside a buffer whose
        capacity is the discriminant -- so a string whose capacity arrives with
        the actual is that record's flexible array member and DynSize needs no
        new case. }
      tyString: begin
        write(ircode, '{ i32, [');
        if b^.hi > 0 then write(ircode, b^.hi:1) else write(ircode, '0');
        write(ircode, ' x i8] }')
      end;
      tyArray: begin
        { The bounds are folded away: an index is lowered to an offset from the
          lower bound, so the type only needs the extent. }
        write(ircode, '[', TypeLength(b):1, ' x ');
        PutLlType(b^.elem);
        write(ircode, ']')
      end;
      tyRecord: PutStructAt(b, nil)
    end
end;

{ ---------------------------------------------------------------- operands }

{ An operand is its text: `%v7`, `42`, `3.5`, `null`, `@s3`. Keeping it as text
  is what lets a constant be an operand without an instruction to materialise
  it, and ISO 7185 6.6.2 forbids a function returning a record, so these are
  filled through a var parameter rather than returned. }

procedure AppendInt(var s: str; v: integer);
var digits: array [1..12] of char; n, k: integer; negative: boolean;
begin
  negative := v < 0;
  n := 0;
  if negative then v := -v;
  if v = 0 then begin
    n := 1;
    digits[1] := '0'
  end;
  while v > 0 do begin
    n := n + 1;
    digits[n] := chr(ord('0') + v mod 10);
    v := v div 10
  end;
  if negative then StrAppend(s, '-');
  for k := n downto 1 do
    StrAppend(s, digits[k])
end;

procedure AppendLit(var s: str; w: msgLit);
var n, k: integer;
begin
  n := msgWidth;
  while (n > 0) and (w[n] = ' ') do
    n := n - 1;
  for k := 1 to n do
    StrAppend(s, w[k])
end;

procedure OpInt(n: integer; var v: str);
begin
  StrClear(v);
  AppendInt(v, n)
end;

procedure OpWord(w: msgLit; var v: str);
begin
  StrClear(v);
  AppendLit(v, w)
end;

procedure OpReg(r: integer; var v: str);
begin
  StrClear(v);
  StrAppend(v, '%');
  StrAppend(v, 'v');
  AppendInt(v, r)
end;

procedure OpGlobal(id: integer; var v: str);
begin
  StrClear(v);
  StrAppend(v, '@');
  StrAppend(v, 's');
  AppendInt(v, id)
end;

procedure PutOp(var v: str);
var k: integer;
begin
  for k := 1 to v.len do
    write(ircode, v.ch[k])
end;

{ Open an instruction line that defines a fresh value: `  %vN = `. }
procedure Def(var v: str);
begin
  nextReg := nextReg + 1;
  OpReg(nextReg, v);
  write(ircode, '  ');
  PutOp(v);
  write(ircode, ' = ')
end;

function NewBlock: integer;
begin
  nextBlock := nextBlock + 1;
  NewBlock := nextBlock
end;

procedure StartBlock(b: integer);
begin
  writeln(ircode, 'L', b:1, ':');
  curBlock := b
end;

{ The block a label denotes. Created on first mention, which may be either the
  labelled statement or a goto to it -- a forward jump reaches here before the
  statement it targets exists. }
function LabelBlock(id: integer): integer;
var p: labelBlockPtr;
begin
  p := labelBlocks;
  while (p <> nil) and (p^.lid <> id) do
    p := p^.next;
  if p = nil then begin
    new(p);
    p^.lid := id;
    p^.blk := NewBlock;
    p^.next := labelBlocks;
    labelBlocks := p
  end;
  LabelBlock := p^.blk
end;

{ ------------------------------------------------------- string constants }

{ A global cannot be written inside a function, so it is numbered here and its
  text written after the last one. }
function AddGlobal(at, len: integer): integer;
var g: strConstPtr;
begin
  new(g);
  nextStr := nextStr + 1;
  g^.id := nextStr;
  g^.at := at;
  g^.len := len;
  g^.next := nil;
  if strHead = nil then strHead := g else strTail^.next := g;
  strTail := g;
  AddGlobal := nextStr
end;

{ A runtime-error message is built before it is emitted, so the sink is turned
  round for the length of the building. }
procedure MsgStart;
begin
  msgOut := true;
  StrClear(msgBuf)
end;

procedure MsgText(w: textLit);
var n, k: integer;
begin
  n := textWidth;
  while (n > 0) and (w[n] = ' ') do
    n := n - 1;
  for k := 1 to n do
    StrAppend(msgBuf, w[k])
end;

function MsgEnd: integer;
var at: integer;
begin
  msgOut := false;
  at := PoolAdd(msgBuf);
  MsgEnd := AddGlobal(at, msgBuf.len)
end;

procedure PutHex(v: integer);
var d: integer;
begin
  d := v div 16;
  if d < 10 then write(ircode, chr(ord('0') + d))
  else write(ircode, chr(ord('A') + d - 10));
  d := v mod 16;
  if d < 10 then write(ircode, chr(ord('0') + d))
  else write(ircode, chr(ord('A') + d - 10))
end;

procedure EmitGlobals;
var g: strConstPtr; k: integer; c: char;
begin
  g := strHead;
  while g <> nil do begin
    write(ircode, '@s', g^.id:1, ' = private unnamed_addr constant [',
          g^.len + 1:1, ' x i8] c"');
    for k := g^.at to g^.at + g^.len - 1 do begin
      c := pool[k];
      if (c = '"') or (c = '\') or (ord(c) < 32) or (ord(c) >= 127) then begin
        write(ircode, '\');
        PutHex(ord(c))
      end
      else
        write(ircode, c)
    end;
    writeln(ircode, '\00"');
    g := g^.next
  end
end;

{ -------------------------------------------------------- traps and checks }

procedure EmitTrapIf(var cond: str; msg: integer);
var t, c: integer;
begin
  t := NewBlock;
  c := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', t:1, ', label %L', c:1);
  StartBlock(t);
  writeln(ircode, '  call void @pas_runtime_error(ptr @s', msg:1, ')');
  writeln(ircode, '  unreachable');
  StartBlock(c)
end;

{ The same shape, for a trap whose message cannot be written here: the runtime
  formats it out of values only the running program has. }
procedure EmitTrapIndex(var cond, lo, hi: str);
var t, c: integer;
begin
  t := NewBlock;
  c := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', t:1, ', label %L', c:1);
  StartBlock(t);
  write(ircode, '  call void @pas_index_error(i32 ');
  PutOp(lo);
  write(ircode, ', i32 ');
  PutOp(hi);
  writeln(ircode, ')');
  writeln(ircode, '  unreachable');
  StartBlock(c)
end;

{ And again for 6.7.2.5's equal-length requirement, where one of the lengths is
  a discriminant and neither is known until the program runs. }
procedure EmitTrapLength(var cond, left, right: str);
var t, c: integer;
begin
  t := NewBlock;
  c := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', t:1, ', label %L', c:1);
  StartBlock(t);
  write(ircode, '  call void @pas_length_error(i32 ');
  PutOp(left);
  write(ircode, ', i32 ');
  PutOp(right);
  writeln(ircode, ')');
  writeln(ircode, '  unreachable');
  StartBlock(c)
end;

{ The same shape again, for 6.4.6 d): the schema and the discriminant are named
  where the program is compiled and their values are known only where it runs,
  so the message is assembled out of two string constants and two integers. }
procedure EmitTrapDisc(var cond: str; schemaMsg, discMsg: integer;
                       var l, r: str);
var t, c: integer;
begin
  t := NewBlock;
  c := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', t:1, ', label %L', c:1);
  StartBlock(t);
  write(ircode, '  call void @pas_disc_error(ptr @s', schemaMsg:1,
        ', ptr @s', discMsg:1, ', i32 ');
  PutOp(l);
  write(ircode, ', i32 ');
  PutOp(r);
  writeln(ircode, ')');
  writeln(ircode, '  unreachable');
  StartBlock(c)
end;

{ ------------------------------------------------------- the static chain }

{ The activation record `levels` deep in the static chain from here. The link
  is field 0 of every frame, so it sits at offset zero and can be loaded from
  the frame pointer without knowing which procedure's struct this level has. }
procedure FrameAt(lev: integer; var v: str);
var l: integer; cur, nxt: str;
begin
  StrClear(cur);
  StrAppend(cur, '%');
  AppendLit(cur, 'frame           ');
  for l := irLevel downto lev + 1 do begin
    Def(nxt);
    write(ircode, 'load ptr, ptr ');
    PutOp(cur);
    writeln(ircode);
    cur := nxt
  end;
  v := cur
end;

{ The jump record is the field after the last variable. Only called for a
  procedure whose nlLabels is non-empty. }
procedure JumpRecord(p: symPtr; var frame: str; var v: str);
begin
  Def(v);
  write(ircode, 'getelementptr inbounds %frame', p^.irId:1, ', ptr ');
  PutOp(frame);
  writeln(ircode, ', i32 0, i32 ', 1 + p^.frameCount:1)
end;

procedure FrameSlot(s: symPtr; var v: str);
var f: str;
begin
  FrameAt(s^.level, f);
  Def(v);
  write(ircode, 'getelementptr inbounds %frame', s^.owner^.irId:1, ', ptr ');
  PutOp(f);
  writeln(ircode, ', i32 0, i32 ', 1 + s^.frameIndex:1)
end;

{ The descriptor a schematic formal parameter travels as: the address of the
  actual, and then its tuple, one discriminant per field in the schema's own
  order. Like the procedural pair it never exists as a value -- the parts are
  stored and loaded through their own getelementptrs and travel as separate
  arguments -- so a caller and a callee agree by both coming through here
  (ADR-0030's shape, and for the same reason). }
procedure PutDescType(param: symPtr);
var p: symListPtr;
begin
  write(ircode, '{ ptr');
  p := param^.descSchema^.discs;
  while p <> nil do begin
    write(ircode, ', ');
    PutLlType(p^.sym^.stype);
    p := p^.next
  end;
  write(ircode, ' }')
end;

{ The arguments one schematic formal parameter contributes: the address, and
  then the tuple, so the descriptor is assembled by the callee and never passed
  as a struct. }
procedure PutDescParamTypes(s: symPtr; named: boolean; var k: integer);
var p: symListPtr;
begin
  write(ircode, 'ptr');
  if named then write(ircode, ' %a', k:1);
  k := k + 1;
  p := s^.descSchema^.discs;
  while p <> nil do begin
    write(ircode, ', ');
    PutLlType(p^.sym^.stype);
    if named then write(ircode, ' %a', k:1);
    k := k + 1;
    p := p^.next
  end
end;

{ The frame variable at this index, which is what a discriminant's frameIndex
  names: the parameter whose slot holds the descriptor it is a field of. }
function FrameVarAt(p: symPtr; idx: integer): symPtr;
var l: symListPtr; k: integer;
begin
  l := p^.frameVars;
  k := 0;
  while (l <> nil) and (k < idx) do begin
    l := l^.next;
    k := k + 1
  end;
  if l = nil then FrameVarAt := nil else FrameVarAt := l^.sym
end;

procedure AddressOfSym(s: symPtr; var v: str);
var slot: str; param: symPtr;
begin
  { A discriminant lives inside the descriptor of the parameter it belongs to,
    so it is reached through that parameter's slot -- which means the walk up
    the static chain is the one every enclosing variable makes, and a recursive
    procedure sees the tuple of the invocation it is running in. }
  if s^.kind = skDisc then begin
    param := FrameVarAt(s^.owner, s^.frameIndex);
    FrameSlot(s, slot);
    Def(v);
    write(ircode, 'getelementptr inbounds ');
    PutDescType(param);
    write(ircode, ', ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 ', 1 + s^.discIndex:1)
  end
  else begin
    FrameSlot(s, slot);
    { A schematic formal parameter's slot is its descriptor, and the variable is
      at the address its first field holds -- for a `var` parameter the actual,
      and for a value parameter the prologue's copy of it. A `var` parameter --
      and the binding of a `with` -- likewise holds an address, so the variable
      it stands for is one load further on. }
    if s^.descSchema <> nil then begin
      Def(v);
      write(ircode, 'getelementptr inbounds ');
      PutDescType(s);
      write(ircode, ', ptr ');
      PutOp(slot);
      writeln(ircode, ', i32 0, i32 0');
      slot := v;
      Def(v);
      write(ircode, 'load ptr, ptr ');
      PutOp(slot);
      writeln(ircode)
    end
    else if s^.kind = skVarParam then begin
      Def(v);
      write(ircode, 'load ptr, ptr ');
      PutOp(slot);
      writeln(ircode)
    end
    else
      v := slot
  end
end;

{ A bound of an array: a constant where the source wrote one, and otherwise the
  discriminant it names, read out of the descriptor. }
{ How many bytes the tuple of a heap variable occupies in front of it. Every
  discriminant is stored as an i32 whatever its own type, so the header is one
  number wide per discriminant -- and it is rounded up to 16 so that the
  variable itself keeps the alignment the allocator gave the block. 16 rather
  than 8 because a set is 256 bits and the target aligns one to 16 (ADR-0028). }
function HeaderSize(t: typePtr): integer;
var bytes, n: integer; d: symListPtr;
begin
  if (t = nil) or not t^.heapTuple or (t^.schema = nil) then
    HeaderSize := 0
  else begin
    n := 0;
    d := t^.schema^.discs;
    while d <> nil do begin
      n := n + 1;
      d := d^.next
    end;
    bytes := 4 * n;
    HeaderSize := ((bytes + 15) div 16) * 16
  end
end;

{ The address of a heap variable's tuple, given the variable's own address.
  Empty for every type whose tuple is somewhere a symbol can name. }
procedure HeaderOf(t: typePtr; var base: str; var v: str);
begin
  if (t = nil) or not t^.heapTuple then
    StrClear(v)
  else begin
    Def(v);
    write(ircode, 'getelementptr i8, ptr ');
    PutOp(base);
    writeln(ircode, ', i32 ', -HeaderSize(t):1)
  end
end;

{ `header` is the tuple of the heap variable this type belongs to, and is
  empty for every other type -- a schematic formal and a variable with
  non-constant discriminants both keep theirs where a symbol can name it, and
  AddressOfSym reaches those by the walk every enclosing variable makes. }
procedure BoundValue(t: typePtr; high: boolean; var header: str; var v: str);
var disc: symPtr; addr, raw: str; d: discValPtr; done: boolean;
begin
  if high then disc := t^.hiDisc else disc := t^.loDisc;
  if disc = nil then
    if high then OpInt(t^.hi, v) else OpInt(t^.lo, v)
  else begin
    done := false;
    { Inside `new` the tuple has no home yet -- the block it will live in
      front of is the thing being sized -- so the values are answered from the
      arguments themselves. That is what keeps the size, the domain check and
      every later read of the same bounds one piece of code. }
    if disc^.heapDisc then begin
      d := newTuple;
      while d <> nil do begin
        if d^.idx = disc^.discIndex then begin
          v := d^.value;
          done := true
        end;
        d := d^.next
      end
    end;
    if not done then begin
    if disc^.heapDisc then begin
      Def(addr);
      write(ircode, 'getelementptr i32, ptr ');
      PutOp(header);
      writeln(ircode, ', i32 ', disc^.discIndex:1)
    end
    else
      AddressOfSym(disc, addr);
    Def(raw);
    write(ircode, 'load ');
    if disc^.heapDisc then write(ircode, 'i32')
    else PutLlType(disc^.stype);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode);
    { A discriminant may be of any ordinal type, and the index arithmetic is
      done in the integer type as it always is. }
    if IsChar(disc^.stype) or IsBoolean(disc^.stype) then
      if disc^.heapDisc then
        v := raw   { a heap tuple is stored one i32 per discriminant }
      else begin
        Def(v);
        write(ircode, 'zext ');
        PutLlType(disc^.stype);
        write(ircode, ' ');
        PutOp(raw);
        writeln(ircode, ' to i32')
      end
    else
      v := raw
    end
  end
end;

{ How many components an array has, as a *value*. TypeLength is `hi - lo + 1`
  and answers only for an array whose bounds are numbers; where they are
  discriminants it returns arithmetic on the placeholders, which is a number
  and therefore not obviously wrong. Everything needing a length rather than a
  size comes through here instead. }
{ The capacity of a string type, as a value. 6.4.3.3.3 makes it the schema's
  one discriminant, so it is a number where the type was written with one and
  the descriptor's when an actual brought it -- the same two answers every
  dynamic bound has (ADR-0040). }
procedure StringCapacity(t: typePtr; var hdr: str; var v: str);
begin
  if t^.hiDisc = nil then begin
    if t^.hi < 0 then OpInt(0, v) else OpInt(t^.hi, v)
  end
  else
    BoundValue(t, true, hdr, v)
end;

procedure DynLength(t: typePtr; var header: str; var v: str);
var lo, hi, extent: str;
begin
  if (t^.loDisc = nil) and (t^.hiDisc = nil) then
    OpInt(TypeLength(t), v)
  else begin
    BoundValue(t, false, header, lo);
    BoundValue(t, true, header, hi);
    Def(extent);
    write(ircode, 'sub i32 ');
    PutOp(hi);
    write(ircode, ', ');
    PutOp(lo);
    writeln(ircode);
    Def(v);
    write(ircode, 'add i32 ');
    PutOp(extent);
    writeln(ircode, ', 1')
  end
end;

{ The bytes a value of this type occupies, as a *value* rather than a constant:
  an array whose bounds arrive with the actual has a size only the descriptor
  can answer. }
procedure DynSize(t: typePtr; var header: str; var v: str);
var lo, hi, extent, count, inner, sum: str;
    f, last: fieldPtr; off, align: integer;
begin
  if not DynamicExtent(t) then
    OpInt(LlSize(t), v)
  { A variable-string is a length beside a buffer, so its size is four bytes
    and the capacity -- the shape ADR-0045 already described, laid out by hand
    because a string is not the record a program could have written. }
  else if IsVarString(t) then begin
    StringCapacity(t, header, count);
    Def(v);
    write(ircode, 'add i32 4, ');
    PutOp(count);
    writeln(ircode)
  end
  { A record's dynamic part is its last field and nothing else (ADR-0045), so
    every offset in it is a constant and the size is the last field's offset
    plus whatever the tail costs. The offset is accumulated here rather than
    asked of LlSize, because LlSize of the last field is the one number that
    is not known. }
  else if t^.kind = tyRecord then begin
    last := LastField(t^.fields);
    off := 0;
    align := 1;
    f := t^.fields;
    while f <> last do begin
      off := RoundUp(off, LlAlign(f^.ftype)) + LlSize(f^.ftype);
      if LlAlign(f^.ftype) > align then align := LlAlign(f^.ftype);
      f := f^.next
    end;
    off := RoundUp(off, LlAlign(last^.ftype));
    if LlAlign(last^.ftype) > align then align := LlAlign(last^.ftype);
    DynSize(last^.ftype, header, inner);
    { An array of these strides by the size, so it is rounded up to the
      record's alignment exactly as a static record's allocation size is. }
    Def(sum);
    write(ircode, 'add i32 ');
    PutOp(inner);
    writeln(ircode, ', ', off + align - 1:1);
    Def(v);
    write(ircode, 'and i32 ');
    PutOp(sum);
    writeln(ircode, ', ', -align:1)
  end
  else begin
    { (hi - lo + 1) components, each of whatever one component costs. The count
      cannot be negative: the tuple that produced the actual's type was checked
      when it was produced, so an empty range never reaches here. }
    BoundValue(t, false, header, lo);
    BoundValue(t, true, header, hi);
    Def(extent);
    write(ircode, 'sub i32 ');
    PutOp(hi);
    write(ircode, ', ');
    PutOp(lo);
    writeln(ircode);
    Def(count);
    write(ircode, 'add i32 ');
    PutOp(extent);
    writeln(ircode, ', 1');
    { One header serves every level: an array of dynamically-bounded arrays
      has one tuple, and the inner bounds are other discriminants of it. }
    DynSize(t^.elem, header, inner);
    Def(v);
    write(ircode, 'mul i32 ');
    PutOp(count);
    write(ircode, ', ');
    PutOp(inner);
    writeln(ircode)
  end
end;


{ A field of the fixed part is one index into the record. A field of a variant
  is two: to the shared storage, then into the arm laid over it. }
{ Walk down the field's path. At each step the shared storage is the last
  member of the struct we are in, and the arm laid over it starts at the same
  address -- so stepping in is one getelementptr, not two. }
procedure FieldAddress(var rec: str; t: typePtr; f: fieldPtr; var v: str);
var cur, p: str; prefix, step: numPtr;
begin
  cur := rec;
  prefix := nil;
  step := f^.variant;
  while step <> nil do begin
    Def(p);
    write(ircode, 'getelementptr inbounds ');
    PutStructAt(t, prefix);
    write(ircode, ', ptr ');
    PutOp(cur);
    writeln(ircode, ', i32 0, i32 ', FieldCount(FieldsAt(t, prefix)):1);
    cur := p;
    prefix := PathAppend(prefix, step^.value);
    step := step^.next
  end;
  Def(v);
  write(ircode, 'getelementptr inbounds ');
  PutStructAt(t, prefix);
  write(ircode, ', ptr ');
  PutOp(cur);
  writeln(ircode, ', i32 0, i32 ', f^.index:1)
end;

{ ------------------------------------------------------------- conversions }

{ Widen an integer to double where Pascal's implicit conversion applies. }
procedure ToReal(var v: str; from: typePtr);
var r: str;
begin
  if IsInteger(from) then begin
    Def(r);
    write(ircode, 'sitofp i32 ');
    PutOp(v);
    writeln(ircode, ' to double');
    v := r
  end
end;

{ The real part of a complex value; 6.7.6.2's `re`. }
procedure ReOf(a: str; var v: str);
begin
  Def(v);
  write(ircode, 'extractelement <2 x double> ');
  PutOp(a);
  writeln(ircode, ', i32 0')
end;

{ ...and the imaginary one, 6.7.6.2's `im`. }
procedure ImOf(a: str; var v: str);
begin
  Def(v);
  write(ircode, 'extractelement <2 x double> ');
  PutOp(a);
  writeln(ircode, ', i32 1')
end;

{ A complex value from its two parts. This and the two above are the whole
  interface to the representation, which is why 6.4.2.2's NOTE that the
  representation "could be rectangular, polar, or something quite different"
  costs nothing to honour: only these three know it is rectangular. }
procedure MakeComplex(re, im: str; var v: str);
var half: str;
begin
  Def(half);
  write(ircode, 'insertelement <2 x double> undef, double ');
  PutOp(re);
  writeln(ircode, ', i32 0');
  Def(v);
  write(ircode, 'insertelement <2 x double> ');
  PutOp(half);
  write(ircode, ', double ');
  PutOp(im);
  writeln(ircode, ', i32 1')
end;

{ 6.4.6 c)'s widening: a real or an integer is the complex with that real part
  and a zero imaginary one. }
procedure ToComplex(var v: str; from: typePtr);
var zero, w: str;
begin
  if not IsComplex(from) then begin
    ToReal(v, from);
    OpWord('0.0             ', zero);
    MakeComplex(v, zero, w);
    v := w
  end
end;

procedure ConvertFor(var v: str; from, toT: typePtr);
begin
  if IsReal(toT) then ToReal(v, from)
  { 6.4.6 c): "an implicit integer-to-complex conversion or real-to-complex
    conversion, respectively, shall be performed". }
  else if IsComplex(toT) then ToComplex(v, from)
end;

{ A real literal reaches the IR as the text it was written with -- which is
  what a textual backend wanted all along, and why the conversion three records
  deferred never had to be written. LLVM's assembler is the strtod, and it is
  the same correctly-rounded conversion the C++ compiler gets from its own.
  The only adjustment is that LLVM's float syntax needs a decimal point, and
  Pascal's `1e6` has none. }
procedure EmitRealText(at, len: integer; negative: boolean; var v: str);
var k, ePos: integer; hasDot: boolean;
begin
  ePos := len + 1;
  hasDot := false;
  for k := 1 to len do
    if (pool[at + k - 1] = 'e') or (pool[at + k - 1] = 'E') then begin
      if ePos > len then ePos := k
    end
    else if pool[at + k - 1] = '.' then
      hasDot := true;

  StrClear(v);
  if negative then StrAppend(v, '-');
  for k := 1 to ePos - 1 do
    StrAppend(v, pool[at + k - 1]);
  if not hasDot then begin
    StrAppend(v, '.');
    StrAppend(v, '0')
  end;
  for k := ePos to len do
    StrAppend(v, pool[at + k - 1])
end;

{ ISO 7185 6.4.6 makes it an error to store a value outside a subrange's
  bounds, so every place a value enters a subrange variable comes through here.
  A subrange covering its whole host needs no check at all, which is what keeps
  `1..maxint` from paying for one. }
procedure CheckedForSubrange(var v: str; target: typePtr);
var host: typePtr; below, above, bad, lo, hi: str; sign: boolean; msg: integer;
begin
  if target <> nil then
    if target^.kind = tySubrange then begin
      host := Base(target);
      if (target^.lo > OrdinalLo(host)) or (target^.hi < OrdinalHi(host)) then
      begin
        sign := IsInteger(target);
        OpInt(target^.lo, lo);
        OpInt(target^.hi, hi);
        Def(below);
        if sign then write(ircode, 'icmp slt ')
        else write(ircode, 'icmp ult ');
        PutLlType(target);
        write(ircode, ' ');
        PutOp(v);
        write(ircode, ', ');
        PutOp(lo);
        writeln(ircode);
        Def(above);
        if sign then write(ircode, 'icmp sgt ')
        else write(ircode, 'icmp ugt ');
        PutLlType(target);
        write(ircode, ' ');
        PutOp(v);
        write(ircode, ', ');
        PutOp(hi);
        writeln(ircode);
        Def(bad);
        write(ircode, 'or i1 ');
        PutOp(below);
        write(ircode, ', ');
        PutOp(above);
        writeln(ircode);

        MsgStart;
        MsgText('value out of range (                    ');
        WriteTypeName(target);
        Put(')');
        msg := MsgEnd;
        EmitTrapIf(bad, msg)
      end
    end
end;

{ ============================== expressions ============================== }

procedure EmitExpr(e: nodePtr; var v: str); forward;
procedure EmitAddress(e: nodePtr; var v: str); forward;

{ The tuple governing a designator, found by walking to the whole variable it
  selects from. One header serves every dimension -- `g^[i][j]` reads `rows`
  and `cols` out of the same one -- and only the outermost designator has the
  address it sits in front of, so an inner subscript cannot compute it from
  its own base. Walking down is what stands in for threading it through. }
procedure HeapHeader(e: nodePtr; var v: str);
var base: str; walking: boolean;
begin
  walking := true;
  while walking do
    if e^.kind = nkIndex then e := e^.ixBase
    else if e^.kind = nkField then e := e^.fdBase
    else walking := false;
  if (e^.ntype = nil) or not e^.ntype^.heapTuple then
    StrClear(v)
  else begin
    EmitAddress(e, base);
    HeaderOf(e^.ntype, base, v)
  end
end;
procedure EmitStmt(s: nodePtr); forward;

{ The value a designator holds. An array or a record has no register form, so
  what it yields is its address; everything else is loaded from it. }
procedure EmitLoad(e: nodePtr; var v: str);
var addr: str;
begin
  EmitAddress(e, addr);
  if IsMemory(e^.ntype) then
    v := addr
  else begin
    Def(v);
    write(ircode, 'load ');
    PutLlType(e^.ntype);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode)
  end
end;

procedure EmitConst(s: symPtr; var v: str);
var b: typePtr;
begin
  b := Base(s^.stype);
  if b = nil then
    OpInt(0, v)
  else
    case b^.kind of
      tyInteger, tyEnum: OpInt(s^.intVal, v);
      tyReal: EmitRealText(s^.realAt, s^.realLen, s^.realNeg, v);
      tyBoolean:
        if s^.boolVal then OpWord('true            ', v)
        else OpWord('false           ', v);
      tyChar: OpInt(ord(s^.charVal), v);
      tyVoid, tySubrange, tyArray, tyRecord, tyPointer, tyFile, tySet, tyProc,
      tyComplex:
        OpInt(0, v)
    end
end;

{ ------------------------------------------------------------------- sets }

{ The 256-bit constant whose set bits are exactly the values of `baseType`:
  the bits from its first ordinal to its last. Built by shifting rather than
  written as a literal, because a 256-bit literal is a number this compiler's
  own source language cannot spell -- and LLVM folds the shifts before they
  ever reach the target. }
procedure SetUniverse(baseType: typePtr; var v: str);
var ones, sh, below, above: str;
begin
  OpInt(-1, ones);
  { Clear the bits above hi, then the bits below lo. Sema has already refused
    a base type outside 0..setLimit, so neither shift can reach setBits. }
  OpInt(setLimit - OrdinalHi(baseType), sh);
  Def(below);
  write(ircode, 'lshr i', setBits:1, ' ');
  PutOp(ones);
  write(ircode, ', ');
  PutOp(sh);
  writeln(ircode);
  OpInt(OrdinalLo(baseType), sh);
  Def(above);
  write(ircode, 'shl i', setBits:1, ' ');
  PutOp(ones);
  write(ircode, ', ');
  PutOp(sh);
  writeln(ircode);
  Def(v);
  write(ircode, 'and i', setBits:1, ' ');
  PutOp(below);
  write(ircode, ', ');
  PutOp(above);
  writeln(ircode)
end;

{ ISO 7185 6.4.6 makes it an error to store a value that is not of the
  variable's type, and a set carrying a member outside its base type is exactly
  that. It is one `and` against the base type's universe: the check a set
  constructor cannot make for itself, because a constructor does not know what
  it is being assigned to. }
procedure CheckedForSetBase(var v: str; target: typePtr);
var universe, notU, stray, bad, zero: str; msg: integer;
begin
  if IsSet(target) and (target^.elem <> nil) then
    { A base type covering the whole universe can hold anything a set value
      can carry, so `set of char` pays nothing. }
    if (OrdinalLo(target^.elem) <> 0) or
       (OrdinalHi(target^.elem) <> setLimit) then begin
      SetUniverse(target^.elem, universe);
      OpInt(-1, notU);
      Def(stray);
      write(ircode, 'xor i', setBits:1, ' ');
      PutOp(universe);
      write(ircode, ', ');
      PutOp(notU);
      writeln(ircode);
      Def(bad);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(v);
      write(ircode, ', ');
      PutOp(stray);
      writeln(ircode);
      OpInt(0, zero);
      Def(notU);
      write(ircode, 'icmp ne i', setBits:1, ' ');
      PutOp(bad);
      write(ircode, ', ');
      PutOp(zero);
      writeln(ircode);

      MsgStart;
      MsgText('set member out of range (               ');
      WriteTypeName(target);
      Put(')');
      msg := MsgEnd;
      EmitTrapIf(notU, msg)
    end
end;

{ A value entering a variable of `target`: the subrange check and the set check
  are the same idea for two kinds of type, so call sites ask once. }
procedure CheckedForStore(var v: str; target: typePtr);
begin
  CheckedForSubrange(v, target);
  CheckedForSetBase(v, target)
end;

{ A member's position in the bit vector, checked and widened. Every set shares
  one 256-bit representation, so the position must lie in 0..setLimit whatever
  the base type is -- a shift by more than that is poison in LLVM, and would be
  a silently wrong answer here. }
procedure SetIndex(e: nodePtr; var v: str);
var raw, lo, hi, below, above, bad: str; msg: integer; sign: boolean;
begin
  EmitExpr(e, raw);
  sign := IsInteger(e^.ntype);
  if sign or (LlSize(e^.ntype) > 1) then begin
    OpInt(0, lo);
    OpInt(setLimit, hi);
    MsgStart;
    MsgText('set member out of range                 ');
    msg := MsgEnd;
    if sign then begin
      Def(below);
      write(ircode, 'icmp slt ');
      PutLlType(e^.ntype);
      write(ircode, ' ');
      PutOp(raw);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      Def(above);
      write(ircode, 'icmp sgt ');
      PutLlType(e^.ntype);
      write(ircode, ' ');
      PutOp(raw);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode);
      Def(bad);
      write(ircode, 'or i1 ');
      PutOp(below);
      write(ircode, ', ');
      PutOp(above);
      writeln(ircode)
    end
    else begin
      Def(bad);
      write(ircode, 'icmp ugt ');
      PutLlType(e^.ntype);
      write(ircode, ' ');
      PutOp(raw);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode)
    end;
    EmitTrapIf(bad, msg)
  end;
  Def(v);
  write(ircode, 'zext ');
  PutLlType(e^.ntype);
  write(ircode, ' ');
  PutOp(raw);
  write(ircode, ' to i', setBits:1);
  writeln(ircode)
end;

{ A set constructor, built by or-ing one member at a time into an empty set. A
  single value contributes 1 shifted left by it; a range lo..hi contributes the
  bits from lo to hi, which is the same pair of shifts SetUniverse uses -- with
  the difference that the bounds are expressions, so hi < lo is a run-time
  possibility and must yield the empty set rather than a mask of everything
  (ISO 7185 6.7.1). }
procedure EmitSet(e: nodePtr; var v: str);
var m: nodePtr; lo, hi, one, ones, bits, tmp, sh, empty, cmp, acc: str;
begin
  OpInt(0, acc);
  OpInt(1, one);
  OpInt(-1, ones);
  OpInt(0, empty);
  m := e^.seMembers;
  while m <> nil do begin
    SetIndex(m^.smLo, lo);
    if m^.smHi = nil then begin
      Def(bits);
      write(ircode, 'shl i', setBits:1, ' ');
      PutOp(one);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode)
    end
    else begin
      SetIndex(m^.smHi, hi);
      OpInt(setLimit, sh);
      Def(tmp);
      write(ircode, 'sub i', setBits:1, ' ');
      PutOp(sh);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode);
      Def(bits);
      write(ircode, 'lshr i', setBits:1, ' ');
      PutOp(ones);
      write(ircode, ', ');
      PutOp(tmp);
      writeln(ircode);
      Def(tmp);
      write(ircode, 'shl i', setBits:1, ' ');
      PutOp(ones);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      Def(sh);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(bits);
      write(ircode, ', ');
      PutOp(tmp);
      writeln(ircode);
      { An empty range selects nothing. Without this the two masks would still
        intersect in the bits between hi and lo. }
      Def(cmp);
      write(ircode, 'icmp ugt i', setBits:1, ' ');
      PutOp(lo);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode);
      Def(bits);
      write(ircode, 'select i1 ');
      PutOp(cmp);
      write(ircode, ', i', setBits:1, ' ');
      PutOp(empty);
      write(ircode, ', i', setBits:1, ' ');
      PutOp(sh);
      writeln(ircode)
    end;
    Def(tmp);
    write(ircode, 'or i', setBits:1, ' ');
    PutOp(acc);
    write(ircode, ', ');
    PutOp(bits);
    writeln(ircode);
    acc := tmp;
    m := m^.next
  end;
  v := acc
end;

{ `x in s`. A member position outside 0..setLimit cannot be in any set, and
  answers false rather than trapping: the value is not of the base type, which
  is what `in` is there to report. }
procedure EmitIn(e: nodePtr; var v: str);
var raw, idx, limit, ok, safe, zero, one, set_, shifted, got, hit: str;
begin
  EmitExpr(e^.bnLhs, raw);
  { Widened with its own signedness, a value outside 0..setLimit lands outside
    that range in the 256-bit word too -- so one unsigned compare catches a
    negative value and an oversized one alike. }
  Def(idx);
  if IsInteger(e^.bnLhs^.ntype) then write(ircode, 'sext ')
  else write(ircode, 'zext ');
  PutLlType(e^.bnLhs^.ntype);
  write(ircode, ' ');
  PutOp(raw);
  write(ircode, ' to i', setBits:1);
  writeln(ircode);
  OpInt(setLimit + 1, limit);
  Def(ok);
  write(ircode, 'icmp ult i', setBits:1, ' ');
  PutOp(idx);
  write(ircode, ', ');
  PutOp(limit);
  writeln(ircode);
  { The shift is by a value LLVM has to see is under setBits, or it is
    poison. }
  OpInt(0, zero);
  Def(safe);
  write(ircode, 'select i1 ');
  PutOp(ok);
  write(ircode, ', i', setBits:1, ' ');
  PutOp(idx);
  write(ircode, ', i', setBits:1, ' ');
  PutOp(zero);
  writeln(ircode);
  EmitExpr(e^.bnRhs, set_);
  Def(shifted);
  write(ircode, 'lshr i', setBits:1, ' ');
  PutOp(set_);
  write(ircode, ', ');
  PutOp(safe);
  writeln(ircode);
  OpInt(1, one);
  Def(got);
  write(ircode, 'and i', setBits:1, ' ');
  PutOp(shifted);
  write(ircode, ', ');
  PutOp(one);
  writeln(ircode);
  Def(hit);
  write(ircode, 'icmp ne i', setBits:1, ' ');
  PutOp(got);
  write(ircode, ', ');
  PutOp(zero);
  writeln(ircode);
  Def(v);
  write(ircode, 'and i1 ');
  PutOp(ok);
  write(ircode, ', ');
  PutOp(hit);
  writeln(ircode)
end;

{ The set operators, all of them one instruction on the bit vector: union is
  `or`, intersection is `and`, difference is `and not`, and inclusion is
  "nothing left over" (ISO 7185 6.7.2.3, 6.7.2.5). }
procedure EmitSetBinary(e: nodePtr; var l, r, v: str);
var notR, left, zero, ones: str;
begin
  case e^.bnOp of
    opAdd: begin
      Def(v);
      write(ircode, 'or i', setBits:1, ' ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    opMul: begin
      Def(v);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    opSub: begin
      OpInt(-1, ones);
      Def(notR);
      write(ircode, 'xor i', setBits:1, ' ');
      PutOp(r);
      write(ircode, ', ');
      PutOp(ones);
      writeln(ircode);
      Def(v);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(notR);
      writeln(ircode)
    end;
    opEq, opNe: begin
      Def(v);
      if e^.bnOp = opEq then write(ircode, 'icmp eq i', setBits:1, ' ')
      else write(ircode, 'icmp ne i', setBits:1, ' ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    { `l <= r` is "l has nothing r lacks", and `l >= r` is the same question
      with the operands the other way round. }
    opLe, opGe, opLt, opGt, opRealDiv, opIntDiv, opMod, opAnd, opOr, opIn,
    opExp, opPow, opAndThen, opOrElse:
    begin
      OpInt(-1, ones);
      if e^.bnOp = opGe then begin notR := l; left := r end
      else begin notR := r; left := l end;
      Def(zero);
      write(ircode, 'xor i', setBits:1, ' ');
      PutOp(notR);
      write(ircode, ', ');
      PutOp(ones);
      writeln(ircode);
      Def(notR);
      write(ircode, 'and i', setBits:1, ' ');
      PutOp(left);
      write(ircode, ', ');
      PutOp(zero);
      writeln(ircode);
      OpInt(0, zero);
      Def(v);
      write(ircode, 'icmp eq i', setBits:1, ' ');
      PutOp(notR);
      write(ircode, ', ');
      PutOp(zero);
      writeln(ircode)
    end
  end
end;

{ An argument list has to be complete before the call line can be written, so
  the operands are collected as they are emitted. }
procedure AppendOpnd(var head, tail: opndPtr; var v: str; asPtr: boolean;
                     t: typePtr);
var o: opndPtr;
begin
  new(o);
  o^.text := v;
  o^.asPtr := asPtr;
  o^.otype := t;
  o^.next := nil;
  if head = nil then head := o else tail^.next := o;
  tail := o
end;

{ The pair a procedural argument travels as. Naming a procedure with a body
  takes its address and the frame it was *declared* under; naming a procedural
  parameter forwards the pair that parameter already holds, so a procedure
  handed on through three levels still runs in its own scope. }
procedure EmitProcArgument(actual: symPtr; var head, tail: opndPtr);
var slot, half, code, link: str;
begin
  if actual^.kind = skProcParam then begin
    FrameSlot(actual, slot);
    Def(half);
    write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 0');
    Def(code);
    write(ircode, 'load ptr, ptr ');
    PutOp(half);
    writeln(ircode);
    AppendOpnd(head, tail, code, true, nil);
    Def(half);
    write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 1');
    Def(link);
    write(ircode, 'load ptr, ptr ');
    PutOp(half);
    writeln(ircode);
    AppendOpnd(head, tail, link, true, nil)
  end
  else begin
    StrClear(code);
    StrAppend(code, '@');
    StrAppend(code, 'p');
    AppendInt(code, actual^.irId);
    AppendOpnd(head, tail, code, true, nil);
    FrameAt(actual^.level - 1, link);
    AppendOpnd(head, tail, link, true, nil)
  end
end;

{ The signature an indirect call through a procedural parameter uses: the
  static link, then the parameters, exactly as EmitProcBody builds it for a
  procedure with a body. }
procedure PutProcSignature(callee: symPtr);
var p: symListPtr; result: typePtr; k: integer;
begin
  result := ResultTypeOf(callee);
  if result = nil then write(ircode, 'void') else PutLlType(result);
  write(ircode, ' (ptr');
  p := callee^.params;
  k := 0;
  while p <> nil do begin
    write(ircode, ', ');
    if p^.sym^.descSchema <> nil then
      PutDescParamTypes(p^.sym, false, k)
    else if (p^.sym^.kind = skVarParam) or (p^.sym^.kind = skProcParam) or
       IsMemory(p^.sym^.stype) then
      if p^.sym^.kind = skProcParam then write(ircode, 'ptr, ptr')
      else write(ircode, 'ptr')
    else
      PutLlType(p^.sym^.stype);
    p := p^.next
  end;
  write(ircode, ')')
end;

{ The k'th discriminant of the tuple this expression's type was produced with.
  A generic type belongs to one variable -- nothing else can be given it, and a
  subscript of one would already have yielded the component -- so an expression
  possessing one *is* that variable, and its tuple is in the descriptor. A heap
  variable carries its tuple in front of it, so any designator of one answers,
  not only a name: `p^` is not a name and `q^[1]^` is not even a pointer
  variable. Every other type produced from a schema was produced from
  constants, and they are on the type. }
procedure DiscValue(e: nodePtr; k: integer; want: typePtr; var v: str);
var d: symListPtr; tv: numPtr; i: integer; hdr, half, raw: str;
begin
  if e^.ntype^.heapTuple then begin
    HeapHeader(e, hdr);
    Def(half);
    write(ircode, 'getelementptr i32, ptr ');
    PutOp(hdr);
    writeln(ircode, ', i32 ', k:1);
    Def(raw);
    write(ircode, 'load i32, ptr ');
    PutOp(half);
    writeln(ircode);
    { The header holds one i32 per discriminant whatever its own type. }
    if IsChar(want) or IsBoolean(want) then begin
      Def(v);
      write(ircode, 'trunc i32 ');
      PutOp(raw);
      write(ircode, ' to ');
      PutLlType(want);
      writeln(ircode)
    end
    else
      v := raw
  end
  else if IsGeneric(e^.ntype) and (e^.kind = nkVar) then begin
    d := e^.vrSym^.discSyms;
    for i := 1 to k do
      if d <> nil then d := d^.next;
    if d = nil then OpInt(0, v)
    else begin
      AddressOfSym(d^.sym, half);
      Def(v);
      write(ircode, 'load ');
      PutLlType(want);
      write(ircode, ', ptr ');
      PutOp(half);
      writeln(ircode)
    end
  end
  else begin
    tv := e^.ntype^.tuple;
    for i := 1 to k do
      if tv <> nil then tv := tv^.next;
    if tv = nil then OpInt(0, v) else OpInt(tv^.value, v)
  end
end;

procedure EmitUserCall(callee: symPtr; args: nodePtr; var v: str);
var link, a, slot, half, target: str; head, tail, o: opndPtr;
    p, dp: symListPtr; arg: nodePtr; result: typePtr; k: integer;
begin
  StrClear(target);
  if callee^.kind = skProcParam then begin
    { The link to run under comes out of the pair, not from the static chain:
      the caller's chain says nothing about where the passed procedure was
      declared, which is the reason the link had to be carried at all. }
    FrameSlot(callee, slot);
    Def(half);
    write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 0');
    Def(target);
    write(ircode, 'load ptr, ptr ');
    PutOp(half);
    writeln(ircode);
    Def(half);
    write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
    PutOp(slot);
    writeln(ircode, ', i32 0, i32 1');
    Def(link);
    write(ircode, 'load ptr, ptr ');
    PutOp(half);
    writeln(ircode)
  end
  else begin
    { A callee declared at level L runs with the frame at level L-1 as its
      enclosing scope -- which for a recursive call is the caller's own
      parent, not the caller. }
    FrameAt(callee^.level - 1, link);
    StrAppend(target, '@');
    StrAppend(target, 'p');
    AppendInt(target, callee^.irId)
  end;

  head := nil;
  tail := nil;
  arg := args;
  p := callee^.params;
  while (arg <> nil) and (p <> nil) do begin
    if p^.sym^.kind = skProcParam then
      EmitProcArgument(arg^.vrSym, head, tail)
    { The address, then the tuple the actual was produced with -- constants
      where the actual is an ordinary variable, and the caller's own descriptor
      where it is itself a schematic formal, which is how a schematic array is
      handed on through any number of blocks. }
    else if p^.sym^.descSchema <> nil then begin
      EmitAddress(arg, a);
      AppendOpnd(head, tail, a, true, nil);
      k := 0;
      dp := p^.sym^.descSchema^.discs;
      while dp <> nil do begin
        DiscValue(arg, k, dp^.sym^.stype, a);
        AppendOpnd(head, tail, a, false, dp^.sym^.stype);
        k := k + 1;
        dp := dp^.next
      end
    end
    else begin
      if (p^.sym^.kind = skVarParam) or IsMemory(p^.sym^.stype) then
        { A `var` parameter binds to the variable itself; a structured value
          parameter is copied from it by the callee. Either way an address
          travels, and Sema has already required something that has one. }
        EmitAddress(arg, a)
      else begin
        EmitExpr(arg, a);
        ConvertFor(a, arg^.ntype, p^.sym^.stype);
        CheckedForStore(a, p^.sym^.stype)
      end;
      AppendOpnd(head, tail, a,
                 (p^.sym^.kind = skVarParam) or IsMemory(p^.sym^.stype),
                 p^.sym^.stype)
    end;
    arg := arg^.next;
    p := p^.next
  end;

  result := ResultTypeOf(callee);
  if result <> nil then begin
    Def(v);
    write(ircode, 'call ')
  end
  else begin
    StrClear(v);
    write(ircode, '  call ')
  end;
  { An indirect call states the whole signature; a direct one names a function
    whose signature the module already carries. }
  if callee^.kind = skProcParam then
    PutProcSignature(callee)
  else if result = nil then write(ircode, 'void')
  else PutLlType(result);
  write(ircode, ' ');
  PutOp(target);
  write(ircode, '(ptr ');
  PutOp(link);
  o := head;
  while o <> nil do begin
    write(ircode, ', ');
    if o^.asPtr then write(ircode, 'ptr') else PutLlType(o^.otype);
    write(ircode, ' ');
    PutOp(o^.text);
    o := o^.next
  end;
  writeln(ircode, ')')
end;

{ ISO 7185 6.7.2.5 orders equal-length strings by their first differing
  character, which is what the runtime helper reports; the operator then only
  has to say what it wants of the sign. }
procedure EmitStringCompare(e: nodePtr; var v: str);
var lhs, rhs, cmp, len, other, bad, lhdr, rhdr: str;
begin
  EmitAddress(e^.bnLhs, lhs);
  EmitAddress(e^.bnRhs, rhs);
  HeapHeader(e^.bnLhs, lhdr);
  DynLength(e^.bnLhs^.ntype, lhdr, len);
  { Sema requires equal lengths, and can say so wherever both are numbers.
    Where one is a discriminant the requirement is the same one, made here --
    and it has to be made, because a comparison over the wrong number of
    characters answers rather than failing. }
  if DynamicExtent(e^.bnLhs^.ntype) or DynamicExtent(e^.bnRhs^.ntype) then begin
    HeapHeader(e^.bnRhs, rhdr);
    DynLength(e^.bnRhs^.ntype, rhdr, other);
    Def(bad);
    write(ircode, 'icmp ne i32 ');
    PutOp(len);
    write(ircode, ', ');
    PutOp(other);
    writeln(ircode);
    EmitTrapLength(bad, len, other)
  end;
  Def(cmp);
  write(ircode, 'call i32 @pas_str_compare(ptr ');
  PutOp(lhs);
  write(ircode, ', ptr ');
  PutOp(rhs);
  write(ircode, ', i32 ');
  PutOp(len);
  writeln(ircode, ')');
  Def(v);
  case e^.bnOp of
    opEq: write(ircode, 'icmp eq i32 ');
    opNe: write(ircode, 'icmp ne i32 ');
    opLt: write(ircode, 'icmp slt i32 ');
    opLe: write(ircode, 'icmp sle i32 ');
    opGt: write(ircode, 'icmp sgt i32 ');
    opGe: write(ircode, 'icmp sge i32 ');
    opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
            opExp, opPow, opAndThen, opOrElse:
      write(ircode, 'icmp eq i32 ')
  end;
  PutOp(cmp);
  writeln(ircode, ', 0')
end;

{ The overflow-reporting form of +, - and *. }
procedure EmitCheckedArith(which: char; var l, r, v: str; msg: integer);
var pair, ovf, isMin, bad: str;
begin
  Def(pair);
  write(ircode, 'call { i32, i1 } @llvm.');
  if which = '+' then write(ircode, 'sadd')
  else if which = '-' then write(ircode, 'ssub')
  else write(ircode, 'smul');
  write(ircode, '.with.overflow.i32(i32 ');
  PutOp(l);
  write(ircode, ', i32 ');
  PutOp(r);
  writeln(ircode, ')');
  Def(v);
  write(ircode, 'extractvalue { i32, i1 } ');
  PutOp(pair);
  writeln(ircode, ', 0');
  Def(ovf);
  write(ircode, 'extractvalue { i32, i1 } ');
  PutOp(pair);
  writeln(ircode, ', 1');
  { -maxint..maxint is the integer type (6.4.2.2), so a result of INT_MIN is
    out of range even though it fits the machine word. }
  Def(isMin);
  write(ircode, 'icmp eq i32 ');
  PutOp(v);
  writeln(ircode, ', -2147483648');
  Def(bad);
  write(ircode, 'or i1 ');
  PutOp(ovf);
  write(ircode, ', ');
  PutOp(isMin);
  writeln(ircode);
  EmitTrapIf(bad, msg)
end;

procedure GuardNonZero(var r: str; msg: integer);
var zero: str;
begin
  Def(zero);
  write(ircode, 'icmp eq i32 ');
  PutOp(r);
  writeln(ircode, ', 0');
  EmitTrapIf(zero, msg)
end;

{ ISO 7185 6.6.6.2: trunc and round are errors unless the result is a value of
  the integer type. The bounds are the exactly-representable powers of two just
  outside the range, and the comparisons are *ordered*, so a NaN fails both and
  traps rather than converting to something unspecified. }
procedure CheckedFpToInt(var x, v: str; msg: integer);
var gt, lt, ok, bad: str;
begin
  Def(gt);
  write(ircode, 'fcmp ogt double ');
  PutOp(x);
  writeln(ircode, ', -2147483648.0');
  Def(lt);
  write(ircode, 'fcmp olt double ');
  PutOp(x);
  writeln(ircode, ', 2147483648.0');
  Def(ok);
  write(ircode, 'and i1 ');
  PutOp(gt);
  write(ircode, ', ');
  PutOp(lt);
  writeln(ircode);
  Def(bad);
  write(ircode, 'xor i1 ');
  PutOp(ok);
  writeln(ircode, ', true');
  EmitTrapIf(bad, msg);
  Def(v);
  write(ircode, 'fptosi double ');
  PutOp(x);
  writeln(ircode, ' to i32')
end;

{ `and` and `or` short-circuit, which is what makes a guarded test such as
  `while (i <= n) and (a[i] <> x)` safe to write (ADR-0010). Extended Pascal's
  `and then` and `or else` (6.8.3.3) *require* that, so the one lowering serves
  all four -- the difference between them is a promise to the programmer, not
  a difference in the code. }
procedure EmitShortCircuit(e: nodePtr; var v: str);
var lhs, rhs: str; isAnd: boolean; rhsB, endB, lhsEnd, rhsEnd: integer;
begin
  isAnd := (e^.bnOp = opAnd) or (e^.bnOp = opAndThen);
  EmitExpr(e^.bnLhs, lhs);
  lhsEnd := curBlock;
  rhsB := NewBlock;
  endB := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(lhs);
  if isAnd then
    writeln(ircode, ', label %L', rhsB:1, ', label %L', endB:1)
  else
    writeln(ircode, ', label %L', endB:1, ', label %L', rhsB:1);

  StartBlock(rhsB);
  EmitExpr(e^.bnRhs, rhs);
  rhsEnd := curBlock;
  writeln(ircode, '  br label %L', endB:1);

  StartBlock(endB);
  Def(v);
  write(ircode, 'phi i1 [ ');
  if isAnd then write(ircode, 'false') else write(ircode, 'true');
  write(ircode, ', %L', lhsEnd:1, ' ], [ ');
  PutOp(rhs);
  writeln(ircode, ', %L', rhsEnd:1, ' ]')
end;

{ The four arithmetic operators and the two relational ones ISO/IEC 10206:1991
  gives the complex type. All six are emitted inline: nothing here needs a
  library, and keeping them out of the runtime keeps the *only* complex-shaped
  value crossing a C boundary out of existence -- which is what lets the
  representation stay a vector without either backend acquiring an opinion
  about how a struct is passed (ADR-0030's constraint). }
{ One `<op> double x, y`. The complex arithmetic is a dozen of these, and
  spelling each out would bury the formula in the emission. }
procedure EmitFBin(op: msgLit; x, y: str; var v: str);
begin
  Def(v);
  PutIrLit(op);
  write(ircode, ' double ');
  PutOp(x);
  write(ircode, ', ');
  PutOp(y);
  writeln(ircode)
end;

{ 6.8.3.2 table 3 gives `**` and `pow` a complex *left* operand, and the right
  one is never complex -- a real for `**`, an integer for `pow`. Both go to the
  runtime, which carries the standard's two special cases with them. }
procedure EmitComplexPow(e: nodePtr; l, r: str; lt, rt: typePtr;
                         realExp: boolean; var v: str);
var re, im, pr, pi_: str;
begin
  ToComplex(l, lt);
  ReOf(l, re);
  ImOf(l, im);
  if realExp then ToReal(r, rt);
  Def(pr);
  if realExp then write(ircode, 'call double @pas_cpow_re(double ')
  else write(ircode, 'call double @pas_cpowi_re(double ');
  PutOp(re);
  write(ircode, ', double ');
  PutOp(im);
  if realExp then write(ircode, ', double ') else write(ircode, ', i32 ');
  PutOp(r);
  writeln(ircode, ')');
  Def(pi_);
  if realExp then write(ircode, 'call double @pas_cpow_im(double ')
  else write(ircode, 'call double @pas_cpowi_im(double ');
  PutOp(re);
  write(ircode, ', double ');
  PutOp(im);
  if realExp then write(ircode, ', double ') else write(ircode, ', i32 ');
  PutOp(r);
  writeln(ircode, ')');
  MakeComplex(pr, pi_, v)
end;

procedure EmitComplexBinary(e: nodePtr; l, r: str; var v: str);
var a, b_, c_, d_, ac, bd, ad, bc, re, im, den, cc, dd, er, ei: str;
begin
  case e^.bnOp of
    opAdd: begin
      Def(v);
      write(ircode, 'fadd <2 x double> ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    opSub: begin
      Def(v);
      write(ircode, 'fsub <2 x double> ');
      PutOp(l);
      write(ircode, ', ');
      PutOp(r);
      writeln(ircode)
    end;
    { (a + bi)(c + di) = (ac - bd) + (ad + bc)i }
    opMul: begin
      ReOf(l, a); ImOf(l, b_); ReOf(r, c_); ImOf(r, d_);
      EmitFBin('fmul            ', a, c_, ac);
      EmitFBin('fmul            ', b_, d_, bd);
      EmitFBin('fsub            ', ac, bd, re);
      EmitFBin('fmul            ', a, d_, ad);
      EmitFBin('fmul            ', b_, c_, bc);
      EmitFBin('fadd            ', ad, bc, im);
      MakeComplex(re, im, v)
    end;
    { (a + bi)/(c + di) = ((ac + bd) + (bc - ad)i) / (c*c + d*d). Division by a
      zero divisor is left to IEEE, exactly as real `/` is: this compiler does
      not trap that one either, so trapping here would be the odd one out. }
    opRealDiv: begin
      ReOf(l, a); ImOf(l, b_); ReOf(r, c_); ImOf(r, d_);
      EmitFBin('fmul            ', c_, c_, cc);
      EmitFBin('fmul            ', d_, d_, dd);
      EmitFBin('fadd            ', cc, dd, den);
      EmitFBin('fmul            ', a, c_, ac);
      EmitFBin('fmul            ', b_, d_, bd);
      EmitFBin('fadd            ', ac, bd, er);
      EmitFBin('fdiv            ', er, den, re);
      EmitFBin('fmul            ', b_, c_, bc);
      EmitFBin('fmul            ', a, d_, ad);
      EmitFBin('fsub            ', bc, ad, ei);
      EmitFBin('fdiv            ', ei, den, im);
      MakeComplex(re, im, v)
    end;
    { Only = and <> reach here; Sema refused the four ordering operators,
      because 6.8.3.5 gives them "any simple-type except complex-type" and
      there is no order on the complex numbers to give them. }
    opEq, opNe, opLt, opLe, opGt, opGe, opIntDiv, opMod, opAnd, opOr,
    opAndThen, opOrElse, opIn, opExp, opPow: begin
      ReOf(l, a); ImOf(l, b_); ReOf(r, c_); ImOf(r, d_);
      Def(ac);
      write(ircode, 'fcmp oeq double ');
      PutOp(a);
      write(ircode, ', ');
      PutOp(c_);
      writeln(ircode);
      Def(bd);
      write(ircode, 'fcmp oeq double ');
      PutOp(b_);
      write(ircode, ', ');
      PutOp(d_);
      writeln(ircode);
      Def(re);
      write(ircode, 'and i1 ');
      PutOp(ac);
      write(ircode, ', ');
      PutOp(bd);
      writeln(ircode);
      if e^.bnOp = opEq then
        v := re
      else begin
        Def(v);
        write(ircode, 'xor i1 ');
        PutOp(re);
        writeln(ircode, ', true')
      end
    end
  end
end;

{ ISO/IEC 10206:1991 6.4.3.3: every string *value*, as the pointer and length
  pair 6.4.3.3.1 describes it -- "a one-to-one mapping from an index-domain to
  a set of components possessing the char-type", with the index-domain's size
  as the length.

  The pair is what makes `substr` and `trim` free: they are a pointer and a
  shorter length into the string they came from, and copy nothing. Only `+`
  makes characters that did not exist. }
procedure EmitString(e: nodePtr; var data, len: str);
var ad, al, bd, bl, at_, count, hdr, addr, c, one: str; st: typePtr;
begin
  st := e^.ntype;
  { A concatenation, and the one operation that needs storage. }
  if (e^.kind = nkBinary) and (e^.bnOp = opAdd) and IsStringType(st) then begin
    EmitString(e^.bnLhs, ad, al);
    EmitString(e^.bnRhs, bd, bl);
    Def(data);
    write(ircode, 'call ptr @pas_str_concat(ptr ');
    PutOp(ad);
    write(ircode, ', i32 ');
    PutOp(al);
    write(ircode, ', ptr ');
    PutOp(bd);
    write(ircode, ', i32 ');
    PutOp(bl);
    writeln(ircode, ')');
    { 6.8.3.6: "whose length shall be equal to the sum of the length of a and
      the length of b" -- so the length is arithmetic here and the runtime
      never returns one. }
    Def(len);
    write(ircode, 'add i32 ');
    PutOp(al);
    write(ircode, ', ');
    PutOp(bl);
    writeln(ircode)
  end
  else if (e^.kind = nkCall) and
          ((e^.clBuiltin = biSubstr) or (e^.clBuiltin = biTrim)) then begin
    EmitString(e^.clArgs, ad, al);
    if e^.clBuiltin = biTrim then begin
      data := ad;
      Def(len);
      write(ircode, 'call i32 @pas_str_trimlen(ptr ');
      PutOp(ad);
      write(ircode, ', i32 ');
      PutOp(al);
      writeln(ircode, ')')
    end
    else begin
      { 6.7.6.7: substr(s, i, j) is j characters from position i, and the
        two-argument form is "substr(sv, iv, length(sv)-(iv)+1)" -- the tail. }
      EmitExpr(e^.clArgs^.next, at_);
      if e^.clArgs^.next^.next <> nil then
        EmitExpr(e^.clArgs^.next^.next, count)
      else begin
        Def(bd);
        write(ircode, 'sub i32 ');
        PutOp(al);
        write(ircode, ', ');
        PutOp(at_);
        writeln(ircode);
        Def(count);
        write(ircode, 'add i32 ');
        PutOp(bd);
        writeln(ircode, ', 1')
      end;
      write(ircode, '  call void @pas_str_slice_check(i32 ');
      PutOp(at_);
      write(ircode, ', i32 ');
      PutOp(count);
      write(ircode, ', i32 ');
      PutOp(al);
      writeln(ircode, ')');
      Def(bl);
      write(ircode, 'sub i32 ');
      PutOp(at_);
      writeln(ircode, ', 1');
      Def(data);
      write(ircode, 'getelementptr inbounds i8, ptr ');
      PutOp(ad);
      write(ircode, ', i32 ');
      PutOp(bl);
      writeln(ircode);
      len := count
    end
  end
  { A literal is its own characters and its own length, whatever type it was
    given -- and the null-string is *why* this comes first: `''` has the
    canonical type, which would otherwise be read as a length in front of
    characters that are not there. }
  else if e^.kind = nkStr then begin
    EmitAddress(e, data);
    OpInt(e^.stLen, len)
  end
  { 6.4.3.3.1 gives the char-type length 1, and a char in a register has no
    address -- this is where it gets one. }
  else if IsChar(st) then begin
    EmitExpr(e, c);
    Def(data);
    write(ircode, 'call ptr @pas_str_char(i8 ');
    PutOp(c);
    writeln(ircode, ')');
    OpInt(1, len)
  end
  { A variable-string variable: the length is stored in front of the
    characters, which is the whole of 6.4.3.3.3's representation. }
  else if IsVarString(st) then begin
    EmitAddress(e, addr);
    Def(at_);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(st);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode, ', i32 0, i32 0');
    Def(len);
    write(ircode, 'load i32, ptr ');
    PutOp(at_);
    writeln(ircode);
    Def(data);
    write(ircode, 'getelementptr inbounds ');
    PutLlType(st);
    write(ircode, ', ptr ');
    PutOp(addr);
    writeln(ircode, ', i32 0, i32 1')
  end
  { ...and a fixed-string-type, whose length 6.4.3.3.2 makes equal to its
    capacity: "the length of all values of a particular fixed-string-type is
    equal to the capacity". }
  else begin
    EmitAddress(e, data);
    HeapHeader(e, hdr);
    DynLength(st, hdr, len)
  end
end;

{ 6.4.6's assignment rules for a string destination, which are three different
  things depending on what the destination is -- padded to the capacity for a
  fixed string, exact for a variable one, one character for a char -- and one
  thing they share: it is an *error* if the value is longer than the
  capacity. }
procedure EmitStringStore(var dst: str; t: typePtr; src: nodePtr;
                          var hdr: str);
var sd, sl, cap: str;
begin
  EmitString(src, sd, sl);
  if IsVarString(t) then begin
    StringCapacity(t, hdr, cap);
    write(ircode, '  call void @pas_str_store_var(ptr ');
    PutOp(dst);
    write(ircode, ', i32 ');
    PutOp(cap);
    write(ircode, ', ptr ');
    PutOp(sd);
    write(ircode, ', i32 ');
    PutOp(sl);
    writeln(ircode, ')')
  end
  else if IsChar(t) then begin
    write(ircode, '  call void @pas_str_store_char(ptr ');
    PutOp(dst);
    write(ircode, ', ptr ');
    PutOp(sd);
    write(ircode, ', i32 ');
    PutOp(sl);
    writeln(ircode, ')')
  end
  else begin
    DynLength(t, hdr, cap);
    write(ircode, '  call void @pas_str_store_fixed(ptr ');
    PutOp(dst);
    write(ircode, ', i32 ');
    PutOp(cap);
    write(ircode, ', ptr ');
    PutOp(sd);
    write(ircode, ', i32 ');
    PutOp(sl);
    writeln(ircode, ')')
  end
end;

{ 6.8.3.5: the relational operators over string types, where the shorter value
  is "effectively extended with trailing spaces to the length of the longer".
  That is the ISO 7185 divergence that matters -- there the lengths had to be
  equal, and this compiler said so. }
{ A concatenation appearing where a *value* is wanted rather than where a
  string is: only a string context can consume one, so the pair is built and
  the pointer stands for it. Sema has already refused every other use. }
procedure EmitStringValue(e: nodePtr; var v: str);
var d, l: str;
begin
  EmitString(e, d, l);
  v := d
end;

procedure EmitStringCompare2(e: nodePtr; var v: str);
var ad, al, bd, bl, cmp: str;
begin
  EmitString(e^.bnLhs, ad, al);
  EmitString(e^.bnRhs, bd, bl);
  Def(cmp);
  write(ircode, 'call i32 @pas_str_cmp_pad(ptr ');
  PutOp(ad);
  write(ircode, ', i32 ');
  PutOp(al);
  write(ircode, ', ptr ');
  PutOp(bd);
  write(ircode, ', i32 ');
  PutOp(bl);
  writeln(ircode, ')');
  Def(v);
  write(ircode, 'icmp ');
  case e^.bnOp of
    opEq: write(ircode, 'eq');
    opNe: write(ircode, 'ne');
    opLt: write(ircode, 'slt');
    opLe: write(ircode, 'sle');
    opGt: write(ircode, 'sgt');
    opGe: write(ircode, 'sge');
    opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr, opAndThen,
    opOrElse, opIn, opExp, opPow: write(ircode, 'eq')
  end;
  write(ircode, ' i32 ');
  PutOp(cmp);
  writeln(ircode, ', 0')
end;

procedure EmitBinary(e: nodePtr; var v: str);
var l, r, rem, neg, adj, bad, m1, m2: str;
    lt, rt: typePtr; msg: integer; sign, useFloat: boolean;
begin
  if (e^.bnOp = opAnd) or (e^.bnOp = opOr) or (e^.bnOp = opAndThen)
     or (e^.bnOp = opOrElse) then
    EmitShortCircuit(e, v)
  { `x in s` is the one operator whose operands are of different kinds, so it
    is taken before the two are evaluated alike. }
  else if e^.bnOp = opIn then
    EmitIn(e, v)
  { 6.8.3.6's concatenation, which is a value and not a comparison. }
  else if (e^.bnOp = opAdd) and IsStringType(e^.ntype) then
    EmitStringValue(e, v)
  { 6.8.3.5's padded comparison, whenever either side is a string and the
    lengths are not both statically equal char arrays -- the ISO 7185 path is
    kept for the case it already handled, so nothing about that language's
    emitted code moved. }
  else if IsStringOrChar(e^.bnLhs^.ntype) and IsStringOrChar(e^.bnRhs^.ntype)
          and not (IsChar(e^.bnLhs^.ntype) and IsChar(e^.bnRhs^.ntype)) then
    if IsCharArray(e^.bnLhs^.ntype) and IsCharArray(e^.bnRhs^.ntype) and
       (e^.bnLhs^.ntype^.loDisc = nil) and (e^.bnLhs^.ntype^.hiDisc = nil) and
       (e^.bnRhs^.ntype^.loDisc = nil) and (e^.bnRhs^.ntype^.hiDisc = nil) and
       (TypeLength(e^.bnLhs^.ntype) = TypeLength(e^.bnRhs^.ntype)) then
      EmitStringCompare(e, v)
    else
      EmitStringCompare2(e, v)
  { Strings compare through the runtime rather than in registers, and must be
    caught before the operands are evaluated: an array has no register form. }
  else if IsCharArray(e^.bnLhs^.ntype) and IsCharArray(e^.bnRhs^.ntype) then
    EmitStringCompare(e, v)
  else begin
    EmitExpr(e^.bnLhs, l);
    EmitExpr(e^.bnRhs, r);
    lt := e^.bnLhs^.ntype;
    rt := e^.bnRhs^.ntype;

    { Both operands are the same 256-bit word whatever their base types, so the
      set operators need nothing from the types beyond knowing they are sets. }
    if IsSet(lt) or IsSet(rt) then
      EmitSetBinary(e, l, r, v)
    { 6.8.3.2 table 3 and 6.8.3.5 table 6. A complex operand decides the whole
      operation, so this is taken before the real/integer split rather than
      inside it: `1 + z` is complex addition with the 1 widened, not integer
      addition with something odd afterwards. The two exponentiating operators
      are excluded because their *right* operand is never complex. }
    else if IsComplex(e^.ntype) and (e^.bnOp = opExp) then
      EmitComplexPow(e, l, r, lt, rt, true, v)
    else if IsComplex(e^.ntype) and (e^.bnOp = opPow) then
      EmitComplexPow(e, l, r, lt, rt, false, v)
    else if IsComplex(lt) or IsComplex(rt) then begin
      ToComplex(l, lt);
      ToComplex(r, rt);
      EmitComplexBinary(e, l, r, v)
    end
    else

    case e^.bnOp of
      opAdd, opSub, opMul:
        if IsReal(e^.ntype) then begin
          ToReal(l, lt);
          ToReal(r, rt);
          Def(v);
          if e^.bnOp = opAdd then write(ircode, 'fadd double ')
          else if e^.bnOp = opSub then write(ircode, 'fsub double ')
          else write(ircode, 'fmul double ');
          PutOp(l);
          write(ircode, ', ');
          PutOp(r);
          writeln(ircode)
        end
        else begin
          MsgStart;
          MsgText('integer overflow in                     ');
          Put(' ');
          if e^.bnOp = opAdd then Put('+')
          else if e^.bnOp = opSub then Put('-')
          else Put('*');
          msg := MsgEnd;
          if e^.bnOp = opAdd then EmitCheckedArith('+', l, r, v, msg)
          else if e^.bnOp = opSub then EmitCheckedArith('-', l, r, v, msg)
          else EmitCheckedArith('*', l, r, v, msg)
        end;

      opRealDiv: begin
        ToReal(l, lt);
        ToReal(r, rt);
        Def(v);
        write(ircode, 'fdiv double ');
        PutOp(l);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode)
      end;

      { Exponentiation is the one arithmetic operator with no instruction
        behind it, so all three forms are runtime calls -- and the error
        conditions of 6.8.3.2 go with them rather than being emitted as tests
        around the call. Integer `pow` is where the trap matters most: it is
        repeated multiplication, and each step is checked exactly as `*` is. }
      opExp: begin
        ToReal(l, lt);
        ToReal(r, rt);
        Def(v);
        write(ircode, 'call double @pas_pow_real(double ');
        PutOp(l);
        write(ircode, ', double ');
        PutOp(r);
        writeln(ircode, ')')
      end;

      opPow:
        if IsReal(e^.ntype) then begin
          ToReal(l, lt);
          Def(v);
          write(ircode, 'call double @pas_pow_realint(double ');
          PutOp(l);
          write(ircode, ', i32 ');
          PutOp(r);
          writeln(ircode, ')')
        end
        else begin
          Def(v);
          write(ircode, 'call i32 @pas_pow_int(i32 ');
          PutOp(l);
          write(ircode, ', i32 ');
          PutOp(r);
          writeln(ircode, ')')
        end;

      opIntDiv: begin
        MsgStart;
        MsgText('division by zero                        ');
        msg := MsgEnd;
        GuardNonZero(r, msg);
        { maxint div -1 is representable, but INT_MIN div -1 is not; LLVM calls
          it undefined rather than wrapping, so it is excluded explicitly. }
        Def(m1);
        write(ircode, 'icmp eq i32 ');
        PutOp(l);
        writeln(ircode, ', -2147483648');
        Def(m2);
        write(ircode, 'icmp eq i32 ');
        PutOp(r);
        writeln(ircode, ', -1');
        Def(bad);
        write(ircode, 'and i1 ');
        PutOp(m1);
        write(ircode, ', ');
        PutOp(m2);
        writeln(ircode);
        MsgStart;
        MsgText('integer overflow in div                 ');
        msg := MsgEnd;
        EmitTrapIf(bad, msg);
        Def(v);
        write(ircode, 'sdiv i32 ');
        PutOp(l);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode)
      end;

      opMod: begin
        MsgStart;
        MsgText('mod by zero                             ');
        msg := MsgEnd;
        GuardNonZero(r, msg);
        { ISO 7185 defines i mod j (for j > 0) as a non-negative result, unlike
          the truncating remainder LLVM gives. }
        Def(rem);
        write(ircode, 'srem i32 ');
        PutOp(l);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode);
        Def(neg);
        write(ircode, 'icmp slt i32 ');
        PutOp(rem);
        writeln(ircode, ', 0');
        Def(adj);
        write(ircode, 'add i32 ');
        PutOp(rem);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode);
        Def(v);
        write(ircode, 'select i1 ');
        PutOp(neg);
        write(ircode, ', i32 ');
        PutOp(adj);
        write(ircode, ', i32 ');
        PutOp(rem);
        writeln(ircode)
      end;

      opEq, opNe, opLt, opLe, opGt, opGe: begin
        useFloat := IsReal(lt) or IsReal(rt);
        if useFloat then begin
          ToReal(l, lt);
          ToReal(r, rt);
          Def(v);
          case e^.bnOp of
            opEq: write(ircode, 'fcmp oeq double ');
            opNe: write(ircode, 'fcmp one double ');
            opLt: write(ircode, 'fcmp olt double ');
            opLe: write(ircode, 'fcmp ole double ');
            opGt: write(ircode, 'fcmp ogt double ');
            opGe: write(ircode, 'fcmp oge double ');
            opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
            opExp, opPow, opAndThen, opOrElse:
              write(ircode, 'fcmp oeq double ')
          end
        end
        else begin
          { char, boolean and enumerations compare as unsigned ordinals;
            integer, the only one with negative values, as signed. Pointers
            compare only for equality, which needs no predicate choice. }
          sign := IsInteger(lt);
          Def(v);
          case e^.bnOp of
            opEq: write(ircode, 'icmp eq ');
            opNe: write(ircode, 'icmp ne ');
            opLt: if sign then write(ircode, 'icmp slt ')
                  else write(ircode, 'icmp ult ');
            opLe: if sign then write(ircode, 'icmp sle ')
                  else write(ircode, 'icmp ule ');
            opGt: if sign then write(ircode, 'icmp sgt ')
                  else write(ircode, 'icmp ugt ');
            opGe: if sign then write(ircode, 'icmp sge ')
                  else write(ircode, 'icmp uge ');
            opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
            opExp, opPow, opAndThen, opOrElse:
              write(ircode, 'icmp eq ')
          end;
          if IsPointer(lt) and IsPointer(rt) then write(ircode, 'ptr')
          else if IsPointer(lt) then PutLlType(lt)
          else PutLlType(rt);
          write(ircode, ' ')
        end;
        PutOp(l);
        write(ircode, ', ');
        PutOp(r);
        writeln(ircode)
      end
    end
  end
end;

procedure EmitUnary(e: nodePtr; var v: str);
var a: str;
begin
  EmitExpr(e^.unArg, a);
  case e^.unOp of
    opPos: begin
      ConvertFor(a, e^.unArg^.ntype, e^.ntype);
      v := a
    end;
    { Negation is unchecked, and verify/ carries the theorem saying it cannot
      overflow: -maxint..maxint is symmetric. }
    opNeg:
      if IsReal(e^.ntype) then begin
        ToReal(a, e^.unArg^.ntype);
        Def(v);
        write(ircode, 'fneg double ');
        PutOp(a);
        writeln(ircode)
      end
      else begin
        Def(v);
        write(ircode, 'sub nsw i32 0, ');
        PutOp(a);
        writeln(ircode)
      end;
    opNot: begin
      Def(v);
      write(ircode, 'xor i1 ');
      PutOp(a);
      writeln(ircode, ', true')
    end
  end
end;

{ 6.7.6.2's transcendentals over a complex operand. Each is two calls, one per
  part, because a `double complex` crossing the C boundary would put an ABI
  question into an interface whose whole point is not to have one -- the same
  reason ADR-0030's procedural pair travels as two arguments. The runtime
  computes both parts from the same C99 call, so the pair cannot disagree about
  anything but rounding, which is exact for both halves. }
procedure ComplexCall(stem: msgLit; a: str; var v: str);
var re, im, pr, pi_: str;
begin
  ReOf(a, re);
  ImOf(a, im);
  Def(pr);
  write(ircode, 'call double @');
  PutIrLit(stem);
  write(ircode, '_re(double ');
  PutOp(re);
  write(ircode, ', double ');
  PutOp(im);
  writeln(ircode, ')');
  Def(pi_);
  write(ircode, 'call double @');
  PutIrLit(stem);
  write(ircode, '_im(double ');
  PutOp(re);
  write(ircode, ', double ');
  PutOp(im);
  writeln(ircode, ')');
  MakeComplex(pr, pi_, v)
end;

procedure EmitCall(e: nodePtr; var v: str);
var a, w, lim, tmp, b_, re, im, x, y, c_, d_: str;
    at, idx: typePtr; msg, up: integer; isSucc: boolean;
begin
  if e^.clSym <> nil then
    EmitUserCall(e^.clSym, e^.clArgs, v)
  { 6.7.6.8's binding(f): the result is a record, so it is built in the hidden
    frame slot Sema gave this call site and the call becomes that slot's
    address. Everything after -- a field selection, a whole-record assignment,
    a value parameter -- is then the ordinary designator it looks like. }
  else if e^.clBuiltin = biBinding then begin
    if e^.clSlot = nil then
      OpInt(0, v)
    else begin
      EmitAddress(e^.clArgs, a);
      AddressOfSym(e^.clSlot, v);
      Def(x);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(e^.clSlot^.stype);
      write(ircode, ', ptr ');
      PutOp(v);
      writeln(ircode, ', i32 0, i32 0');
      Def(y);
      write(ircode, 'call ptr @pas_binding_name(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      Def(c_);
      write(ircode, 'call i32 @pas_binding_namelen(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      write(ircode, '  call void @pas_str_store_var(ptr ');
      PutOp(x);
      write(ircode, ', i32 ', bindNameCap:1, ', ptr ');
      PutOp(y);
      write(ircode, ', i32 ');
      PutOp(c_);
      writeln(ircode, ')');
      Def(d_);
      write(ircode, 'call i32 @pas_binding_bound(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      Def(w);
      write(ircode, 'trunc i32 ');
      PutOp(d_);
      writeln(ircode, ' to i1');
      Def(x);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(e^.clSlot^.stype);
      write(ircode, ', ptr ');
      PutOp(v);
      writeln(ircode, ', i32 0, i32 1');
      write(ircode, '  store i1 ');
      PutOp(w);
      write(ircode, ', ptr ');
      PutOp(x);
      writeln(ircode)
    end
  end
  { 6.7.6.7's string functions. `substr` and `trim` are string *values* and are
    emitted by EmitString; the rest answer about one, so they take the pair
    apart here. }
  else if e^.clBuiltin = biLength then begin
    EmitString(e^.clArgs, x, v)
  end
  else if e^.clBuiltin = biIndex then begin
    EmitString(e^.clArgs, x, y);
    EmitString(e^.clArgs^.next, c_, d_);
    Def(v);
    write(ircode, 'call i32 @pas_str_index(ptr ');
    PutOp(x);
    write(ircode, ', i32 ');
    PutOp(y);
    write(ircode, ', ptr ');
    PutOp(c_);
    write(ircode, ', i32 ');
    PutOp(d_);
    writeln(ircode, ')')
  end
  else if (e^.clBuiltin = biSubstr) or (e^.clBuiltin = biTrim) then
    EmitStringValue(e, v)
  else if (e^.clBuiltin = biStrEq) or (e^.clBuiltin = biStrNe) or
          (e^.clBuiltin = biStrLt) or (e^.clBuiltin = biStrGt) or
          (e^.clBuiltin = biStrLe) or (e^.clBuiltin = biStrGe) then begin
    EmitString(e^.clArgs, x, y);
    EmitString(e^.clArgs^.next, c_, d_);
    { 6.7.6.7's NOTE 3: these are *not* the operators -- they compare lengths
      as well as characters, so a proper prefix is strictly less than its
      extension where `<` would pad and call them equal. }
    Def(w);
    write(ircode, 'call i32 @pas_str_cmp_exact(ptr ');
    PutOp(x);
    write(ircode, ', i32 ');
    PutOp(y);
    write(ircode, ', ptr ');
    PutOp(c_);
    write(ircode, ', i32 ');
    PutOp(d_);
    writeln(ircode, ')');
    Def(v);
    write(ircode, 'icmp ');
    case e^.clBuiltin of
      biStrEq: write(ircode, 'eq');
      biStrNe: write(ircode, 'ne');
      biStrLt: write(ircode, 'slt');
      biStrGt: write(ircode, 'sgt');
      biStrLe: write(ircode, 'sle');
      biStrGe: write(ircode, 'sge');
      biNone, biAbs, biSqr, biOdd, biOrd, biChr, biSucc, biPred, biSqrt,
      biSin, biCos, biLn, biExp, biArcTan, biTrunc, biRound, biEof, biEoln,
      biCmplx, biPolar, biRe, biIm, biArg, biPosition, biLastPosition,
      biEmpty, biLength, biIndex, biSubstr, biTrim: write(ircode, 'eq')
    end;
    write(ircode, ' i32 ');
    PutOp(w);
    writeln(ircode, ', 0')
  end
  { 6.7.6.5's `empty` and 6.7.6.6's two positions. The runtime counts from
    zero, so a position comes back relative to the index-type's smallest value
    and the lower bound is added here -- the same fold an array subscript makes
    in the other direction. }
  else if (e^.clBuiltin = biEmpty) or (e^.clBuiltin = biPosition) or
          (e^.clBuiltin = biLastPosition) then begin
    if e^.clArgs = nil then
      OpInt(0, v)
    else begin
      EmitAddress(e^.clArgs, a);
      Def(w);
      if e^.clBuiltin = biEmpty then write(ircode, 'call i32 @pas_empty(ptr ')
      else if e^.clBuiltin = biPosition then
        write(ircode, 'call i32 @pas_position(ptr ')
      else write(ircode, 'call i32 @pas_lastposition(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      if e^.clBuiltin = biEmpty then begin
        Def(v);
        write(ircode, 'trunc i32 ');
        PutOp(w);
        writeln(ircode, ' to i1')
      end
      else begin
        idx := e^.clArgs^.ntype^.indexType;
        if OrdinalLo(idx) <> 0 then begin
          Def(lim);
          write(ircode, 'add i32 ');
          PutOp(w);
          writeln(ircode, ', ', OrdinalLo(idx):1);
          w := lim
        end;
        { the result possesses the index type, which may be narrower than i32 }
        if IsChar(idx) or IsBoolean(idx) then begin
          Def(v);
          write(ircode, 'trunc i32 ');
          PutOp(w);
          write(ircode, ' to ');
          PutLlType(idx);
          writeln(ircode)
        end
        else
          v := w
      end
    end
  end
  { The file enquiries take the file's address, not its value, and Sema has
    already supplied `input` where the program left the argument out. }
  else if (e^.clBuiltin = biEof) or (e^.clBuiltin = biEoln) then begin
    if e^.clArgs = nil then
      OpWord('false           ', v)   { the parameter was missing: reported }
    else begin
      EmitAddress(e^.clArgs, a);
      Def(w);
      if e^.clBuiltin = biEof then write(ircode, 'call i32 @pas_eof(ptr ')
      else write(ircode, 'call i32 @pas_eoln(ptr ');
      PutOp(a);
      writeln(ircode, ')');
      Def(v);
      write(ircode, 'trunc i32 ');
      PutOp(w);
      writeln(ircode, ' to i1')
    end
  end
  { 6.7.6.3: the two-argument constructors, and the only way to write a complex
    value -- the standard gives the type no literal. `polar` is
    `r*cos t + r*sin t * i`, computed here rather than in the runtime for the
    same reason the operators are. }
  else if (e^.clBuiltin = biCmplx) or (e^.clBuiltin = biPolar) then begin
    EmitExpr(e^.clArgs, x);
    ToReal(x, e^.clArgs^.ntype);
    EmitExpr(e^.clArgs^.next, y);
    ToReal(y, e^.clArgs^.next^.ntype);
    if e^.clBuiltin = biCmplx then
      MakeComplex(x, y, v)
    else begin
      Def(c_);
      write(ircode, 'call double @llvm.cos.f64(double ');
      PutOp(y);
      writeln(ircode, ')');
      Def(d_);
      write(ircode, 'call double @llvm.sin.f64(double ');
      PutOp(y);
      writeln(ircode, ')');
      Def(re);
      write(ircode, 'fmul double ');
      PutOp(x);
      write(ircode, ', ');
      PutOp(c_);
      writeln(ircode);
      Def(im);
      write(ircode, 'fmul double ');
      PutOp(x);
      write(ircode, ', ');
      PutOp(d_);
      writeln(ircode);
      MakeComplex(re, im, v)
    end
  end
  else begin
    EmitExpr(e^.clArgs, a);
    at := e^.clArgs^.ntype;
    { The three accessors are the representation itself, so they are not
      calls. }
    if IsComplex(at) then
      case e^.clBuiltin of
        biRe: ReOf(a, v);
        biIm: ImOf(a, v);
        { 6.7.6.2's `abs` of a complex is its magnitude and `arg` its argument,
          and both yield a *real* -- the two places the table's result kind
          does not follow its operand. }
        biAbs: begin
          ReOf(a, re);
          ImOf(a, im);
          Def(v);
          write(ircode, 'call double @hypot(double ');
          PutOp(re);
          write(ircode, ', double ');
          PutOp(im);
          writeln(ircode, ')')
        end;
        biArg: begin
          ReOf(a, re);
          ImOf(a, im);
          Def(v);
          write(ircode, 'call double @atan2(double ');
          PutOp(im);
          write(ircode, ', double ');
          PutOp(re);
          writeln(ircode, ')')
        end;
        { sqr keeps its operand's type, so this is the multiplication with
          both operands the same value. }
        biSqr: begin
          ReOf(a, x);
          ImOf(a, y);
          Def(c_);
          write(ircode, 'fmul double ');
          PutOp(x);
          write(ircode, ', ');
          PutOp(x);
          writeln(ircode);
          Def(d_);
          write(ircode, 'fmul double ');
          PutOp(y);
          write(ircode, ', ');
          PutOp(y);
          writeln(ircode);
          Def(re);
          write(ircode, 'fsub double ');
          PutOp(c_);
          write(ircode, ', ');
          PutOp(d_);
          writeln(ircode);
          Def(b_);
          write(ircode, 'fmul double ');
          PutOp(x);
          write(ircode, ', ');
          PutOp(y);
          writeln(ircode);
          Def(im);
          write(ircode, 'fmul double 2.0, ');
          PutOp(b_);
          writeln(ircode);
          MakeComplex(re, im, v)
        end;
        biSqrt:   ComplexCall('pas_csqrt       ', a, v);
        biSin:    ComplexCall('pas_csin        ', a, v);
        biCos:    ComplexCall('pas_ccos        ', a, v);
        biLn:     ComplexCall('pas_cln         ', a, v);
        biExp:    ComplexCall('pas_cexp        ', a, v);
        biArcTan: ComplexCall('pas_carctan     ', a, v);
        biNone, biOdd, biOrd, biChr, biSucc, biPred, biTrunc, biRound,
        biEof, biEoln, biCmplx, biPolar, biPosition, biLastPosition, biEmpty,
        biLength, biIndex, biSubstr, biTrim, biStrEq, biStrNe, biStrLt,
        biStrGt, biStrLe, biStrGe:
          OpWord('undef           ', v)
      end
    else
    case e^.clBuiltin of
      biAbs:
        if IsReal(at) then begin
          Def(v);
          write(ircode, 'call double @llvm.fabs.f64(double ');
          PutOp(a);
          writeln(ircode, ')')
        end
        else begin
          Def(v);
          write(ircode, 'call i32 @llvm.abs.i32(i32 ');
          PutOp(a);
          writeln(ircode, ', i1 false)')
        end;
      biSqr:
        if IsReal(at) then begin
          Def(v);
          write(ircode, 'fmul double ');
          PutOp(a);
          write(ircode, ', ');
          PutOp(a);
          writeln(ircode)
        end
        else begin
          MsgStart;
          MsgText('integer overflow in sqr                 ');
          msg := MsgEnd;
          EmitCheckedArith('*', a, a, v, msg)
        end;
      biOdd: begin
        Def(w);
        write(ircode, 'and i32 ');
        PutOp(a);
        writeln(ircode, ', 1');
        Def(v);
        write(ircode, 'icmp ne i32 ');
        PutOp(w);
        writeln(ircode, ', 0')
      end;
      biOrd:
        if IsInteger(at) or IsEnum(at) then
          v := a
        else begin
          Def(v);
          write(ircode, 'zext ');
          PutLlType(at);
          write(ircode, ' ');
          PutOp(a);
          writeln(ircode, ' to i32')
        end;
      biChr: begin
        { ISO 7185 6.6.6.4: chr(i) is an error unless i is the ordinal of some
          char, so the truncation is guarded rather than allowed to alias. }
        Def(w);
        write(ircode, 'icmp slt i32 ');
        PutOp(a);
        writeln(ircode, ', 0');
        Def(lim);
        write(ircode, 'icmp sgt i32 ');
        PutOp(a);
        writeln(ircode, ', 255');
        Def(tmp);
        write(ircode, 'or i1 ');
        PutOp(w);
        write(ircode, ', ');
        PutOp(lim);
        writeln(ircode);
        MsgStart;
        MsgText('chr: argument is not a character        ');
        Put(' ');
        MsgText('ordinal                                 ');
        msg := MsgEnd;
        EmitTrapIf(tmp, msg);
        Def(v);
        write(ircode, 'trunc i32 ');
        PutOp(a);
        writeln(ircode, ' to i8')
      end;
      biSucc, biPred: begin
        { succ and pred are errors at the ends of the ordinal type (6.6.6.4),
          and which type that is decides where the ends are: `blue` for an
          enumeration, 9 for a subrange 1..9, maxint for an integer. }
        isSucc := e^.clBuiltin = biSucc;
        if isSucc then up := OrdinalHi(at) else up := OrdinalLo(at);
        OpInt(up, lim);
        Def(w);
        write(ircode, 'icmp eq ');
        PutLlType(at);
        write(ircode, ' ');
        PutOp(a);
        write(ircode, ', ');
        PutOp(lim);
        writeln(ircode);
        MsgStart;
        if isSucc then MsgText('succ                                    ')
        else MsgText('pred                                    ');
        MsgText(':                                       ');
        Put(' ');
        WriteOrdinalName(at, up);
        MsgText(' has no                                 ');
        Put(' ');
        if isSucc then MsgText('successor                               ')
        else MsgText('predecessor                             ');
        Put(' ');
        MsgText('in                                      ');
        Put(' ');
        WriteTypeName(at);
        msg := MsgEnd;
        EmitTrapIf(w, msg);
        Def(v);
        if isSucc then write(ircode, 'add ') else write(ircode, 'sub ');
        PutLlType(at);
        write(ircode, ' ');
        PutOp(a);
        writeln(ircode, ', 1')
      end;
      biSqrt, biSin, biCos, biLn, biExp, biArcTan: begin
        ToReal(a, at);
        Def(v);
        case e^.clBuiltin of
          biSqrt: write(ircode, 'call double @llvm.sqrt.f64(double ');
          biSin:  write(ircode, 'call double @llvm.sin.f64(double ');
          biCos:  write(ircode, 'call double @llvm.cos.f64(double ');
          biLn:   write(ircode, 'call double @llvm.log.f64(double ');
          biExp:  write(ircode, 'call double @llvm.exp.f64(double ');
          biArcTan: write(ircode, 'call double @atan(double ');
          biNone, biAbs, biSqr, biOdd, biOrd, biChr, biSucc, biPred, biTrunc,
          biRound, biEof, biEoln: write(ircode, 'call double @atan(double ')
        end;
        PutOp(a);
        writeln(ircode, ')')
      end;
      biTrunc: begin
        ToReal(a, at);
        MsgStart;
        MsgText('trunc: value out of integer range       ');
        msg := MsgEnd;
        CheckedFpToInt(a, v, msg)
      end;
      biRound: begin
        { llvm.round rounds halfway cases away from zero, which is what ISO
          7185 6.6.6.3 asks for; the range check then applies to the rounded
          value. }
        ToReal(a, at);
        Def(w);
        write(ircode, 'call double @llvm.round.f64(double ');
        PutOp(a);
        writeln(ircode, ')');
        MsgStart;
        MsgText('round: value out of integer range       ');
        msg := MsgEnd;
        CheckedFpToInt(w, v, msg)
      end;
      biNone, biEof, biEoln, biCmplx, biPolar, biRe, biIm, biArg,
      biPosition, biLastPosition, biEmpty, biLength, biIndex, biSubstr,
      biTrim, biStrEq, biStrNe, biStrLt, biStrGt, biStrLe, biStrGe: OpInt(0, v)
    end
  end
end;

procedure EmitAddress;
var base, idx, lo, hi, below, above, bad, off, target, stride, byte: str;
    hdr: str; arr: typePtr; msg: integer;
begin
  case e^.kind of
    nkVar: begin
      AddressOfSym(e^.vrSym, base);
      if e^.vrField = nil then
        v := base
      else
        { The name was a field of an enclosing `with`, and vrSym is that
          statement's binding -- the record's address, taken once on entry. }
        FieldAddress(base, e^.vrSym^.stype, e^.vrField, v)
    end;

    nkField: begin
      EmitAddress(e^.fdBase, base);
      FieldAddress(base, e^.fdBase^.ntype, e^.fdResolved, v)
    end;

    nkIndex: begin
      arr := e^.ixBase^.ntype;
      { 6.4.3.3.3 NOTE 1: "The individual components of a variable-string-type
        can be obtained by indexing it as an array." The bound is the *length*,
        not the capacity (6.5.3.2), because the index-domain is the value's and
        the capacity is the type's -- so this cannot go through the array path,
        whose bounds come from the type. }
      if IsVarString(arr) then begin
        EmitString(e^.ixBase, base, hi);
        EmitExpr(e^.ixIndex, idx);
        Def(below);
        write(ircode, 'icmp slt i32 ');
        PutOp(idx);
        writeln(ircode, ', 1');
        Def(above);
        write(ircode, 'icmp sgt i32 ');
        PutOp(idx);
        write(ircode, ', ');
        PutOp(hi);
        writeln(ircode);
        Def(bad);
        write(ircode, 'or i1 ');
        PutOp(below);
        write(ircode, ', ');
        PutOp(above);
        writeln(ircode);
        OpInt(1, lo);
        EmitTrapIndex(bad, lo, hi);
        Def(off);
        write(ircode, 'sub i32 ');
        PutOp(idx);
        writeln(ircode, ', 1');
        Def(v);
        write(ircode, 'getelementptr inbounds i8, ptr ');
        PutOp(base);
        write(ircode, ', i32 ');
        PutOp(off);
        writeln(ircode)
      end
      else begin
      arr := e^.ixBase^.ntype;
      EmitAddress(e^.ixBase, base);
      EmitExpr(e^.ixIndex, idx);
      { char and boolean subscripts are narrower than i32; widening is exact
        because their ordinals are non-negative. }
      if IsChar(e^.ixIndex^.ntype) or IsBoolean(e^.ixIndex^.ntype) then begin
        Def(off);
        write(ircode, 'zext ');
        PutLlType(e^.ixIndex^.ntype);
        write(ircode, ' ');
        PutOp(idx);
        writeln(ircode, ' to i32');
        idx := off
      end;
      { ISO 7185 6.5.3.2 makes an index outside the bounds an error. The check
        comes first, so the subtraction below cannot overflow: afterwards
        lo <= i <= hi, and both bounds are values of the index type. }
      { A heap variable's tuple sits in front of the *variable*, so the
        bounds come from there rather than from any activation record -- and
        for an inner dimension that is not the address just computed. }
      HeapHeader(e^.ixBase, hdr);
      BoundValue(arr, false, hdr, lo);
      BoundValue(arr, true, hdr, hi);
      Def(below);
      write(ircode, 'icmp slt i32 ');
      PutOp(idx);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      Def(above);
      write(ircode, 'icmp sgt i32 ');
      PutOp(idx);
      write(ircode, ', ');
      PutOp(hi);
      writeln(ircode);
      Def(bad);
      write(ircode, 'or i1 ');
      PutOp(below);
      write(ircode, ', ');
      PutOp(above);
      writeln(ircode);
      { The message names the bounds, so a schematic array's has to be built
        where the bounds are known -- which is at run time, in the runtime. }
      if (arr^.loDisc <> nil) or (arr^.hiDisc <> nil) then
        EmitTrapIndex(bad, lo, hi)
      else begin
        MsgStart;
        MsgText('array index out of bounds (             ');
        AppendInt(msgBuf, arr^.lo);
        MsgText('..                                      ');
        AppendInt(msgBuf, arr^.hi);
        Put(')');
        msg := MsgEnd;
        EmitTrapIf(bad, msg)
      end;

      Def(off);
      write(ircode, 'sub i32 ');
      PutOp(idx);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      { An array whose extent is not known until the block is entered has no
        LLVM array type to index: the component's size is what the descriptor
        answers, so the address is computed in bytes. The arithmetic is the
        same `(i - lo) * stride` the two-index getelementptr stands for. }
      if DynamicExtent(arr) then begin
        DynSize(arr^.elem, hdr, stride);
        Def(byte);
        write(ircode, 'mul i32 ');
        PutOp(off);
        write(ircode, ', ');
        PutOp(stride);
        writeln(ircode);
        Def(v);
        write(ircode, 'getelementptr inbounds i8, ptr ');
        PutOp(base);
        write(ircode, ', i32 ');
        PutOp(byte);
        writeln(ircode)
      end
      else begin
        Def(v);
        write(ircode, 'getelementptr inbounds ');
        PutLlType(arr);
        write(ircode, ', ptr ');
        PutOp(base);
        write(ircode, ', i32 0, i32 ');
        PutOp(off);
        writeln(ircode)
      end
      end
    end;

    nkDeref:
      { `f^` on a file is the buffer variable, not a dereference: the runtime
        owns it, so it hands back its address -- and fetches the character it
        holds first, which is where the lookahead actually happens. }
      if IsFile(e^.drBase^.ntype) then begin
        EmitAddress(e^.drBase, base);
        Def(v);
        write(ircode, 'call ptr @pas_buffer(ptr ');
        PutOp(base);
        writeln(ircode, ')')
      end
      else begin
        { The pointer's *value* is the address of the variable it denotes. }
        EmitExpr(e^.drBase, target);
        Def(bad);
        write(ircode, 'icmp eq ptr ');
        PutOp(target);
        writeln(ircode, ', null');
        MsgStart;
        MsgText('dereference of nil                      ');
        msg := MsgEnd;
        EmitTrapIf(bad, msg);
        v := target
      end;

    { A literal is a packed array of char, so it needs an address like any
      other value of that type. }
    nkStr: OpGlobal(AddGlobal(e^.stAt, e^.stLen), v);

    { 6.7.6.8's binding(f) denotes the hidden frame slot its result was built
      in, so it is an address like any designator's. }
    nkCall: EmitCall(e, v);

    nkInt, nkReal, nkChar, nkNil, nkSet, nkSetMember, nkBinary, nkUnary,
    nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
    nkFor, nkProcCall, nkWith, nkCase, nkWriteArg, nkCaseArm, nkVariantArm,
    nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord,
    nkPointer, nkFile, nkSetOf, nkSchema, nkInquiry, nkConstDecl, nkTypeDecl,
    nkProcDecl, nkBlock:
      OpWord('null            ', v)   { Sema has already required a designator }
  end
end;

procedure EmitExpr;
var addr: str;
begin
  case e^.kind of
    nkInt: OpInt(e^.intVal, v);
    nkReal: EmitRealText(e^.rlAt, e^.rlLen, false, v);
    nkChar: OpInt(ord(e^.chVal), v);
    nkStr: EmitAddress(e, v);
    nkNil: OpWord('null            ', v);
    nkDeref, nkIndex: EmitLoad(e, v);
    { A schema-discriminant is the value the type was produced with, so it is
      a constant here and there is nothing to load (6.8.4). }
    nkField:
      { ...unless the base is a schematic formal parameter, whose type was
        produced with no tuple: then it is one field of the descriptor the
        actual brought, and reading it is a load like any other. }
      if e^.fdDiscSym <> nil then
        { A heap variable's tuple is in front of the variable, so `p^.n` is
          read from where `p^` is; every other descriptor is reached by the
          walk any enclosing variable takes. }
        if e^.fdDiscSym^.heapDisc then
          DiscValue(e^.fdBase, e^.fdDiscSym^.discIndex, e^.ntype, v)
        else begin
          AddressOfSym(e^.fdDiscSym, addr);
          Def(v);
          write(ircode, 'load ');
          PutLlType(e^.ntype);
          write(ircode, ', ptr ');
          PutOp(addr);
          writeln(ircode)
        end
      else if e^.fdIsDisc then OpInt(e^.fdDiscValue, v)
      else EmitLoad(e, v);
    nkVar:
      if (e^.vrField = nil) and (e^.vrSym^.kind = skConst) then
        EmitConst(e^.vrSym, v)
      { A parameterless call written as a bare name -- of a function, or of a
        functional parameter, which is the same call through a loaded
        address. }
      else if (e^.vrField = nil) and IsInvocable(e^.vrSym) then
        EmitUserCall(e^.vrSym, nil, v)
      else
        EmitLoad(e, v);
    nkSet: EmitSet(e, v);
    nkBinary: EmitBinary(e, v);
    nkUnary: EmitUnary(e, v);
    nkCall: EmitCall(e, v);
    nkSetMember,
    nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
    nkFor, nkProcCall, nkWith, nkCase, nkWriteArg, nkCaseArm, nkVariantArm,
    nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord,
    nkPointer, nkFile, nkSetOf, nkSchema, nkInquiry, nkConstDecl, nkTypeDecl,
    nkProcDecl, nkBlock:
      OpInt(0, v)
  end
end;

{ ============================== statements =============================== }

{ Copy one whole array or record from an address already in hand. `read` from
  a file whose component is structured needs this form: what it copies from is
  the buffer variable, which is a runtime call rather than a designator. }
procedure EmitCopyAt(var dst: str; t: typePtr; var src: str);
var align: integer;
begin
  align := LlAlign(t);
  write(ircode, '  call void @llvm.memcpy.p0.p0.i64(ptr align ', align:1, ' ');
  PutOp(dst);
  write(ircode, ', ptr align ', align:1, ' ');
  PutOp(src);
  writeln(ircode, ', i64 ', LlSize(t):1, ', i1 false)')
end;

procedure EmitCopy(var dst: str; t: typePtr; src: nodePtr);
var s: str;
begin
  EmitAddress(src, s);
  EmitCopyAt(dst, t, s)
end;

{ Give the variable at `dst`, of type `t`, the value of `src`. This is the
  whole of what assignment does -- the conversion, the range check, and the
  whole-variable copy -- and `write` to a file that is not a text needs exactly
  it, because 6.6.5.2 defines that write as `f^ := e`. }
procedure EmitStore(var dst: str; t: typePtr; src: nodePtr);
var v, hdr: str;
begin
  { ISO/IEC 10206:1991 6.4.6: a string destination is not a memcpy. A short
    value is padded with spaces into a fixed string, kept at its own length in
    a variable one, and a value longer than the capacity is an *error* -- so
    this is a runtime operation and is taken before the copy below. }
  if IsStringType(t) and IsStringOrChar(src^.ntype) and
     (IsVarString(t) or IsVarString(src^.ntype) or IsChar(src^.ntype) or
      (TypeLength(t) <> TypeLength(src^.ntype))) then begin
    StrClear(hdr);
    EmitStringStore(dst, t, src, hdr)
  end
  { A whole array or record is copied; ISO 7185 6.8.2.2 makes assignment of a
    structured value a copy of every component, not a sharing of storage. }
  else if IsStructured(t) then
    EmitCopy(dst, t, src)
  else begin
    EmitExpr(src, v);
    ConvertFor(v, src^.ntype, t);
    CheckedForStore(v, t);
    write(ircode, '  store ');
    PutLlType(t);
    write(ircode, ' ');
    PutOp(v);
    write(ircode, ', ptr ');
    PutOp(dst);
    writeln(ircode)
  end
end;

{ A discriminant may be of any ordinal type, and a message reports it as a
  number -- which is what its ordinal is. }
procedure WidenOrdinal(var v: str; t: typePtr);
var raw: str;
begin
  if IsChar(t) or IsBoolean(t) then begin
    raw := v;
    Def(v);
    write(ircode, 'zext ');
    PutLlType(t);
    write(ircode, ' ');
    PutOp(raw);
    writeln(ircode, ' to i32')
  end
end;

{ Two types produced from one schema are the same type exactly when they were
  produced with the same tuple (6.4.8), so that is the comparison -- one per
  discriminant, whatever the body did with them. A discriminant may be of any
  ordinal type; the message reports it as a number, which is what its ordinal
  is. }
procedure EmitTupleCheck(dst, src: nodePtr);
var dp: symListPtr; l, r, bad: str;
    schema: symPtr; schemaMsg, discMsg, k: integer;
begin
  schema := dst^.ntype^.schema;
  MsgStart;
  WritePool(schema^.at, schema^.len);
  schemaMsg := MsgEnd;
  dp := schema^.discs;
  k := 0;
  while dp <> nil do begin
    DiscValue(dst, k, dp^.sym^.stype, l);
    DiscValue(src, k, dp^.sym^.stype, r);
    MsgStart;
    WritePool(dp^.sym^.at, dp^.sym^.len);
    discMsg := MsgEnd;
    Def(bad);
    write(ircode, 'icmp ne ');
    PutLlType(dp^.sym^.stype);
    write(ircode, ' ');
    PutOp(l);
    write(ircode, ', ');
    PutOp(r);
    writeln(ircode);
    WidenOrdinal(l, dp^.sym^.stype);
    WidenOrdinal(r, dp^.sym^.stype);
    EmitTrapDisc(bad, schemaMsg, discMsg, l, r);
    k := k + 1;
    dp := dp^.next
  end
end;

{ 6.4.6 d): where both types were produced from one schema but the tuples are
  not both known, whether they are the same type is a question only the running
  program can answer. Sema let the assignment through on the schema alone, so
  this is where the tuples meet -- and once they agree the copy is the ordinary
  whole-variable one with a length that is computed rather than written. }
procedure EmitAssign(s: nodePtr);
var dst, src, size, hdr: str; t, comp: typePtr; align: integer;
begin
  EmitAddress(s^.asTarget, dst);
  t := s^.asTarget^.ntype;
  { A string is produced from the required schema, so it would otherwise take
    the tuple-comparison path below -- and must not: 6.4.6 f) makes two
    capacities *compatible*, and the check that matters is the value's length
    against the destination's capacity, which the store makes. }
  if IsStringType(t) then begin
    HeapHeader(s^.asTarget, hdr);
    EmitStringStore(dst, t, s^.asValue, hdr)
  end
  else if (t^.schema <> nil) and
     (IsGeneric(t) or IsGeneric(s^.asValue^.ntype)) then begin
    EmitTupleCheck(s^.asTarget, s^.asValue);
    EmitAddress(s^.asValue, src);
    { The alignment is the component's, for the same reason a schematic value
      parameter's copy takes it from there: the array type has no extent to
      give. }
    comp := t;
    while comp^.kind = tyArray do comp := comp^.elem;
    align := LlAlign(comp);
    { The length is the *destination's*, which the tuple check has just shown
      to be the source's too -- and for a variable created by `new` it is read
      from the header in front of it rather than from a descriptor. }
    HeaderOf(t, dst, hdr);
    DynSize(t, hdr, size);
    write(ircode, '  call void @llvm.memcpy.p0.p0.i32(ptr align ', align:1,
          ' ');
    PutOp(dst);
    write(ircode, ', ptr align ', align:1, ' ');
    PutOp(src);
    write(ircode, ', i32 ');
    PutOp(size);
    writeln(ircode, ', i1 false)')
  end
  else
    EmitStore(dst, t, s^.asValue)
end;

procedure EmitWrite(s: nodePtr);
var fh, v, width, prec, addr, slen, shdr, sdata: str;
    a: nodePtr; b: typePtr;
begin
  if s^.wrFile <> nil then begin
    EmitAddress(s^.wrFile, fh);
    { On a file that is not a text, ISO 7185 6.6.5.2 defines write(f, e) as
      f^ := e; put(f) -- so it is emitted as exactly that, an assignment to
      the buffer variable and the primitive. No formatting applies. }
    if not IsTextFile(s^.wrFile^.ntype) then begin
      a := s^.wrArgs;
      while a <> nil do begin
        Def(addr);
        write(ircode, 'call ptr @pas_buffer(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        EmitStore(addr, s^.wrFile^.ntype^.elem, a^.waValue);
        write(ircode, '  call void @pas_put(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        a := a^.next
      end
    end
    else begin
    a := s^.wrArgs;
    while a <> nil do begin
      if a^.waWidth <> nil then EmitExpr(a^.waWidth, width)
      else OpInt(-1, width);
      if a^.waPrec <> nil then EmitExpr(a^.waPrec, prec)
      else OpInt(-1, prec);

      { A packed array of char is written as its address plus its length --
        which covers a string literal, since that is what a literal's type is. }
      { A string is written as its address plus its length -- which covers a
      literal, since that is what a literal's type is, and a variable-string
      and a canonical value alike, since EmitString is what a string value
      *is*. 6.10.3.6 asks for exactly those two numbers. }
    if IsStringType(a^.waValue^.ntype) then begin
      EmitString(a^.waValue, sdata, slen);
      write(ircode, '  call void @pas_write_str(ptr ');
      PutOp(fh);
      write(ircode, ', ptr ');
      PutOp(sdata);
      write(ircode, ', i32 ');
      PutOp(slen);
      write(ircode, ', i32 ');
      PutOp(width);
      writeln(ircode, ')')
    end
    else if IsCharArray(a^.waValue^.ntype) then begin
        EmitAddress(a^.waValue, addr);
        HeapHeader(a^.waValue, shdr);
        DynLength(a^.waValue^.ntype, shdr, slen);
        write(ircode, '  call void @pas_write_str(ptr ');
        PutOp(fh);
        write(ircode, ', ptr ');
        PutOp(addr);
        write(ircode, ', i32 ');
        PutOp(slen);
        write(ircode, ', i32 ');
        PutOp(width);
        writeln(ircode, ')')
      end
      else begin
        EmitExpr(a^.waValue, v);
        b := Base(a^.waValue^.ntype);
        if b^.kind = tyInteger then begin
          Def(addr);
          write(ircode, 'sext i32 ');
          PutOp(v);
          writeln(ircode, ' to i64');
          write(ircode, '  call void @pas_write_int(ptr ');
          PutOp(fh);
          write(ircode, ', i64 ');
          PutOp(addr);
          write(ircode, ', i32 ');
          PutOp(width);
          writeln(ircode, ')')
        end
        else if b^.kind = tyReal then begin
          write(ircode, '  call void @pas_write_real(ptr ');
          PutOp(fh);
          write(ircode, ', double ');
          PutOp(v);
          write(ircode, ', i32 ');
          PutOp(width);
          write(ircode, ', i32 ');
          PutOp(prec);
          writeln(ircode, ')')
        end
        else if b^.kind = tyBoolean then begin
          Def(addr);
          write(ircode, 'zext i1 ');
          PutOp(v);
          writeln(ircode, ' to i32');
          write(ircode, '  call void @pas_write_bool(ptr ');
          PutOp(fh);
          write(ircode, ', i32 ');
          PutOp(addr);
          write(ircode, ', i32 ');
          PutOp(width);
          writeln(ircode, ')')
        end
        else if b^.kind = tyChar then begin
          write(ircode, '  call void @pas_write_char(ptr ');
          PutOp(fh);
          write(ircode, ', i8 ');
          PutOp(v);
          write(ircode, ', i32 ');
          PutOp(width);
          writeln(ircode, ')')
        end
      end;
      a := a^.next
    end;
    if s^.wrNewline then begin
      write(ircode, '  call void @pas_writeln(ptr ');
      PutOp(fh);
      writeln(ircode, ')')
    end
    end
  end
end;

{ Each variable is filled by the runtime call its type selects, and `readln`
  then finishes the line -- which is what makes readln(x) one statement. }
procedure EmitRead(s: nodePtr);
var fh, slot, v, wide, buf, rhdr, rcap: str; a: nodePtr; t, comp: typePtr;
begin
  if s^.rdFile <> nil then begin
    EmitAddress(s^.rdFile, fh);
    { The mirror of EmitWrite: on a file that is not a text, 6.6.5.2 makes
      read(f, v) mean v := f^; get(f). The buffer variable is fetched again
      for each variable because `get` invalidates the previous one. }
    if not IsTextFile(s^.rdFile^.ntype) then begin
      comp := s^.rdFile^.ntype^.elem;
      a := s^.rdArgs;
      while a <> nil do begin
        EmitAddress(a, slot);
        Def(buf);
        write(ircode, 'call ptr @pas_buffer(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        if IsStructured(a^.ntype) then
          EmitCopyAt(slot, a^.ntype, buf)
        else begin
          Def(v);
          write(ircode, 'load ');
          PutLlType(comp);
          write(ircode, ', ptr ');
          PutOp(buf);
          writeln(ircode);
          ConvertFor(v, comp, a^.ntype);
          CheckedForStore(v, a^.ntype);
          write(ircode, '  store ');
          PutLlType(a^.ntype);
          write(ircode, ' ');
          PutOp(v);
          write(ircode, ', ptr ');
          PutOp(slot);
          writeln(ircode)
        end;
        write(ircode, '  call void @pas_get(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        a := a^.next
      end
    end
    else begin
    a := s^.rdArgs;
    while a <> nil do begin
      EmitAddress(a, slot);
      t := a^.ntype;
      { ISO/IEC 10206:1991 6.10.1 e) and f): reading a string does not skip
        leading blanks, never crosses an end-of-line, and takes at most the
        capacity -- a fixed target is then padded with spaces and a variable
        one gets exactly what was read. That is one runtime call for both, told
        apart by the capacity and one flag. }
      if IsStringType(t) then begin
        HeapHeader(a, rhdr);
        if IsVarString(t) then StringCapacity(t, rhdr, rcap)
        else DynLength(t, rhdr, rcap);
        write(ircode, '  call void @pas_read_str(ptr ');
        PutOp(fh);
        write(ircode, ', ptr ');
        PutOp(slot);
        write(ircode, ', i32 ');
        PutOp(rcap);
        if IsVarString(t) then writeln(ircode, ', i32 1)')
        else writeln(ircode, ', i32 0)')
      end
      else if IsChar(t) then begin
        Def(v);
        write(ircode, 'call i8 @pas_read_char(ptr ');
        PutOp(fh);
        writeln(ircode, ')')
      end
      else if IsReal(t) then begin
        Def(v);
        write(ircode, 'call double @pas_read_real(ptr ');
        PutOp(fh);
        writeln(ircode, ')')
      end
      else begin
        { The runtime returns i64 and has already rejected anything outside
          -maxint..maxint, so this truncation cannot lose a valid value. }
        Def(wide);
        write(ircode, 'call i64 @pas_read_int(ptr ');
        PutOp(fh);
        writeln(ircode, ')');
        Def(v);
        write(ircode, 'trunc i64 ');
        PutOp(wide);
        writeln(ircode, ' to i32');
        CheckedForSubrange(v, t)
      end;
      write(ircode, '  store ');
      PutLlType(t);
      write(ircode, ' ');
      PutOp(v);
      write(ircode, ', ptr ');
      PutOp(slot);
      writeln(ircode);
      a := a^.next
    end;
    if s^.rdNewline then begin
      write(ircode, '  call void @pas_readln(ptr ');
      PutOp(fh);
      writeln(ircode, ')')
    end
    end
  end
end;

{ `new(p)` gives p the address of fresh storage for one variable of its domain;
  `dispose(p)` gives it back. The size is a compile-time constant because the
  domain type is. }
{ 10206 6.7.5.3's other form of `new`: the arguments are the tuple the created
  variable's type is produced with. The size is asked of the tuple before there
  is anywhere to put the tuple, so for the length of those two calls the bounds
  are answered from the values rather than from a header -- no scratch storage
  exists, which is what lets a sequential emitter do this at all. }
procedure CheckSchemaDomain(t: typePtr; schema: symPtr;
                            var header: str);
  forward;

procedure EmitNewTuple(s: nodePtr; domain: typePtr; var slot: str);
var d: symListPtr; value: nodePtr; v, size, raw, block, vr, nohdr: str;
    k, head: integer; cell, next: discValPtr;
begin
  newTuple := nil;
  k := 0;
  d := domain^.schema^.discs;
  value := s^.pcArgs^.next;
  while (d <> nil) and (value <> nil) do begin
    EmitExpr(value, v);
    ConvertFor(v, value^.ntype, d^.sym^.stype);
    { A discriminant outside its own type is outside 6.4.7's domain, and this
      is where the value enters the variable that holds it -- so the check
      that guards every other such store makes this one too. }
    CheckedForStore(v, d^.sym^.stype);
    if IsChar(d^.sym^.stype) or IsBoolean(d^.sym^.stype) then begin
      raw := v;
      Def(v);
      write(ircode, 'zext ');
      PutLlType(d^.sym^.stype);
      write(ircode, ' ');
      PutOp(raw);
      writeln(ircode, ' to i32')
    end;
    new(cell);
    cell^.idx := k;
    cell^.value := v;
    cell^.next := newTuple;
    newTuple := cell;
    k := k + 1;
    d := d^.next;
    value := value^.next
  end;

  StrClear(nohdr);
  { 6.7.5.3: it shall be a dynamic-violation if the tuple is not in the domain
    of the schema -- the same check a variable's tuple gets on entry. }
  CheckSchemaDomain(domain, domain^.schema, nohdr);
  DynSize(domain, nohdr, size);
  head := HeaderSize(domain);
  Def(raw);
  write(ircode, 'add i32 ');
  PutOp(size);
  writeln(ircode, ', ', head:1);
  Def(v);
  write(ircode, 'zext i32 ');
  PutOp(raw);
  writeln(ircode, ' to i64');
  Def(block);
  write(ircode, 'call ptr @pas_new(i64 ');
  PutOp(v);
  writeln(ircode, ')');

  cell := newTuple;
  while cell <> nil do begin
    Def(vr);
    write(ircode, 'getelementptr i32, ptr ');
    PutOp(block);
    writeln(ircode, ', i32 ', cell^.idx:1);
    write(ircode, '  store i32 ');
    PutOp(cell^.value);
    write(ircode, ', ptr ');
    PutOp(vr);
    writeln(ircode);
    next := cell^.next;
    cell := next
  end;
  newTuple := nil;

  { The pointer denotes the *variable*, not the block, so everything else
    about a pointer -- assignment, comparison with nil, dereference -- is
    unchanged, and only `new` and `dispose` know the header is there. }
  Def(vr);
  write(ircode, 'getelementptr i8, ptr ');
  PutOp(block);
  writeln(ircode, ', i32 ', head:1);
  write(ircode, '  store ptr ');
  PutOp(vr);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode)
end;

procedure EmitStdProc(s: nodePtr);
var slot, block, raw, rec, nameRec, nlen, ndata: str;
    domain, idx: typePtr; head, msg: integer;
begin
  EmitAddress(s^.pcArgs, slot);
  case s^.pcStd of
    { 6.7.5.6's bind(f, b). The binding is implementation-defined and here it
      is a file name, so what crosses to the runtime is b.name as the pointer
      and length every string value is -- b.bound is ignored, which NOTE 3 says
      outright. }
    spBind: begin
      EmitAddress(s^.pcArgs^.next, rec);
      Def(nameRec);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(s^.pcArgs^.next^.ntype);
      write(ircode, ', ptr ');
      PutOp(rec);
      writeln(ircode, ', i32 0, i32 0');
      Def(nlen);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(s^.pcArgs^.next^.ntype^.fields^.ftype);
      write(ircode, ', ptr ');
      PutOp(nameRec);
      writeln(ircode, ', i32 0, i32 0');
      Def(raw);
      write(ircode, 'load i32, ptr ');
      PutOp(nlen);
      writeln(ircode);
      Def(ndata);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(s^.pcArgs^.next^.ntype^.fields^.ftype);
      write(ircode, ', ptr ');
      PutOp(nameRec);
      writeln(ircode, ', i32 0, i32 1');
      write(ircode, '  call void @pas_bind(ptr ');
      PutOp(slot);
      write(ircode, ', ptr ');
      PutOp(ndata);
      write(ircode, ', i32 ');
      PutOp(raw);
      writeln(ircode, ')')
    end;
    spUnbind: begin
      write(ircode, '  call void @pas_unbind(ptr ');
      PutOp(slot);
      writeln(ircode, ')')
    end;
    spReset, spRewrite, spGet, spPut, spUpdate, spExtend: begin
      write(ircode, '  call void @pas_');
      case s^.pcStd of
        spReset:   write(ircode, 'reset');
        spRewrite: write(ircode, 'rewrite');
        spGet:     write(ircode, 'get');
        spPut:     write(ircode, 'put');
        spUpdate:  write(ircode, 'update');
        spExtend:  write(ircode, 'extend');
        spNone, spNew, spDispose, spSeekRead, spSeekWrite, spSeekUpdate,
        spBind, spUnbind:
          write(ircode, 'get')
      end;
      write(ircode, '(ptr ');
      PutOp(slot);
      writeln(ircode, ')')
    end;
    { 6.7.5.2's three seeks. The position reaches the runtime already relative
      to the index-type's smallest value, so `SeekRead(f, 'c')` on a
      `file ['a'..'z'] of T` arrives as 2 -- the same division of labour an
      array subscript has, where the lower bound is folded into the offset and
      the runtime never sees an ordinal. }
    spSeekRead, spSeekWrite, spSeekUpdate: begin
      EmitExpr(s^.pcArgs^.next, raw);
      WidenOrdinal(raw, s^.pcArgs^.next^.ntype);
      idx := s^.pcArgs^.ntype^.indexType;
      if OrdinalLo(idx) <> 0 then begin
        Def(block);
        write(ircode, 'sub i32 ');
        PutOp(raw);
        writeln(ircode, ', ', OrdinalLo(idx):1);
        raw := block
      end;
      write(ircode, '  call void @pas_');
      case s^.pcStd of
        spSeekRead:   write(ircode, 'seekread');
        spSeekWrite:  write(ircode, 'seekwrite');
        spSeekUpdate: write(ircode, 'seekupdate');
        spNone, spNew, spDispose, spReset, spRewrite, spGet, spPut, spUpdate,
        spExtend, spBind, spUnbind: write(ircode, 'seekread')
      end;
      write(ircode, '(ptr ');
      PutOp(slot);
      write(ircode, ', i32 ');
      PutOp(raw);
      writeln(ircode, ')')
    end;
    spNew: begin
      domain := s^.pcArgs^.ntype^.elem;
      if domain^.heapTuple then EmitNewTuple(s, domain, slot)
      else begin
      { ISO 7185 6.6.5.3: with tag values, only the selected variants have to
        fit. Without them the whole record does. }
      Def(block);
      if s^.pcSelect = nil then
        writeln(ircode, 'call ptr @pas_new(i64 ',
                LlSize(s^.pcArgs^.ntype^.elem):1, ')')
      else
        writeln(ircode, 'call ptr @pas_new(i64 ',
                SelectedSize(s^.pcArgs^.ntype^.elem, nil, s^.pcSelect):1, ')');
      write(ircode, '  store ptr ');
      PutOp(block);
      write(ircode, ', ptr ');
      PutOp(slot);
      writeln(ircode)
      end
    end;
    spDispose: begin
      Def(block);
      write(ircode, 'load ptr, ptr ');
      PutOp(slot);
      writeln(ircode);
      { What was allocated is the header and the variable together, so what is
        given back has to be the block rather than the variable. }
      head := HeaderSize(s^.pcArgs^.ntype^.elem);
      if head <> 0 then begin
        { ISO 7185 6.6.5.3 makes disposing nil an error, and until there was a
          header it was a harmless one -- freeing nil does nothing. Stepping
          back over a header first turns it into a free of an address that was
          never allocated, so the check exists where the hazard was introduced
          rather than being extended to every pointer. }
        Def(raw);
        write(ircode, 'icmp eq ptr ');
        PutOp(block);
        writeln(ircode, ', null');
        MsgStart;
        MsgText('dispose of nil                          ');
        msg := MsgEnd;
        EmitTrapIf(raw, msg);
        raw := block;
        Def(block);
        write(ircode, 'getelementptr i8, ptr ');
        PutOp(raw);
        writeln(ircode, ', i32 ', -head:1)
      end;
      write(ircode, '  call void @pas_dispose(ptr ');
      PutOp(block);
      writeln(ircode, ')');
      { ISO 7185 6.6.5.3 leaves the pointer undefined afterwards. Setting it to
        nil makes the next dereference trap instead of reading freed storage --
        stricter than the standard requires, and cheap. }
      write(ircode, '  store ptr null, ptr ');
      PutOp(slot);
      writeln(ircode)
    end;
    spNone: { not a standard procedure }
  end
end;

procedure EmitIf(s: nodePtr);
var cond: str; thenB, elseB, endB: integer;
begin
  EmitExpr(s^.ifCond, cond);
  thenB := NewBlock;
  if s^.ifElse <> nil then elseB := NewBlock else elseB := 0;
  endB := NewBlock;
  write(ircode, '  br i1 ');
  PutOp(cond);
  write(ircode, ', label %L', thenB:1, ', label %L');
  if elseB <> 0 then writeln(ircode, elseB:1) else writeln(ircode, endB:1);

  StartBlock(thenB);
  EmitStmt(s^.ifThen);
  writeln(ircode, '  br label %L', endB:1);

  if elseB <> 0 then begin
    StartBlock(elseB);
    EmitStmt(s^.ifElse);
    writeln(ircode, '  br label %L', endB:1)
  end;

  StartBlock(endB)
end;

procedure EmitWhile(s: nodePtr);
var cond: str; condB, bodyB, endB: integer;
begin
  condB := NewBlock;
  bodyB := NewBlock;
  endB := NewBlock;
  writeln(ircode, '  br label %L', condB:1);
  StartBlock(condB);
  EmitExpr(s^.whCond, cond);
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', bodyB:1, ', label %L', endB:1);

  StartBlock(bodyB);
  EmitStmt(s^.whBody);
  writeln(ircode, '  br label %L', condB:1);

  StartBlock(endB)
end;

procedure EmitRepeat(s: nodePtr);
var cond: str; bodyB, endB: integer; sub: nodePtr;
begin
  bodyB := NewBlock;
  endB := NewBlock;
  writeln(ircode, '  br label %L', bodyB:1);
  StartBlock(bodyB);
  sub := s^.rpBody;
  while sub <> nil do begin
    EmitStmt(sub);
    sub := sub^.next
  end;
  { repeat runs until the condition becomes true }
  EmitExpr(s^.rpCond, cond);
  write(ircode, '  br i1 ');
  PutOp(cond);
  writeln(ircode, ', label %L', endB:1, ', label %L', bodyB:1);
  StartBlock(endB)
end;

{ A labelled statement is its own basic block, entered by falling into it as
  well as by jumping to it -- so the preceding code branches there rather than
  running on, which is what makes the label a join point rather than a second
  entry to the same block. }
procedure EmitLabeled(s: nodePtr);
var b: integer;
begin
  if s^.lbId < 0 then
    EmitStmt(s^.lbStmt)   { Sema reported it; emit the body anyway }
  else begin
    b := LabelBlock(s^.lbId);
    writeln(ircode, '  br label %L', b:1);
    StartBlock(b);
    EmitStmt(s^.lbStmt)
  end
end;

{ Anything written after a goto is unreachable, but it is still *code*: a
  statement may follow it in the same sequence, and LLVM requires it to live in
  a block of its own rather than after a terminator. }
procedure EmitGoto(s: nodePtr);
var frame, rec: str;
begin
  if s^.gtId >= 0 then begin
    if s^.gtNonLocal then begin
      { Out of this block altogether. The target's activation is the one on
        this procedure's static chain, which for a recursive enclosing
        procedure is the invocation this one was called from -- the same rule
        every other access to an enclosing frame follows (ADR-0016). The
        runtime closes the abandoned blocks' files before cutting the stack
        back. The label arrives as its id plus one, because a longjmp with
        zero would come back looking like the ordinary entry. }
      FrameAt(s^.gtOwner^.level, frame);
      JumpRecord(s^.gtOwner, frame, rec);
      write(ircode, '  call void @pas_jump_go(ptr ');
      PutOp(rec);
      writeln(ircode, ', i32 ', s^.gtId + 1:1, ')');
      writeln(ircode, '  unreachable')
    end
    else
      writeln(ircode, '  br label %L', LabelBlock(s^.gtId):1);
    StartBlock(NewBlock)
  end
end;

procedure EmitFor(s: nodePtr);
var slot, from, toV, limit, cur, lim, test, now, lim2, same, next: str;
    t: typePtr; condB, bodyB, stepB, endB: integer; unsignedOrdinal: boolean;
begin
  EmitAddress(s^.frVar, slot);
  t := s^.frVar^.ntype;

  { Both bounds are checked against the control variable's type, and nothing
    between them needs checking: the loop never leaves [from, to]. }
  EmitExpr(s^.frFrom, from);
  ConvertFor(from, s^.frFrom^.ntype, t);
  CheckedForSubrange(from, t);
  EmitExpr(s^.frTo, toV);
  ConvertFor(toV, s^.frTo^.ntype, t);
  CheckedForSubrange(toV, t);

  { The limit is evaluated exactly once, as ISO 7185 6.8.3.9 requires. }
  Def(limit);
  write(ircode, 'alloca ');
  PutLlType(t);
  writeln(ircode);
  write(ircode, '  store ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(toV);
  write(ircode, ', ptr ');
  PutOp(limit);
  writeln(ircode);
  write(ircode, '  store ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(from);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);

  condB := NewBlock;
  bodyB := NewBlock;
  stepB := NewBlock;
  endB := NewBlock;
  writeln(ircode, '  br label %L', condB:1);

  StartBlock(condB);
  Def(cur);
  write(ircode, 'load ');
  PutLlType(t);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);
  Def(lim);
  write(ircode, 'load ');
  PutLlType(t);
  write(ircode, ', ptr ');
  PutOp(limit);
  writeln(ircode);
  { Integer is the only ordinal with negative values; char, boolean and
    enumerations all order as unsigned. }
  unsignedOrdinal := not IsInteger(t);
  Def(test);
  if s^.frDownto then
    if unsignedOrdinal then write(ircode, 'icmp uge ')
    else write(ircode, 'icmp sge ')
  else
    if unsignedOrdinal then write(ircode, 'icmp ule ')
    else write(ircode, 'icmp sle ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(cur);
  write(ircode, ', ');
  PutOp(lim);
  writeln(ircode);
  write(ircode, '  br i1 ');
  PutOp(test);
  writeln(ircode, ', label %L', bodyB:1, ', label %L', endB:1);

  StartBlock(bodyB);
  EmitStmt(s^.frBody);
  { Stop before stepping past the limit so the last iteration cannot overflow.
    verify/ carries the theorem that says the step is therefore unchecked. }
  Def(now);
  write(ircode, 'load ');
  PutLlType(t);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);
  Def(lim2);
  write(ircode, 'load ');
  PutLlType(t);
  write(ircode, ', ptr ');
  PutOp(limit);
  writeln(ircode);
  Def(same);
  write(ircode, 'icmp eq ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(now);
  write(ircode, ', ');
  PutOp(lim2);
  writeln(ircode);
  write(ircode, '  br i1 ');
  PutOp(same);
  writeln(ircode, ', label %L', endB:1, ', label %L', stepB:1);

  StartBlock(stepB);
  Def(next);
  if s^.frDownto then write(ircode, 'sub ') else write(ircode, 'add ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(now);
  writeln(ircode, ', 1');
  write(ircode, '  store ');
  PutLlType(t);
  write(ircode, ' ');
  PutOp(next);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);
  writeln(ircode, '  br label %L', condB:1);

  StartBlock(endB)
end;

{ The record is designated once and its address kept for the body, so a
  subscript in the designator is evaluated a single time (6.8.3.10) and cannot
  see a change the body makes to the subscript's variable. }
procedure EmitWith(s: nodePtr);
var addr, slot: str;
begin
  EmitAddress(s^.wtRecord, addr);
  FrameSlot(s^.wtBinding, slot);
  write(ircode, '  store ptr ');
  PutOp(addr);
  write(ircode, ', ptr ');
  PutOp(slot);
  writeln(ircode);
  EmitStmt(s^.wtBody)
end;

{ ISO 7185 6.8.3.5 has no `else` arm, so the default is an error rather than a
  way out: a selector matching no label stops the program. That maps onto a
  switch exactly, and the jump table survives optimisation. }
procedure EmitCase(s: nodePtr);
var sel, wide, ge, le, both: str; arm: nodePtr; n: rangePtr;
    first, k, count, armB, defaultB, endB, nextB, msg: integer;
begin
  EmitExpr(s^.csSelector, sel);
  { The switch wants a single integer type; a char or boolean selector is
    widened, and its labels with it. }
  if IsChar(s^.csSelector^.ntype) or IsBoolean(s^.csSelector^.ntype) then begin
    Def(wide);
    write(ircode, 'zext ');
    PutLlType(s^.csSelector^.ntype);
    write(ircode, ' ');
    PutOp(sel);
    writeln(ircode, ' to i32');
    sel := wide
  end;

  count := 0;
  arm := s^.csArms;
  while arm <> nil do begin
    count := count + 1;
    arm := arm^.next
  end;
  { The arms' blocks are numbered before the switch is written, because the
    switch names them all and they are filled afterwards. They are consecutive,
    so one number is enough to find them again. }
  first := nextBlock + 1;
  for k := 1 to count do
    armB := NewBlock;
  defaultB := NewBlock;
  endB := NewBlock;

  { A range is *tested*, not enumerated: `1..maxint` is a legal label list
    (ISO/IEC 10206:1991 6.8.3.5) and two billion switch cases. So the ranges are
    a chain of comparisons ahead of the switch, and only single constants reach
    the switch itself. Sema has already proved the arms disjoint, so which of
    the two answers first cannot matter. }
  arm := s^.csArms;
  k := first;
  while arm <> nil do begin
    n := arm^.caValues;
    while n <> nil do begin
      if n^.lo <> n^.hi then begin
        nextB := NewBlock;
        Def(ge);
        write(ircode, 'icmp sge i32 ');
        PutOp(sel);
        writeln(ircode, ', ', n^.lo:1);
        Def(le);
        write(ircode, 'icmp sle i32 ');
        PutOp(sel);
        writeln(ircode, ', ', n^.hi:1);
        Def(both);
        write(ircode, 'and i1 ');
        PutOp(ge);
        write(ircode, ', ');
        PutOp(le);
        writeln(ircode);
        write(ircode, '  br i1 ');
        PutOp(both);
        writeln(ircode, ', label %L', k:1, ', label %L', nextB:1);
        StartBlock(nextB)
      end;
      n := n^.next
    end;
    k := k + 1;
    arm := arm^.next
  end;

  write(ircode, '  switch i32 ');
  PutOp(sel);
  write(ircode, ', label %L', defaultB:1, ' [');
  arm := s^.csArms;
  k := first;
  while arm <> nil do begin
    n := arm^.caValues;
    while n <> nil do begin
      if n^.lo = n^.hi then
        write(ircode, ' i32 ', n^.lo:1, ', label %L', k:1);
      n := n^.next
    end;
    k := k + 1;
    arm := arm^.next
  end;
  writeln(ircode, ' ]');

  arm := s^.csArms;
  k := first;
  while arm <> nil do begin
    StartBlock(k);
    EmitStmt(arm^.caBody);
    writeln(ircode, '  br label %L', endB:1);
    k := k + 1;
    arm := arm^.next
  end;

  StartBlock(defaultB);
  if s^.csHasOtherwise then begin
    { ISO/IEC 10206:1991: the default arm is a statement-sequence rather than
      the trap. Everything else about the lowering is unchanged, which is the
      point -- an `otherwise` is what the default block holds, not a different
      shape of switch. }
    arm := s^.csOtherwise;
    while arm <> nil do begin
      EmitStmt(arm);
      arm := arm^.next
    end;
    writeln(ircode, '  br label %L', endB:1)
  end
  else begin
    MsgStart;
    MsgText('case: no label matches the selector     ');
    msg := MsgEnd;
    writeln(ircode, '  call void @pas_runtime_error(ptr @s', msg:1, ')');
    writeln(ircode, '  unreachable')
  end;

  StartBlock(endB)
end;

procedure EmitStmt;
var sub: nodePtr; v: str;
begin
  if s <> nil then
    case s^.kind of
      nkEmpty: ;
      nkCompound: begin
        sub := s^.cpBody;
        while sub <> nil do begin
          EmitStmt(sub);
          sub := sub^.next
        end
      end;
      nkAssign: EmitAssign(s);
      nkWrite: EmitWrite(s);
      nkRead: EmitRead(s);
      nkIf: EmitIf(s);
      nkWhile: EmitWhile(s);
      nkRepeat: EmitRepeat(s);
      nkFor: EmitFor(s);
      nkWith: EmitWith(s);
      nkCase: EmitCase(s);
      nkGoto: EmitGoto(s);
      nkLabeled: EmitLabeled(s);
      nkProcCall:
        if s^.pcStd <> spNone then EmitStdProc(s)
        else if s^.pcSym <> nil then EmitUserCall(s^.pcSym, s^.pcArgs, v);
      nkInt, nkReal, nkChar, nkStr, nkNil, nkSet, nkSetMember, nkVar, nkIndex,
      nkField, nkDeref,
      nkBinary, nkUnary, nkCall, nkWriteArg, nkCaseArm, nkVariantArm, nkGroup,
      nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord, nkPointer,
      nkFile, nkSetOf, nkSchema, nkInquiry, nkConstDecl, nkTypeDecl, nkProcDecl,
      nkLabelDecl, nkBlock: ;
    end
end;

{ ============================== procedures =============================== }

procedure PutSlotType(s: symPtr);
begin
  { A schematic formal parameter's slot holds the whole descriptor: the
    address, and the tuple that says how far the thing at it reaches. A `var`
    parameter's slot holds the address of the caller's variable, not a copy of
    its value. Everything else -- including a structured value parameter, which
    the prologue copies in -- holds the value itself. }
  if s^.descSchema <> nil then PutDescType(s)
  else if s^.kind = skVarParam then write(ircode, 'ptr')
  else PutLlType(s^.stype)
end;

{ The LLVM parameters one Pascal parameter list contributes, after the static
  link. Every parameter is one argument except a procedural one, which is two
  -- the code and the link it needs -- so a caller and a callee agree on the
  shape only by both coming through here. }
procedure PutParamTypes(p: symListPtr; named: boolean);
var k: integer;
begin
  k := 0;
  while p <> nil do begin
    write(ircode, ', ');
    if p^.sym^.descSchema <> nil then
      PutDescParamTypes(p^.sym, named, k)
    else begin
      if p^.sym^.kind = skProcParam then begin
        write(ircode, 'ptr');
        if named then write(ircode, ' %a', k:1);
        k := k + 1;
        write(ircode, ', ptr')
      end
      else if (p^.sym^.kind = skVarParam) or IsMemory(p^.sym^.stype) then
        write(ircode, 'ptr')
      else
        PutLlType(p^.sym^.stype);
      if named then write(ircode, ' %a', k:1);
      k := k + 1
    end;
    p := p^.next
  end
end;

procedure EmitFrameType(p: symPtr);
var l: symListPtr;
begin
  p^.irId := nextProcId;
  nextProcId := nextProcId + 1;
  write(ircode, '%frame', p^.irId:1, ' = type { ptr');
  l := p^.frameVars;
  while l <> nil do begin
    write(ircode, ', ');
    PutSlotType(l^.sym);
    l := l^.next
  end;
  { A block reachable by a non-local goto carries the jump record after its
    variables. It is last so that no frame index moves, and it is not a frame
    variable because nothing in the source can name it: the prologue arms it,
    the epilogue disarms it, and a goto in a nested block reaches it by
    walking the static chain (ADR-0032). }
  if p^.nlLabels <> nil then
    write(ircode, ', [', jumpSize div 8:1, ' x i64]');
  writeln(ircode, ' }')
end;

procedure DeclareProcs(b: nodePtr);
var d: nodePtr;
begin
  d := b^.blProcs;
  while d <> nil do begin
    if d^.pdSym <> nil then
      if d^.pdSym^.irId = 0 then   { a forward declaration already made one }
        EmitFrameType(d^.pdSym);
    d := d^.next
  end;
  d := b^.blProcs;
  while d <> nil do begin
    if d^.pdBody <> nil then DeclareProcs(d^.pdBody);
    d := d^.next
  end
end;

{ Every file variable the frame holds starts closed, and knows how reset and
  rewrite will find the external file it stands for. The standard files are
  opened here -- ISO 7185 6.10 has `input` reset and `output` rewritten before
  the program body runs -- but no character is read until the program asks, or
  a program that never reads would hang waiting for a terminal. }
procedure InitFiles(p: symPtr);
var l: symListPtr; addr: str;
    binding, name, comp, istext, direct: integer;
begin
  l := p^.frameVars;
  while l <> nil do begin
    if IsFile(l^.sym^.stype) and (l^.sym^.kind <> skVarParam) then begin
      case l^.sym^.binding of
        fbInternal:  binding := 0;
        fbStdInput:  binding := 1;
        fbStdOutput: binding := 2;
        fbArgument:  binding := 3
      end;
      name := AddGlobal(l^.sym^.at, l^.sym^.len);
      AddressOfSym(l^.sym, addr);
      { The component type is the whole of what the runtime needs to know
        about a `file of T`: how many bytes one component is, and whether the
        file has the line structure only a `text` has. }
      comp := 1;
      if l^.sym^.stype^.elem <> nil then comp := LlSize(l^.sym^.stype^.elem);
      istext := 0;
      if l^.sym^.stype^.isText then istext := 1;
      { 6.4.3.6: an index-type makes the file direct-access, and the one thing
        the runtime does differently is open the stream for reading *and*
        writing -- SeekUpdate must be able to turn one into the other without
        reopening, since it has to preserve the contents. }
      direct := 0;
      if l^.sym^.stype^.indexType <> nil then direct := 1;
      write(ircode, '  call void @pas_file_init(ptr ');
      PutOp(addr);
      writeln(ircode, ', i32 ', binding:1, ', i32 ', l^.sym^.fileArg:1,
              ', ptr @s', name:1, ', i32 ', comp:1, ', i32 ', istext:1,
              ', i32 ', direct:1, ')')
    end;
    l := l^.next
  end
end;

{ A block exit closes the files the block declared, which is ISO 7185's rule
  and also the only thing that flushes a file written to inside a procedure.
  Pascal has no early return, so the single exit point each body ends with is
  the whole of the epilogue. }
procedure CloseFiles(p: symPtr);
var l: symListPtr; addr, frame, rec: str;
begin
  l := p^.frameVars;
  while l <> nil do begin
    if IsFile(l^.sym^.stype) and (l^.sym^.kind <> skVarParam) then begin
      AddressOfSym(l^.sym, addr);
      write(ircode, '  call void @pas_file_done(ptr ');
      PutOp(addr);
      writeln(ircode, ')')
    end;
    l := l^.next
  end;
  { Disarming the jump record is part of the same exit. Nothing the compiler
    accepts can reach a dead frame -- the static chain only names live ones --
    so it buys a diagnosable error rather than a jump into reclaimed stack. }
  if p^.nlLabels <> nil then begin
    FrameAt(p^.level, frame);
    JumpRecord(p, frame, rec);
    write(ircode, '  call void @pas_jump_done(ptr ');
    PutOp(rec);
    writeln(ircode, ')')
  end
end;

{ The target's half of a non-local goto. The record is armed first -- which
  notes the files the block already has open, so a later jump knows which ones
  it abandons -- and then `_setjmp` is called *here*, in the function that owns
  the frame. It cannot be called through a runtime wrapper: the wrapper would
  have returned by the time the jump arrived, and its frame is what `_setjmp`
  recorded. #0 is `returns_twice`, without which LLVM may keep a value in a
  register across the call that the jump will not restore. }
procedure JumpDispatch(p: symPtr);
var frame, rec, env, arrived: str; num: numPtr; bodyB: integer;
begin
  if p^.nlLabels <> nil then begin
    FrameAt(p^.level, frame);
    JumpRecord(p, frame, rec);
    Def(env);
    write(ircode, 'call ptr @pas_jump_env(ptr ');
    PutOp(rec);
    writeln(ircode, ')');
    Def(arrived);
    write(ircode, 'call i32 @_setjmp(ptr ');
    PutOp(env);
    writeln(ircode, ') #0');
    bodyB := NewBlock;
    write(ircode, '  switch i32 ');
    PutOp(arrived);
    writeln(ircode, ', label %L', bodyB:1, ' [');
    num := p^.nlLabels;
    while num <> nil do begin
      writeln(ircode, '    i32 ', num^.value + 1:1, ', label %L',
              LabelBlock(num^.value):1);
      num := num^.next
    end;
    writeln(ircode, '  ]');
    StartBlock(bodyB)
  end
end;

{ 6.4.7 NOTE 2: a tuple that leaves an index range empty selects no type from
  the schema at all. Where the tuple is a constant Sema says so; where it is
  not, this does. }
procedure CheckSchemaDomain;
var lo, hi, bad: str; msg: integer; last: fieldPtr;
begin
  if t <> nil then
    { A record reaches here only with its dynamic part last (ADR-0045), so the
      walk into it is the same walk: one dimension per level, wherever the
      level came from. }
    if (t^.kind = tyRecord) and DynamicExtent(t) then begin
      last := LastField(t^.fields);
      CheckSchemaDomain(last^.ftype, schema, header)
    end
    else if (t^.kind = tyArray) and DynamicExtent(t) then begin
      if (t^.loDisc <> nil) or (t^.hiDisc <> nil) then begin
        BoundValue(t, false, header, lo);
        BoundValue(t, true, header, hi);
        Def(bad);
        write(ircode, 'icmp slt i32 ');
        PutOp(hi);
        write(ircode, ', ');
        PutOp(lo);
        writeln(ircode);
        MsgStart;
        MsgText('no type is produced from schema ''       ');
        WritePool(schema^.at, schema^.len);
        MsgText(''' with these discriminants              ');
        msg := MsgEnd;
        EmitTrapIf(bad, msg)
      end;
      CheckSchemaDomain(t^.elem, schema, header)
    end
end;

{ 6.2.3.2: the actual-discriminant-part of a variable is evaluated when the
  block is entered. The tuple goes into the descriptor first, because
  everything after it -- the domain check, the size, the storage -- is asked of
  the descriptor and not of the expressions that filled it. }
{ ISO/IEC 10206:1991 6.2.3.5: "Each variable contained by an activation of a
  block ... shall be created in its initial state within the commencement of
  the activation." 6.6 makes every expression in one nonvarying, so nothing
  here can depend on the order -- which is why the whole feature is a walk of
  the frame rather than a place in the declaration sequence.

  A record's fields may each carry one, so a record with no initial state of
  its own may still have parts of it initialised. That is the recursion; it
  does not go into an array, because 6.4.3.2 forbids a component-type from
  carrying a specifier at all. }
procedure InitialStateInto(var addr: str; t: typePtr; init: nodePtr);
var f: fieldPtr; sub: str;
begin
  if init <> nil then
    EmitStore(addr, t, init)
  else if IsRecord(t) then begin
    f := t^.fields;
    while f <> nil do begin
      if (f^.initValue <> nil) or IsRecord(f^.ftype) then begin
        FieldAddress(addr, t, f, sub);
        InitialStateInto(sub, f^.ftype, f^.initValue)
      end;
      f := f^.next
    end
  end
end;

procedure InitInitialStates(p: symPtr);
var l: symListPtr; addr: str;
begin
  l := p^.frameVars;
  while l <> nil do begin
    { 6.2.3.5 excludes formal parameters, and a hidden slot has no declaration
      to have carried a specifier. }
    if l^.sym^.kind = skVar then
      if (l^.sym^.initValue <> nil) or IsRecord(l^.sym^.stype) then begin
        AddressOfSym(l^.sym, addr);
        InitialStateInto(addr, l^.sym^.stype, l^.sym^.initValue)
      end;
    l := l^.next
  end
end;

procedure InitDynamicVars(p: symPtr);
var l, d: symListPtr; a: nodePtr; slot, half, value, size, storage: str;
    nohdr: str; comp: typePtr; align: integer;
begin
  l := p^.frameVars;
  while l <> nil do begin
    if (l^.sym^.descSchema <> nil) and (l^.sym^.discExprs <> nil) then begin
      Def(slot);
      writeln(ircode, 'getelementptr inbounds %frame', p^.irId:1,
              ', ptr %frame, i32 0, i32 ', 1 + l^.sym^.frameIndex:1);
      a := l^.sym^.discExprs;
      d := l^.sym^.discSyms;
      while (a <> nil) and (d <> nil) do begin
        EmitExpr(a, value);
        ConvertFor(value, a^.ntype, d^.sym^.stype);
        { A discriminant outside its own type is outside 6.4.7's domain. The
          store is where a value enters a variable, so the check that guards
          every other such store is the one that says so here too. }
        CheckedForStore(value, d^.sym^.stype);
        Def(half);
        write(ircode, 'getelementptr inbounds ');
        PutDescType(l^.sym);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 ', 1 + d^.sym^.discIndex:1);
        write(ircode, '  store ');
        PutLlType(d^.sym^.stype);
        write(ircode, ' ');
        PutOp(value);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode);
        a := a^.next;
        d := d^.next
      end;
      StrClear(nohdr);
      CheckSchemaDomain(l^.sym^.stype, l^.sym^.descSchema, nohdr);
      comp := l^.sym^.stype;
      while comp^.kind = tyArray do comp := comp^.elem;
      align := LlAlign(comp);
      DynSize(l^.sym^.stype, nohdr, size);
      Def(storage);
      write(ircode, 'alloca i8, i32 ');
      PutOp(size);
      writeln(ircode, ', align ', align:1);
      Def(half);
      write(ircode, 'getelementptr inbounds ');
      PutDescType(l^.sym);
      write(ircode, ', ptr ');
      PutOp(slot);
      writeln(ircode, ', i32 0, i32 0');
      write(ircode, '  store ptr ');
      PutOp(storage);
      write(ircode, ', ptr ');
      PutOp(half);
      writeln(ircode)
    end;
    l := l^.next
  end
end;

{ The prologue shared by main and every procedure: alloca the frame, store the
  static link, copy the incoming arguments into their slots. }
procedure EnterFrame(p: symPtr);
var l, d: symListPtr; link, slot, arg, half, actual, size, copy: str;
    nohdr: str; k, align: integer; comp: typePtr;
begin
  { A label belongs to exactly one block, so the map is emptied per function.
    Sema numbers labels across the whole program, so a stale entry would never
    be *matched* -- this bounds what is kept, and is not what makes the block
    numbers right. }
  labelBlocks := nil;
  irProc := p;
  irLevel := p^.level;
  nextReg := 0;
  nextBlock := 0;
  StartBlock(NewBlock);
  writeln(ircode, '  %frame = alloca %frame', p^.irId:1);
  Def(link);
  writeln(ircode, 'getelementptr inbounds %frame', p^.irId:1,
          ', ptr %frame, i32 0, i32 0');

  if p^.level = 0 then begin
    { The program has no enclosing block, so its static link is never followed.
      The command line goes to the runtime before any file is opened: it is
      where `reset` looks for the name of an external file. }
    write(ircode, '  store ptr null, ptr ');
    PutOp(link);
    writeln(ircode);
    writeln(ircode, '  call void @pas_args(i32 %argc, ptr %argv)')
  end
  else begin
    write(ircode, '  store ptr %link, ptr ');
    PutOp(link);
    writeln(ircode);
    l := p^.params;
    k := 0;
    while l <> nil do begin
      StrClear(arg);
      StrAppend(arg, '%');
      StrAppend(arg, 'a');
      AppendInt(arg, k);
      Def(slot);
      writeln(ircode, 'getelementptr inbounds %frame', p^.irId:1,
              ', ptr %frame, i32 0, i32 ', 1 + l^.sym^.frameIndex:1);
      if l^.sym^.descSchema <> nil then begin
        { The tuple is stored first, because everything about the size of what
          the address points at is asked of it -- including, for a value
          parameter, how much to copy. }
        actual := arg;
        d := l^.sym^.discSyms;
        while d <> nil do begin
          k := k + 1;
          StrClear(arg);
          StrAppend(arg, '%');
          StrAppend(arg, 'a');
          AppendInt(arg, k);
          Def(half);
          write(ircode, 'getelementptr inbounds ');
          PutDescType(l^.sym);
          write(ircode, ', ptr ');
          PutOp(slot);
          writeln(ircode, ', i32 0, i32 ', 1 + d^.sym^.discIndex:1);
          write(ircode, '  store ');
          PutLlType(d^.sym^.stype);
          write(ircode, ' ');
          PutOp(arg);
          write(ircode, ', ptr ');
          PutOp(half);
          writeln(ircode);
          d := d^.next
        end;
        Def(half);
        write(ircode, 'getelementptr inbounds ');
        PutDescType(l^.sym);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 0');
        write(ircode, '  store ptr ');
        PutOp(actual);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode);
        if l^.sym^.kind <> skVarParam then begin
          { A value parameter is a copy, and this one's size is not known until
            the tuple is in place -- so the storage is claimed here rather than
            in the frame, and dies with the activation as the frame does. }
          comp := l^.sym^.stype;
          while comp^.kind = tyArray do comp := comp^.elem;
          align := LlAlign(comp);
          StrClear(nohdr);
          DynSize(l^.sym^.stype, nohdr, size);
          Def(copy);
          write(ircode, 'alloca i8, i32 ');
          PutOp(size);
          writeln(ircode, ', align ', align:1);
          write(ircode, '  call void @llvm.memcpy.p0.p0.i32(ptr align ',
                align:1, ' ');
          PutOp(copy);
          write(ircode, ', ptr align ', align:1, ' ');
          PutOp(actual);
          write(ircode, ', i32 ');
          PutOp(size);
          writeln(ircode, ', i1 false)');
          write(ircode, '  store ptr ');
          PutOp(copy);
          write(ircode, ', ptr ');
          PutOp(half);
          writeln(ircode)
        end
      end
      else if l^.sym^.kind = skProcParam then begin
        { Two arguments, one slot: the pair is assembled here and never exists
          as a value. }
        Def(half);
        write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 0');
        write(ircode, '  store ptr ');
        PutOp(arg);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode);
        k := k + 1;
        StrClear(arg);
        StrAppend(arg, '%');
        StrAppend(arg, 'a');
        AppendInt(arg, k);
        Def(half);
        write(ircode, 'getelementptr inbounds { ptr, ptr }, ptr ');
        PutOp(slot);
        writeln(ircode, ', i32 0, i32 1');
        write(ircode, '  store ptr ');
        PutOp(arg);
        write(ircode, ', ptr ');
        PutOp(half);
        writeln(ircode)
      end
      else if (l^.sym^.kind <> skVarParam) and IsStructured(l^.sym^.stype) then
      begin
        { A structured value parameter arrives as the caller's address; the
          copy that makes it a *value* parameter is made here, once, so the
          callee can write to it without the caller seeing the change. }
        align := LlAlign(l^.sym^.stype);
        write(ircode, '  call void @llvm.memcpy.p0.p0.i64(ptr align ',
              align:1, ' ');
        PutOp(slot);
        write(ircode, ', ptr align ', align:1, ' ');
        PutOp(arg);
        writeln(ircode, ', i64 ', LlSize(l^.sym^.stype):1, ', i1 false)')
      end
      else begin
        write(ircode, '  store ');
        PutSlotType(l^.sym);
        write(ircode, ' ');
        PutOp(arg);
        write(ircode, ', ptr ');
        PutOp(slot);
        writeln(ircode)
      end;
      k := k + 1;
      l := l^.next
    end
  end;

  { After the parameters, because a discriminant may be one of them, and
    before anything that could jump: the storage a dynamically sized variable
    stands for has to exist for the whole activation. }
  InitDynamicVars(p);
  InitInitialStates(p);
  InitFiles(p);
  JumpDispatch(p)
end;

procedure EmitProcBody(d: nodePtr);
var p: symPtr; slot, res: str;
begin
  p := d^.pdSym;
  writeln(ircode);
  write(ircode, 'define internal ');
  if p^.kind = skFunc then PutLlType(p^.stype) else write(ircode, 'void');
  write(ircode, ' @p', p^.irId:1, '(ptr %link');
  PutParamTypes(p^.params, true);
  writeln(ircode, ') {');

  EnterFrame(p);
  EmitStmt(d^.pdBody^.blBody);
  CloseFiles(p);

  if p^.kind = skFunc then begin
    Def(slot);
    writeln(ircode, 'getelementptr inbounds %frame', p^.irId:1,
            ', ptr %frame, i32 0, i32 ', 1 + p^.resultVar^.frameIndex:1);
    Def(res);
    write(ircode, 'load ');
    PutLlType(p^.stype);
    write(ircode, ', ptr ');
    PutOp(slot);
    writeln(ircode);
    write(ircode, '  ret ');
    PutLlType(p^.stype);
    write(ircode, ' ');
    PutOp(res);
    writeln(ircode)
  end
  else
    writeln(ircode, '  ret void');
  writeln(ircode, '}')
end;

procedure EmitProcs(b: nodePtr);
var d: nodePtr;
begin
  d := b^.blProcs;
  while d <> nil do begin
    if d^.pdBody <> nil then begin   { a forward heading has no body of its own }
      EmitProcBody(d);
      EmitProcs(d^.pdBody)
    end;
    d := d^.next
  end
end;

procedure EmitDeclares;
begin
  writeln(ircode);
  writeln(ircode, 'declare void @pas_runtime_error(ptr)');
  writeln(ircode, 'declare void @pas_args(i32, ptr)');
  writeln(ircode,
          'declare void @pas_file_init(ptr, i32, i32, ptr, i32, i32, i32)');
  writeln(ircode, 'declare void @pas_file_done(ptr)');
  writeln(ircode, 'declare ptr @pas_jump_env(ptr)');
  writeln(ircode, 'declare void @pas_jump_done(ptr)');
  writeln(ircode, 'declare void @pas_jump_go(ptr, i32)');
  writeln(ircode, 'declare i32 @_setjmp(ptr) #0');
  writeln(ircode, 'attributes #0 = { returns_twice }');
  writeln(ircode, 'declare void @pas_reset(ptr)');
  writeln(ircode, 'declare void @pas_rewrite(ptr)');
  writeln(ircode, 'declare void @pas_get(ptr)');
  writeln(ircode, 'declare void @pas_put(ptr)');
  writeln(ircode, 'declare ptr @pas_buffer(ptr)');
  writeln(ircode, 'declare ptr @pas_new(i64)');
  writeln(ircode, 'declare void @pas_dispose(ptr)');
  writeln(ircode, 'declare void @pas_write_int(ptr, i64, i32)');
  writeln(ircode, 'declare void @pas_write_real(ptr, double, i32, i32)');
  writeln(ircode, 'declare void @pas_write_bool(ptr, i32, i32)');
  writeln(ircode, 'declare void @pas_write_char(ptr, i8, i32)');
  writeln(ircode, 'declare void @pas_write_str(ptr, ptr, i32, i32)');
  writeln(ircode, 'declare void @pas_writeln(ptr)');
  writeln(ircode, 'declare i8 @pas_read_char(ptr)');
  writeln(ircode, 'declare double @pas_read_real(ptr)');
  writeln(ircode, 'declare i64 @pas_read_int(ptr)');
  writeln(ircode, 'declare void @pas_readln(ptr)');
  writeln(ircode, 'declare i32 @pas_eof(ptr)');
  writeln(ircode, 'declare i32 @pas_eoln(ptr)');
  writeln(ircode, 'declare i32 @pas_str_compare(ptr, ptr, i32)');
  writeln(ircode, 'declare double @pas_pow_real(double, double)');
  writeln(ircode, 'declare double @pas_pow_realint(double, i32)');
  writeln(ircode, 'declare i32 @pas_pow_int(i32, i32)');
  writeln(ircode, 'declare { i32, i1 } @llvm.sadd.with.overflow.i32(i32, i32)');
  writeln(ircode, 'declare { i32, i1 } @llvm.ssub.with.overflow.i32(i32, i32)');
  writeln(ircode, 'declare { i32, i1 } @llvm.smul.with.overflow.i32(i32, i32)');
  writeln(ircode, 'declare i32 @llvm.abs.i32(i32, i1)');
  writeln(ircode, 'declare double @llvm.fabs.f64(double)');
  writeln(ircode, 'declare double @llvm.sqrt.f64(double)');
  writeln(ircode, 'declare double @llvm.sin.f64(double)');
  writeln(ircode, 'declare double @llvm.cos.f64(double)');
  writeln(ircode, 'declare double @llvm.log.f64(double)');
  writeln(ircode, 'declare double @llvm.exp.f64(double)');
  writeln(ircode, 'declare double @llvm.round.f64(double)');
  writeln(ircode, 'declare double @atan(double)');
  { ISO/IEC 10206:1991 6.4.3.3's string operations. A string value is a pointer
    and a length, so every one of these takes the pair rather than an
    aggregate. }
  writeln(ircode, 'declare ptr @pas_str_char(i8)');
  writeln(ircode, 'declare ptr @pas_str_concat(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare i32 @pas_str_cmp_pad(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare i32 @pas_str_cmp_exact(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare i32 @pas_str_trimlen(ptr, i32)');
  writeln(ircode, 'declare i32 @pas_str_index(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare void @pas_str_slice_check(i32, i32, i32)');
  writeln(ircode, 'declare void @pas_str_store_fixed(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare void @pas_str_store_var(ptr, i32, ptr, i32)');
  writeln(ircode, 'declare void @pas_str_store_char(ptr, ptr, i32)');
  writeln(ircode, 'declare void @pas_read_str(ptr, ptr, i32, i32)');
  { ISO/IEC 10206:1991 6.7.5.6 and 6.7.6.8's binding operations. }
  writeln(ircode, 'declare void @pas_bind(ptr, ptr, i32)');
  writeln(ircode, 'declare void @pas_unbind(ptr)');
  writeln(ircode, 'declare i32 @pas_binding_bound(ptr)');
  writeln(ircode, 'declare ptr @pas_binding_name(ptr)');
  writeln(ircode, 'declare i32 @pas_binding_namelen(ptr)');
  { ISO/IEC 10206:1991 6.7.5.2 and 6.7.6.6's direct-access operations. }
  writeln(ircode, 'declare void @pas_seekread(ptr, i32)');
  writeln(ircode, 'declare void @pas_seekwrite(ptr, i32)');
  writeln(ircode, 'declare void @pas_seekupdate(ptr, i32)');
  writeln(ircode, 'declare void @pas_update(ptr)');
  writeln(ircode, 'declare void @pas_extend(ptr)');
  writeln(ircode, 'declare i32 @pas_position(ptr)');
  writeln(ircode, 'declare i32 @pas_lastposition(ptr)');
  writeln(ircode, 'declare i32 @pas_empty(ptr)');
  { ISO/IEC 10206:1991's complex functions. `abs` and `arg` are one libm call
    each; the six transcendentals are two runtime calls each, one per part,
    because a `double complex` returned across this boundary would put the C
    ABI's opinion about a two-double aggregate into an interface whose whole
    point is not to have one. }
  writeln(ircode, 'declare double @hypot(double, double)');
  writeln(ircode, 'declare double @atan2(double, double)');
  writeln(ircode, 'declare double @pas_csqrt_re(double, double)');
  writeln(ircode, 'declare double @pas_csqrt_im(double, double)');
  writeln(ircode, 'declare double @pas_cexp_re(double, double)');
  writeln(ircode, 'declare double @pas_cexp_im(double, double)');
  writeln(ircode, 'declare double @pas_cln_re(double, double)');
  writeln(ircode, 'declare double @pas_cln_im(double, double)');
  writeln(ircode, 'declare double @pas_csin_re(double, double)');
  writeln(ircode, 'declare double @pas_csin_im(double, double)');
  writeln(ircode, 'declare double @pas_ccos_re(double, double)');
  writeln(ircode, 'declare double @pas_ccos_im(double, double)');
  writeln(ircode, 'declare double @pas_carctan_re(double, double)');
  writeln(ircode, 'declare double @pas_carctan_im(double, double)');
  writeln(ircode, 'declare double @pas_cpow_re(double, double, double)');
  writeln(ircode, 'declare double @pas_cpow_im(double, double, double)');
  writeln(ircode, 'declare double @pas_cpowi_re(double, double, i32)');
  writeln(ircode, 'declare double @pas_cpowi_im(double, double, i32)');
  writeln(ircode, 'declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)');
  { A schematic formal parameter's copy has a length only the descriptor knows,
    and the message for a subscript outside its bounds names bounds the
    compiler never had. }
  writeln(ircode, 'declare void @llvm.memcpy.p0.p0.i32(ptr, ptr, i32, i1)');
  writeln(ircode, 'declare void @pas_index_error(i32, i32)');
  { 6.4.6 d): an assignment between two types produced from one schema with
    different tuples. The schema and the discriminant are named here; only the
    values come from the running program. }
  writeln(ircode, 'declare void @pas_disc_error(ptr, ptr, i32, i32)');
  { 6.7.2.5 compares strings of one length, and a schema's is a discriminant. }
  writeln(ircode, 'declare void @pas_length_error(i32, i32)')
end;

procedure RunCodeGen;
begin
  rewrite(ircode);
  { The layout LlSize and LlAlign model, stated so the assembler uses the same
    one. Without it LLVM falls back to its own defaults, and the two disagree
    the moment a type is wider than a machine word: an i256 is 16-aligned here
    and 8-aligned there, so a set in a record got 16-byte moves against an
    8-aligned frame. The hand-written rules were never wrong -- they were
    unstated, which is the same thing once someone else is doing the layout. }
  writeln(ircode, 'target datalayout = "e-m:e-p270:32:32-p271:32:32-',
                  'p272:64:64-i64:64-i128:128-f80:128-n8:16:32:64-S128"');
  writeln(ircode, 'target triple = "x86_64-pc-linux-gnu"');
  writeln(ircode);
  nextProcId := 1;
  nextStr := 0;
  strHead := nil;
  strTail := nil;

  { The frame types come before any function that indexes one. }
  EmitFrameType(programSym);
  DeclareProcs(progBlock);

  { main takes the command line, because ISO 7185 6.10 leaves it to the
    implementation to say how a program parameter names an external file and
    this one binds them to the arguments, in the order they are written. }
  writeln(ircode);
  writeln(ircode, 'define i32 @main(i32 %argc, ptr %argv) {');
  EnterFrame(programSym);
  EmitStmt(progBlock^.blBody);
  CloseFiles(programSym);
  writeln(ircode, '  ret i32 0');
  writeln(ircode, '}');

  EmitProcs(progBlock);

  writeln(ircode);
  EmitGlobals;
  EmitDeclares
end;

procedure DumpEverything;
begin
  writeln('=== tokens');
  Tokenize;
  DumpTokens;

  writeln('=== ast');
  { The C++ driver stops after lexing when the lexer found anything wrong, so a
    f with a bad token is compared on its diagnostics and not on a tree
    built from tokens that were never valid. }
  if not errorSeen then begin
    ParseProgram;
    if not errorSeen then begin
      annotate := false;
      DumpProgram
    end
  end;

  writeln('=== sema');
  if not errorSeen then begin
    RunSema;
    if not errorSeen then begin
      annotate := true;
      DumpProgram
    end
  end;

  { The IR is the compiler's *product*, not a dump, so it goes to a file of its
    own rather than to a fourth section: it has to be assembled and linked, and
    two backends' assembler text cannot be diffed the way three stages of a
    tree can (ADR-0025). It is still written on every run, which is what keeps
    the differential test exercising it on all 207 files. }
  if not errorSeen then RunCodeGen
end;

begin
  ReadOptions;
  InstallKeywords;
  poolLen := 0;
  tokCount := 0;
  pos := 1;
  depth := 0;
  level := 0;
  aborted := false;
  errorSeen := false;
  errorCount := 0;
  annotate := false;
  msgOut := false;
  StrClear(msgBuf);
  scopeTop := nil;
  scopeDepth := 0;
  pendingHead := nil;
  pendingTail := nil;
  withTop := nil;
  producedHead := nil;
  producingTop := nil;
  heapTypes := nil;
  newTuple := nil;
  genericFor := nil;
  dynamicVarFor := nil;
  variantField := false;
  inSchemaBody := false;
  stdInput := nil;
  stdOutput := nil;
  for stringIndex := 1 to strMax do
    stringCache[stringIndex] := nil;

  DumpEverything
end.
