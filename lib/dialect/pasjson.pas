{ PasJson -- a JSON document a program can read, build and write back.

  It is here because `doc/roadmap.md` names it as the one library gap with a
  named client: every Language Server Protocol message is a JSON object, so the
  program that would judge this language needs this on its first day. Nothing
  in it needed a language feature, which is what made it the next thing to
  write rather than the next thing to argue about.

  **A value is a heap node and a document is a tree.** `JsonFree` disposes one,
  and a program that forgets it leaks -- the shape `PasVector` and `PasMap`
  have, and deliberately not `PasList`'s. An owned pointer (AP 6.4.14) would
  give the document a lifetime it could not get wrong, and AP 6.4.14.3 gives an
  owned pointer no copy, so nothing could hold a second name for a subtree:
  `JsonMember(doc, 'params')` is exactly such a name, and navigation is what a
  client does. The container that cannot be navigated is the wrong one here.

  **A string is bytes, and that is a decision.** AP 6.4.15's `utf8` is the
  right type for text a program means to *read*, and the wrong one for this:
  assignment to a text establishes Normalization Form C, so the bytes that came
  in are not the bytes that go out. A language server round-trips the contents
  of somebody's source file through this module, and silently normalising it
  would edit their document. `utf8` also stops the program on ill-formed bytes
  (AP 6.4.15.5), which is right for a program's own literals and wrong for a
  socket. A caller who wants text calls `PasUnicode.ToText` and gets both
  behaviours where it can see them.

  What follows from that: this module does **not** check that a string's bytes
  are well-formed UTF-8. It checks the JSON grammar, and `\uXXXX` escapes
  including surrogate pairs, and passes every other byte through unread.

  **A string value has no bound and a member name does.** A value goes into a
  `JsonChars`, which is `PasContainer`'s growable vector over `char`, because a
  `didChange` notification carries a whole file in one string. A name is a
  `JsonName`, a `string(255)`, because a key is a key; a longer one is
  `errFull` rather than a silent truncation.

  This is the second caller of `lib/dialect/pascontainer.pas` and the first
  from inside the library, which is how ADR-0216 was found: a module that
  instantiates an imported generic emitted the call and not the body, and the
  failure was a linker error about a name no source spells. }

module PasJson;

{ **What a client is given is the types, and the types carry their routines**
  (AP 6.7.10.5, ADR-0411). Twenty-five names are exported where fifty were:
  `JsonChars` and `JsonPtr` each have an implementation in the block below,
  and an implementation is selected from the *type* of the receiver rather
  than from a name in scope (AP 6.7.10.2), so none of its routines is an
  exported name and none can collide with another module's. That is what
  retired the `Json` prefix from twenty-four of them: `JsonCharsAddLine`
  became `AddText` and `JsonIntegerOr` became `IntegerOr`, and what makes
  the short spelling safe is that §6.11.2's one scope is never reached.

  What stays exported is what has no receiver to be selected from: the types,
  the three bounds, the seven constructors, and the two entry points that
  build a document out of bytes. }

export PasJson = (JsonKind, jsNull, jsFalse, jsTrue, jsNumber, jsString,
                  jsArray, jsObject,
                  JsonName, JsonLine, JsonChars, JsonPtr, JsonResult,
                  JsonDepthMax, JsonNameMax, JsonLineMax,

                  JsonParse, JsonParseChars,

                  JsonNewNull, JsonNewBoolean, JsonNewNumber, JsonNewInteger,
                  JsonNewText, JsonNewArray, JsonNewObject);

import PasError; PasContainer; PasText;

const
  { A key is a key. `errFull` rather than a silent truncation past this. }
  JsonNameMax = 255;
  { A ready-made capacity for a caller that wants one, and **not** a bound
    this module imposes: every routine below that takes a string in one piece
    takes a schematic one, so the capacity is the caller's (ADR-0291). A
    document larger than any string goes through `JsonChars`, which is bounded
    by PasContainer's CapMax and says so: `Full` is how a caller asks, and until ADR-0276 this comment claimed there was no bound and a
    buffer past it trapped. }
  JsonLineMax = 255;
  { Nesting, so a hostile document cannot exhaust the stack -- the parser is
    recursive descent and this is the compiler's own answer (ADR-0020) at a
    depth a message will never reach. }
  JsonDepthMax = 100;

type
  { RFC 8259's seven. `true` and `false` are kinds rather than one boolean kind
    because that is how the grammar has them, and because a `case` over this
    then covers the document rather than the document minus a field. }
  JsonKind = (jsNull, jsFalse, jsTrue, jsNumber, jsString, jsArray, jsObject);

  JsonName = string(JsonNameMax);
  JsonLine = string(JsonLineMax);

  { PasContainer's vector over `char`, which is what makes a string value
    unbounded. A caller never names `Vec` and never imports PasContainer: the
    eight methods of `impl JsonChars` are the whole of what it needs. }
  JsonChars = ^Vec(char);

  JsonPtr = ^JsonNode;
  JsonNode = record
    { The next sibling of an array element or an object member. A document is
      a tree of these and nothing here is shared, so `Free` is a walk. }
    next: JsonPtr;
    { The member name, for a member of an object; empty otherwise, and never
      read for anything else. In the fixed part because it belongs to the
      *containment* and not to the value: the same value is a member here and
      an element there. }
    name: JsonName;
    case kind: JsonKind of
      jsNull, jsFalse, jsTrue: ();
      { `whole` is what a JSON number does not record and a client needs: an
        LSP request id and a line number are integers, and re-emitting one as
        `3.0` is a different message. True when the source had no fraction and
        no exponent and the value fits -maxint..maxint. }
      jsNumber: (num: real; whole: boolean; inum: integer);
      jsString: (text: JsonChars);
      jsArray, jsObject: (first, last: JsonPtr; count: integer)
  end;

  { ADR-0120's shape, and AP 6.4.13 since ADR-0176. `errSyntax` for a document
    that is not one, `errRange` for a number that cannot be represented,
    `errFull` for a member name longer than `JsonNameMax`. }
  JsonResult = Fallible(JsonPtr);

{ --- parsing -------------------------------------------------------------- }

{ Parse a whole document. `at` receives the 1-based byte position parsing
  stopped at, which is where a caller reports from; it is the position *after*
  the value on success. A successful result owns a tree the caller must free
  with `Free`. }
function JsonParseChars(var b: JsonChars; var at: integer) = r: JsonResult;

{ The same, for a document that fits in one string -- of whatever capacity
  the caller declared. }
function JsonParse(s: string; var at: integer) = r: JsonResult;

{ --- building ------------------------------------------------------------- }

{ The seven constructors, which stay exported because a constructor has no
  receiver for AP 6.7.10.2 to select from: `JsonNewNull` takes nothing at all,
  and the rest take the value rather than the document. They keep the prefix
  for §6.11.2's reason -- these are names in one scope with every other
  module's. }
function JsonNewNull: JsonPtr;
function JsonNewBoolean(b: boolean): JsonPtr;
function JsonNewNumber(x: real): JsonPtr;
function JsonNewInteger(n: integer): JsonPtr;
function JsonNewText(s: string): JsonPtr;
function JsonNewArray: JsonPtr;
function JsonNewObject: JsonPtr;

end;


{ --- reading a number ------------------------------------------------------ }

const
  { The significant digits a number is read from (ADR-0314). Seventeen
    identify a double; this keeps more than twice as many, so what is dropped
    can only matter where the value sits within 10^-23 of a halfway point.
    Keeping every digit a document may write would need a string with no
    capacity, and this language has none. }
  SigMax = 40;

type
  JsonSig = string(SigMax);
  { The significand, an `E`, and a decimal exponent. The scan bounds the
    exponent it reads at five digits, and the significand can shift it by at
    most `SigMax` more, so seven characters would hold it and this holds
    fifteen: a margin is cheaper than the argument that the exact figure is
    right, and overflowing a string capacity in a library is a trap rather
    than a wrong answer. }
  JsonNumText = string(SigMax + 16);

{ --- the byte buffer ------------------------------------------------------ }


impl JsonChars;

  { An empty buffer. Every `JsonChars` a caller holds comes from here or from
    a routine that says it answers one. }
  procedure Init(var b: JsonChars);
  begin
    VecInit(JsonChars, b, 32)
  end;

  { Release it and leave `b` nil. A nil `b` is harmless. }
  procedure Free(var b: JsonChars);
  begin
    VecFree(JsonChars, b)
  end;

  { Append one byte. }
  procedure Add(var b: JsonChars; c: char);
  begin
    VecPush(JsonChars, b, c)
  end;

  { Append a whole string, which is how a caller assembles a document to
    parse. Schematic, so a caller holding a longer capacity than `JsonLine`
    is not refused at this boundary (ADR-0291). }
  procedure AddText(var b: JsonChars; s: string);
  var i: integer;
  begin
    for i := 1 to length(s) do
      VecPush(JsonChars, b, s[i])
  end;

  function Len(var b: JsonChars): integer;
  begin
    Len := VecLen(JsonChars, b)
  end;

  { Has this buffer reached the largest extent it can have, so that the next
    character would be dropped? A caller assembling someone else's bytes -- a
    message body, a document -- asks this and reports `errFull`, which is this
    module's rule everywhere else a bound is met (ADR-0276). }
  function Full(var b: JsonChars): boolean;
  begin
    Full := VecFull(JsonChars, b)
  end;

  { The i'th byte, 1-based. Out of range is the caller's error and traps, as
    an array subscript does. }
  function At(var b: JsonChars; i: integer): char;
  begin
    At := VecGet(char, b, i)
  end;

  { Copy the whole buffer into a string. `errFull` when it does not fit, and
    `s` is then untouched. }
  function Into(var b: JsonChars; var s: string): ErrorCode;
  var i, n: integer;
  begin
    n := VecLen(JsonChars, b);
    if n > s.capacity then
      Into := errFull
    else begin
      { Built into `s` and not through a local accumulator. It was built through
        `acc: string(JsonLineMax)`, which made the capacity check a lie: the guard
        asks the *caller's* capacity and the accumulator imposed 255 whatever
        the caller passed, so a document between 256 and the caller's capacity
        passed the check and then stopped the program at
        `a string of length 256 does not fit a capacity of 255`. A
        `publishDiagnostics` notification carrying two diagnostics is 300-odd
        characters, which is how it was found: the first realistic client
        exceeded it. `s` is 6.4.3.3.3's canonical string-type through a `var`
        parameter, so its own capacity is what the appends are checked against,
        which is the capacity the guard already asked about. }
      s := '';
      for i := 1 to n do
        s := s + VecGet(char, b, i);
      Into := errNone
    end
  end;
end;

{ --- nodes ---------------------------------------------------------------- }

{ A fresh node of one kind, with the fields of that kind emptied. The tag is
  assigned before any field is, which is what AP 6.4.11's authoritative tag
  asks of a producer: a field written first would activate a variant this did
  not mean. }
function FreshNode(k: JsonKind): JsonPtr;
var p: JsonPtr;
begin
  new(p);
  p^.next := nil;
  p^.name := '';
  p^.kind := k;
  case k of
    jsNull, jsFalse, jsTrue: ;
    jsNumber: begin p^.num := 0.0; p^.whole := true; p^.inum := 0 end;
    jsString: p^.text.Init;
    jsArray, jsObject: begin
      p^.first := nil;
      p^.last := nil;
      p^.count := 0
    end
  end;
  FreshNode := p
end;

{ The one place a node joins a container, so the sibling list and the count are
  maintained together and nowhere else. }
procedure Attach(owner, item: JsonPtr);
begin
  if owner^.first = nil then owner^.first := item
  else owner^.last^.next := item;
  owner^.last := item;
  owner^.count := owner^.count + 1
end;

{ --- writing a value ------------------------------------------------------ }

function HexDigit(n: integer): char;
begin
  if n < 10 then HexDigit := chr(ord('0') + n)
  else HexDigit := chr(ord('a') + n - 10)
end;

{ RFC 8259 §7. The quotation mark and the reverse solidus must be escaped and
  every control character must be; the solidus may be and is not, because
  escaping it makes a URL unreadable for no gain. }
procedure RenderText(var t: JsonChars; var out: JsonChars);
var k, n, c: integer; ch: char;
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
    else if c < 32 then begin
      out.AddText('\u00');
      out.Add(HexDigit(c div 16));
      out.Add(HexDigit(c mod 16))
    end
    else
      out.Add(ch)
  end;
  out.Add('"')
end;

procedure RenderNumber(v: JsonPtr; var out: JsonChars);
var s: TextLine; k: integer;
begin
  { A number the document wrote without a fraction and without an exponent is
    written back the same way (`whole`, ADR-0120): JSON has one number type,
    and an LSP request id re-emitted as `3.0` is a different message.

    The shortest spelling that reads back is `PasText.RealToStr`, which is
    where ADR-0309's search moved when this stopped being its only caller.
    What it answers for a value with no decimal representation -- an infinity,
    a NaN -- is what `writestr` writes, which is not a JSON number; JSON has
    neither value and no answer here is one. }
  if v^.whole then s := IntToStr(v^.inum) else s := RealToStr(v^.num);
  for k := 1 to length(s) do out.Add(s[k])
end;

{ --- the document --------------------------------------------------------- }


impl JsonPtr;

  { Dispose a value and everything under it, and leave `v` nil. }
  procedure Free(var v: JsonPtr);
  var kid, nxt: JsonPtr;
  begin
    if v <> nil then begin
      case v^.kind of
        jsNull, jsFalse, jsTrue, jsNumber: ;
        jsString: v^.text.Free;
        jsArray, jsObject: begin
          kid := v^.first;
          while kid <> nil do begin
            nxt := kid^.next;
            kid.Free;
            kid := nxt
          end
        end
      end;
      dispose(v);
      v := nil
    end
  end;

  { The kind of a value. `jsNull` for nil, which is what makes every reader
    below safe to call on a member that was not there. }
  function Kind(v: JsonPtr): JsonKind;
  begin
    if v = nil then Kind := jsNull else Kind := v^.kind
  end;

  { How many elements an array has, or members an object; 0 for anything
    else. }
  function Count(v: JsonPtr): integer;
  begin
    if v = nil then Count := 0
    else
      case v^.kind of
        jsNull, jsFalse, jsTrue, jsNumber, jsString: Count := 0;
        jsArray, jsObject: Count := v^.count
      end
  end;

  { The i'th element or member, 1-based, or nil. }
  function At(v: JsonPtr; i: integer): JsonPtr;
  var p: JsonPtr; n: integer;
  begin
    At := nil;
    if v <> nil then
      case v^.kind of
        jsNull, jsFalse, jsTrue, jsNumber, jsString: ;
        jsArray, jsObject:
          if (i >= 1) and (i <= v^.count) then begin
            p := v^.first;
            n := 1;
            while n < i do begin
              p := p^.next;
              n := n + 1
            end;
            At := p
          end
      end
  end;

  { The member of an object with this name, or nil. }
  function Member(v: JsonPtr; name: JsonName): JsonPtr;
  var p: JsonPtr; found: JsonPtr;
  begin
    found := nil;
    if v <> nil then
      if v^.kind = jsObject then begin
        p := v^.first;
        while (p <> nil) and (found = nil) do begin
          if p^.name = name then found := p;
          p := p^.next
        end
      end;
    Member := found
  end;

  { The name of the i'th member of an object, or the empty string. }
  function NameAt(v: JsonPtr; i: integer): JsonName;
  var p: JsonPtr;
  begin
    NameAt := '';
    if v <> nil then
      if v^.kind = jsObject then begin
        p := v.At(i);
        if p <> nil then NameAt := p^.name
      end
  end;

  function NumberOr(v: JsonPtr; whenBad: real): real;
  begin
    NumberOr := whenBad;
    if v <> nil then
      if v^.kind = jsNumber then NumberOr := v^.num
  end;

  { The value as an integer, when it was written as one and fits. `whenBad`
    otherwise -- including for a number that has a fraction, since 1.5 is not
    an integer and answering 1 would be a different message. }
  function IntegerOr(v: JsonPtr; whenBad: integer): integer;
  begin
    IntegerOr := whenBad;
    if v <> nil then
      if v^.kind = jsNumber then
        if v^.whole then IntegerOr := v^.inum
  end;

  function BooleanOr(v: JsonPtr; whenBad: boolean): boolean;
  begin
    BooleanOr := whenBad;
    if v <> nil then
      case v^.kind of
        jsTrue: BooleanOr := true;
        jsFalse: BooleanOr := false;
        jsNull, jsNumber, jsString, jsArray, jsObject: ;
      end
  end;

  function IsNull(v: JsonPtr): boolean;
  begin
    IsNull := (v = nil) or (v^.kind = jsNull)
  end;

  { The length of a string value in bytes; 0 for anything else. }
  function TextLen(v: JsonPtr): integer;
  begin
    TextLen := 0;
    if v <> nil then
      if v^.kind = jsString then TextLen := v^.text.Len
  end;

  { The i'th byte of a string value, 1-based. }
  function TextAt(v: JsonPtr; i: integer): char;
  begin
    TextAt := v^.text.At(i)
  end;

  { A string value copied into `s`. `errAbsent` when the value is not a
    string, `errFull` when it does not fit. }
  function TextInto(v: JsonPtr; var s: string): ErrorCode;
  begin
    if v = nil then TextInto := errAbsent
    else if v^.kind <> jsString then TextInto := errAbsent
    else TextInto := v^.text.Into(s)
  end;

  { Append `item` to an array. The array takes ownership: freeing it frees
    the item, and a caller must not free the item itself. }
  procedure Append(arr: JsonPtr; item: JsonPtr);
  begin
    if (arr <> nil) and (item <> nil) then
      if arr^.kind = jsArray then Attach(arr, item)
  end;

  { Put `item` in an object under `name`, replacing a member of that name.
    Takes ownership, as `Append` does. }
  procedure Put(obj: JsonPtr; name: JsonName; item: JsonPtr);
  var p, prev: JsonPtr;
  begin
    if (obj <> nil) and (item <> nil) then
      if obj^.kind = jsObject then begin
        item^.name := name;
        { Replacing in place keeps the written order, which is what a reader of
          the output expects and what a round-trip through this module should
          not disturb. }
        p := obj^.first;
        prev := nil;
        while (p <> nil) and (p^.name <> name) do begin
          prev := p;
          p := p^.next
        end;
        if p = nil then Attach(obj, item)
        else begin
          item^.next := p^.next;
          if prev = nil then obj^.first := item
          else prev^.next := item;
          if obj^.last = p then obj^.last := item;
          p^.next := nil;
          p.Free
        end
      end
  end;

  { Append to a string value, which is how a caller builds one longer than
    any capacity it can declare. }
  procedure TextAdd(v: JsonPtr; s: string);
  begin
    if v <> nil then
      if v^.kind = jsString then v^.text.AddText(s)
  end;

  { Append the document's text to `out`. No spaces and no newlines: what this
    writes is what a protocol wants, and a caller wanting it readable is
    writing it for a person rather than for a peer. }
  procedure Render(v: JsonPtr; var out: JsonChars);
  var kid: JsonPtr; nm: JsonChars; k: integer;
  begin
    if v = nil then
      out.AddText('null')
    else
      case v^.kind of
        jsNull:  out.AddText('null');
        jsTrue:  out.AddText('true');
        jsFalse: out.AddText('false');
        jsNumber: RenderNumber(v, out);
        jsString: RenderText(v^.text, out);
        jsArray: begin
          out.Add('[');
          kid := v^.first;
          while kid <> nil do begin
            kid.Render(out);
            kid := kid^.next;
            if kid <> nil then out.Add(',')
          end;
          out.Add(']')
        end;
        jsObject: begin
          out.Add('{');
          kid := v^.first;
          while kid <> nil do begin
            { A name is a string value like any other and is escaped by the same
              routine, which is why it is put into a buffer first rather than
              written out with quotes around it. }
            nm.Init;
            for k := 1 to length(kid^.name) do
              nm.Add(kid^.name[k]);
            RenderText(nm, out);
            nm.Free;
            out.Add(':');
            kid.Render(out);
            kid := kid^.next;
            if kid <> nil then out.Add(',')
          end;
          out.Add('}')
        end
      end
  end;
end;

{ --- building ------------------------------------------------------------- }

function JsonNewNull;
begin JsonNewNull := FreshNode(jsNull) end;

function JsonNewBoolean;
begin
  if b then JsonNewBoolean := FreshNode(jsTrue)
  else JsonNewBoolean := FreshNode(jsFalse)
end;

function JsonNewNumber;
var p: JsonPtr;
begin
  p := FreshNode(jsNumber);
  p^.num := x;
  p^.whole := false;
  p^.inum := 0;
  JsonNewNumber := p
end;

function JsonNewInteger;
var p: JsonPtr;
begin
  p := FreshNode(jsNumber);
  p^.num := n;
  p^.whole := true;
  p^.inum := n;
  JsonNewInteger := p
end;

function JsonNewText;
var p: JsonPtr;
begin
  p := FreshNode(jsString);
  p^.text.AddText(s);
  JsonNewText := p
end;

function JsonNewArray;
begin JsonNewArray := FreshNode(jsArray) end;

function JsonNewObject;
begin JsonNewObject := FreshNode(jsObject) end;

{ --- parsing -------------------------------------------------------------- }

{ The cursor travels as a `var` parameter rather than living in the module.
  A module variable would be shared by every parse in a program, and a client
  that parses a message while rendering another is the ordinary case here. }

function AtEnd(var b: JsonChars; i: integer): boolean;
begin
  AtEnd := i > b.Len
end;

{ RFC 8259 §2: space, horizontal tab, line feed, carriage return, and nothing
  else -- a form feed is whitespace in Pascal and is not in JSON. }
procedure SkipWhite(var b: JsonChars; var i: integer);
var c: char; going: boolean;
begin
  going := true;
  while going do
    if AtEnd(b, i) then going := false
    else begin
      c := b.At(i);
      if (c = ' ') or (c = chr(9)) or (c = chr(10)) or (c = chr(13)) then
        i := i + 1
      else
        going := false
    end
end;

function Peek(var b: JsonChars; i: integer): char;
begin
  if AtEnd(b, i) then Peek := chr(0) else Peek := b.At(i)
end;

{ One of the three literals, matched whole: `truex` is not `true` followed by
  anything, because the value would then end inside a name. }
function MatchWord(var b: JsonChars; var i: integer; w: JsonLine): boolean;
var k: integer; ok: boolean;
begin
  ok := true;
  for k := 1 to length(w) do
    if Peek(b, i + k - 1) <> w[k] then ok := false;
  if ok then i := i + length(w);
  MatchWord := ok
end;

function Digit(c: char): boolean;
begin
  Digit := (c >= '0') and (c <= '9')
end;

function HexVal(c: char; var ok: boolean): integer;
begin
  HexVal := 0;
  if (c >= '0') and (c <= '9') then HexVal := ord(c) - ord('0')
  else if (c >= 'a') and (c <= 'f') then HexVal := ord(c) - ord('a') + 10
  else if (c >= 'A') and (c <= 'F') then HexVal := ord(c) - ord('A') + 10
  else ok := false
end;

{ A code point as UTF-8. This is the one place this module writes bytes it was
  not given, `\uXXXX` being the only thing in JSON that names a character
  rather than carrying one. }
procedure PushUtf8(var t: JsonChars; cp: integer);
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

function Hex4(var b: JsonChars; var i: integer; var ok: boolean): integer;
var k, acc: integer;
begin
  acc := 0;
  for k := 1 to 4 do begin
    acc := acc * 16 + HexVal(Peek(b, i), ok);
    i := i + 1
  end;
  Hex4 := acc
end;

{ The body of a string, from the opening quote to the closing one, decoded into
  `t`. False on a syntax error, and `i` is then where it was noticed.

  RFC 8259 §7: a control character below U+0020 may not appear unescaped, which
  is checked because a raw newline inside a string is the commonest way a
  hand-written document is wrong. Every other byte is passed through unread --
  this module does not decide whether the input is well-formed UTF-8, and says
  so in its heading. }
function ParseStringInto(var b: JsonChars; var i: integer;
                         var t: JsonChars): boolean;
var c: char; ok, going: boolean; cp, lo: integer;
begin
  ok := Peek(b, i) = '"';
  if ok then begin
    i := i + 1;
    going := true;
    while going and ok do
      if AtEnd(b, i) then begin
        ok := false;
        going := false
      end
      else begin
        c := b.At(i);
        if c = '"' then begin
          i := i + 1;
          going := false
        end
        else if ord(c) < 32 then begin
          ok := false;
          going := false
        end
        else if c <> '\' then begin
          t.Add(c);
          i := i + 1
        end
        else begin
          i := i + 1;
          c := Peek(b, i);
          i := i + 1;
          if c = '"' then t.Add('"')
          else if c = '\' then t.Add('\')
          else if c = '/' then t.Add('/')
          else if c = 'b' then t.Add(chr(8))
          else if c = 'f' then t.Add(chr(12))
          else if c = 'n' then t.Add(chr(10))
          else if c = 'r' then t.Add(chr(13))
          else if c = 't' then t.Add(chr(9))
          else if c = 'u' then begin
            cp := Hex4(b, i, ok);
            { A surrogate pair is two escapes and one character. A high
              surrogate not followed by a low one is refused rather than
              written out, because what it would encode is not a character and
              PasUnicode would then reject the result of a successful parse. }
            if ok and (cp >= 55296) and (cp <= 56319) then
              if (Peek(b, i) = '\') and (Peek(b, i + 1) = 'u') then begin
                i := i + 2;
                lo := Hex4(b, i, ok);
                if ok and (lo >= 56320) and (lo <= 57343) then
                  cp := 65536 + (cp - 55296) * 1024 + (lo - 56320)
                else
                  ok := false
              end
              else
                ok := false
            else if ok and (cp >= 56320) and (cp <= 57343) then
              ok := false;
            if ok then PushUtf8(t, cp)
          end
          else
            ok := false;
          if not ok then going := false
        end
      end
  end;
  ParseStringInto := ok
end;

{ RFC 8259 §6's number, read correctly rounded (ADR-0314).

  **What this used to do and why it was wrong.** It accumulated the digits into
  a `real` and then scaled by ten *once per decade*, so a value with a large
  exponent was rounded as many times as its exponent had decades and a
  mantissa past 2^53 was inexact before the scaling began. ADR-0309 made that
  visible rather than causing it: the writer began rendering the shortest
  spelling that reads back, so the case could ask whether the reader read its
  own output, and the answer was FALSE for `1E+300`, `1E-7`,
  `1.7976931348623157E+308` and `2.2250738585072014E-308`.

  **What it does now is hand the value to the language.** The scan is
  unchanged -- it still validates RFC 8259 §6's grammar exactly, which is
  stricter than Pascal's, and still advances `i` -- but it no longer computes.
  It normalises what it reads into a significand and a decimal exponent,
  writes them as a Pascal real-literal, and `readstr` converts it. That goes
  through ISO/IEC 10206:1991 §6.9.5 to the same routine `read(f, r)` uses,
  which is correctly rounded, so this module gets the answer without owning
  the arithmetic. Correctly rounding a decimal to a double is a decision with
  its own arithmetic and the language had already taken it.

  **The one place it is not exact is stated rather than hidden.** At most
  `SigMax` significant digits are kept and the rest move into the exponent, so
  a number written with more than that many is rounded from its first
  `SigMax`. Seventeen identify a double, so the digits dropped can only matter
  where the value sits within 10^-(SigMax-17) of a halfway point -- which a
  document has to be built to hit. Keeping them all would need a string with
  no capacity, and this language has none. }
function ParseNumberNode(var b: JsonChars; var i: integer;
                         var e: ErrorCode): JsonPtr;
var mant: real; neg, ok, exneg, plain, any: boolean;
    p: JsonPtr; ex, dexp: integer;
    sig: JsonSig; text: JsonNumText;

  { A significant digit, or the place value of one there is no room for.
    Dropping a digit of the integer part leaves its place behind, so the
    exponent takes it; dropping one of the fraction part cancels against the
    -1 that appending it would have carried, so nothing happens. }
  procedure Keep(c: char; fraction: boolean);
  begin
    if (c = '0') and not any then begin
      { A leading zero contributes no digit. Before the point it contributes
        nothing at all; after it, it shifts what follows one place down. }
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

begin
  ok := true;
  plain := true;
  neg := false;
  any := false;
  dexp := 0;
  sig := '';
  if Peek(b, i) = '-' then begin
    neg := true;
    i := i + 1
  end;
  if Peek(b, i) = '0' then begin
    i := i + 1;
    Keep('0', false);
    if Digit(Peek(b, i)) then ok := false
  end
  else if Digit(Peek(b, i)) then
    while Digit(Peek(b, i)) do begin
      Keep(b.At(i), false);
      i := i + 1
    end
  else
    ok := false;
  if ok and (Peek(b, i) = '.') then begin
    plain := false;
    i := i + 1;
    if not Digit(Peek(b, i)) then ok := false;
    while ok and Digit(Peek(b, i)) do begin
      Keep(b.At(i), true);
      i := i + 1
    end
  end;
  if ok and ((Peek(b, i) = 'e') or (Peek(b, i) = 'E')) then begin
    plain := false;
    i := i + 1;
    exneg := false;
    if Peek(b, i) = '-' then begin exneg := true; i := i + 1 end
    else if Peek(b, i) = '+' then i := i + 1;
    if not Digit(Peek(b, i)) then ok := false;
    ex := 0;
    while ok and Digit(Peek(b, i)) do begin
      { A document may write any exponent it likes; what this refuses is one
        the exponent arithmetic below could not hold. The bound is far past
        the range of a double either way -- what is outside it is `inf` or
        zero, which is what it was before. }
      if ex > 10000 then ok := false
      else ex := ex * 10 + (ord(b.At(i)) - ord('0'));
      i := i + 1
    end;
    if ok then
      if exneg then dexp := dexp - ex else dexp := dexp + ex
  end;
  if not ok then begin
    e := errSyntax;
    ParseNumberNode := nil
  end
  else begin
    { No significant digit at all is the one value the conversion cannot be
      asked for: `0`, `0.000` and `0E9` are all zero, and `E-3` is not a
      real-literal. }
    if not any then mant := 0.0
    else begin
      { Written as a real-literal and read back as one, which is the whole of
        the conversion: 6.9.5's two required procedures are how a program
        hands a value to the language's own number reading and takes the
        answer back. The exponent writes its own sign. }
      writestr(text, sig, 'E', dexp:1);
      readstr(text, mant)
    end;
    if neg then mant := -mant;
    p := FreshNode(jsNumber);
    p^.num := mant;
    if plain and (mant <= maxint) and (mant >= -maxint) then begin
      p^.whole := true;
      p^.inum := trunc(mant)
    end
    else begin
      p^.whole := false;
      p^.inum := 0
    end;
    ParseNumberNode := p
  end
end;

function ParseValue(var b: JsonChars; var i: integer; depth: integer;
                    var e: ErrorCode): JsonPtr; forward;

{ An array or an object. One routine because the two differ in three places --
  the brackets, whether a member has a name, and nothing else -- and a second
  copy would be a second place for the comma rule to be wrong. }
function ParseGroup(var b: JsonChars; var i: integer; depth: integer;
                    named: boolean; var e: ErrorCode): JsonPtr;
var owner, item: JsonPtr; closer: char; going, first: boolean;
    nm: JsonChars; s: JsonName;
begin
  if named then closer := '}' else closer := ']';
  if named then owner := FreshNode(jsObject) else owner := FreshNode(jsArray);
  i := i + 1;
  going := true;
  first := true;
  while going and (e = errNone) do begin
    SkipWhite(b, i);
    if Peek(b, i) = closer then begin
      i := i + 1;
      going := false
    end
    else if AtEnd(b, i) then
      e := errSyntax
    else begin
      if not first then
        if Peek(b, i) = ',' then begin
          i := i + 1;
          SkipWhite(b, i)
        end
        else
          e := errSyntax;
      if e = errNone then begin
        s := '';
        if named then begin
          nm.Init;
          if not ParseStringInto(b, i, nm) then e := errSyntax
          else if nm.Len > JsonNameMax then e := errFull
          else e := nm.Into(s);
          nm.Free;
          if e = errNone then begin
            SkipWhite(b, i);
            if Peek(b, i) = ':' then i := i + 1 else e := errSyntax;
            SkipWhite(b, i)
          end
        end;
        if e = errNone then begin
          item := ParseValue(b, i, depth + 1, e);
          if e = errNone then begin
            item^.name := s;
            Attach(owner, item)
          end
        end;
        first := false
      end
    end
  end;
  if e <> errNone then begin
    owner.Free;
    ParseGroup := nil
  end
  else
    ParseGroup := owner
end;

function ParseValue;
var c: char; p: JsonPtr;
begin
  ParseValue := nil;
  SkipWhite(b, i);
  if depth > JsonDepthMax then
    e := errRange
  else if AtEnd(b, i) then
    e := errSyntax
  else begin
    c := b.At(i);
    if c = '{' then ParseValue := ParseGroup(b, i, depth, true, e)
    else if c = '[' then ParseValue := ParseGroup(b, i, depth, false, e)
    else if c = '"' then begin
      p := FreshNode(jsString);
      if ParseStringInto(b, i, p^.text) then ParseValue := p
      else begin
        p.Free;
        e := errSyntax
      end
    end
    else if c = 't' then
      if MatchWord(b, i, 'true') then ParseValue := FreshNode(jsTrue)
      else e := errSyntax
    else if c = 'f' then
      if MatchWord(b, i, 'false') then ParseValue := FreshNode(jsFalse)
      else e := errSyntax
    else if c = 'n' then
      if MatchWord(b, i, 'null') then ParseValue := FreshNode(jsNull)
      else e := errSyntax
    else if (c = '-') or Digit(c) then
      ParseValue := ParseNumberNode(b, i, e)
    else
      e := errSyntax
  end
end;

function JsonParseChars;
var e: ErrorCode; v: JsonPtr;
begin
  e := errNone;
  at := 1;
  v := ParseValue(b, at, 1, e);
  if e = errNone then begin
    { RFC 8259 §2: a document is one value. Trailing text is a separate
      message arriving in the same buffer, and answering the first value would
      hide that from the caller who has to frame them. }
    SkipWhite(b, at);
    if not AtEnd(b, at) then begin
      v.Free;
      e := errSyntax
    end
  end;
  if e = errNone then r := v else r := e
end;

function JsonParse;
var b: JsonChars;
begin
  b.Init;
  b.AddText(s);
  r := JsonParseChars(b, at);
  b.Free
end;

end.
