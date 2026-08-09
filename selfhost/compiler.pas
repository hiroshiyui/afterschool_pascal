program Compile(output, source);

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
  kwCount  = 35;
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

type
  strLen = 0..strMax;
  str = record
    len: strLen;
    ch: packed array [1..strMax] of char
  end;
  kwLit = packed array [1..kwWidth] of char;
  wordLit = packed array [1..wordWidth] of char;

  tokenKind = (
    tkEof, tkIdent, tkInt, tkReal, tkStr,
    tkPlus, tkMinus, tkStar, tkSlash, tkAssign, tkComma, tkSemi, tkColon,
    tkPeriod, tkDotDot, tkLParen, tkRParen, tkLBracket, tkRBracket, tkCaret,
    tkEq, tkNotEq, tkLt, tkLe, tkGt, tkGe,
    tkAnd, tkArray, tkBegin, tkCase, tkConst, tkDiv, tkDo, tkDownto, tkElse,
    tkEnd, tkFile, tkFor, tkFunction, tkGoto, tkIf, tkIn, tkLabel, tkMod,
    tkNil, tkNot, tkOf, tkOr, tkPacked, tkProcedure, tkProgram, tkRecord,
    tkRepeat, tkSet, tkThen, tkTo, tkType, tkUntil, tkVar, tkWhile, tkWith);

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
    ctxAfterFile, ctxSubrangeBounds, ctxEnumConstants, ctxAfterArray,
    ctxArrayIndex, ctxRecordEnd, ctxFieldList, ctxVariantTag,
    ctxVariantLabels, ctxVariantOpen, ctxVariantFields, ctxVariantClose,
    ctxConstDef, ctxConstDefEnd, ctxTypeDef, ctxTypeDefEnd, ctxVarDecl,
    ctxVarDeclEnd, ctxParamList, ctxParamListEnd, ctxProcHeading, ctxProcBody,
    ctxCompoundStart, ctxCompoundEnd, ctxIf, ctxWhile, ctxRepeatEnd, ctxFor,
    ctxCaseSelector, ctxCaseLabels, ctxCaseEnd, ctxWith, ctxAssign,
    ctxProcCallArgs, ctxWriteArgs, ctxReadArgs, ctxSubscript, ctxParenExpr,
    ctxCallArgs);

  binaryOp = (opAdd, opSub, opMul, opRealDiv, opIntDiv, opMod, opAnd, opOr,
              opEq, opNe, opLt, opLe, opGt, opGe);
  unaryOp = (opPos, opNeg, opNot);

  { The tag ADR-0005 has been carrying since the first commit. Expressions and
    statements are the C++ NK enumeration; the rest are the plain structs of
    ast.h, which become nodes here because one arena and one walker is less
    code than five parallel ones. }
  nodeKind = (
    { expressions }
    nkInt, nkReal, nkChar, nkStr, nkNil, nkVar, nkIndex, nkField, nkDeref,
    nkBinary, nkUnary, nkCall,
    { statements }
    nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
    nkFor, nkProcCall, nkWith, nkCase,
    { the pieces the C++ side keeps in vectors of plain structs }
    nkWriteArg, nkCaseArm, nkVariantArm, nkGroup, nkDeclName,
    { type denoters }
    nkNamed, nkEnum, nkSubrange, nkArray, nkRecord, nkPointer, nkFile,
    { declarations }
    nkConstDecl, nkTypeDecl, nkProcDecl, nkBlock);

  { ------------------------------------------------------- Sema's own types }

  symKind = (skConst, skType, skVar, skParam, skVarParam, skProc, skFunc);

  { How a file variable reaches something outside the program. ISO 7185 6.10
    makes only a *program parameter* external; every other file variable is a
    scratch file with no name, which is what skInternal means. }
  fileBinding = (fbInternal, fbStdInput, fbStdOutput, fbArgument);

  typeKind = (tyVoid, tyInteger, tyReal, tyBoolean, tyChar, tyEnum, tySubrange,
              tyArray, tyRecord, tyPointer, tyFile);

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
  namePtr = ^nameRec;
  symListPtr = ^symListRec;

  numRec = record value: integer; next: numPtr end;
  nameRec = record at, len: integer; next: namePtr end;
  symListRec = record sym: symPtr; next: symListPtr end;

  { One field of a record. `index` is the position in the struct it belongs to,
    which is also the declaration order; `variant` says which struct that is --
    -1 for the fixed part, otherwise the arm. }
  fieldRec = record
    at, len: integer;
    ftype: typePtr;
    index, variant: integer;
    line, col: integer;
    next: fieldPtr
  end;

  variantRec = record
    labels: numPtr;
    fields, fieldTail: fieldPtr;
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
      constant keeps no value: nothing in Sema reads one, and carrying it would
      mean converting a real literal, which this compiler still defers. }
    intVal: integer;
    charVal: char;
    boolVal: boolean;
    { lexical position: `level` is the nesting depth, and owner/frameIndex say
      which activation record holds this variable and where (ADR-0016) }
    level, frameIndex: integer;
    owner: symPtr;
    params, paramTail: symListPtr;
    frameVars, frameTail: symListPtr;
    frameCount: integer;
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
      nkProcCall:   (pcAt, pcLen: integer; pcArgs: nodePtr;
                     pcSym: symPtr; pcStd: stdProcKind);
      nkWith:       (wtRecord, wtBody: nodePtr);
      nkCase:       (csSelector, csArms: nodePtr);
      nkCaseArm:    (caLabels, caBody: nodePtr; caValues, caValueTail: numPtr);
      nkDeclName:   (dnAt, dnLen: integer);
      { one type-denoter shared by a list of names: a field group, a variable
        declaration, or a parameter group }
      nkGroup:      (grNames, grType: nodePtr; grByRef: boolean);
      nkNamed:      (nmAt, nmLen: integer);
      nkPointer:    (ptAt, ptLen: integer);
      nkEnum:       (enConstants: nodePtr);
      nkSubrange:   (sbLo, sbHi: nodePtr);
      nkArray:      (arDims, arElem: nodePtr; arPacked: boolean);
      nkFile:       (flElem: nodePtr; flPacked: boolean);
      nkRecord:     (rcFields, rcTagType, rcVariants: nodePtr;
                     rcTagAt, rcTagLen, rcTagLine, rcTagCol: integer;
                     rcPacked: boolean);
      nkVariantArm: (vaLabels, vaFields: nodePtr);
      nkConstDecl:  (kdAt, kdLen: integer; kdValue: nodePtr);
      nkTypeDecl:   (tdAt, tdLen: integer; tdType: nodePtr);
      nkProcDecl:   (pdAt, pdLen: integer;
                     pdParams, pdResult, pdBody: nodePtr;
                     pdIsFunction, pdIsForward: boolean; pdSym: symPtr);
      nkBlock:      (blConsts, blTypes, blVars, blProcs, blBody: nodePtr)
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
  { the predefined types, shared singletons }
  intType, realType, boolType, charType, voidType, nilType, textType: typePtr;
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
    write(pool[k])
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
  DefineKeyword(35, 'with     ', tkWith)
end;

procedure WriteKwWord(i: integer);
var n, k: integer;
begin
  n := kwWidth;
  while (n > 0) and (kwText[i][n] = ' ') do n := n - 1;
  for k := 1 to n do write(kwText[i][k])
end;

function LookupKeyword(var s: str): tokenKind;
var i, k, n: integer; found: tokenKind; same: boolean;
begin
  found := tkIdent;
  for i := 1 to kwCount do begin
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

procedure LexNumber;
var
  sl, sc, digit, digitAt: integer;
  text: str;
  isReal, overflow: boolean;
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
  else if c = '*' then AddSimple(sl, sc, tkStar)
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
    tkWith:      write('''with''')
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
    tkGe: write('>=');
    tkEof, tkIdent, tkInt, tkReal, tkStr, tkAnd, tkArray, tkBegin, tkCase,
    tkConst, tkDiv, tkDo, tkDownto, tkElse, tkEnd, tkFile, tkFor, tkFunction,
    tkGoto, tkIf, tkIn, tkLabel, tkMod, tkNil, tkNot, tkOf, tkOr, tkPacked,
    tkProcedure, tkProgram, tkRecord, tkRepeat, tkSet, tkThen, tkTo, tkType,
    tkUntil, tkVar, tkWhile, tkWith: write('?')
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
    ctxCallArgs:       write('after the arguments of a function call')
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
    nkProcCall: begin n^.pcSym := nil; n^.pcStd := spNone end;
    nkCaseArm: begin n^.caValues := nil; n^.caValueTail := nil end;
    nkProcDecl: n^.pdSym := nil;
    nkInt, nkReal, nkChar, nkStr, nkNil, nkIndex, nkDeref, nkBinary, nkUnary,
    nkEmpty, nkAssign, nkCompound, nkIf, nkWhile, nkRepeat, nkFor, nkWith,
    nkCase, nkWriteArg, nkVariantArm, nkGroup, nkDeclName, nkNamed, nkEnum,
    nkSubrange, nkArray, nkRecord, nkPointer, nkFile, nkConstDecl, nkTypeDecl,
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
    if Check(tkCase) then
      if inVariant then begin
        { A variant inside a variant is legal Pascal and nothing in the
          bootstrap needs one; rejecting it keeps the gap visible. }
        ErrorAtCur;
        writeln('a variant part inside a variant is not supported yet');
        Bail
      end
      else
        { the variant part of a record ends its field list, and the caller
          parses it -- it is last (ISO 7185 6.4.3.3) }
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
                 (';' variant)*

  The tag may be a real field or exist only as a type (ISO 7185 6.4.3.3). The
  two are told apart by the ':' -- `case kind: nodekind of` names a field,
  `case nodekind of` does not. }
procedure ParseVariantPart(rec: nodePtr);
var head, tail, arm, lh, lt: nodePtr; more, moreLabels: boolean;
begin
  Expect(tkCase, ctxNone);
  rec^.rcTagLine := CurLine;
  rec^.rcTagCol := CurCol;

  if Check(tkIdent) and (PeekKind(1) = tkColon) then begin
    rec^.rcTagAt := tok[pos].at;
    rec^.rcTagLen := tok[pos].len;
    pos := pos + 2
  end;
  if not aborted then
    if not Check(tkIdent) then begin
      ErrorAtCur;
      writeln('the tag of a variant part must be a type name');
      Bail
    end;
  rec^.rcTagType := ParseTypeExpr;
  Expect(tkOf, ctxVariantTag);

  head := nil;
  tail := nil;
  more := true;
  while more and not aborted and not Check(tkEnd) do begin
    arm := NewNode(nkVariantArm, CurLine, CurCol);
    arm^.vaLabels := nil;
    arm^.vaFields := nil;
    lh := nil;
    lt := nil;
    moreLabels := true;
    while moreLabels and not aborted do begin
      Append(lh, lt, ParseExpr);
      moreLabels := Accept(tkComma)
    end;
    arm^.vaLabels := lh;

    Expect(tkColon, ctxVariantLabels);
    Expect(tkLParen, ctxVariantOpen);
    arm^.vaFields := ParseFieldGroups(tkRParen, true);
    Expect(tkRParen, ctxVariantClose);
    Append(head, tail, arm);
    more := Accept(tkSemi)
  end;
  rec^.rcVariants := head
end;

{ record-type = 'record' field-list 'end'

  Note the local: reading a function's own name is a recursive call in Pascal
  (ISO 7185 6.8.2.2), so the node under construction cannot live in the result
  -- it is built here and assigned once at the end. }
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
    ParseVariantPart(t);
  Expect(tkEnd, ctxRecordEnd);
  ParseRecordType := t
end;

{ type-denoter = 'packed'? structured-type | ordinal-type | type-identifier }
function ParseTypeExpr;
var t: nodePtr; packed_: boolean;
begin
  EnterLevel;
  t := nil;
  if not aborted then begin
    packed_ := Accept(tkPacked);

    if Check(tkFile) then begin
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
    else if Check(tkSet) then begin
      ErrorAtCur;
      WriteTokenName(tok[pos].kind);
      writeln(' types are not supported yet');
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

function ParseFactor: nodePtr;
var e, call: nodePtr; head, tail: nodePtr; more: boolean;
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
      e := NewNode(nkUnary, CurLine, CurCol);
      e^.unOp := opNot;
      pos := pos + 1;
      e^.unArg := ParseFactor
    end
    else if Check(tkMinus) then begin
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
  ParseFactor := e
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
var s, head, tail, arm, lh, lt: nodePtr; more, moreLabels: boolean;
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
    arm := NewNode(nkCaseArm, CurLine, CurCol);
    arm^.caLabels := nil;
    arm^.caBody := nil;
    lh := nil;
    lt := nil;
    moreLabels := true;
    while moreLabels and not aborted do begin
      Append(lh, lt, ParseExpr);
      moreLabels := Accept(tkComma)
    end;
    arm^.caLabels := lh;
    Expect(tkColon, ctxCaseLabels);
    arm^.caBody := ParseStatement;
    Append(head, tail, arm);
    more := Accept(tkSemi)
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
    else if Check(tkEnd) or Check(tkSemi) then
      s := NewNode(nkEmpty, CurLine, CurCol)
    else if Check(tkGoto) then begin
      ErrorAtCur;
      WriteTokenName(tok[pos].kind);
      writeln(' statements are not supported yet');
      Bail
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

  ISO 7185 6.6.3.1 restricts a parameter's type to a type *identifier*, so an
  array parameter needs a named type. That is a real restriction, not an
  omission: it is what makes a formal and an actual parameter the same type
  rather than two structurally identical ones. }
function ParseFormalParameters: nodePtr;
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
    g^.grByRef := Accept(tkVar);
    g^.grNames := ParseNameList(ctxParamList);
    Expect(tkColon, ctxParamList);
    if not aborted then
      if not Check(tkIdent) then begin
        ErrorAtCur;
        writeln('a parameter''s type must be a type name');
        Bail
      end;
    g^.grType := ParseTypeExpr;
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
var b, ph, pt, ch, ct, th, tt, vh, vt: nodePtr; done: boolean;
begin
  b := NewNode(nkBlock, CurLine, CurCol);
  b^.blConsts := nil;
  b^.blTypes := nil;
  b^.blVars := nil;
  b^.blProcs := nil;
  b^.blBody := nil;
  ph := nil; pt := nil;
  ch := nil; ct := nil;
  th := nil; tt := nil;
  vh := nil; vt := nil;

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
    else if Check(tkLabel) then begin
      ErrorAtCur;
      WriteTokenName(tok[pos].kind);
      writeln(' declarations are not supported yet');
      Bail
    end
    else
      done := true
  end;
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

{ `nil`, which is a value of every pointer type and of no other. }
function IsNil(t: typePtr): boolean;
begin IsNil := IsPointer(t) and (t^.elem = nil) end;

{ Arrays and records live in memory and are copied wholesale. A file is *not*
  structured: it also lives in memory, but it may never be copied, so grouping
  it here would grant it exactly the operations it must not have. }
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
function FindField(t: typePtr; at, len: integer): fieldPtr;
var f: fieldPtr; v: variantPtr; found: fieldPtr;
begin
  found := nil;
  f := t^.fields;
  while (f <> nil) and (found = nil) do begin
    if PoolSame(f^.at, f^.len, at, len) then found := f;
    f := f^.next
  end;
  v := t^.variants;
  while (v <> nil) and (found = nil) do begin
    f := v^.fields;
    while (f <> nil) and (found = nil) do begin
      if PoolSame(f^.at, f^.len, at, len) then found := f;
      f := f^.next
    end;
    v := v^.next
  end;
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
    write(value:1)
  { A printable character is written as itself; anything else is written as
    chr(n). Not cosmetic: the C++ prints a diagnostic with %s, so a char of
    value 0 written literally would truncate the message at that point. }
  else if b^.kind = tyChar then
    if (value >= 32) and (value < 127) then
      write('''', chr(value), '''')
    else
      write('chr(', value:1, ')')
  else if b^.kind = tyBoolean then
    if value <> 0 then write('true') else write('false')
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
    write(value:1)
end;

{ A description for diagnostics. A named type reports its name; an anonymous
  one is spelled out the way the source would have written it. }
procedure WriteTypeName;
var p: namePtr; f: fieldPtr; first: boolean;
begin
  if t = nil then
    write('?')
  else if t^.aliasLen > 0 then
    WritePool(t^.aliasAt, t^.aliasLen)
  else
    case t^.kind of
      tyInteger: write('integer');
      tyReal:    write('real');
      tyBoolean: write('boolean');
      tyChar:    write('char');
      tyVoid:    write('void');
      tyEnum: begin
        write('(');
        p := t^.enumNames;
        first := true;
        while p <> nil do begin
          if not first then write(', ');
          WritePool(p^.at, p^.len);
          first := false;
          p := p^.next
        end;
        write(')')
      end;
      tySubrange: begin
        WriteOrdinalName(t^.host, t^.lo);
        write('..');
        WriteOrdinalName(t^.host, t^.hi)
      end;
      { ISO 7185 6.4.4 makes a pointer's domain a type *identifier*, so the
        recursion always stops at a name -- which is what lets a type point at
        itself without this looping forever. }
      tyPointer:
        if t^.elem <> nil then begin
          write('^');
          WriteTypeName(t^.elem)
        end
        else
          write('nil');
      tyFile:
        if IsChar(t^.elem) then write('text') else write('file');
      tyRecord: begin
        { An anonymous record is named by its fields, which is the only thing
          that distinguishes it from any other anonymous record. }
        write('record ');
        f := t^.fields;
        first := true;
        while f <> nil do begin
          if not first then write(', ');
          WritePool(f^.at, f^.len);
          first := false;
          f := f^.next
        end;
        write(' end')
      end;
      tyArray: begin
        if t^.isPacked then write('packed array [') else write('array [');
        WriteOrdinalName(t^.indexType, t^.lo);
        write('..');
        WriteOrdinalName(t^.indexType, t^.hi);
        write('] of ');
        if t^.elem <> nil then WriteTypeName(t^.elem) else write('?')
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
  s^.level := 0;
  s^.frameIndex := -1;
  s^.owner := nil;
  s^.params := nil;
  s^.paramTail := nil;
  s^.frameVars := nil;
  s^.frameTail := nil;
  s^.frameCount := 0;
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
  else if toT = fromT then
    Assignable := true
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
      { A real constant folds, but carries no value: nothing in Sema reads one,
        and keeping it would mean converting the literal, which this compiler
        still defers (ADR-0022). }
      nkReal: begin
        res.stype := realType;
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
              else
                ok := IsReal(inner.stype)
            end;
            opNot:
              if IsBoolean(inner.stype) then begin
                res := inner;
                res.boolVal := not inner.boolVal;
                ok := true
              end
          end;
      nkStr, nkNil, nkIndex, nkField, nkDeref, nkBinary, nkCall,
      nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
      nkFor, nkProcCall, nkWith, nkCase, nkWriteArg, nkCaseArm, nkVariantArm,
      nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord,
      nkPointer, nkFile, nkConstDecl, nkTypeDecl, nkProcDecl, nkBlock:
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
function ResolveFile(d: nodePtr): typePtr;
var t, component: typePtr;
begin
  t := NewType(tyFile);
  if d^.flElem <> nil then component := ResolveType(d^.flElem)
  else component := charType;
  if not IsChar(component) then begin
    ErrorAt(d^.line, d^.col);
    write('only a text file is supported: the component type of a file must ',
          'be char, found ');
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
                   t: typePtr; variant, index: integer);
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

procedure ResolveVariants(d: nodePtr; rec: typePtr);
var
  tag, labelType, fieldType: typePtr;
  arm, label_, g, n, tagName: nodePtr;
  v, w: variantPtr;
  num, seen: numPtr;
  index, value: integer;
  claimed: boolean;
begin
  tag := ResolveType(d^.rcTagType);
  if not IsOrdinal(tag) then begin
    ErrorAt(d^.rcTagLine, d^.rcTagCol);
    write('the tag of a variant part must be an ordinal type, found ');
    WriteTypeName(tag);
    writeln
  end
  else begin
    rec^.tagType := tag;

    { A named tag is an ordinary field of the fixed part; a tagless variant
      part has the type but no storage for it (ISO 7185 6.4.3.3). }
    if d^.rcTagLen > 0 then begin
      rec^.tagField := FieldCount(rec^.fields);
      tagName := NewNode(nkDeclName, d^.rcTagLine, d^.rcTagCol);
      tagName^.dnAt := d^.rcTagAt;
      tagName^.dnLen := d^.rcTagLen;
      AddField(rec, rec^.fields, rec^.fieldTail, tagName, tag, -1,
               rec^.tagField)
    end;

    index := 0;
    arm := d^.rcVariants;
    while arm <> nil do begin
      new(v);
      v^.labels := nil;
      v^.fields := nil;
      v^.fieldTail := nil;
      v^.line := arm^.line;
      v^.col := arm^.col;
      v^.next := nil;

      label_ := arm^.vaLabels;
      while label_ <> nil do begin
        labelType := nil;
        value := 0;
        if not EvalOrdinal(label_, labelType, value) then begin
          ErrorAt(label_^.line, label_^.col);
          writeln('a variant''s label must be an ordinal constant')
        end
        else if Base(labelType) <> Base(tag) then begin
          ErrorAt(label_^.line, label_^.col);
          write('this variant''s tag is ');
          WriteTypeName(tag);
          write(', but the label is ');
          WriteTypeName(labelType);
          writeln
        end
        else begin
          { has an earlier variant already claimed this tag value? }
          claimed := false;
          w := rec^.variants;
          while w <> nil do begin
            seen := w^.labels;
            while seen <> nil do begin
              if seen^.value = value then claimed := true;
              seen := seen^.next
            end;
            w := w^.next
          end;
          seen := v^.labels;
          while seen <> nil do begin
            if seen^.value = value then claimed := true;
            seen := seen^.next
          end;
          if claimed then begin
            ErrorAt(label_^.line, label_^.col);
            write('the tag value ');
            WriteOrdinalName(tag, value);
            writeln(' already selects an earlier variant')
          end
          else begin
            new(num);
            num^.value := value;
            num^.next := nil;
            if v^.labels = nil then v^.labels := num
            else begin
              seen := v^.labels;
              while seen^.next <> nil do seen := seen^.next;
              seen^.next := num
            end
          end
        end;
        label_ := label_^.next
      end;

      { The fields are pushed into the arm, so each variant is numbered from
        zero and codegen can index it as a struct of its own. }
      if rec^.variants = nil then rec^.variants := v
      else rec^.variantTail^.next := v;
      rec^.variantTail := v;

      g := arm^.vaFields;
      while g <> nil do begin
        fieldType := ResolveType(g^.grType);
        n := g^.grNames;
        while n <> nil do begin
          AddField(rec, v^.fields, v^.fieldTail, n, fieldType, index,
                   FieldCount(v^.fields));
          n := n^.next
        end;
        g := g^.next
      end;

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
      AddField(t, t^.fields, t^.fieldTail, n, fieldType, -1,
               FieldCount(t^.fields));
      n := n^.next
    end;
    g := g^.next
  end;
  if d^.rcTagType <> nil then
    ResolveVariants(d, t);
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
      nkInt, nkReal, nkChar, nkStr, nkNil, nkVar, nkIndex, nkField, nkDeref,
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
      as a `continue`; there is no such statement here, and an empty one before
      `else` is a statement this compiler does not accept, so the condition is
      folded into the test below instead. }
    else if (s <> stdInput) and (s <> stdOutput) then
      if not IsFile(s^.stype) then begin
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

{ -------------------------------------------------------------- arguments }

{ Check an argument list against a callable's parameters. A `var` parameter is
  bound to a variable, not to a value, so the argument has to be one. }
procedure CheckArguments(callee: symPtr; args: nodePtr; line, col: integer);
var a: nodePtr; p: symListPtr; n, given, i: integer;
begin
  a := args;
  while a <> nil do begin
    CheckExpr(a);
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
      if p^.sym^.kind = skVarParam then begin
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
    opEq:      write('=');
    opNe:      write('<>');
    opLt:      write('<');
    opLe:      write('<=');
    opGt:      write('>');
    opGe:      write('>=')
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

procedure CheckBinary(b: nodePtr);
var l, r: typePtr;
begin
  CheckExpr(b^.bnLhs);
  CheckExpr(b^.bnRhs);
  l := b^.bnLhs^.ntype;
  r := b^.bnRhs^.ntype;
  if (l = nil) or (r = nil) then
    b^.ntype := intType
  else
    case b^.bnOp of
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

function LookupBuiltin(at, len: integer): builtinKind;
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
  if (sym <> nil) and (sym^.kind = skFunc) then begin
    c^.clSym := sym;
    c^.ntype := sym^.stype;
    CheckArguments(sym, c^.clArgs, c^.line, c^.col)
  end
  else if (sym <> nil) and (sym^.kind = skProc) then begin
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
          else if e^.vrSym^.kind = skProc then begin
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
          else if (e^.vrSym^.kind = skFunc) and (e^.vrSym^.params = nil) then
            e^.ntype := e^.vrSym^.stype
          else if e^.vrSym^.kind = skFunc then begin
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

      nkEmpty, nkAssign, nkWrite, nkRead, nkCompound, nkIf, nkWhile, nkRepeat,
      nkFor, nkProcCall, nkWith, nkCase, nkWriteArg, nkCaseArm, nkVariantArm,
      nkGroup, nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord,
      nkPointer, nkFile, nkConstDecl, nkTypeDecl, nkProcDecl, nkBlock:
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
var a: nodePtr; t: typePtr;
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
end;

{ ISO 7185 6.9.1. Like write, the first argument may be the file; every other
  one is a *variable* to store into, so each has to be a designator. }
procedure CheckRead(r: nodePtr);
var a: nodePtr; t: typePtr;
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

  a := r^.rdArgs;
  while a <> nil do begin
    if not IsDesignator(a) then begin
      ErrorAt(a^.line, a^.col);
      writeln('read needs a variable, not a value')
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
var a: nodePtr; n: integer;
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
  else if n <> 1 then begin
    { ISO 7185 6.6.5.3 also allows `new(p, c1, ...)` to allocate only the
      storage some variants need. Rejecting it is honest: this compiler always
      allocates the whole record, which is safe but is not that feature. }
    ErrorAt(p^.line, p^.col);
    write('''');
    WritePool(p^.pcAt, p^.pcLen);
    writeln(''' takes exactly one argument in this compiler; the ',
            'variant-selecting form is not supported')
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
  end
end;

{ ISO 7185 6.8.3.5: the selector is an ordinal expression, every label is a
  constant of a compatible type, and no value may appear twice. There is no
  `else` arm, so a value matching nothing is an error at run time. }
procedure CheckCase(c: nodePtr);
var
  sel, labelType, named: typePtr;
  arm, label_: nodePtr;
  seenHead, seenTail, n: numPtr;
  value: integer;
  seen: boolean;
begin
  CheckExpr(c^.csSelector);
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
      value := 0;
      if not EvalOrdinal(label_, labelType, value) then begin
        ErrorAt(label_^.line, label_^.col);
        writeln('a case label must be an ordinal constant')
      end
      else if (sel <> nil) and not Assignable(sel, labelType) then begin
        ErrorAt(label_^.line, label_^.col);
        write('this case selects on ');
        WriteTypeName(sel);
        write(', but the label is ');
        WriteTypeName(labelType);
        writeln
      end
      else begin
        seen := false;
        n := seenHead;
        while n <> nil do begin
          if n^.value = value then seen := true;
          n := n^.next
        end;
        if seen then begin
          ErrorAt(label_^.line, label_^.col);
          write('the label ');
          if sel <> nil then named := sel else named := labelType;
          WriteOrdinalName(named, value);
          writeln(' appears twice in this case statement')
        end
        else begin
          new(n);
          n^.value := value;
          n^.next := nil;
          if seenHead = nil then seenHead := n else seenTail^.next := n;
          seenTail := n;
          new(n);
          n^.value := value;
          n^.next := nil;
          if arm^.caValues = nil then arm^.caValues := n
          else arm^.caValueTail^.next := n;
          arm^.caValueTail := n
        end
      end;
      label_ := label_^.next
    end;
    CheckStmt(arm^.caBody);
    arm := arm^.next
  end
end;

{ `with r do S` makes the fields of r visible as bare names throughout S. The
  record is designated once, so the binding holds its address and any subscripts
  in the designator are evaluated a single time. }
procedure CheckWith(w: nodePtr);
var t: typePtr; at, len: integer; entry: symListPtr;
begin
  CheckExpr(w^.wtRecord);
  t := w^.wtRecord^.ntype;

  if not IsDesignator(w^.wtRecord) then begin
    ErrorAt(w^.wtRecord^.line, w^.wtRecord^.col);
    writeln('''with'' needs a record variable');
    CheckStmt(w^.wtBody)
  end
  else if not IsRecord(t) then begin
    ErrorAt(w^.wtRecord^.line, w^.wtRecord^.col);
    write('''with'' needs a record variable, found ');
    if t = nil then write('nothing') else WriteTypeName(t);
    writeln;
    CheckStmt(w^.wtBody)
  end
  else begin
    { The binding is a frame slot holding a pointer -- the same shape as a
      `var` parameter -- so a `with` inside a recursive procedure binds the
      record of the invocation it is running in. }
    InternWithName(currentProc^.frameCount, at, len);
    new(entry);
    entry^.sym := AddHiddenVar(at, len, skVarParam, t, currentProc);
    entry^.next := withTop;
    withTop := entry;
    CheckStmt(w^.wtBody);
    withTop := withTop^.next
  end
end;

procedure CheckStmt;
var sub: nodePtr; sym, named: symPtr;
begin
  if s <> nil then
    case s^.kind of
      nkEmpty: ;

      nkCompound: begin
        sub := s^.cpBody;
        while sub <> nil do begin
          CheckStmt(sub);
          sub := sub^.next
        end
      end;

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
        else if sym^.kind <> skProc then begin
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
        CheckStmt(s^.ifThen);
        CheckStmt(s^.ifElse)
      end;

      nkWhile: begin
        CheckExpr(s^.whCond);
        if (s^.whCond^.ntype <> nil) and not IsBoolean(s^.whCond^.ntype) then
        begin
          ErrorAt(s^.whCond^.line, s^.whCond^.col);
          writeln('the condition of a while statement must be boolean')
        end;
        CheckStmt(s^.whBody)
      end;

      nkRepeat: begin
        sub := s^.rpBody;
        while sub <> nil do begin
          CheckStmt(sub);
          sub := sub^.next
        end;
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
        CheckStmt(s^.frBody)
      end;

      nkInt, nkReal, nkChar, nkStr, nkNil, nkVar, nkIndex, nkField, nkDeref,
      nkBinary, nkUnary, nkCall, nkWriteArg, nkCaseArm, nkVariantArm, nkGroup,
      nkDeclName, nkNamed, nkEnum, nkSubrange, nkArray, nkRecord, nkPointer,
      nkFile, nkConstDecl, nkTypeDecl, nkProcDecl, nkBlock:
        { not a statement }
    end
end;

{ ------------------------------------------------------------ declarations }

procedure DeclareProcHeading(d: nodePtr; owner: symPtr);
var existing, sym, ps: symPtr; g, n: nodePtr; t: typePtr;
    mark: entryPtr; at, len: integer;
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
        { ISO 7185 6.6.2: a function returns a simple type, which is what lets
          the result travel in a register and be read back with a plain load. }
        if IsMemory(sym^.stype) then begin
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
    g := d^.pdParams;
    while g <> nil do begin
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
        if g^.grByRef then
          ps := AddFrameVar(n^.dnAt, n^.dnLen, skVarParam, t, sym, n^.line,
                            n^.col)
        else
          ps := AddFrameVar(n^.dnAt, n^.dnLen, skParam, t, sym, n^.line,
                            n^.col);
        AppendSym(sym^.params, sym^.paramTail, ps);
        n := n^.next
      end;
      g := g^.next
    end;
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
procedure CheckBlock;
var d, g, n: nodePtr; s: symPtr; t: typePtr; value: symbol;
begin
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
      s^.boolVal := value.boolVal
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

  CheckStmt(b^.blBody)
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
  { `text`, the predefined file of char (ISO 7185 6.4.3.5). A singleton like
    the other predefined types, so every variable declared `text` has the same
    type -- a `file of char` written out longhand is a different one, exactly
    as ADR-0017's name equivalence says it should be. }
  textType := NewType(tyFile);
  textType^.elem := charType;
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
      skVar, skParam, skVarParam: begin
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
    opEq:      write('eq');
    opNe:      write('ne');
    opLt:      write('lt');
    opLe:      write('le');
    opGt:      write('gt');
    opGe:      write('ge')
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

procedure DumpField(f: fieldPtr);
begin
  Pad;
  write('field ');
  WritePool(f^.at, f^.len);
  write(' #', f^.index:1, '/', f^.variant:1, ' : ');
  WriteTypeName(f^.ftype);
  writeln
end;

{ The layout Sema gave a record: which struct each field lives in and at what
  position, and which tag values select each variant. Codegen indexes by
  exactly these numbers, so they are what a record type *is*. }
procedure DumpRecordLayout(r: typePtr);
var f: fieldPtr; v: variantPtr; lbl: numPtr; i: integer;
begin
  Pad;
  writeln('layout');
  level := level + 1;
  f := r^.fields;
  while f <> nil do begin
    DumpField(f);
    f := f^.next
  end;
  if r^.tagField >= 0 then begin
    Pad;
    writeln('tagfield #', r^.tagField:1)
  end;
  i := 0;
  v := r^.variants;
  while v <> nil do begin
    Pad;
    write('variant ', i:1, ' labels');
    lbl := v^.labels;
    while lbl <> nil do begin
      write(' ', lbl^.value:1);
      lbl := lbl^.next
    end;
    writeln;
    level := level + 1;
    f := v^.fields;
    while f <> nil do begin
      DumpField(f);
      f := f^.next
    end;
    level := level - 1;
    i := i + 1;
    v := v^.next
  end;
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
          write(' field #', n^.vrField^.index:1, '/', n^.vrField^.variant:1)
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
        if n^.fdResolved <> nil then
          write(' -> #', n^.fdResolved^.index:1, '/', n^.fdResolved^.variant:1)
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
var p: nodePtr; num: numPtr;
begin
  Pad;
  case n^.kind of
    nkEmpty: begin
      write('empty');
      At(n^.line, n^.col)
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
        DumpExprList(p^.caLabels);
        level := level - 1;
        { The folded label values: this is where constant folding of an ordinal
          is compared, and a label the checker rejected leaves a gap. }
        if annotate then begin
          Pad;
          write('values');
          num := p^.caValues;
          while num <> nil do begin
            write(' ', num^.value:1);
            num := num^.next
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
      level := level - 1
    end;
    nkProcCall: begin
      write('proccall ');
      WritePool(n^.pcAt, n^.pcLen);
      if annotate then
        if n^.pcStd <> spNone then
          write(' -> standard ', ord(n^.pcStd):1)
        else begin
          write(' -> ');
          WriteSymRef(n^.pcSym)
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
procedure DumpGroup(g: nodePtr; asVar: boolean);
begin
  Pad;
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
end;

procedure DumpGroupList(n: nodePtr; asVar: boolean);
var p: nodePtr;
begin
  p := n;
  while p <> nil do begin
    DumpGroup(p, asVar);
    p := p^.next
  end
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
      if n^.rcTagType <> nil then begin
        { An empty tag name is the `case T of` form, where the tag exists as a
          type but not as a field (ISO 7185 6.4.3.3); '-' says so, and no
          field could be spelled that. }
        Pad;
        write('tag ');
        if n^.rcTagLen = 0 then
          write('-')
        else
          WritePool(n^.rcTagAt, n^.rcTagLen);
        At(n^.rcTagLine, n^.rcTagCol);
        level := level + 1;
        DumpTypeExpr(n^.rcTagType);
        p := n^.rcVariants;
        while p <> nil do begin
          Pad;
          write('arm');
          At(p^.line, p^.col);
          level := level + 1;
          Pad;
          writeln('labels');
          level := level + 1;
          DumpExprList(p^.vaLabels);
          level := level - 1;
          Pad;
          writeln('fields');
          level := level + 1;
          DumpGroupList(p^.vaFields, false);
          level := level - 2;
          p := p^.next
        end;
        level := level - 1
      end;
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
      tkEq, tkNotEq, tkLt, tkLe, tkGt, tkGe: begin
        write('op ');
        WriteOperator(tok[i].kind);
        writeln
      end;
      tkAnd, tkArray, tkBegin, tkCase, tkConst, tkDiv, tkDo, tkDownto, tkElse,
      tkEnd, tkFile, tkFor, tkFunction, tkGoto, tkIf, tkIn, tkLabel, tkMod,
      tkNil, tkNot, tkOf, tkOr, tkPacked, tkProcedure, tkProgram, tkRecord,
      tkRepeat, tkSet, tkThen, tkTo, tkType, tkUntil, tkVar, tkWhile,
      tkWith: begin
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
procedure DumpEverything;
begin
  writeln('=== tokens');
  Tokenize;
  DumpTokens;

  writeln('=== ast');
  { The C++ driver stops after lexing when the lexer found anything wrong, so a
    file with a bad token is compared on its diagnostics and not on a tree
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
  end
end;

begin
  InstallKeywords;
  poolLen := 0;
  tokCount := 0;
  pos := 1;
  depth := 0;
  level := 0;
  aborted := false;
  errorSeen := false;
  annotate := false;
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
