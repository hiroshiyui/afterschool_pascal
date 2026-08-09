program Parse(output, source);

{ The parser and the AST of the self-hosted compiler: stage 1, component 2.

  A port of src/parser.cpp and src/ast.h into the language that compiler
  accepts, checked by comparing the tree it builds against the C++ parser's on
  every file in the tree (selfhost/difftest.sh, `pascalc --dump-ast`).

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
  kwCount  = 35;
  nul      = 0;      { what Peek yields past the end, as the C++ lexer does }
  tab      = 9;
  newline  = 10;
  creturn  = 13;
  poolMax  = 200000; { characters of identifier and literal text }
  tokMax   = 30000;
  maxDepth = 1000;   { ADR-0020, and the same number the C++ parser uses }

type
  strLen = 0..strMax;
  str = record
    len: strLen;
    ch: packed array [1..strMax] of char
  end;
  kwLit = packed array [1..kwWidth] of char;

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
    intVal: integer
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

  nodePtr = ^node;
  node = record
    line, col: integer;
    { The sibling list that a std::vector<...Ptr> becomes. }
    next: nodePtr;
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
      nkVar:        (vrAt, vrLen: integer);
      nkIndex:      (ixBase, ixIndex: nodePtr);
      nkField:      (fdBase: nodePtr; fdAt, fdLen: integer);
      nkDeref:      (drBase: nodePtr);
      nkBinary:     (bnOp: binaryOp; bnLhs, bnRhs: nodePtr);
      nkUnary:      (unOp: unaryOp; unArg: nodePtr);
      nkCall:       (clAt, clLen: integer; clArgs: nodePtr);
      nkEmpty:      ();
      nkAssign:     (asTarget, asValue: nodePtr);
      nkWrite:      (wrArgs: nodePtr; wrNewline: boolean);
      nkWriteArg:   (waValue, waWidth, waPrec: nodePtr);
      nkRead:       (rdArgs: nodePtr; rdNewline: boolean);
      nkCompound:   (cpBody: nodePtr);
      nkIf:         (ifCond, ifThen, ifElse: nodePtr);
      nkWhile:      (whCond, whBody: nodePtr);
      nkRepeat:     (rpBody, rpCond: nodePtr);
      nkFor:        (frVar, frFrom, frTo, frBody: nodePtr; frDownto: boolean);
      nkProcCall:   (pcAt, pcLen: integer; pcArgs: nodePtr);
      nkWith:       (wtRecord, wtBody: nodePtr);
      nkCase:       (csSelector, csArms: nodePtr);
      nkCaseArm:    (caLabels, caBody: nodePtr);
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
                     pdIsFunction, pdIsForward: boolean);
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

procedure AddInt(l, c, v: integer);
var i: integer;
begin
  i := AddToken(tkInt, l, c);
  tok[i].intVal := v
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
    AddInt(sl, sc, value)
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
      At(n^.line, n^.col)
    end;
    nkReal: begin
      write('real ');
      WritePool(n^.rlAt, n^.rlLen);
      At(n^.line, n^.col)
    end;
    nkChar: begin
      write('char ', ord(n^.chVal):1);
      At(n^.line, n^.col)
    end;
    nkStr: begin
      write('str [');
      WritePool(n^.stAt, n^.stLen);
      write(']');
      At(n^.line, n^.col)
    end;
    nkNil: begin
      write('nil');
      At(n^.line, n^.col)
    end;
    nkVar: begin
      write('var ');
      WritePool(n^.vrAt, n^.vrLen);
      At(n^.line, n^.col)
    end;
    nkIndex: begin
      write('index');
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.ixBase);
      DumpExpr(n^.ixIndex);
      level := level - 1
    end;
    nkField: begin
      write('field ');
      WritePool(n^.fdAt, n^.fdLen);
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.fdBase);
      level := level - 1
    end;
    nkDeref: begin
      write('deref');
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.drBase);
      level := level - 1
    end;
    nkBinary: begin
      write('binary ');
      WriteBinOp(n^.bnOp);
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.bnLhs);
      DumpExpr(n^.bnRhs);
      level := level - 1
    end;
    nkUnary: begin
      write('unary ');
      WriteUnOp(n^.unOp);
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.unArg);
      level := level - 1
    end;
    nkCall: begin
      write('call ');
      WritePool(n^.clAt, n^.clLen);
      At(n^.line, n^.col);
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
var p: nodePtr;
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
      At(n^.line, n^.col)
    end;
    nkPointer: begin
      write('pointer ');
      WritePool(n^.ptAt, n^.ptLen);
      At(n^.line, n^.col)
    end;
    nkEnum: begin
      write('enum');
      At(n^.line, n^.col);
      level := level + 1;
      DumpNames(n^.enConstants);
      level := level - 1
    end;
    nkSubrange: begin
      write('subrange');
      At(n^.line, n^.col);
      level := level + 1;
      DumpExpr(n^.sbLo);
      DumpExpr(n^.sbHi);
      level := level - 1
    end;
    nkFile: begin
      write('file');
      if n^.flPacked then write(' packed');
      At(n^.line, n^.col);
      level := level + 1;
      DumpTypeExpr(n^.flElem);
      level := level - 1
    end;
    nkArray: begin
      write('array');
      if n^.arPacked then write(' packed');
      At(n^.line, n^.col);
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
      At(n^.line, n^.col);
      level := level + 1;
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
  level := 1;
  DumpBlock(progBlock)
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

  Tokenize;
  { The C++ driver stops after lexing when the lexer found anything wrong, so
    a file with a bad token is compared on its diagnostics and not on a tree
    built from tokens that were never valid. }
  if not errorSeen then
    ParseProgram;
  if not errorSeen then
    DumpProgram
end.
