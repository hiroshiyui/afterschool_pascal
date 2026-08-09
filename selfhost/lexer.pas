program Lex(output, source);

{ The lexer of the self-hosted compiler: stage 1, component 1.

  This is a port of src/lexer.cpp into the language that compiler accepts, and
  it is checked by comparing its token stream against the C++ lexer's on every
  file in tests/ (selfhost/difftest.sh). A disagreement is a bug in one of the
  two, found now and cheaply, rather than a byte mismatch at stage 3 with
  nothing to bisect.

  Two constraints shape the shape of it:

  * ISO 7185 has no include mechanism, so the finished compiler is one source
    file. This program is written to be pasted into that file: everything below
    the character source is declarations the rest of the compiler will share.

  * ISO's file model gives exactly one character of lookahead -- the buffer
    variable source^. The lexer needs three, because an exponent is only an
    exponent if a digit follows the optional sign (`1e+5`), so a window is
    maintained here on top of the buffer variable rather than pretending one
    character is enough.

  Strings follow ADR-0012: a length and a fixed buffer, with keyword literals
  padded to a common width because a literal cannot otherwise be passed to a
  procedure. }

const
  strMax  = 255;  { longest identifier or string literal kept }
  kwWidth = 9;    { 'procedure', the longest reserved word }
  kwCount = 35;
  nul     = 0;    { what Peek yields past the end, as the C++ lexer does }
  tab     = 9;
  newline = 10;
  creturn = 13;

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

var
  source: text;

  { The lookahead window. win[0] is the character the lexer is looking at. }
  win: array [0..2] of char;
  winEof: array [0..2] of boolean;
  line, col: integer;

  { The lexer runs twice over the file: once reporting only diagnostics, once
    emitting only tokens. That is what puts every error before every token in
    the output without holding either in memory -- and reset makes a second
    pass cost one line. }
  reporting: boolean;

  kwText: array [1..kwCount] of kwLit;
  kwKind: array [1..kwCount] of tokenKind;

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

procedure StrWrite(var s: str);
var k: integer;
begin
  for k := 1 to s.len do
    write(s.ch[k])
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
  write(l:1, ' ', c:1, ' error ')
end;

{ --------------------------------------------------------------- the dump }

procedure EmitPos(l, c: integer);
begin
  write(l:1, ' ', c:1, ' ')
end;

{ The spelling of every kind that carries no payload. These literals are
  *written*, never stored, so they need no padding -- which is the whole
  reason ADR-0012's record costs as little as it does. }
{ The reporting pass emits no tokens at all. Guarding here rather than at every
  call site is what keeps the scanner below identical in both passes -- and
  Pascal has no early return, so the guard wraps the body rather than leaving
  it. }
procedure EmitSimple(l, c: integer; k: tokenKind);
begin
  if not reporting then begin
  EmitPos(l, c);
  case k of
    tkEof:      write('eof');
    tkPlus:     write('op +');
    tkMinus:    write('op -');
    tkStar:     write('op *');
    tkSlash:    write('op /');
    tkAssign:   write('op :=');
    tkComma:    write('op ,');
    tkSemi:     write('op ;');
    tkColon:    write('op :');
    tkPeriod:   write('op .');
    tkDotDot:   write('op ..');
    tkLParen:   write('op (');
    tkRParen:   write('op )');
    tkLBracket: write('op [');
    tkRBracket: write('op ]');
    tkCaret:    write('op ^');
    tkEq:       write('op =');
    tkNotEq:    write('op <>');
    tkLt:       write('op <');
    tkLe:       write('op <=');
    tkGt:       write('op >');
    tkGe:       write('op >=');
    tkAnd:       write('kw and');
    tkArray:     write('kw array');
    tkBegin:     write('kw begin');
    tkCase:      write('kw case');
    tkConst:     write('kw const');
    tkDiv:       write('kw div');
    tkDo:        write('kw do');
    tkDownto:    write('kw downto');
    tkElse:      write('kw else');
    tkEnd:       write('kw end');
    tkFile:      write('kw file');
    tkFor:       write('kw for');
    tkFunction:  write('kw function');
    tkGoto:      write('kw goto');
    tkIf:        write('kw if');
    tkIn:        write('kw in');
    tkLabel:     write('kw label');
    tkMod:       write('kw mod');
    tkNil:       write('kw nil');
    tkNot:       write('kw not');
    tkOf:        write('kw of');
    tkOr:        write('kw or');
    tkPacked:    write('kw packed');
    tkProcedure: write('kw procedure');
    tkProgram:   write('kw program');
    tkRecord:    write('kw record');
    tkRepeat:    write('kw repeat');
    tkSet:       write('kw set');
    tkThen:      write('kw then');
    tkTo:        write('kw to');
    tkType:      write('kw type');
    tkUntil:     write('kw until');
    tkVar:       write('kw var');
    tkWhile:     write('kw while');
    tkWith:      write('kw with');
    tkIdent, tkInt, tkReal, tkStr: write('?')
  end;
  writeln
  end
end;

{ ---------------------------------------------------------- keyword lookup }

procedure DefineKeyword(i: integer; spelling: kwLit; k: tokenKind);
begin
  kwText[i] := spelling;
  kwKind[i] := k
end;

{ The padded literals ADR-0012 predicted, and the whole of what option A
  costs: thirty-five of them, written once. }
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
    { trailing blanks are padding, so the keyword ends where they start }
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
var sl, sc: integer; done, stop: boolean;
begin
  done := false;
  while not done do begin
    while (not AtEof) and IsSpace(Peek(0)) do
      Advance;

    if Peek(0) = '{' then begin
      sl := line;
      sc := col;
      Advance;
      stop := false;
      while (not AtEof) and (Peek(0) <> '}') do
        Advance;
      if AtEof then begin
        if reporting then begin
          ErrorAt(sl, sc);
          writeln('unterminated comment')
        end;
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
        if reporting then begin
          ErrorAt(sl, sc);
          writeln('unterminated comment')
        end;
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
  if not reporting then
    if k = tkIdent then begin
      EmitPos(sl, sc);
      write('ident ');
      StrWrite(text);
      writeln
    end
    else
      EmitSimple(sl, sc, k)
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

  if isReal then begin
    if not reporting then begin
      EmitPos(sl, sc);
      write('real ');
      StrWrite(text);
      writeln
    end
  end
  else begin
    if overflow and reporting then begin
      ErrorAt(sl, sc);
      write('integer literal out of range (maxint is ', maxint:1, '): ');
      StrWrite(text);
      writeln
    end;
    if not reporting then begin
      EmitPos(sl, sc);
      { A value that does not fit is not printed: it was rejected, and
        printing whatever the conversion happened to leave behind would be
        comparing two accidents. }
      if overflow then
        writeln('int ?')
      else
        writeln('int ', value:1)
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
  if bad and reporting then begin
    ErrorAt(sl, sc);
    writeln('unterminated string literal')
  end;
  if not reporting then begin
    EmitPos(sl, sc);
    write('str [');
    StrWrite(value);
    writeln(']')
  end
end;

procedure LexOperator;
var sl, sc: integer; c: char;
begin
  sl := line;
  sc := col;
  c := Peek(0);
  Advance;
  if c = '+' then EmitSimple(sl, sc, tkPlus)
  else if c = '-' then EmitSimple(sl, sc, tkMinus)
  else if c = '*' then EmitSimple(sl, sc, tkStar)
  else if c = '/' then EmitSimple(sl, sc, tkSlash)
  else if c = ',' then EmitSimple(sl, sc, tkComma)
  else if c = ';' then EmitSimple(sl, sc, tkSemi)
  else if c = '=' then EmitSimple(sl, sc, tkEq)
  else if c = '(' then EmitSimple(sl, sc, tkLParen)
  else if c = ')' then EmitSimple(sl, sc, tkRParen)
  else if c = '[' then EmitSimple(sl, sc, tkLBracket)
  else if c = ']' then EmitSimple(sl, sc, tkRBracket)
  else if c = '^' then EmitSimple(sl, sc, tkCaret)
  else if c = ':' then begin
    if Peek(0) = '=' then begin Advance; EmitSimple(sl, sc, tkAssign) end
    else EmitSimple(sl, sc, tkColon)
  end
  else if c = '.' then begin
    if Peek(0) = '.' then begin Advance; EmitSimple(sl, sc, tkDotDot) end
    else EmitSimple(sl, sc, tkPeriod)
  end
  else if c = '<' then begin
    if Peek(0) = '=' then begin Advance; EmitSimple(sl, sc, tkLe) end
    else if Peek(0) = '>' then begin Advance; EmitSimple(sl, sc, tkNotEq) end
    else EmitSimple(sl, sc, tkLt)
  end
  else if c = '>' then begin
    if Peek(0) = '=' then begin Advance; EmitSimple(sl, sc, tkGe) end
    else EmitSimple(sl, sc, tkGt)
  end
  else begin
    if reporting then begin
      ErrorAt(sl, sc);
      writeln('unexpected character ''', c, '''')
    end
  end
end;

{ One pass over the file. Reporting and emitting are separated so that every
  diagnostic precedes every token without either being held in memory. }
procedure Scan;
var done: boolean; c: char;
begin
  StartFile;
  done := false;
  while not done do begin
    SkipTriviaAndComments;
    if AtEof then begin
      if not reporting then
        EmitSimple(line, col, tkEof);
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

begin
  InstallKeywords;
  reporting := true;
  Scan;
  reporting := false;
  Scan
end.
