{ PasToml -- a TOML document a program can read, build and write back.

  It is here for the reason `lib/dialect/pasjson.pas` is here, one format
  over: a program that reads its own configuration reads TOML, and this tree
  already had a client before it had the module -- `pascalcc` reads
  `afterschool-pascal.toml` (ADR-0348) with a hand-written reader in shell,
  which is where a strict subset of a format goes when the language it is
  driving cannot read it.

  **It is TOML v1.0.0 and not a subset**, because a configuration file is
  written by a person against the specification and not against this parser:
  bare, quoted and dotted keys; basic, literal and both multi-line strings;
  decimal, hexadecimal, octal and binary integers; floats with `inf` and
  `nan`; the four date-time forms; arrays; inline tables; tables; and arrays
  of tables. What it refuses, it refuses with a position.

  **A value is a heap node and a document is a tree**, which is `PasJson`'s
  shape and taken deliberately rather than by habit: `Free` disposes one
  and a program that forgets it leaks. An owned pointer (AP 6.4.14) would give
  the document a lifetime it could not get wrong, and would take away
  `doc.Member('server')` -- a second name for a subtree, which is the
  whole of what navigating a configuration is.

  **A string is bytes**, for `PasJson`'s reason: assignment to AP 6.4.15's
  `utf8` establishes Normalization Form C, so the bytes that came in are not
  the bytes that go out, and a program round-tripping somebody's file must not
  edit it. This module checks the TOML grammar and the `\uXXXX` and
  `\UXXXXXXXX` escapes; every other byte passes through unread. A caller who
  wants text calls `PasUnicode.ToText` and gets both behaviours where it can
  see them.

  **A date-time is the language's own `TimeStamp` and two fields beside it**,
  which is the one place this module asks another for something rather than
  writing it. 6.4.3.4's record already carries the eight numbers with six of
  them in subranges that refuse a thirteenth month at the store, and
  `PasTime.ParseStamp` already reads exactly three of TOML's four forms --
  `YYYY-MM-DD`, `hh:mm:ss` and the two joined by a `T`. What it refuses is a
  fractional second and a zone offset, and it refuses them because it has
  nowhere to put them; those two fields are what `TomlStamp` adds. So the
  calendar rules -- the 29th of February in an ordinary year -- are spelled
  once in this tree and this module does not repeat them.

  **An integer is this language's `integer`**, which is narrower than TOML's:
  the format requires a reader to handle the full range of a signed 64-bit
  number and `integer` here is -maxint..maxint (ADR-0014). A value outside it
  is `errRange` at the position it was written, never a wrapped number. The
  dialect has `int64` (ADR-0128) and `lib/dialect/README.md`'s second rule is
  why it is not in this interface: it is a boundary shape, and a document is
  not a boundary.

  **A key is a `TomlKey` and a value's string is not.** A key is a key, and a
  longer one is `errFull`; a value goes into a `TomlChars`, because a
  multi-line literal string is how a person puts a certificate or a script in
  a configuration file. }

module PasToml;

{ **What a client is given is the types, and the types carry their routines**
  (AP 6.7.10.5, ADR-0411). Thirty-one names are exported where fifty-nine
  were: `TomlChars` and `TomlPtr` each have an implementation in the block
  below, and an implementation is selected from the *type* of the receiver
  rather than from a name in scope (AP 6.7.10.2), so none of its routines is
  an exported name and none can collide with another module's -- which is what
  `PasJson` did one format over (ADR-0412), and why `TomlCharsAddLine` is
  `AddText` and `TomlIntegerOr` is `IntegerOr` here as they are there. The two
  modules are read together and now spell the same operation the same way.

  What stays exported is what has no receiver to be selected from: the types,
  the three bounds, the eight constructors, and the two entry points that
  build a document out of bytes. A parse is not an operation *of* a buffer --
  it answers a document -- so it keeps its name where `PositionOf`, which
  asks a buffer about itself, does not. }

export PasToml = (TomlKind, tkString, tkInteger, tkFloat, tkBoolean,
                  tkDateTime, tkArray, tkTable,
                  TomlDateKind, tdDate, tdTime, tdLocal, tdOffset,
                  TomlKey, TomlChars, TomlPtr, TomlStamp, TomlResult,
                  TomlKeyMax, TomlDepthMax, TomlPathMax,

                  TomlParse, TomlParseChars,

                  TomlNewText, TomlNewInteger, TomlNewFloat, TomlNewBoolean,
                  TomlNewStamp, TomlNewArray, TomlNewTableArray, TomlNewTable);

import PasError; PasContainer; PasText; PasTime;

const
  { A key is a key. `errFull` rather than a silent truncation past this, which
    is `PasJson`'s rule for a member name and this library's rule everywhere a
    bound is met (ADR-0276). }
  TomlKeyMax = 255;

  { Segments in one dotted key, and therefore the depth of table this module
    will build from a header. TOML bounds neither; a document reaching sixteen
    is a document nobody has to read, and `errFull` says so at the key. }
  TomlPathMax = 16;

  { Nesting of arrays and inline tables, so that a hostile document cannot
    exhaust the stack -- the parser is recursive descent and this is the
    compiler's own answer (ADR-0020) at a depth a configuration will not
    reach. }
  TomlDepthMax = 100;

type
  { TOML v1.0.0's value types, with its four date-time forms folded into one
    kind and told apart by `TomlDateKind`. A `case` over this covers a
    document.

    There is no null: TOML has none, and a key that is not there is what
    `Member` answers nil for. That is the one place this differs from
    `PasJson` in a way a reader porting between them will notice. }
  TomlKind = (tkString, tkInteger, tkFloat, tkBoolean, tkDateTime,
              tkArray, tkTable);

  { Which of the four date-time forms was written. The distinction is the
    document's and not an implementation detail: an offset date-time names an
    instant, a local one names a wall clock somewhere unstated, and a program
    that treats the second as the first has moved it by an unknown number of
    hours. }
  TomlDateKind = (tdDate,    { YYYY-MM-DD }
                  tdTime,    { hh:mm:ss, with an optional fraction }
                  tdLocal,   { the two joined by a T or a space }
                  tdOffset); { the same, and Z or +hh:mm }

  TomlKey = string(TomlKeyMax);

  { PasContainer's vector over `char`, which is what makes a string value
    unbounded. A caller never names `Vec` and never imports PasContainer: the
    eight routines below are the whole of what it needs. It is the same type
    `PasJson` calls `JsonChars` -- 6.4.7 interns a schema production per
    tuple -- so a program holding both may pass one where the other is asked
    for, which is a consequence of the language and not a promise made here. }
  TomlChars = ^Vec(char);

  { 6.4.3.4's record, and the two things TOML has that it has not.

    `clock.DateValid` and `clock.TimeValid` say which halves were written, so
    a `tdDate` carries a date and midnight with `TimeValid` false, exactly as
    `PasTime.ParseStamp` fills one.

    `nanosecond` is the fractional second, 0 when none was written. TOML
    permits any number of digits and allows a reader to truncate; this keeps
    nine and drops the rest, which is the precision the field is named for.

    `offset` is minutes east of UTC and is read only for `tdOffset`. `Z` is 0,
    and `-00:00` -- which RFC 3339 gives a meaning TOML does not repeat -- is
    read as 0 like any other zero offset. `PasTime.Shift` is what a caller
    hands it to. }
  TomlStamp = record
    form: TomlDateKind;
    clock: TimeStamp;
    nanosecond: integer;
    offset: integer
  end;

  TomlPtr = ^TomlNode;
  TomlNode = record
    { The next entry of a table or element of an array. A document is a tree
      of these and nothing here is shared, so `Free` is a walk. }
    next: TomlPtr;
    { The key, for an entry of a table; empty otherwise, and never read for
      anything else. In the fixed part because it belongs to the *containment*
      and not to the value. }
    key: TomlKey;
    case kind: TomlKind of
      tkString:   (text: TomlChars);
      tkInteger:  (inum: integer);
      tkFloat:    (fnum: real);
      tkBoolean:  (bool: boolean);
      tkDateTime: (when: TomlStamp);
      { Four booleans are what TOML's redefinition rules are decided by, and
        they are in the node because those rules are about *how* a table came
        to exist rather than about what is in it. The format's own sentence is
        that nothing may be defined twice, and the work is in what counts as
        defining: `[a.b]` creates `a` implicitly and `[a]` afterwards is
        legal, while `a.b = 1` creates `a` too and `[a]` afterwards is not.

        `explicit` -- a `[header]` defined this table, or it is an inline
        table. A second header on it is an error, and a dotted key may not
        descend into it.
        `closed` -- an inline table, or a table inside a value array. Nothing
        may reach into it at all.
        `dotted` -- created as an intermediate of a dotted key. Another
        dotted key may extend it; a header may not define it.
        `tabArray` -- an array that `[[header]]` blocks append to, as
        against one written as a value.

        Nothing but the parser writes the first three. `tabArray` is the one a
        caller can read, through `IsTableArray`, because it is the one the
        renderer's output depends on. }
      tkArray, tkTable: (first, last: TomlPtr; count: integer;
                         explicit: boolean;
                         closed: boolean;
                         dotted: boolean;
                         tabArray: boolean)
  end;

  { ADR-0120's shape, and AP 6.4.13 since ADR-0176; a production of
    `PasError.Fallible` since ADR-0297, so `ValueOr` takes it.

    `errSyntax` for a document that is not one -- which includes every
    redefinition TOML forbids, those being errors of the format and not of the
    world. `errRange` for a number, a date or a time that is well-formed and
    cannot be represented. `errFull` for a key longer than `TomlKeyMax`, a
    dotted key deeper than `TomlPathMax`, or nesting past `TomlDepthMax`. }
  TomlResult = Fallible(TomlPtr);

{ --- parsing -------------------------------------------------------------- }

{ Parse a whole document. The value of a successful result is always a table,
  possibly empty, and the caller must free it with `Free`.

  `at` receives the 1-based byte position parsing stopped at, which is where a
  caller reports from; on success it is one past the last byte. A
  configuration file's reader wants a line rather than an offset, and
  `TomlChars.PositionOf` is that conversion. }
function TomlParseChars(var b: TomlChars; var at: integer) = r: TomlResult;

{ The same, for a document that fits in one string -- of whatever capacity the
  caller declared. }
function TomlParse(s: string; var at: integer) = r: TomlResult;

{ --- building ------------------------------------------------------------- }

function TomlNewText(s: string): TomlPtr;
function TomlNewInteger(n: integer): TomlPtr;
function TomlNewFloat(x: real): TomlPtr;
function TomlNewBoolean(b: boolean): TomlPtr;
function TomlNewStamp(t: TomlStamp): TomlPtr;

{ An array written as a value: `xs = [1, 2, 3]`. }
function TomlNewArray: TomlPtr;

{ An array written as `[[header]]` blocks. Its elements should be tables; the
  renderer writes any that is not as an ordinary element of a value array,
  because there is no way to write one as a header. }
function TomlNewTableArray: TomlPtr;

function TomlNewTable: TomlPtr;

end;

{ --- reading a number ------------------------------------------------------ }

const
  { The significant digits a float is read from, and the reasoning is
    ADR-0314's: seventeen identify a double, so what is dropped past this can
    only matter where the value sits within 10^-23 of a halfway point.
    Keeping every digit a document may write would need a string with no
    capacity, and this language has none. }
  SigMax = 40;

  { A run of quotes longer than this ends nothing: TOML admits three, four or
    five at the end of a multi-line string, the extra one or two being
    content. }
  QuoteRunMax = 5;

type
  TomlSig = string(SigMax);
  { The significand, an `E`, and a decimal exponent. The scan bounds the
    exponent at five digits and the significand can shift it by `SigMax`
    more, so seven characters would hold it; fifteen is a margin, because
    overflowing a string capacity in a library is a trap rather than a wrong
    answer. }
  TomlNumText = string(SigMax + 16);

  { A dotted key, held while the segments are read and before the tables they
    name are walked. `TomlPathMax` segments, and `errFull` past it. }
  TomlKeyPath = array [1..TomlPathMax] of TomlKey;

{ --- the byte buffer ------------------------------------------------------ }

impl TomlChars;

  { An empty buffer. Every `TomlChars` a caller holds comes from here or from
    a routine that says it answers one. }
  procedure Init(var b: TomlChars);
  begin
    VecInit(TomlChars, b, 64)
  end;

  { Release it and leave `b` nil. A nil `b` is harmless. }
  procedure Free(var b: TomlChars);
  begin
    VecFree(TomlChars, b)
  end;

  { Append one byte. }
  procedure Add(var b: TomlChars; c: char);
  begin
    VecPush(TomlChars, b, c)
  end;

  { Append a whole string, which is how a caller assembles a document to
    parse a line at a time. Schematic, so a caller holding a longer capacity
    than any this module names is not refused at this boundary (ADR-0291). }
  procedure AddText(var b: TomlChars; s: string);
  var i: integer;
  begin
    for i := 1 to length(s) do
      VecPush(TomlChars, b, s[i])
  end;

  function Len(var b: TomlChars): integer;
  begin
    Len := VecLen(TomlChars, b)
  end;

  { Has this buffer reached the largest extent it can have, so that the next
    character would be dropped? A caller assembling someone else's bytes asks
    this and reports `errFull` (ADR-0276). }
  function Full(var b: TomlChars): boolean;
  begin
    Full := VecFull(TomlChars, b)
  end;

  { The i'th byte, 1-based. Out of range is the caller's error and traps, as
    an array subscript does. }
  function At(var b: TomlChars; i: integer): char;
  begin
    At := VecGet(char, b, i)
  end;

  { Copy the whole buffer into a string. `errFull` when it does not fit, and
    `s` is then untouched. }
  function Into(var b: TomlChars; var s: string): ErrorCode;
  var i, n: integer;
  begin
    n := VecLen(TomlChars, b);
    if n > s.capacity then
      Into := errFull
    else begin
      { Built into `s` and not through a local accumulator, for the reason
        `PasJson`'s `JsonChars.Into` records: an accumulator of this module's own
        capacity would make the guard above a lie about the caller's. }
      s := '';
      for i := 1 to n do
        s := s + VecGet(char, b, i);
      Into := errNone
    end
  end;

  { The line and column of a byte position, both 1-based, counting a `<LF>`
    as the end of a line and treating a `<CR>` as an ordinary byte of the line
    it sits in. A position past the end answers the position of the end.

    It is a routine rather than a field of the result because a caller that
    never fails never pays for it, and because a caller reporting a *warning*
    about a value it read wants the same conversion for a position the parser
    did not stop at. }
  procedure PositionOf(var b: TomlChars; at: integer;
                       var line, column: integer);
  var k, n, last: integer;
  begin
    n := VecLen(TomlChars, b);
    if at > n + 1 then at := n + 1;
    if at < 1 then at := 1;
    line := 1;
    last := 0;
    for k := 1 to at - 1 do
      if VecGet(char, b, k) = chr(10) then begin
        line := line + 1;
        last := k
      end;
    column := at - last
  end;

end;

{ --- the scanner ---------------------------------------------------------- }

function AtEnd(var b: TomlChars; i: integer): boolean;
begin
  AtEnd := i > VecLen(TomlChars, b)
end;

{ The byte at `i`, or chr(0) past the end. A document may not contain chr(0)
  anywhere this module looks at one -- TOML forbids a control character
  unescaped in a string, in a comment and in a bare key -- so the sentinel
  cannot be mistaken for content. }
function Peek(var b: TomlChars; i: integer): char;
begin
  if AtEnd(b, i) then Peek := chr(0) else Peek := VecGet(char, b, i)
end;

function Digit(c: char): boolean;
begin
  Digit := (c >= '0') and (c <= '9')
end;

function HexDigit(c: char): boolean;
begin
  HexDigit := Digit(c) or ((c >= 'a') and (c <= 'f'))
            or ((c >= 'A') and (c <= 'F'))
end;

{ The value of a hexadecimal digit, and `ok` false for anything else. }
function HexVal(c: char; var ok: boolean): integer;
begin
  if Digit(c) then HexVal := ord(c) - ord('0')
  else if (c >= 'a') and (c <= 'f') then HexVal := 10 + ord(c) - ord('a')
  else if (c >= 'A') and (c <= 'F') then HexVal := 10 + ord(c) - ord('A')
  else begin
    ok := false;
    HexVal := 0
  end
end;

{ TOML's bare key: an ASCII letter, a digit, an underscore or a hyphen. }
function BareChar(c: char): boolean;
begin
  BareChar := Digit(c) or ((c >= 'a') and (c <= 'z'))
            or ((c >= 'A') and (c <= 'Z')) or (c = '_') or (c = '-')
end;

{ A control character TOML forbids outside an escape: everything below a space
  except the tab, and the delete. }
function Control(c: char): boolean;
begin
  Control := ((ord(c) < 32) and (c <> chr(9))) or (ord(c) = 127)
end;

{ Spaces and tabs, which is all TOML calls whitespace. A newline is a
  terminator here and never skipped by accident. }
procedure SkipBlank(var b: TomlChars; var i: integer);
begin
  while (Peek(b, i) = ' ') or (Peek(b, i) = chr(9)) do
    i := i + 1
end;

{ A comment, from the `#` to the byte before the newline. False for a control
  character inside one, which TOML forbids and which is how a file that is not
  text at all announces itself on its first line. }
function SkipComment(var b: TomlChars; var i: integer): boolean;
var ok: boolean;
begin
  ok := true;
  if Peek(b, i) = '#' then begin
    i := i + 1;
    while ok and not AtEnd(b, i) and (Peek(b, i) <> chr(10)) do
      if Control(Peek(b, i)) and (Peek(b, i) <> chr(13)) then ok := false
      else i := i + 1
  end;
  SkipComment := ok
end;

{ Consume a newline, in either spelling. False when there is not one. }
function SkipNewline(var b: TomlChars; var i: integer): boolean;
begin
  if (Peek(b, i) = chr(13)) and (Peek(b, i + 1) = chr(10)) then begin
    i := i + 2;
    SkipNewline := true
  end
  else if Peek(b, i) = chr(10) then begin
    i := i + 1;
    SkipNewline := true
  end
  else
    SkipNewline := false
end;

{ What must follow the last token of a line: blanks, an optional comment, and
  then a newline or the end of the document. False for anything else, which is
  the check that refuses two key-value pairs on one line. }
function EndOfLine(var b: TomlChars; var i: integer): boolean;
var ok: boolean;
begin
  SkipBlank(b, i);
  ok := SkipComment(b, i);
  if ok then
    ok := AtEnd(b, i) or SkipNewline(b, i);
  EndOfLine := ok
end;

{ Blanks, comments and newlines between one statement and the next. False for
  a control character in a comment, which is the only way this can fail. }
function SkipBlankLines(var b: TomlChars; var i: integer): boolean;
var ok, going: boolean;
begin
  ok := true;
  going := true;
  while ok and going do begin
    SkipBlank(b, i);
    ok := SkipComment(b, i);
    if ok then going := SkipNewline(b, i)
  end;
  SkipBlankLines := ok
end;
{ --- nodes ---------------------------------------------------------------- }

{ A fresh node of one kind, with the fields of that kind emptied. The tag is
  assigned before any field is, which is what AP 6.4.11's authoritative tag
  asks of a producer: a field written first would activate a variant this did
  not mean. }
function FreshNode(k: TomlKind): TomlPtr;
var p: TomlPtr;
begin
  new(p);
  p^.kind := k;
  p^.next := nil;
  p^.key := '';
  case k of
    tkString:   p^.text.Init;
    tkInteger:  p^.inum := 0;
    tkFloat:    p^.fnum := 0.0;
    tkBoolean:  p^.bool := false;
    tkDateTime: begin
                  p^.when.form := tdDate;
                  p^.when.clock.DateValid := false;
                  p^.when.clock.TimeValid := false;
                  p^.when.clock.year := 1;
                  p^.when.clock.month := 1;
                  p^.when.clock.day := 1;
                  p^.when.clock.hour := 0;
                  p^.when.clock.minute := 0;
                  p^.when.clock.second := 0;
                  p^.when.nanosecond := 0;
                  p^.when.offset := 0
                end;
    tkArray, tkTable: begin
                  p^.first := nil;
                  p^.last := nil;
                  p^.count := 0;
                  p^.explicit := false;
                  p^.closed := false;
                  p^.dotted := false;
                  p^.tabArray := false
                end
  end;
  FreshNode := p
end;

{ --- tables --------------------------------------------------------------- }

{ The entry of `tab` with this key, or nil. The lookup a table does for
  itself: linear, because a table in a configuration file has a handful of
  keys and a map would be a hash of a string per lookup to save nothing. }
function Lookup(tab: TomlPtr; key: TomlKey): TomlPtr;
var c: TomlPtr;
begin
  Lookup := nil;
  c := tab^.first;
  while c <> nil do begin
    if c^.key = key then begin
      Lookup := c;
      c := nil
    end
    else
      c := c^.next
  end
end;

{ Append an entry, which is `Put` without the replacement: everything in
  this module has already established that the key is not there, because
  TOML's answer to a key that is there is a refusal and not a replacement. }
procedure Attach(tab: TomlPtr; key: TomlKey; item: TomlPtr);
begin
  item^.key := key;
  item^.next := nil;
  if tab^.first = nil then tab^.first := item else tab^.last^.next := item;
  tab^.last := item;
  tab^.count := tab^.count + 1
end;
{ --- writing -------------------------------------------------------------- }

type
  { A header's path, assembled as the walk descends. Sixteen segments of up to
    255 bytes would need four thousand; what a document actually writes is a
    handful of short words, and `errFull` has nowhere to be reported from
    inside a procedure that answers nothing -- so this is generous rather than
    exact, and a path past it is truncated by the string assignment's own
    trap. }
  TomlPathText = string(1024);

{ `n` in decimal, padded with zeros to `w` digits. TOML's date-time spelling
  is RFC 3339's, so it is written out here rather than taken from `date(t)`
  and `time(t)`: those are *this processor's* representations (§6.7.6.9 makes
  them implementation-defined), and a format's spelling must not move with the
  processor that writes it. }
function Pad(n, w: integer): TomlKey;
var s: TomlKey;
begin
  writestr(s, n:1);
  while length(s) < w do s := '0' + s;
  Pad := s
end;

{ A key, bare where the format admits one and a basic string otherwise. An
  empty key is a quoted empty string, which TOML admits and which nothing but
  a program building a document will produce. }
procedure RenderKey(key: TomlKey; var out: TomlChars);
var k: integer; bare: boolean;
begin
  bare := length(key) > 0;
  for k := 1 to length(key) do
    if not BareChar(key[k]) then bare := false;
  if bare then
    out.AddText(key)
  else begin
    out.Add('"');
    for k := 1 to length(key) do
      if (key[k] = '"') or (key[k] = '\') then begin
        out.Add('\');
        out.Add(key[k])
      end
      else
        out.Add(key[k]);
    out.Add('"')
  end
end;

{ A string value as a basic string. The escapes are the ones the format
  requires -- the quotation mark, the reverse solidus and every control
  character -- and no others: a byte above 127 is part of a UTF-8 sequence
  this module was handed and passes through unread, which is the decision the
  heading records. }
procedure RenderText(var t: TomlChars; var out: TomlChars);
var k, n, c: integer; ch: char;

  function HexCh(d: integer): char;
  begin
    if d < 10 then HexCh := chr(ord('0') + d) else HexCh := chr(ord('A') + d - 10)
  end;

begin
  out.Add('"');
  n := t.Len;
  for k := 1 to n do begin
    ch := t.At(k);
    c := ord(ch);
    if ch = '"' then out.AddText('\"')
    else if ch = '\' then out.AddText('\\')
    else if c = 8 then out.AddText('\b')
    else if c = 9 then out.AddText('\t')
    else if c = 10 then out.AddText('\n')
    else if c = 12 then out.AddText('\f')
    else if c = 13 then out.AddText('\r')
    else if (c < 32) or (c = 127) then begin
      out.AddText('\u00');
      out.Add(HexCh(c div 16));
      out.Add(HexCh(c mod 16))
    end
    else
      out.Add(ch)
  end;
  out.Add('"')
end;

{ A float. TOML has `inf`, `-inf` and `nan`, so unlike `PasJson` this module
  has a spelling for every value the type holds and none of them is what
  `writestr` writes.

  A finite one is the shortest decimal that reads back (`PasText.RealToStr`,
  ADR-0309) and then, if that has neither a point nor an exponent, a `.0`:
  TOML's float must show one or the other, so the shortest spelling of 1.0 is
  `1` for JSON and `1.0` here. }
procedure RenderFloat(x: real; var out: TomlChars);
var s: TextLine; k: integer; plain: boolean;
begin
  if not (x = x) then
    out.AddText('nan')
  else if x > maxreal then
    out.AddText('inf')
  else if x < -maxreal then
    out.AddText('-inf')
  else begin
    s := RealToStr(x);
    plain := true;
    for k := 1 to length(s) do
      if (s[k] = '.') or (s[k] = 'E') or (s[k] = 'e') then plain := false;
    if plain then s := s + '.0';
    out.AddText(s)
  end
end;

procedure RenderStamp(t: TomlStamp; var out: TomlChars);
var frac: TomlKey; k: integer;
begin
  if (t.form = tdDate) or (t.form = tdLocal) or (t.form = tdOffset) then begin
    out.AddText(Pad(t.clock.year, 4));
    out.Add('-');
    out.AddText(Pad(t.clock.month, 2));
    out.Add('-');
    out.AddText(Pad(t.clock.day, 2))
  end;
  if t.form = tdDate then
    { nothing further }
  else begin
    if t.form <> tdTime then out.Add('T');
    out.AddText(Pad(t.clock.hour, 2));
    out.Add(':');
    out.AddText(Pad(t.clock.minute, 2));
    out.Add(':');
    out.AddText(Pad(t.clock.second, 2));
    if t.nanosecond > 0 then begin
      { Nine digits with the trailing zeros taken off, so a half second is
        `.5` and not `.500000000`. }
      frac := Pad(t.nanosecond, 9);
      k := length(frac);
      while (k > 1) and (frac[k] = '0') do k := k - 1;
      out.Add('.');
      out.AddText(substr(frac, 1, k))
    end;
    if t.form = tdOffset then
      if t.offset = 0 then
        out.Add('Z')
      else begin
        if t.offset < 0 then out.Add('-') else out.Add('+');
        out.AddText(Pad(abs(t.offset) div 60, 2));
        out.Add(':');
        out.AddText(Pad(abs(t.offset) mod 60, 2))
      end
  end
end;

{ Whether every element of an array is a table, which is what an array of
  tables must be for `[[header]]` blocks to be able to spell it. }
function AllTables(arr: TomlPtr): boolean;
var c: TomlPtr; all: boolean;
begin
  all := arr^.count > 0;
  c := arr^.first;
  while c <> nil do begin
    if c^.kind <> tkTable then all := false;
    c := c^.next
  end;
  AllTables := all
end;

{ Whether this entry of a table becomes a header of its own rather than a
  value on the line after its key. }
function IsHeaderEntry(c: TomlPtr): boolean;
begin
  IsHeaderEntry := ((c^.kind = tkTable) and not c^.closed)
                   or ((c^.kind = tkArray) and c^.tabArray and AllTables(c))
end;

procedure RenderValue(v: TomlPtr; var out: TomlChars); forward;

{ A table written as a value -- an inline table, in braces, with its pairs
  separated by commas. Everything under it is a value too, there being no
  header form inside one.

  What this comment does not do is show one, and that is not fastidiousness:
  §6.1.8 makes the four comment delimiters two pairs in any combination, so a
  brace inside a brace comment closes it, and a routine's leading comment
  holding an example of the syntax it renders would end at the example.
  `tests/dialect/lib_toml.pas` is where one is written out. }
procedure RenderInline(v: TomlPtr; var out: TomlChars);
var c: TomlPtr;
begin
  out.AddText('{ ');
  c := v^.first;
  while c <> nil do begin
    RenderKey(c^.key, out);
    out.AddText(' = ');
    RenderValue(c, out);
    c := c^.next;
    if c <> nil then out.AddText(', ')
  end;
  out.AddText(' }')
end;

procedure RenderValue;
var c: TomlPtr; s: TextLine;
begin
  case v^.kind of
    tkString:   RenderText(v^.text, out);
    tkInteger:  begin
                  s := IntToStr(v^.inum);
                  out.AddText(s)
                end;
    tkFloat:    RenderFloat(v^.fnum, out);
    tkBoolean:  if v^.bool then out.AddText('true')
                else out.AddText('false');
    tkDateTime: RenderStamp(v^.when, out);
    tkTable:    RenderInline(v, out);
    tkArray:    begin
                  out.Add('[');
                  c := v^.first;
                  while c <> nil do begin
                    RenderValue(c, out);
                    c := c^.next;
                    if c <> nil then out.AddText(', ')
                  end;
                  out.Add(']')
                end
  end
end;

{ A table's own `key = value` lines, and then its sub-tables as headers of
  their own. The order is the format's requirement and not a preference: after
  a `[header]` every bare key belongs to that table, so a value written after
  a sub-table's header would join the sub-table. }
procedure RenderBody(v: TomlPtr; path: TomlPathText; var out: TomlChars);
var c, el: TomlPtr; sub: TomlPathText;

  { The path of an entry, as the header line spells it. Assembled through a
    buffer because `RenderKey` decides whether the segment is bare. }
  function Extend(base: TomlPathText; entry: TomlPtr): TomlPathText;
  var kb: TomlChars; t: TextLine; e2: ErrorCode;
  begin
    kb.Init;
    RenderKey(entry^.key, kb);
    e2 := kb.Into(t);
    kb.Free;
    if length(base) = 0 then Extend := t else Extend := base + '.' + t
  end;

begin
  c := v^.first;
  while c <> nil do begin
    if not IsHeaderEntry(c) then begin
      RenderKey(c^.key, out);
      out.AddText(' = ');
      RenderValue(c, out);
      out.Add(chr(10))
    end;
    c := c^.next
  end;
  c := v^.first;
  while c <> nil do begin
    if IsHeaderEntry(c) then begin
      sub := Extend(path, c);
      if c^.kind = tkTable then begin
        out.Add(chr(10));
        out.Add('[');
        out.AddText(sub);
        out.AddText(']');
        out.Add(chr(10));
        RenderBody(c, sub, out)
      end
      else begin
        el := c^.first;
        while el <> nil do begin
          out.Add(chr(10));
          out.AddText('[[');
          out.AddText(sub);
          out.AddText(']]');
          out.Add(chr(10));
          RenderBody(el, sub, out);
          el := el^.next
        end
      end
    end;
    c := c^.next
  end
end;

impl TomlPtr;

  { Dispose a value and everything under it, and leave `v` nil. }
  procedure Free(var v: TomlPtr);
  var c, n: TomlPtr;
  begin
    if v <> nil then begin
      case v^.kind of
        tkString: v^.text.Free;
        tkInteger, tkFloat, tkBoolean, tkDateTime: ;
        tkArray, tkTable: begin
          { Iterative over the siblings and recursive into them, so a table of
            ten thousand entries costs one frame and a document nested a
            hundred deep costs a hundred -- which `TomlDepthMax` is what bounds.
            A tree the parser built cannot be deeper than that; one a program
            built with `Put` can, and that is the program's own recursion to
            answer for. }
          c := v^.first;
          while c <> nil do begin
            n := c^.next;
            c.Free;
            c := n
          end
        end
      end;
      dispose(v);
      v := nil
    end
  end;

  { The kind of a value. `tkTable` for nil, so that every reader below is
    safe to call on a key that was not there -- an absent key reads as an empty
    table, which is what a configuration reader wants:
    `doc.Path('server.tls.verify')` answers nil rather than trapping when there
    is no `server`. }
  function Kind(v: TomlPtr): TomlKind;
  begin
    { An absent key reads as an empty table, which is what makes every reader
      below safe to call on one -- `doc.Path('server.tls.verify')` answers
      nil where there is no `server`, and the caller's `BooleanOr` of nil is
      its default rather than a trap. }
    if v = nil then Kind := tkTable else Kind := v^.kind
  end;

  { How many entries a table has, or elements an array; 0 for anything
    else. }
  function Count(v: TomlPtr): integer;
  begin
    if (v <> nil) and ((v^.kind = tkArray) or (v^.kind = tkTable)) then
      Count := v^.count
    else
      Count := 0
  end;

  { The i'th entry or element, 1-based, or nil. }
  function At(v: TomlPtr; i: integer): TomlPtr;
  var c: TomlPtr; k: integer;
  begin
    At := nil;
    if (v <> nil) and ((v^.kind = tkArray) or (v^.kind = tkTable))
       and (i >= 1) and (i <= v^.count) then begin
      c := v^.first;
      for k := 2 to i do c := c^.next;
      At := c
    end
  end;

  { The key of the i'th entry of a table, or the empty string. }
  function KeyAt(v: TomlPtr; i: integer): TomlKey;
  var c: TomlPtr;
  begin
    c := v.At(i);
    if c = nil then KeyAt := '' else KeyAt := c^.key
  end;

  { The entry of a table with this key, or nil. One segment: a key
    containing a dot is reached with this and not with `Path`. }
  function Member(v: TomlPtr; key: TomlKey): TomlPtr;
  begin
    if (v <> nil) and (v^.kind = tkTable) then Member := Lookup(v, key)
    else Member := nil
  end;

  { The value at a dotted path -- `doc.Path('server.port')` -- or nil.

    The dots are separators here, so a *key* that contains one cannot be reached
    this way; that key is reached by `Member` a segment at a time. It is worth
    knowing which of the two a program needs, because a document written by a
    person almost never has a dot in a key and a document written by a program
    sometimes does. An empty path answers `v` itself. }
  function Path(v: TomlPtr; dotted: string): TomlPtr;
  var cur: TomlPtr; seg: TomlKey; k: integer;
  begin
    cur := v;
    seg := '';
    k := 1;
    while (cur <> nil) and (k <= length(dotted) + 1) do begin
      if (k > length(dotted)) or (dotted[k] = '.') then begin
        if seg = '' then cur := nil else cur := cur.Member(seg);
        seg := ''
      end
      else
        seg := seg + dotted[k];
      k := k + 1
    end;
    if length(dotted) = 0 then Path := v else Path := cur
  end;

  { Whether this array is one the document wrote as `[[header]]` blocks
    rather than as a value. Both are arrays and both are read the same way; the
    difference is only what `Render` writes, and a caller building a document
    chooses it with `TomlNewTableArray`. }
  function IsTableArray(v: TomlPtr): boolean;
  begin
    IsTableArray := (v <> nil) and (v^.kind = tkArray) and v^.tabArray
  end;

  { The value as an integer, or `whenBad` for anything that is not one --
    including a float, since 1.5 is not an integer and answering 1 would be a
    different configuration. }
  function IntegerOr(v: TomlPtr; whenBad: integer): integer;
  begin
    if (v <> nil) and (v^.kind = tkInteger) then IntegerOr := v^.inum
    else IntegerOr := whenBad
  end;

  { The value as a real. An *integer* answers as one, because a program
    asking for a float means a number, and a person who writes `timeout = 30`
    where the documentation said `30.0` has not made a mistake worth
    reporting. }
  function FloatOr(v: TomlPtr; whenBad: real): real;
  begin
    if v = nil then FloatOr := whenBad
    else if v^.kind = tkFloat then FloatOr := v^.fnum
    { An integer answers as a real: a person who wrote `timeout = 30` where the
      documentation said `30.0` has not made a mistake worth reporting, and TOML
      keeps the two types apart for what is *written* rather than for what may
      be read. `IntegerOr` is the reader that does not do this, and a
      caller needing the distinction asks `Kind`. }
    else if v^.kind = tkInteger then FloatOr := v^.inum
    else FloatOr := whenBad
  end;

  function BooleanOr(v: TomlPtr; whenBad: boolean): boolean;
  begin
    if (v <> nil) and (v^.kind = tkBoolean) then BooleanOr := v^.bool
    else BooleanOr := whenBad
  end;

  { The value as a date-time, or `whenBad`. The `form` field of the answer
    is what says which of the four was written, and a caller that needs an
    instant must check it -- see `TomlDateKind`. }
  function StampOr(v: TomlPtr; whenBad: TomlStamp): TomlStamp;
  begin
    if (v <> nil) and (v^.kind = tkDateTime) then StampOr := v^.when
    else StampOr := whenBad
  end;

  { The length of a string value in bytes; 0 for anything else. }
  function TextLen(v: TomlPtr): integer;
  begin
    if (v <> nil) and (v^.kind = tkString) then TextLen := v^.text.Len
    else TextLen := 0
  end;

  { The i'th byte of a string value, 1-based. }
  function TextAt(v: TomlPtr; i: integer): char;
  begin
    TextAt := v^.text.At(i)
  end;

  { A string value copied into `s`. `errAbsent` when the value is not a
    string, `errFull` when it does not fit. }
  function TextInto(v: TomlPtr; var s: string): ErrorCode;
  begin
    if (v = nil) or (v^.kind <> tkString) then TextInto := errAbsent
    else TextInto := v^.text.Into(s)
  end;

  { Append `item` to an array. The array takes ownership: freeing it frees
    the item, and a caller must not free the item itself. }
  procedure Append(arr: TomlPtr; item: TomlPtr);
  begin
    if (arr <> nil) and (arr^.kind = tkArray) and (item <> nil) then begin
      item^.next := nil;
      if arr^.first = nil then arr^.first := item else arr^.last^.next := item;
      arr^.last := item;
      arr^.count := arr^.count + 1
    end
  end;

  { Put `item` in a table under `key`, replacing an entry of that key. Takes
    ownership, as `Append` does.

    One segment, and deliberately: a dotted key is ambiguous about which of the
    tables on the way is being created, and a program building a document knows
    which it means. `t.Put('a', TomlNewTable)` and then putting into that is the
    unambiguous spelling. }
  procedure Put(tab: TomlPtr; key: TomlKey; item: TomlPtr);
  var old, prev: TomlPtr;
  begin
    if (tab <> nil) and (tab^.kind = tkTable) and (item <> nil) then begin
      old := Lookup(tab, key);
      if old = nil then
        Attach(tab, key, item)
      else begin
        { Replaced in place, so that a program building a document keeps the
          order it wrote the keys in -- which is the order the renderer emits
          and therefore the order a person reads. }
        item^.key := key;
        item^.next := old^.next;
        if tab^.first = old then tab^.first := item
        else begin
          prev := tab^.first;
          while prev^.next <> old do prev := prev^.next;
          prev^.next := item
        end;
        if tab^.last = old then tab^.last := item;
        old^.next := nil;
        old.Free
      end
    end
  end;

  { Append to a string value, which is how a caller builds one longer than
    any capacity it can declare. }
  procedure TextAdd(v: TomlPtr; s: string);
  begin
    if (v <> nil) and (v^.kind = tkString) then v^.text.AddText(s)
  end;

  { Append the document's text to `out`, as a TOML document a person can
    read and this module can read back.

    A table's own values come before its sub-tables, which TOML requires: after
    a `[header]` every bare key belongs to that table. A sub-table becomes a
    `[header]` of its own, an array made by `TomlNewTableArray` becomes a run of
    `[[header]]` blocks, and everything else -- an array of values, a table
    inside an array -- is written inline, because there is no header form for
    it.

    What it does not do is preserve the document it was given. Comments are not
    in the tree, key order inside a table is the order the tree holds, and a
    string comes back as a basic string however it was written. A program that
    must edit somebody's file in place is editing bytes and not a tree, and this
    is the wrong tool for it -- the same sentence `PasJson` writes about
    whitespace. }
  procedure Render(v: TomlPtr; var out: TomlChars);
  begin
    if v = nil then
      { Nothing at all, which is a document: an empty TOML file is an empty
        table. }
    else if v^.kind = tkTable then
      RenderBody(v, '', out)
    else
      RenderValue(v, out)
  end;

end;

{ --- building ------------------------------------------------------------- }

function TomlNewText;
var p: TomlPtr;
begin
  p := FreshNode(tkString);
  p^.text.AddText(s);
  TomlNewText := p
end;

function TomlNewInteger;
var p: TomlPtr;
begin
  p := FreshNode(tkInteger);
  p^.inum := n;
  TomlNewInteger := p
end;

function TomlNewFloat;
var p: TomlPtr;
begin
  p := FreshNode(tkFloat);
  p^.fnum := x;
  TomlNewFloat := p
end;

function TomlNewBoolean;
var p: TomlPtr;
begin
  p := FreshNode(tkBoolean);
  p^.bool := b;
  TomlNewBoolean := p
end;

function TomlNewStamp;
var p: TomlPtr;
begin
  p := FreshNode(tkDateTime);
  p^.when := t;
  TomlNewStamp := p
end;

function TomlNewArray;
var p: TomlPtr;
begin
  p := FreshNode(tkArray);
  p^.closed := true;
  TomlNewArray := p
end;

function TomlNewTableArray;
var p: TomlPtr;
begin
  p := FreshNode(tkArray);
  p^.tabArray := true;
  TomlNewTableArray := p
end;

function TomlNewTable;
var p: TomlPtr;
begin
  p := FreshNode(tkTable);
  p^.explicit := true;
  TomlNewTable := p
end;

{ --- strings -------------------------------------------------------------- }

{ A code point as UTF-8. This is the one place this module writes bytes it was
  not given, an escape being the only thing in TOML that names a character
  rather than carrying one. }
procedure PushUtf8(var t: TomlChars; cp: integer);
begin
  if cp < 128 then
    t.Add(chr(cp))
  else if cp < 2048 then begin
    t.Add(chr(192 + cp div 64));
    t.Add(chr(128 + cp mod 64))
  end
  else if cp < 65536 then begin
    t.Add(chr(224 + cp div 4096));
    t.Add(chr(128 + (cp div 64) mod 64));
    t.Add(chr(128 + cp mod 64))
  end
  else begin
    t.Add(chr(240 + cp div 262144));
    t.Add(chr(128 + (cp div 4096) mod 64));
    t.Add(chr(128 + (cp div 64) mod 64));
    t.Add(chr(128 + cp mod 64))
  end
end;

{ `n` hexadecimal digits as a number, with `i` left after them. }
function HexRun(var b: TomlChars; var i: integer; n: integer;
                var ok: boolean): integer;
var k, acc: integer;
begin
  acc := 0;
  for k := 1 to n do begin
    acc := acc * 16 + HexVal(Peek(b, i), ok);
    i := i + 1
  end;
  HexRun := acc
end;

{ An escape sequence, `i` at the reverse solidus.

  The line-ending backslash is the one that is not a character: inside a
  multi-line basic string it removes itself, the rest of the line, the newline
  and every blank line and leading blank after it, which is how a document
  writes one long line as several. It is refused in a single-line string,
  where there is no line to end. }
function ReadEscape(var b: TomlChars; var i: integer; var t: TomlChars;
                    multi: boolean; var e: ErrorCode): boolean;
var c: char; ok, going: boolean; cp, j: integer;
begin
  ok := true;
  i := i + 1;
  c := Peek(b, i);
  i := i + 1;
  if c = '"' then t.Add('"')
  else if c = '\' then t.Add('\')
  else if c = 'b' then t.Add(chr(8))
  else if c = 'f' then t.Add(chr(12))
  else if c = 'n' then t.Add(chr(10))
  else if c = 'r' then t.Add(chr(13))
  else if c = 't' then t.Add(chr(9))
  else if c = 'e' then ok := false   { TOML 1.1's escape, and this is 1.0 }
  else if (c = 'u') or (c = 'U') then begin
    if c = 'u' then cp := HexRun(b, i, 4, ok) else cp := HexRun(b, i, 8, ok);
    { TOML: the escape must name a Unicode scalar value. A surrogate is not
      one, and writing its bytes out would produce a document `PasUnicode`
      then refuses -- the same refusal `PasJson` makes for a lone surrogate,
      and for the same reason. }
    if ok and ((cp > 1114111) or ((cp >= 55296) and (cp <= 57343))) then
      ok := false;
    if ok then PushUtf8(t, cp)
  end
  else if multi then begin
    { A blank, a tab or a newline after the solidus: the line ends here. }
    j := i - 1;
    while (Peek(b, j) = ' ') or (Peek(b, j) = chr(9)) or (Peek(b, j) = chr(13)) do
      j := j + 1;
    if Peek(b, j) <> chr(10) then ok := false
    else begin
      i := j + 1;
      going := true;
      while going do
        if (Peek(b, i) = ' ') or (Peek(b, i) = chr(9))
           or (Peek(b, i) = chr(10)) or (Peek(b, i) = chr(13)) then
          i := i + 1
        else
          going := false
    end
  end
  else
    ok := false;
  if not ok and (e = errNone) then e := errSyntax;
  ReadEscape := ok
end;

{ A single-line basic string, `i` at the opening quote. }
function ParseBasic(var b: TomlChars; var i: integer; var t: TomlChars;
                    var e: ErrorCode): boolean;
var ok, going: boolean; c: char;
begin
  ok := true;
  i := i + 1;
  going := true;
  while ok and going do
    if AtEnd(b, i) then begin
      e := errSyntax;
      ok := false
    end
    else begin
      c := Peek(b, i);
      if c = '"' then begin
        i := i + 1;
        going := false
      end
      else if c = chr(10) then begin
        { A newline inside a single-line string is the commonest way a
          hand-written document is wrong, and saying so at the newline puts
          the position on the line that is missing its quote. }
        e := errSyntax;
        ok := false
      end
      else if Control(c) then begin
        e := errSyntax;
        ok := false
      end
      else if c = '\' then
        ok := ReadEscape(b, i, t, false, e)
      else begin
        t.Add(c);
        i := i + 1
      end
    end;
  ParseBasic := ok
end;

{ The run of quote characters at `i`, without consuming it. }
function QuoteRun(var b: TomlChars; i: integer; q: char): integer;
var n: integer;
begin
  n := 0;
  while Peek(b, i + n) = q do
    n := n + 1;
  QuoteRun := n
end;

{ A multi-line string, `i` at the first of the three opening delimiters.
  `basic` says whether escapes are read; a literal one has none.

  Two rules of the format are in here and both are easy to miss. A newline
  immediately after the opening delimiter is not content. And the closing
  delimiter may be preceded by one or two of the same quote, which are: so
  `"""he said """"` ends with a quotation mark inside the string. A run of
  more than five ends nothing and is refused. }
function ParseMulti(var b: TomlChars; var i: integer; var t: TomlChars;
                    basic: boolean; var e: ErrorCode): boolean;
var ok, going: boolean; c, q: char; run, k: integer;
begin
  ok := true;
  if basic then q := '"' else q := '''';
  i := i + 3;
  if (Peek(b, i) = chr(13)) and (Peek(b, i + 1) = chr(10)) then i := i + 2
  else if Peek(b, i) = chr(10) then i := i + 1;
  going := true;
  while ok and going do
    if AtEnd(b, i) then begin
      e := errSyntax;
      ok := false
    end
    else begin
      c := Peek(b, i);
      if c = q then begin
        run := QuoteRun(b, i, q);
        if run < 3 then begin
          for k := 1 to run do t.Add(q);
          i := i + run
        end
        else if run > QuoteRunMax then begin
          e := errSyntax;
          ok := false
        end
        else begin
          for k := 1 to run - 3 do t.Add(q);
          i := i + run;
          going := false
        end
      end
      else if (c = chr(10)) or (c = chr(13)) or (c = chr(9)) then begin
        t.Add(c);
        i := i + 1
      end
      else if Control(c) then begin
        e := errSyntax;
        ok := false
      end
      else if basic and (c = '\') then
        ok := ReadEscape(b, i, t, true, e)
      else begin
        t.Add(c);
        i := i + 1
      end
    end;
  ParseMulti := ok
end;

{ A single-line literal string, `i` at the opening apostrophe. No escapes: what
  is between the apostrophes is what the value is, which is why a Windows path
  and a regular expression are written this way. }
function ParseLiteral(var b: TomlChars; var i: integer; var t: TomlChars;
                      var e: ErrorCode): boolean;
var ok, going: boolean; c: char;
begin
  ok := true;
  i := i + 1;
  going := true;
  while ok and going do
    if AtEnd(b, i) then begin
      e := errSyntax;
      ok := false
    end
    else begin
      c := Peek(b, i);
      if c = '''' then begin
        i := i + 1;
        going := false
      end
      else if (c = chr(10)) or Control(c) then begin
        e := errSyntax;
        ok := false
      end
      else begin
        t.Add(c);
        i := i + 1
      end
    end;
  ParseLiteral := ok
end;

{ Any of the four string forms, chosen by what is at `i`. A caller asks
  whether there is a string there before calling: this reports `errSyntax` for
  anything else, which is what a value position wants and not what a key
  position does. }
function ParseString(var b: TomlChars; var i: integer; var t: TomlChars;
                     var e: ErrorCode): boolean;
begin
  if Peek(b, i) = '"' then
    if QuoteRun(b, i, '"') >= 3 then ParseString := ParseMulti(b, i, t, true, e)
    else ParseString := ParseBasic(b, i, t, e)
  else if Peek(b, i) = '''' then
    if QuoteRun(b, i, '''') >= 3 then ParseString := ParseMulti(b, i, t, false, e)
    else ParseString := ParseLiteral(b, i, t, e)
  else begin
    e := errSyntax;
    ParseString := false
  end
end;

{ --- keys ----------------------------------------------------------------- }

{ A buffer copied into a key, `errFull` when it does not fit. }
function CharsIntoKey(var t: TomlChars; var k: TomlKey;
                      var e: ErrorCode): boolean;
var n, j: integer;
begin
  n := t.Len;
  if n > TomlKeyMax then begin
    e := errFull;
    CharsIntoKey := false
  end
  else begin
    k := '';
    for j := 1 to n do
      k := k + t.At(j);
    CharsIntoKey := true
  end
end;

{ One segment of a key: bare, or either single-line string form. A quoted key
  is the same characters as a bare one when it spells one -- `"a"` and `a` are
  one key, which the format says and which this gets for free by holding the
  decoded bytes. }
function ParseKeySegment(var b: TomlChars; var i: integer; var k: TomlKey;
                         var e: ErrorCode): boolean;
var ok: boolean; t: TomlChars; n: integer;
begin
  if BareChar(Peek(b, i)) then begin
    k := '';
    n := 0;
    ok := true;
    while ok and BareChar(Peek(b, i)) do begin
      n := n + 1;
      if n > TomlKeyMax then begin
        e := errFull;
        ok := false
      end
      else begin
        k := k + Peek(b, i);
        i := i + 1
      end
    end
  end
  else if (Peek(b, i) = '"') or (Peek(b, i) = '''') then begin
    { A multi-line string is not a key, and the run is what says so before the
      body is read: `"""a"""` as a key is a document nobody meant. }
    if QuoteRun(b, i, Peek(b, i)) >= 3 then begin
      e := errSyntax;
      ok := false
    end
    else begin
      t.Init;
      if Peek(b, i) = '"' then ok := ParseBasic(b, i, t, e)
      else ok := ParseLiteral(b, i, t, e);
      if ok then ok := CharsIntoKey(t, k, e);
      t.Free
    end
  end
  else begin
    e := errSyntax;
    ok := false
  end;
  ParseKeySegment := ok
end;

{ A dotted key: segments separated by dots, blanks allowed around each dot.
  `n` is how many were read. }
function ParseKeyPath(var b: TomlChars; var i: integer; var path: TomlKeyPath;
                      var n: integer; var e: ErrorCode): boolean;
var ok, going: boolean; k: TomlKey;
begin
  n := 0;
  ok := true;
  going := true;
  while ok and going do begin
    ok := ParseKeySegment(b, i, k, e);
    if ok then
      if n >= TomlPathMax then begin
        e := errFull;
        ok := false
      end
      else begin
        n := n + 1;
        path[n] := k;
        SkipBlank(b, i);
        if Peek(b, i) = '.' then begin
          i := i + 1;
          SkipBlank(b, i)
        end
        else
          going := false
      end
  end;
  ParseKeyPath := ok
end;

{ --- numbers -------------------------------------------------------------- }

{ An infinity and a NaN, which TOML has literals for and this language has
  not. `doc/implementation-defined.md` §3 is where the first is recorded as
  breaking no rule: §6.7.2.2 makes the accuracy of the real operations
  implementation-defined rather than making an unrepresentable result an
  error, so a multiplication that overflows yields one. The second is the
  difference of two infinities.

  They are computed through variables rather than written as a
  constant-expression, so that nothing here depends on what the compiler's own
  folder does with an overflowing constant. }
function PosInf: real;
var x: real;
begin
  x := 1.0e308;
  PosInf := x * 10.0
end;

function MakeNan: real;
var x: real;
begin
  x := PosInf;
  MakeNan := x - x
end;

{ Whether the three letters of a bare word are at `i`, and nothing that could
  continue a word after them. }
function WordAt(var b: TomlChars; i: integer; w: string): boolean;
var k: integer; ok: boolean;
begin
  ok := true;
  for k := 1 to length(w) do
    if Peek(b, i + k - 1) <> w[k] then ok := false;
  if ok and BareChar(Peek(b, i + length(w))) then ok := false;
  WordAt := ok
end;

{ A number, an integer or a float. `i` is at its first character, sign
  included.

  TOML's underscore rule is *between digits*, which is checked rather than
  ignored: `1_000` is a thousand, `_1`, `1_` and `1__0` are not numbers at
  all, and a reader that dropped underscores without looking would accept all
  three.

  A radix prefix takes no sign -- the format's `dec-int` is the only
  alternative with one -- and a decimal integer part takes no leading zero,
  which is the rule that keeps `01` from being read as 1 and a date from being
  read as a subtraction. }
function ParseNumber(var b: TomlChars; var i: integer;
                     var e: ErrorCode): TomlPtr;
var p: TomlPtr; neg, signed, exneg, ok, any, isFloat, over: boolean;
    ival, base, dexp, ex, d: integer; mant: real;
    sig: TomlSig; num: TomlNumText;

  { A significant digit of the float path, or the place value of one there is
    no room for -- `PasJson`'s `Keep`, whose reasoning is ADR-0314's. }
  procedure Keep(c: char; fraction: boolean);
  begin
    if (c = '0') and not any then begin
      if fraction then dexp := dexp - 1
    end
    else begin
      any := true;
      if length(sig) < SigMax then begin
        sig := sig + c;
        if fraction then dexp := dexp - 1
      end
      else if not fraction then dexp := dexp + 1
    end
  end;

  { A digit of the integer path, refusing an overflow before it happens:
    ADR-0014 makes integer arithmetic trap, so a document naming a number
    larger than this language holds must be reported and not computed. }
  procedure Take(v: integer);
  begin
    if ival > (maxint - v) div base then over := true
    else ival := ival * base + v
  end;

  { A run of digits of `base` with underscores between them, and at least one
    digit. `frac` says which of the two accumulators the run feeds.

    A procedure and not a function, which it was for one draft: it reports
    through `ok`, and a caller writing `ok := Run(false)` overwrote the
    refusal this had just recorded with *did it read any digits*, so `1_` was
    accepted. There is nothing for it to answer that `ok` does not already
    say. }
  procedure Run(frac: boolean);
  var got: boolean; c: char; v: integer;
  begin
    got := false;
    while ok and (Digit(Peek(b, i)) or (HexDigit(Peek(b, i)) and (base = 16))
                  or (Peek(b, i) = '_')) do begin
      c := Peek(b, i);
      if c = '_' then begin
        { Between digits: one before it, and one after it. }
        if not got then ok := false
        else begin
          i := i + 1;
          if not (Digit(Peek(b, i)) or (HexDigit(Peek(b, i)) and (base = 16)))
            then ok := false
        end
      end
      else begin
        v := HexVal(c, ok);
        if v >= base then ok := false
        else begin
          got := true;
          { Both accumulators are fed on the way past, because whether this is
            a float is not known until the point or the exponent arrives. }
          Keep(c, frac);
          if not frac then Take(v);
          i := i + 1
        end
      end
    end;
    if ok and not got then ok := false
  end;

begin
  ok := true;
  neg := false;
  signed := false;
  any := false;
  over := false;
  isFloat := false;
  ival := 0;
  dexp := 0;
  base := 10;
  sig := '';
  if Peek(b, i) = '-' then begin neg := true; signed := true; i := i + 1 end
  else if Peek(b, i) = '+' then begin signed := true; i := i + 1 end;

  if WordAt(b, i, 'inf') then begin
    i := i + 3;
    p := FreshNode(tkFloat);
    if neg then p^.fnum := -PosInf else p^.fnum := PosInf;
    ParseNumber := p
  end
  else if WordAt(b, i, 'nan') then begin
    { A sign on a NaN is admitted by the grammar and means nothing: there is
      one NaN as far as this module is concerned, and negating it would be a
      claim about a bit pattern. }
    i := i + 3;
    p := FreshNode(tkFloat);
    p^.fnum := MakeNan;
    ParseNumber := p
  end
  else begin
    if (Peek(b, i) = '0') and not Digit(Peek(b, i + 1))
       and ((Peek(b, i + 1) = 'x') or (Peek(b, i + 1) = 'o')
            or (Peek(b, i + 1) = 'b')) then begin
      { A prefixed integer, and the format gives it no sign: `dec-int` is the
        only alternative of `integer` that has one. }
      if signed then ok := false;
      if Peek(b, i + 1) = 'x' then base := 16
      else if Peek(b, i + 1) = 'o' then base := 8
      else base := 2;
      i := i + 2;
      if ok then Run(false)
    end
    else begin
      { A decimal integer part. A leading zero is refused, which is what stops
        `01` and is why a date must be recognised before a number is. }
      if Peek(b, i) = '0' then begin
        i := i + 1;
        Keep('0', false);
        if Digit(Peek(b, i)) or (Peek(b, i) = '_') then ok := false
      end
      else if Digit(Peek(b, i)) then
        Run(false)
      else
        ok := false;

      if ok and (Peek(b, i) = '.') then begin
        isFloat := true;
        i := i + 1;
        { The point must be surrounded by digits, which is the format's own
          sentence and is what makes `1.` and `.5` not numbers. }
        if not Digit(Peek(b, i)) then ok := false else Run(true)
      end;

      if ok and ((Peek(b, i) = 'e') or (Peek(b, i) = 'E')) then begin
        isFloat := true;
        i := i + 1;
        exneg := false;
        if Peek(b, i) = '-' then begin exneg := true; i := i + 1 end
        else if Peek(b, i) = '+' then i := i + 1;
        if not Digit(Peek(b, i)) then ok := false;
        ex := 0;
        while ok and (Digit(Peek(b, i)) or (Peek(b, i) = '_')) do
          if Peek(b, i) = '_' then begin
            if not Digit(Peek(b, i + 1)) then ok := false;
            i := i + 1
          end
          else begin
            { What is refused here is an exponent the arithmetic below could
              not hold, and the bound is far past the range of a double either
              way: outside it the value is an infinity or a zero. }
            d := ord(Peek(b, i)) - ord('0');
            if ex > 10000 then ok := false else ex := ex * 10 + d;
            i := i + 1
          end;
        if ok then
          if exneg then dexp := dexp - ex else dexp := dexp + ex
      end
    end;

    if not ok then begin
      if e = errNone then e := errSyntax;
      ParseNumber := nil
    end
    else if isFloat then begin
      { Written as a real-literal and read back as one (ADR-0314): 6.9.5's two
        required procedures are how a program hands a value to the language's
        own number reading and takes the answer back. }
      if not any then mant := 0.0
      else begin
        writestr(num, sig, 'E', dexp:1);
        readstr(num, mant)
      end;
      p := FreshNode(tkFloat);
      if neg then p^.fnum := -mant else p^.fnum := mant;
      ParseNumber := p
    end
    else if over then begin
      { The format asks a reader to hold the full range of a signed 64-bit
        number and `integer` here is -maxint..maxint (ADR-0014). Reporting it
        is the only honest answer: a wrapped one would be a different
        configuration. }
      e := errRange;
      ParseNumber := nil
    end
    else begin
      p := FreshNode(tkInteger);
      if neg then p^.inum := -ival else p^.inum := ival;
      ParseNumber := p
    end
  end
end;

{ --- dates and times ------------------------------------------------------- }

{ Four digits and a hyphen: the shape only a date has. A number cannot begin
  this way -- a leading zero is refused above and `1979-` would be a
  subtraction, which is not a value. }
function LooksLikeDate(var b: TomlChars; i: integer): boolean;
begin
  LooksLikeDate := Digit(Peek(b, i)) and Digit(Peek(b, i + 1))
                   and Digit(Peek(b, i + 2)) and Digit(Peek(b, i + 3))
                   and (Peek(b, i + 4) = '-')
end;

{ Two digits and a colon. }
function LooksLikeTime(var b: TomlChars; i: integer): boolean;
begin
  LooksLikeTime := Digit(Peek(b, i)) and Digit(Peek(b, i + 1))
                   and (Peek(b, i + 2) = ':')
end;

{ `n` digits appended to `s`. }
function TakeDigits(var b: TomlChars; var i: integer; n: integer;
                    var s: string; var ok: boolean): boolean;
var k: integer;
begin
  for k := 1 to n do
    if Digit(Peek(b, i)) then begin
      s := s + Peek(b, i);
      i := i + 1
    end
    else
      ok := false;
  TakeDigits := ok
end;

{ One literal character. }
function TakeChar(var b: TomlChars; var i: integer; c: char;
                  var s: string; var ok: boolean): boolean;
begin
  if Peek(b, i) = c then begin
    s := s + c;
    i := i + 1
  end
  else
    ok := false;
  TakeChar := ok
end;

{ A date-time in any of TOML's four forms.

  What is built here is the *lexical* check and the two fields 6.4.3.4's record
  has no room for; the calendar itself is `PasTime.ParseStamp`, which reads
  exactly the three forms this leaves it -- `YYYY-MM-DD`, `hh:mm:ss` and the
  two joined by a `T` -- and answers `errRange` for the 29th of February in an
  ordinary year. That is the whole reason this module imports PasTime: the
  rules are spelled once in this tree.

  A fractional second is kept to nine digits and the rest are dropped, which
  the format permits in as many words. }
function ParseDateTime(var b: TomlChars; var i: integer;
                       var e: ErrorCode): TomlPtr;
var p: TomlPtr; ok, offneg: boolean; core: string(32);
    nanos, digits, hh, mm: integer; r: StampResult; form: TomlDateKind;

  { The fraction after the point, into nanoseconds. `k` is this procedure's
    own because §6.8.3.9 requires a control variable to be declared in the
    block containing the for-statement -- not merely to be a variable -- and
    the enclosing block's would be neither. }
  procedure Fraction;
  var k: integer;
  begin
    if Peek(b, i) = '.' then begin
      i := i + 1;
      if not Digit(Peek(b, i)) then ok := false;
      while Digit(Peek(b, i)) do begin
        if digits < 9 then begin
          nanos := nanos * 10 + (ord(Peek(b, i)) - ord('0'));
          digits := digits + 1
        end;
        i := i + 1
      end;
      { Scaled to nanoseconds however few digits were written: `.5` is half a
        second and not five nanoseconds. }
      for k := digits + 1 to 9 do nanos := nanos * 10
    end
  end;

begin
  ok := true;
  core := '';
  nanos := 0;
  digits := 0;
  hh := 0;
  mm := 0;
  offneg := false;
  form := tdDate;
  if LooksLikeDate(b, i) then begin
    ok := TakeDigits(b, i, 4, core, ok);
    ok := TakeChar(b, i, '-', core, ok);
    ok := TakeDigits(b, i, 2, core, ok);
    ok := TakeChar(b, i, '-', core, ok);
    ok := TakeDigits(b, i, 2, core, ok);
    { A `T`, a `t` or a space, and a space only when a time follows it: a
      bare date at the end of a line is followed by a space and a comment far
      more often than by a time. }
    if ok and ((Peek(b, i) = 'T') or (Peek(b, i) = 't')
               or ((Peek(b, i) = ' ') and LooksLikeTime(b, i + 1))) then begin
      i := i + 1;
      core := core + 'T';
      form := tdLocal;
      ok := TakeDigits(b, i, 2, core, ok);
      ok := TakeChar(b, i, ':', core, ok);
      ok := TakeDigits(b, i, 2, core, ok);
      ok := TakeChar(b, i, ':', core, ok);
      ok := TakeDigits(b, i, 2, core, ok);
      if ok then Fraction;
      if ok and ((Peek(b, i) = 'Z') or (Peek(b, i) = 'z')) then begin
        i := i + 1;
        form := tdOffset
      end
      else if ok and ((Peek(b, i) = '+') or (Peek(b, i) = '-')) then begin
        offneg := Peek(b, i) = '-';
        i := i + 1;
        if Digit(Peek(b, i)) and Digit(Peek(b, i + 1)) then begin
          hh := (ord(Peek(b, i)) - ord('0')) * 10
                + ord(Peek(b, i + 1)) - ord('0');
          i := i + 2
        end
        else ok := false;
        if ok and (Peek(b, i) = ':') then i := i + 1 else ok := false;
        if ok and Digit(Peek(b, i)) and Digit(Peek(b, i + 1)) then begin
          mm := (ord(Peek(b, i)) - ord('0')) * 10
                + ord(Peek(b, i + 1)) - ord('0');
          i := i + 2
        end
        else ok := false;
        if ok and ((hh > 23) or (mm > 59)) then begin
          e := errRange;
          ok := false
        end;
        form := tdOffset
      end
    end
  end
  else begin
    form := tdTime;
    ok := TakeDigits(b, i, 2, core, ok);
    ok := TakeChar(b, i, ':', core, ok);
    ok := TakeDigits(b, i, 2, core, ok);
    ok := TakeChar(b, i, ':', core, ok);
    ok := TakeDigits(b, i, 2, core, ok);
    if ok then Fraction
  end;

  if not ok then begin
    if e = errNone then e := errSyntax;
    ParseDateTime := nil
  end
  else begin
    r := ParseStamp(core);
    if not r.ok then begin
      e := r.cause;
      ParseDateTime := nil
    end
    else begin
      p := FreshNode(tkDateTime);
      p^.when.form := form;
      p^.when.clock := r.val;
      p^.when.nanosecond := nanos;
      if form = tdOffset then
        if offneg then p^.when.offset := -(hh * 60 + mm)
        else p^.when.offset := hh * 60 + mm;
      ParseDateTime := p
    end
  end
end;

{ --- values --------------------------------------------------------------- }

{ Forward, because a value may be an array or an inline table and both hold
  values. The recursion is bounded by `depth`, which is the compiler's own
  answer to a hostile document (ADR-0020). }
function ParseValue(var b: TomlChars; var i, depth: integer;
                    var e: ErrorCode): TomlPtr; forward;

function ParseKeyVal(var b: TomlChars; var i, depth: integer; tab: TomlPtr;
                     var e: ErrorCode): boolean; forward;

{ An array. Whitespace, comments and newlines may appear anywhere inside one,
  and a trailing comma is admitted -- both are the format's own, and both are
  what a person editing a list of paths relies on. }
function ParseArray(var b: TomlChars; var i, depth: integer;
                    var e: ErrorCode): TomlPtr;
var arr, item: TomlPtr; ok, going: boolean;
begin
  arr := FreshNode(tkArray);
  { A value array is closed: `[[header]]` may not append to it, and nothing may
    reach into a table written inside one. }
  arr^.closed := true;
  ok := true;
  i := i + 1;
  going := true;
  while ok and going do begin
    ok := SkipBlankLines(b, i);
    if ok and (Peek(b, i) = ']') then begin
      i := i + 1;
      going := false
    end
    else if not ok then
      e := errSyntax
    else if AtEnd(b, i) then begin
      e := errSyntax;
      ok := false
    end
    else begin
      item := ParseValue(b, i, depth, e);
      if item = nil then ok := false
      else begin
        arr.Append(item);
        ok := SkipBlankLines(b, i);
        if not ok then e := errSyntax
        else if Peek(b, i) = ',' then i := i + 1
        else if Peek(b, i) <> ']' then begin
          e := errSyntax;
          ok := false
        end
      end
    end
  end;
  if ok then ParseArray := arr
  else begin
    arr.Free;
    ParseArray := nil
  end
end;

{ An inline table. TOML 1.0 admits no newline inside one and no trailing
  comma, and both refusals are the format's: an inline table is meant to be a
  value on one line, and a document that wants otherwise writes a header. }
function ParseInline(var b: TomlChars; var i, depth: integer;
                     var e: ErrorCode): TomlPtr;
var tab: TomlPtr; ok, going: boolean;
begin
  tab := FreshNode(tkTable);
  tab^.explicit := true;
  tab^.closed := true;
  ok := true;
  i := i + 1;
  SkipBlank(b, i);
  going := Peek(b, i) <> '}';
  if not going then i := i + 1;
  while ok and going do begin
    SkipBlank(b, i);
    ok := ParseKeyVal(b, i, depth, tab, e);
    if ok then begin
      SkipBlank(b, i);
      if Peek(b, i) = ',' then begin
        i := i + 1;
        SkipBlank(b, i);
        { A comma must be followed by another pair. }
        if Peek(b, i) = '}' then begin
          e := errSyntax;
          ok := false
        end
      end
      else if Peek(b, i) = '}' then begin
        i := i + 1;
        going := false
      end
      else begin
        e := errSyntax;
        ok := false
      end
    end
  end;
  if ok then ParseInline := tab
  else begin
    tab.Free;
    ParseInline := nil
  end
end;

function ParseValue;
var p: TomlPtr; c: char;
begin
  if depth >= TomlDepthMax then begin
    e := errFull;
    ParseValue := nil
  end
  else begin
    depth := depth + 1;
    c := Peek(b, i);
    if (c = '"') or (c = '''') then begin
      p := FreshNode(tkString);
      if ParseString(b, i, p^.text, e) then ParseValue := p
      else begin
        p.Free;
        ParseValue := nil
      end
    end
    else if c = '[' then
      ParseValue := ParseArray(b, i, depth, e)
    else if c = '{' then
      ParseValue := ParseInline(b, i, depth, e)
    else if WordAt(b, i, 'true') then begin
      i := i + 4;
      p := FreshNode(tkBoolean);
      p^.bool := true;
      ParseValue := p
    end
    else if WordAt(b, i, 'false') then begin
      i := i + 5;
      p := FreshNode(tkBoolean);
      p^.bool := false;
      ParseValue := p
    end
    else if LooksLikeDate(b, i) or LooksLikeTime(b, i) then
      ParseValue := ParseDateTime(b, i, e)
    { `inf` and `nan` are numbers and are the two that do not begin like one;
      a sign may precede either. Nothing else in the format begins with an
      `i` or an `n`, so admitting the two letters here costs no ambiguity and
      `ParseNumber` refuses a word that turns out to be neither. }
    else if Digit(c) or (c = '+') or (c = '-') or (c = 'i') or (c = 'n') then
      ParseValue := ParseNumber(b, i, e)
    else begin
      e := errSyntax;
      ParseValue := nil
    end;
    depth := depth - 1
  end
end;

{ --- tables --------------------------------------------------------------- }

{ Walk the first `n` segments of `path` from `tab`, creating what is not
  there. `forHeader` says which of the two callers this is, and the difference
  is the whole of TOML's redefinition rule:

  a **header** may pass through a table another header defined -- `[a]` then
  `[a.b]` -- and may not pass through one a dotted key made;

  a **dotted key** may pass through a table another dotted key made -- `a.b =
  1` then `a.c = 2` -- and may not pass through one a header defined.

  Both may pass through an array of tables, and arrive at its last element:
  that is what makes `[[fruit]]` then `[fruit.variety]` name the variety of
  the fruit just started. Neither may pass through anything closed, which is
  an inline table or a table inside a value array. }
function Descend(tab: TomlPtr; protected var path: TomlKeyPath; n: integer;
                 forHeader: boolean; var e: ErrorCode): TomlPtr;
var cur, got: TomlPtr; k: integer;
begin
  cur := tab;
  k := 1;
  while (cur <> nil) and (k <= n) do begin
    got := Lookup(cur, path[k]);
    if got = nil then begin
      got := FreshNode(tkTable);
      got^.dotted := not forHeader;
      Attach(cur, path[k], got);
      cur := got
    end
    else if got^.kind = tkTable then
      if got^.closed then begin
        e := errSyntax;
        cur := nil
      end
      else if forHeader and got^.dotted then begin
        e := errSyntax;
        cur := nil
      end
      else if not forHeader and got^.explicit then begin
        e := errSyntax;
        cur := nil
      end
      else
        cur := got
    else if (got^.kind = tkArray) and got^.tabArray then
      cur := got^.last
    else begin
      e := errSyntax;
      cur := nil
    end;
    k := k + 1
  end;
  Descend := cur
end;

{ One `key = value` line, or one pair of an inline table. The key may be
  dotted, in which case the tables on the way are made here and are the
  dotted kind. }
function ParseKeyVal;
var path: TomlKeyPath; n: integer; owner, v: TomlPtr; ok: boolean;
begin
  ok := ParseKeyPath(b, i, path, n, e);
  if ok then begin
    SkipBlank(b, i);
    if Peek(b, i) = '=' then i := i + 1 else begin
      e := errSyntax;
      ok := false
    end
  end;
  if ok then begin
    SkipBlank(b, i);
    owner := Descend(tab, path, n - 1, false, e);
    if owner = nil then ok := false
    else if Lookup(owner, path[n]) <> nil then begin
      { The format's one-definition rule, and the reason this module answers
        `errSyntax` for it rather than inventing a code: a key defined twice
        is a document that is not TOML, not a world that refused. }
      e := errSyntax;
      ok := false
    end
    else begin
      v := ParseValue(b, i, depth, e);
      if v = nil then ok := false
      else Attach(owner, path[n], v)
    end
  end;
  ParseKeyVal := ok
end;

{ A `[header]` or a `[[header]]` line, `i` at the first bracket. `cur` is left
  naming the table that bare keys after it belong to. }
function ParseHeader(var b: TomlChars; var i: integer; root: TomlPtr;
                     var cur: TomlPtr; var e: ErrorCode): boolean;
var path: TomlKeyPath; n: integer; owner, got, made: TomlPtr;
    ok, isArray: boolean;
begin
  ok := true;
  i := i + 1;
  isArray := Peek(b, i) = '[';
  if isArray then i := i + 1;
  SkipBlank(b, i);
  ok := ParseKeyPath(b, i, path, n, e);
  if ok then begin
    SkipBlank(b, i);
    if Peek(b, i) = ']' then i := i + 1 else ok := false;
    if ok and isArray then
      if Peek(b, i) = ']' then i := i + 1 else ok := false;
    if not ok and (e = errNone) then e := errSyntax
  end;
  if ok then begin
    owner := Descend(root, path, n - 1, true, e);
    if owner = nil then ok := false
    else begin
      got := Lookup(owner, path[n]);
      if isArray then
        if got = nil then begin
          made := FreshNode(tkArray);
          made^.tabArray := true;
          Attach(owner, path[n], made);
          cur := FreshNode(tkTable);
          cur^.explicit := true;
          made.Append(cur)
        end
        else if (got^.kind = tkArray) and got^.tabArray and not got^.closed
          then begin
            cur := FreshNode(tkTable);
            cur^.explicit := true;
            got.Append(cur)
          end
        else begin
          e := errSyntax;
          ok := false
        end
      else
        if got = nil then begin
          cur := FreshNode(tkTable);
          cur^.explicit := true;
          Attach(owner, path[n], cur)
        end
        else if (got^.kind = tkTable) and not got^.explicit
                and not got^.dotted and not got^.closed then begin
          { A super-table a deeper header created, now given a body of its
            own: `[a.b]` and then `[a]`, which the format admits and which is
            why `explicit` is a flag rather than the table's existence. }
          got^.explicit := true;
          cur := got
        end
        else begin
          e := errSyntax;
          ok := false
        end
    end
  end;
  ParseHeader := ok
end;

{ --- the document --------------------------------------------------------- }

function TomlParseChars;
var root, cur: TomlPtr; e: ErrorCode; ok, going: boolean; depth: integer;
begin
  e := errNone;
  at := 1;
  depth := 0;
  root := FreshNode(tkTable);
  root^.explicit := true;
  cur := root;
  ok := true;
  going := true;
  while ok and going do begin
    ok := SkipBlankLines(b, at);
    if not ok then e := errSyntax
    else if AtEnd(b, at) then
      going := false
    else if Peek(b, at) = '[' then begin
      ok := ParseHeader(b, at, root, cur, e);
      if ok then begin
        ok := EndOfLine(b, at);
        if not ok then e := errSyntax
      end
    end
    else begin
      ok := ParseKeyVal(b, at, depth, cur, e);
      if ok then begin
        ok := EndOfLine(b, at);
        if not ok then e := errSyntax
      end
    end
  end;
  if ok then r := root
  else begin
    root.Free;
    if e = errNone then e := errSyntax;
    r := e
  end
end;

function TomlParse;
var b: TomlChars;
begin
  b.Init;
  b.AddText(s);
  r := TomlParseChars(b, at);
  b.Free
end;

end.
