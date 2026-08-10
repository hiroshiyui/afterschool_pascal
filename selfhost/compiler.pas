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
  wordWidth = 12;    { the longest word a diagnostic passes about, padded }
  msgWidth = 16;     { 'packed array [', the longest piece of a type name }
  textWidth = 40;    { the longest fixed part of a runtime-error message }
  kwCount  = 37;     { 35 word-symbols of ISO 7185, then ISO 10206's }
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
    tkOtherwise, tkPow,
    { And the one operator ISO/IEC 10206:1991 spells in symbols. It is scanned
      under both standards and refused under ISO 7185, where no valid program
      can hold two adjacent stars outside a comment or a string anyway. }
    tkStarStar);

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
  binaryOp = (opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
              opExp, opPow,
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
    { declarations }
    nkConstDecl, nkTypeDecl, nkProcDecl, nkLabelDecl, nkBlock);

  { ------------------------------------------------------- Sema's own types }

  { skProcParam is a procedural or functional parameter (ISO 7185 6.6.3.1).
    Its frame slot holds a *pair*: the code to call, and the static link to
    call it with -- the link of the block the actual procedure was declared
    in, not of the caller. `stype` is the procedural type and its `elem` is
    the result type, nil for a procedural parameter as against a functional
    one. }
  symKind = (skConst, skType, skVar, skParam, skVarParam, skProcParam,
             skProc, skFunc);

  { How a file variable reaches something outside the program. ISO 7185 6.10
    makes only a *program parameter* external; every other file variable is a
    scratch file with no name, which is what skInternal means. }
  fileBinding = (fbInternal, fbStdInput, fbStdOutput, fbArgument);

  { tyProc is the type of a procedural or functional parameter. There is no
    way to *write* one outside a formal parameter list -- the type part has no
    procedure type -- so no variable ever has it, and it takes part in no
    operation but being passed on and being called. }
  typeKind = (tyVoid, tyInteger, tyReal, tyBoolean, tyChar, tyEnum, tySubrange,
              tyArray, tyRecord, tyPointer, tyFile, tySet, tyProc);

  { The required functions of ISO 7185, and the standard procedures that are
    not statements of their own. }
  builtinKind = (biNone, biAbs, biSqr, biOdd, biOrd, biChr, biSucc, biPred,
                 biSqrt, biSin, biCos, biLn, biExp, biArcTan, biTrunc, biRound,
                 biEof, biEoln);
  stdProcKind = (spNone, spNew, spDispose, spReset, spRewrite, spGet, spPut);

  typePtr = ^typeRec;
  symPtr = ^symbol;
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
    aliasAt, aliasLen: integer
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
    defined: boolean
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
  pendingPtr = ^pendingRec;
  pendingRec = record
    ptype: typePtr;
    at, len: integer;
    line, col: integer;
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

  nodePtr = ^node;
  node = record
    line, col: integer;
    { The sibling list that a std::vector<...Ptr> becomes. }
    next: nodePtr;
    { The type of an expression, or the type a type-denoter resolved to. A node
      is never both, so one field serves -- the same sharing typeRec.elem uses,
      and what the C++ splits over Expr::type and TypeExpr::resolved. }
    ntype: typePtr;
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
      nkField:      (fdBase: nodePtr; fdAt, fdLen: integer;
                     fdResolved: fieldPtr);
      nkDeref:      (drBase: nodePtr);
      nkBinary:     (bnOp: binaryOp; bnLhs, bnRhs: nodePtr);
      nkUnary:      (unOp: unaryOp; unArg: nodePtr);
      nkCall:       (clAt, clLen: integer; clArgs: nodePtr;
                     clBuiltin: builtinKind; clSym: symPtr);
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
      nkGroup:      (grNames, grType: nodePtr; grByRef, grIsProc,
                     grIsFunction: boolean; grParams, grResult: nodePtr);
      nkNamed:      (nmAt, nmLen: integer);
      nkPointer:    (ptAt, ptLen: integer);
      nkEnum:       (enConstants: nodePtr);
      nkSubrange:   (sbLo, sbHi: nodePtr);
      nkArray:      (arDims, arElem: nodePtr; arPacked: boolean);
      nkFile:       (flElem: nodePtr; flPacked: boolean);
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
      nkTypeDecl:   (tdAt, tdLen: integer; tdType: nodePtr);
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
  { The `packed array [1..n] of char` of each length, so two literals of a
    length share one type as ISO 7185 6.4.5 requires. }
  stringCache: array [1..strMax] of typePtr;
  { The bindings of the `with` statements currently open, innermost first. }
  withTop: symListPtr;
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
  DefineKeyword(37, 'pow      ', tkPow)
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
var sl, sc: integer; text: str; k: tokenKind;
begin
  sl := line;
  sc := col;
  StrClear(text);
  while (not AtEof) and (IsAlnum(Peek(0)) or (Peek(0) = '_')) do begin
    StrAppend(text, Lower(Peek(0)));
    Advance
  end;
  k := LookupKeyword(text);
  if k = tkIdent then
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
    tkStarStar:  write('''**''')
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
    tkUntil, tkVar, tkWhile, tkWith, tkOtherwise, tkPow: write('?')
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
  { What Sema will fill in. A C++ struct gets these from its member
    initialisers; a variant record has none, and the dump reads them whether or
    not Sema ran, so they are cleared where the node is made. }
  case k of
    nkVar: begin n^.vrSym := nil; n^.vrField := nil end;
    nkField: n^.fdResolved := nil;
    nkCall: begin n^.clBuiltin := biNone; n^.clSym := nil end;
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
    nkSubrange, nkArray, nkRecord, nkPointer, nkFile, nkSetOf, nkConstDecl,
    nkTypeDecl, nkLabelDecl,
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
        ctxEnumConstants: write('an enumeration constant')
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
    Append(head, tail, ParseTypeExpr);
    more := Accept(tkComma)
  end;
  t^.arDims := head;

  Expect(tkRBracket, ctxArrayIndex);
  Expect(tkOf, ctxArrayIndex);
  t^.arElem := ParseTypeExpr;
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
  tagType := ParseTypeExpr;
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
function ParseTypeExpr;
var t: nodePtr; packed_: boolean;
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
      t^.soElem := ParseTypeExpr
    end
    else if Check(tkFile) then begin
      t := NewNode(nkFile, CurLine, CurCol);
      t^.flPacked := packed_;
      t^.flElem := nil;
      pos := pos + 1;
      Expect(tkOf, ctxAfterFile);
      t^.flElem := ParseTypeExpr
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
      pos := pos + 1
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
      pos := pos + 1;
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
    g^.grResult := ParseTypeExpr
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
    if Check(tkProcedure) or Check(tkFunction) then
      ParseProcParam(g, Check(tkFunction))
    else begin
      g^.grByRef := Accept(tkVar);
      g^.grNames := ParseNameList(ctxParamList);
      Expect(tkColon, ctxParamList);
      if not aborted then
        if not Check(tkIdent) then begin
          ErrorAtCur;
          writeln('a parameter''s type must be a type name');
          Bail
        end;
      g^.grType := ParseTypeExpr
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
    d^.pdResult := ParseTypeExpr
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
  t^.tagField := -1;
  t^.aliasAt := 0;
  t^.aliasLen := 0;
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

function IsNumeric(t: typePtr): boolean;
begin IsNumeric := IsInteger(t) or IsReal(t) end;

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
begin IsMemory := IsStructured(t) or IsFile(t) end;

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
        WriteOrdinalName(t^.host, t^.lo);
        PutLit('..              ');
        WriteOrdinalName(t^.host, t^.hi)
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
      tyFile:
        if t^.isText then PutLit('text            ')
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
        WriteOrdinalName(t^.indexType, t^.lo);
        PutLit('..              ');
        WriteOrdinalName(t^.indexType, t^.hi);
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
      else if f^.sym^.kind = skProcParam then
        ok := Congruous(f^.sym, a^.sym)
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
  else if e^.kind = nkField then IsDesignator := IsDesignator(e^.fdBase)
  { What a pointer points at is a variable however the pointer was obtained,
    so a dereference is a designator even when its base is not. }
  else if e^.kind = nkDeref then IsDesignator := true
  else IsDesignator := false
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
      nkPointer, nkFile, nkSetOf, nkConstDecl, nkTypeDecl, nkProcDecl,
      nkBlock:
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
  else BuiltinType := nil
end;

{ An enumerated type also *declares* its constants, into whatever scope the
  type itself appears in (ISO 7185 6.4.2.3) -- which is why this is done here
  rather than by the declaration part that happens to contain it. }
function ResolveEnum(d: nodePtr): typePtr;
var t: typePtr; n: nodePtr; s: symPtr; e: namePtr;
begin
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
function ResolvePointer(d: nodePtr): typePtr;
var t: typePtr; s: symPtr; p: pendingPtr;
begin
  t := NewType(tyPointer);
  t^.elem := BuiltinType(d^.ptAt, d^.ptLen);
  if t^.elem = nil then begin
    s := Lookup(d^.ptAt, d^.ptLen);
    if (s <> nil) and (s^.kind = skType) then
      t^.elem := s^.stype
    else begin
      { Not yet -- it may arrive before the type part ends. }
      new(p);
      p^.ptype := t;
      p^.at := d^.ptAt;
      p^.len := d^.ptLen;
      p^.line := d^.line;
      p^.col := d^.col;
      p^.next := nil;
      if pendingHead = nil then pendingHead := p else pendingTail^.next := p;
      pendingTail := p
    end
  end;
  ResolvePointer := t
end;

procedure ResolvePendingPointers;
var p: pendingPtr; s: symPtr;
begin
  p := pendingHead;
  while p <> nil do begin
    s := Lookup(p^.at, p^.len);
    if (s <> nil) and (s^.kind = skType) then
      p^.ptype^.elem := s^.stype
    else begin
      ErrorAt(p^.line, p^.col);
      write('unknown type ''');
      WritePool(p^.at, p^.len);
      writeln(''' as the domain of a pointer');
      p^.ptype^.elem := intType   { keep the tree checkable }
    end;
    p := p^.next
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
  ResolveFile := t
end;

function ResolveSubrange(d: nodePtr): typePtr;
var t, loType, hiType: typePtr; lo, hi: integer; ok: boolean;
begin
  loType := nil;
  hiType := nil;
  lo := 0;
  hi := 0;
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
  else if (OrdinalLo(index) <= 0) and
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
  t^.isPacked := d^.arPacked;
  if dim^.next <> nil then
    t^.elem := ResolveArray(d, dim^.next)
  else
    t^.elem := ResolveType(d^.arElem);
  ResolveArray := t
end;

procedure AddField(rec: typePtr; var into, tail: fieldPtr; n: nodePtr;
                   t: typePtr; variant: numPtr; index: integer);
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

{ Resolve one variant part -- a record's, or one nested inside an arm. The
  containers are passed explicitly because both a typeRec and a variantRec have
  them, and `path` says where the container sits so a field can record how to
  reach it (ISO 7185 6.4.3.3 allows any depth of nesting). }
procedure ResolveVariantPart(tagAt, tagLen, tagLine, tagCol: integer;
                             tagDenoter, arms: nodePtr; rec: typePtr;
                             var fields, fieldTail: fieldPtr;
                             var variants, variantTail: variantPtr;
                             var tagField: integer; var tagTypeOut: typePtr;
                             path: numPtr);
var
  tag, labelType, fieldType: typePtr;
  arm, label_, g, n, tagName: nodePtr;
  v, w: variantPtr;
  rg, rseen: rangePtr;
  armPath: numPtr;
  index, lo, hi, at: integer;
  claimed: boolean;
begin
  tag := ResolveType(tagDenoter);
  if not IsOrdinal(tag) then begin
    ErrorAt(tagLine, tagCol);
    write('the tag of a variant part must be an ordinal type, found ');
    WriteTypeName(tag);
    writeln
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
      AddField(rec, fields, fieldTail, tagName, tag, path, tagField)
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
        fieldType := ResolveType(g^.grType);
        n := g^.grNames;
        while n <> nil do begin
          AddField(rec, v^.fields, v^.fieldTail, n, fieldType, armPath,
                   FieldCount(v^.fields));
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
                           v^.variantTail, v^.tagField, v^.tagType, armPath);

      index := index + 1;
      arm := arm^.next
    end
  end
end;

function ResolveRecord(d: nodePtr): typePtr;
var t, fieldType: typePtr; g, n: nodePtr;
begin
  t := NewType(tyRecord);
  t^.isPacked := d^.rcPacked;
  g := d^.rcFields;
  while g <> nil do begin
    fieldType := ResolveType(g^.grType);
    n := g^.grNames;
    while n <> nil do begin
      AddField(t, t^.fields, t^.fieldTail, n, fieldType, nil,
               FieldCount(t^.fields));
      n := n^.next
    end;
    g := g^.next
  end;
  if d^.rcTagType <> nil then
    ResolveVariantPart(d^.rcTagAt, d^.rcTagLen, d^.rcTagLine, d^.rcTagCol,
                       d^.rcTagType, d^.rcVariants, t, t^.fields, t^.fieldTail,
                       t^.variants, t^.variantTail, t^.tagField, t^.tagType,
                       nil);
  ResolveRecord := t
end;

function ResolveType;
var t: typePtr; s: symPtr;
begin
  if d^.ntype <> nil then
    ResolveType := d^.ntype
  else begin
    t := nil;
    case d^.kind of
      nkNamed: begin
        t := BuiltinType(d^.nmAt, d^.nmLen);
        if t = nil then begin
          s := Lookup(d^.nmAt, d^.nmLen);
          if (s <> nil) and (s^.kind = skType) then
            t := s^.stype
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
      nkInt, nkReal, nkChar, nkStr, nkNil, nkSet, nkSetMember,
      nkVar, nkIndex, nkField, nkDeref,
      nkBinary, nkUnary, nkCall, nkEmpty, nkAssign, nkWrite, nkRead,
      nkCompound, nkIf, nkWhile, nkRepeat, nkFor, nkProcCall, nkWith, nkCase,
      nkWriteArg, nkCaseArm, nkVariantArm, nkGroup, nkDeclName, nkConstDecl,
      nkTypeDecl, nkProcDecl, nkBlock:
        t := intType
    end;
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
var a: nodePtr; p: symListPtr; n, given, i: integer;
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
      else if p^.sym^.kind = skVarParam then begin
        if not IsDesignator(a) then begin
          ErrorAt(a^.line, a^.col);
          write('argument ', i:1, ' of ''');
          WritePool(callee^.at, callee^.len);
          writeln(''' is a var parameter and needs a variable')
        end
        { No implicit conversion is possible through a reference, so the types
          must be the same rather than merely assignment-compatible. }
        else if (a^.ntype <> nil) and (p^.sym^.stype <> nil) and
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

      opAdd, opSub, opMul:
        if not IsNumeric(l) or not IsNumeric(r) then begin
          BadOperands(b, l, r, 'numeric     ');
          b^.ntype := intType
        end
        else if IsReal(l) or IsReal(r) then b^.ntype := realType
        else b^.ntype := intType;

      opRealDiv: begin
        if not IsNumeric(l) or not IsNumeric(r) then
          BadOperands(b, l, r, 'numeric     ');
        b^.ntype := realType
      end;

      opIntDiv, opMod: begin
        if not IsInteger(l) or not IsInteger(r) then
          BadOperands(b, l, r, 'integer     ');
        b^.ntype := intType
      end;

      opAnd, opOr: begin
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
      opExp: begin
        if not IsNumeric(l) or not IsNumeric(r) then
          BadOperands(b, l, r, 'numeric     ');
        b^.ntype := realType
      end;

      opPow:
        if not IsNumeric(l) then begin
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
          if IsReal(l) then b^.ntype := realType
          else b^.ntype := intType
        end;

      opEq, opNe, opLt, opLe, opGt, opGe: begin
        { ISO 7185 6.7.2.5 gives the string types the full set of relational
          operators, comparing character by character; every other structured
          type has none at all. }
        if IsCharArray(l) and IsCharArray(r) then begin
          if TypeLength(l) <> TypeLength(r) then begin
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
  else LookupBuiltin := biNone
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
var sym: symPtr; a, def, last: nodePtr; t: typePtr; n: integer;
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
    if c^.clBuiltin = biNone then begin
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
      if (c^.clBuiltin = biEof) or (c^.clBuiltin = biEoln) then begin
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
          biAbs, biSqr: begin
            RequireArg(c, IsNumeric(t), 'a numeric   ', t);
            if IsReal(t) then c^.ntype := realType else c^.ntype := intType
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
          biNone, biSqrt, biSin, biCos, biLn, biExp, biArcTan, biEof,
          biEoln: begin   { the transcendental functions }
            RequireArg(c, IsNumeric(t), 'a numeric   ', t);
            c^.ntype := realType
          end
        end
      end
    end
  end
end;

procedure CheckExpr;
var t, b: typePtr; f: fieldPtr; binding: symPtr;
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
      nkStr:
        if e^.stLen = 0 then begin
          ErrorAt(e^.line, e^.col);
          writeln('a string literal cannot be empty');
          e^.ntype := StringType(1)
        end
        else
          e^.ntype := StringType(e^.stLen);

      nkIndex: begin
        CheckExpr(e^.ixBase);
        CheckExpr(e^.ixIndex);
        b := e^.ixBase^.ntype;
        if not IsArray(b) then begin
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
        if not IsRecord(b) then begin
          if b <> nil then begin
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
      nkPointer, nkFile, nkSetOf, nkConstDecl, nkTypeDecl, nkProcDecl,
      nkBlock:
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
      and neither is any other structured type. }
    if (t <> nil) and not (IsInteger(t) or IsReal(t) or IsBoolean(t) or
                           IsChar(t) or IsCharArray(t)) then begin
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
procedure CheckStdProc(p: nodePtr);
var
  a, value: nodePtr;
  n, v, k, chosen: integer;
  domain, tag, valueType: typePtr;
  arms, w: variantPtr;
  lbl: rangePtr;
  stop: boolean;
begin
  if PoolIs(p^.pcAt, p^.pcLen, 'reset    ') then p^.pcStd := spReset
  else if PoolIs(p^.pcAt, p^.pcLen, 'rewrite  ') then p^.pcStd := spRewrite
  else if PoolIs(p^.pcAt, p^.pcLen, 'get      ') then p^.pcStd := spGet
  else if PoolIs(p^.pcAt, p^.pcLen, 'put      ') then p^.pcStd := spPut
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

  if (p^.pcStd = spReset) or (p^.pcStd = spRewrite) or (p^.pcStd = spGet) or
     (p^.pcStd = spPut) then begin
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
    { ISO 7185 6.6.5.3: `new(p, c1, ..., cn)` creates a variable with the
      variants those tag values select, one value per nested variant part,
      outermost first. `dispose` takes the same list. }
    else if n > 1 then begin
      if a^.ntype = nil then domain := nil else domain := a^.ntype^.elem;
      if not IsRecord(domain) then begin
        ErrorAt(a^.next^.line, a^.next^.col);
        writeln('tag values are only for a pointer to a record with a ',
                'variant part')
      end
      else begin
        arms := domain^.variants;
        tag := domain^.tagType;
        value := a^.next;
        stop := false;
        while (value <> nil) and not stop do begin
          if arms = nil then begin
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
            PoolIs(s^.pcAt, s^.pcLen, 'put      ')) then
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
      nkFile, nkSetOf, nkConstDecl, nkTypeDecl, nkProcDecl, nkBlock:
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
var g, n: nodePtr; t: typePtr; ps: symPtr;
begin
  g := groups;
  while g <> nil do begin
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
           not IsPointer(t^.elem) then begin
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
      t := ResolveType(g^.grType);
      { ISO 7185 6.6.3.3: a file may only be passed by reference. A value
        parameter is a copy, and a file has no copy -- the position, the buffer
        and the operating system's handle are one object, not a value. }
      if IsFile(t) and not g^.grByRef and (g^.grNames <> nil) then begin
        ErrorAt(g^.grNames^.line, g^.grNames^.col);
        writeln('a file parameter must be a var parameter')
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
        AppendSym(into^.params, into^.paramTail, ps);
        n := n^.next
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
        if not IsOrdinal(sym^.stype) and not IsReal(sym^.stype) and
           not IsPointer(sym^.stype) then begin
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
var d, g, n: nodePtr; s: symPtr; t: typePtr; value: symbol;
    outerPath: stmtPathPtr;
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
    t := ResolveType(d^.tdType);
    s := Declare(d^.tdAt, d^.tdLen, skType, d^.line, d^.col);
    if s^.stype = nil then begin   { a duplicate: keep the first definition }
      s^.stype := t;
      if t^.aliasLen = 0 then begin
        t^.aliasAt := d^.tdAt;
        t^.aliasLen := d^.tdLen
      end
    end;
    d := d^.next
  end;
  { Every name in the type part is now visible, so the pointers that named one
    before it existed can be completed. }
  ResolvePendingPointers;

  g := b^.blVars;
  while g <> nil do begin
    { One denoter for the whole group, so `a, b: array [1..3] of integer` makes
      a and b the same type and lets `a := b` through. }
    t := ResolveType(g^.grType);
    n := g^.grNames;
    while n <> nil do begin
      s := AddFrameVar(n^.dnAt, n^.dnLen, skVar, t, owner, n^.line, n^.col);
      n := n^.next
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
var s: symPtr; at, len: integer;
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
  s^.intVal := maxint
end;

procedure RunSema;
var p: nodePtr;
begin
  intType := NewType(tyInteger);
  realType := NewType(tyReal);
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
      end
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
    skProc:     write('proc');
    skFunc:     write('func')
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
      write('field ');
      WritePool(n^.fdAt, n^.fdLen);
      WritePos(n^.line, n^.col);
      if annotate then
        if n^.fdResolved <> nil then begin
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
    nkPointer: begin
      write('pointer ');
      WritePool(n^.ptAt, n^.ptLen);
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
var p: nodePtr;
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
    write('type ');
    WritePool(p^.tdAt, p^.tdLen);
    At(p^.line, p^.col);
    level := level + 1;
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
      tkWith, tkOtherwise, tkPow: begin
        write('kw ');
        WriteKeyword(tok[i].kind);
        writeln
      end
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

{ A `var` parameter -- and the binding of a `with` -- holds an address, so the
  variable it stands for is one load further on. }
procedure AddressOfSym(s: symPtr; var v: str);
var slot: str;
begin
  FrameSlot(s, slot);
  if s^.kind = skVarParam then begin
    Def(v);
    write(ircode, 'load ptr, ptr ');
    PutOp(slot);
    writeln(ircode)
  end
  else
    v := slot
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

procedure ConvertFor(var v: str; from, toT: typePtr);
begin
  if IsReal(toT) then ToReal(v, from)
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
      tyVoid, tySubrange, tyArray, tyRecord, tyPointer, tyFile, tySet, tyProc:
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
    opExp, opPow:
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
var p: symListPtr; result: typePtr;
begin
  result := ResultTypeOf(callee);
  if result = nil then write(ircode, 'void') else PutLlType(result);
  write(ircode, ' (ptr');
  p := callee^.params;
  while p <> nil do begin
    write(ircode, ', ');
    if (p^.sym^.kind = skVarParam) or (p^.sym^.kind = skProcParam) or
       IsMemory(p^.sym^.stype) then
      if p^.sym^.kind = skProcParam then write(ircode, 'ptr, ptr')
      else write(ircode, 'ptr')
    else
      PutLlType(p^.sym^.stype);
    p := p^.next
  end;
  write(ircode, ')')
end;

procedure EmitUserCall(callee: symPtr; args: nodePtr; var v: str);
var link, a, slot, half, target: str; head, tail, o: opndPtr;
    p: symListPtr; arg: nodePtr; result: typePtr;
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
var lhs, rhs, cmp: str;
begin
  EmitAddress(e^.bnLhs, lhs);
  EmitAddress(e^.bnRhs, rhs);
  Def(cmp);
  write(ircode, 'call i32 @pas_str_compare(ptr ');
  PutOp(lhs);
  write(ircode, ', ptr ');
  PutOp(rhs);
  writeln(ircode, ', i32 ', TypeLength(e^.bnLhs^.ntype):1, ')');
  Def(v);
  case e^.bnOp of
    opEq: write(ircode, 'icmp eq i32 ');
    opNe: write(ircode, 'icmp ne i32 ');
    opLt: write(ircode, 'icmp slt i32 ');
    opLe: write(ircode, 'icmp sle i32 ');
    opGt: write(ircode, 'icmp sgt i32 ');
    opGe: write(ircode, 'icmp sge i32 ');
    opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
            opExp, opPow:
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
  `while (i <= n) and (a[i] <> x)` safe to write (ADR-0010). }
procedure EmitShortCircuit(e: nodePtr; var v: str);
var lhs, rhs: str; isAnd: boolean; rhsB, endB, lhsEnd, rhsEnd: integer;
begin
  isAnd := e^.bnOp = opAnd;
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

procedure EmitBinary(e: nodePtr; var v: str);
var l, r, rem, neg, adj, bad, m1, m2: str;
    lt, rt: typePtr; msg: integer; sign, useFloat: boolean;
begin
  if (e^.bnOp = opAnd) or (e^.bnOp = opOr) then
    EmitShortCircuit(e, v)
  { `x in s` is the one operator whose operands are of different kinds, so it
    is taken before the two are evaluated alike. }
  else if e^.bnOp = opIn then
    EmitIn(e, v)
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
            opExp, opPow:
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
            opExp, opPow:
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

procedure EmitCall(e: nodePtr; var v: str);
var a, w, lim, tmp: str; at: typePtr; msg, up: integer; isSucc: boolean;
begin
  if e^.clSym <> nil then
    EmitUserCall(e^.clSym, e^.clArgs, v)
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
  else begin
    EmitExpr(e^.clArgs, a);
    at := e^.clArgs^.ntype;
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
      biNone, biEof, biEoln: OpInt(0, v)
    end
  end
end;

procedure EmitAddress;
var base, idx, lo, hi, below, above, bad, off, target: str;
    arr: typePtr; msg: integer;
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
      OpInt(arr^.lo, lo);
      OpInt(arr^.hi, hi);
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
      MsgStart;
      MsgText('array index out of bounds (             ');
      AppendInt(msgBuf, arr^.lo);
      MsgText('..                                      ');
      AppendInt(msgBuf, arr^.hi);
      Put(')');
      msg := MsgEnd;
      EmitTrapIf(bad, msg);

      Def(off);
      write(ircode, 'sub i32 ');
      PutOp(idx);
      write(ircode, ', ');
      PutOp(lo);
      writeln(ircode);
      Def(v);
      write(ircode, 'getelementptr inbounds ');
      PutLlType(arr);
      write(ircode, ', ptr ');
      PutOp(base);
      write(ircode, ', i32 0, i32 ');
      PutOp(off);
      writeln(ircode)
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

    nkInt, nkReal, nkChar, nkNil, nkSet, nkSetMember, nkBinary, nkUnary,
    nkCall,
    nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
    nkFor, nkProcCall, nkWith, nkCase, nkWriteArg, nkCaseArm, nkVariantArm,
    nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord,
    nkPointer, nkFile, nkSetOf, nkConstDecl, nkTypeDecl, nkProcDecl, nkBlock:
      OpWord('null            ', v)   { Sema has already required a designator }
  end
end;

procedure EmitExpr;
begin
  case e^.kind of
    nkInt: OpInt(e^.intVal, v);
    nkReal: EmitRealText(e^.rlAt, e^.rlLen, false, v);
    nkChar: OpInt(ord(e^.chVal), v);
    nkStr: EmitAddress(e, v);
    nkNil: OpWord('null            ', v);
    nkDeref, nkIndex, nkField: EmitLoad(e, v);
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
    nkPointer, nkFile, nkSetOf, nkConstDecl, nkTypeDecl, nkProcDecl, nkBlock:
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
var v: str;
begin
  { A whole array or record is copied; ISO 7185 6.8.2.2 makes assignment of a
    structured value a copy of every component, not a sharing of storage. }
  if IsStructured(t) then
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

procedure EmitAssign(s: nodePtr);
var dst: str;
begin
  EmitAddress(s^.asTarget, dst);
  EmitStore(dst, s^.asTarget^.ntype, s^.asValue)
end;

procedure EmitWrite(s: nodePtr);
var fh, v, width, prec, addr: str; a: nodePtr; b: typePtr;
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
      if IsCharArray(a^.waValue^.ntype) then begin
        EmitAddress(a^.waValue, addr);
        write(ircode, '  call void @pas_write_str(ptr ');
        PutOp(fh);
        write(ircode, ', ptr ');
        PutOp(addr);
        write(ircode, ', i32 ', TypeLength(a^.waValue^.ntype):1, ', i32 ');
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
var fh, slot, v, wide, buf: str; a: nodePtr; t, comp: typePtr;
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
      if IsChar(t) then begin
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
procedure EmitStdProc(s: nodePtr);
var slot, block: str;
begin
  EmitAddress(s^.pcArgs, slot);
  case s^.pcStd of
    spReset, spRewrite, spGet, spPut: begin
      write(ircode, '  call void @pas_');
      case s^.pcStd of
        spReset:   write(ircode, 'reset');
        spRewrite: write(ircode, 'rewrite');
        spGet:     write(ircode, 'get');
        spPut:     write(ircode, 'put');
        spNone, spNew, spDispose: write(ircode, 'get')
      end;
      write(ircode, '(ptr ');
      PutOp(slot);
      writeln(ircode, ')')
    end;
    spNew: begin
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
    end;
    spDispose: begin
      Def(block);
      write(ircode, 'load ptr, ptr ');
      PutOp(slot);
      writeln(ircode);
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
      nkFile, nkSetOf, nkConstDecl, nkTypeDecl, nkProcDecl, nkLabelDecl,
      nkBlock: ;
    end
end;

{ ============================== procedures =============================== }

procedure PutSlotType(s: symPtr);
begin
  { A `var` parameter's slot holds the address of the caller's variable, not a
    copy of its value. Everything else -- including a structured value
    parameter, which the prologue copies in -- holds the value itself. }
  if s^.kind = skVarParam then write(ircode, 'ptr') else PutLlType(s^.stype)
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
    k := k + 1;
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
var l: symListPtr; addr: str; binding, name, comp, istext: integer;
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
      write(ircode, '  call void @pas_file_init(ptr ');
      PutOp(addr);
      writeln(ircode, ', i32 ', binding:1, ', i32 ', l^.sym^.fileArg:1,
              ', ptr @s', name:1, ', i32 ', comp:1, ', i32 ', istext:1, ')')
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

{ The prologue shared by main and every procedure: alloca the frame, store the
  static link, copy the incoming arguments into their slots. }
procedure EnterFrame(p: symPtr);
var l: symListPtr; link, slot, arg, half: str; k, align: integer;
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
      if l^.sym^.kind = skProcParam then begin
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
  writeln(ircode, 'declare void @pas_file_init(ptr, i32, i32, ptr, i32, i32)');
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
  writeln(ircode, 'declare void @llvm.memcpy.p0.p0.i64(ptr, ptr, i64, i1)')
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
  annotate := false;
  msgOut := false;
  StrClear(msgBuf);
  scopeTop := nil;
  scopeDepth := 0;
  pendingHead := nil;
  pendingTail := nil;
  withTop := nil;
  stdInput := nil;
  stdOutput := nil;
  for stringIndex := 1 to strMax do
    stringCache[stringIndex] := nil;

  DumpEverything
end.
