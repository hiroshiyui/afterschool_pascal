{ PasLsp -- the Language Server Protocol's framing, and nothing above it.

  `doc/roadmap.md` proposes a language server as **the caller**: the program
  large enough to say whether this dialect is pleasant to write in, which no
  gate here can measure. That chapter named one library gap before starting --
  JSON, now `PasJson` -- and said `PasStream` frames the messages. It does not,
  and this module is why.

  **A message is a byte count, not a line.** LSP frames each message as

      Content-Length: 42<CR><LF><CR><LF> then exactly 42 bytes

  so the header is line-oriented and the body is not, and a reader that has
  just consumed a header line will usually be holding the first bytes of the
  body as well. Nothing that reads *lines* can hand those back. `PasStream`
  reads lines; `PasIO` reads bytes into the caller's array and says how many
  arrived, and this module is the buffer between the two -- which has to exist
  somewhere, and whose only alternative is a one-byte read per header
  character, a system call per byte.

  So a `LspReader` is a record the caller declares and this module fills,
  which is `PasStream`'s shape and for the same reason (ADR-0130): the state
  belongs to the descriptor, and a module variable would make two servers in
  one program share a buffer.

  **The reader is lenient and the writer is not.** A bare `<LF>` ends a header
  line here, because a hand-written test message is the commonest input a
  server sees before it sees a client, and rejecting one teaches nothing. What
  this module *writes* is always `<CR><LF>`, which is what the specification
  says. Postel's rule, applied where it is safe: the leniency is in what is
  accepted and never in what is produced.

  **It does not read the message.** What comes back is the body's bytes, for
  `PasJson.JsonParseChars` to make a document of -- the framing and the
  content are two failures with two causes, and a routine answering both would
  have to say which in a code that has one field. }

module PasLsp;

export PasLsp = (LspBufMax, LspHeadMax, LspHeader, LspReader,
                 LspOpen, LspRead, LspWrite);

import PasError; PasIO; PasJson;

const
  { One read's worth. A message body may be any size -- it goes into a
    `JsonChars`, which grows -- and this bounds only how much arrives at once. }
  LspBufMax = 8192;
  { A header line. The specification has two headers and neither is long; a
    longer line is `errFull` rather than a silent truncation, because a
    truncated `Content-Length` is a number and would be believed. }
  LspHeadMax = 255;

type
  LspHeader = string(LspHeadMax);

  { A descriptor and whatever the last message did not use. `buf[head..tail]`
    is unconsumed; `head > tail` is empty. }
  LspReader = record
    fd: integer;
    head, tail: integer;
    ended: boolean;
    buf: array [1..LspBufMax] of char
  end;

{ Attach a reader to a descriptor. `LspOpen(r, StdIn)` is what a server does
  once; nothing is opened and nothing needs closing. }
procedure LspOpen(var r: LspReader; fd: integer);

{ Read one message's body, appending it to `body`. `errAbsent` at the end of
  the input, which is how a server's loop ends and is not a failure;
  `errSyntax` for a frame that is not one -- a missing or unreadable
  `Content-Length`, or an input that stops inside a body; `errFull` for a
  header line longer than `LspHeadMax`; `errIO` where the read was refused. }
function LspRead(var r: LspReader; var body: JsonChars): ErrorCode;

{ Write one message: the header, the blank line, and the body's bytes. }
function LspWrite(fd: integer; var body: JsonChars): ErrorCode;

end;

procedure LspOpen;
begin
  r.fd := fd;
  r.head := 1;
  r.tail := 0;
  r.ended := false
end;

{ True when `buf[head]` may be read. False at the end of the input and on a
  refusal, which `e` tells apart: end of input leaves it `errNone`, because
  ending is not a failure and only the caller knows whether it was expected. }
function Ready(var r: LspReader; var e: ErrorCode): boolean;
var got: CountResult;
begin
  if r.head <= r.tail then
    Ready := true
  else if r.ended then
    Ready := false
  else begin
    got := ReadInto(r.fd, r.buf[1..LspBufMax]);
    if not got.ok then begin
      e := got.cause;
      Ready := false
    end
    else if got.val = 0 then begin
      r.ended := true;
      Ready := false
    end
    else begin
      r.head := 1;
      r.tail := got.val;
      Ready := true
    end
  end
end;

function NextByte(var r: LspReader; var c: char; var e: ErrorCode): boolean;
begin
  if not Ready(r, e) then
    NextByte := false
  else begin
    c := r.buf[r.head];
    r.head := r.head + 1;
    NextByte := true
  end
end;

{ One header line, without its terminator. False at the end of the input --
  which before any header is the end of the stream and inside one is a
  truncated frame, and only the caller can tell those apart. }
function ReadHeaderLine(var r: LspReader; var line: LspHeader;
                        var e: ErrorCode): boolean;
var c: char; going, any: boolean;
begin
  line := '';
  any := false;
  going := true;
  while going do
    if not NextByte(r, c, e) then begin
      going := false;
      if e <> errNone then any := false
    end
    else begin
      any := true;
      if c = chr(10) then
        going := false
      else if length(line) >= LspHeadMax then begin
        e := errFull;
        going := false;
        any := false
      end
      else
        line := line + c
    end;
  { The specification writes <CR><LF>; a bare <LF> is accepted, so the carriage
    return is stripped here rather than required above.

    The length-one case is written out because §6.5.6 makes `s[1..0]` an
    **error**: "it shall be an error if ... the value of the first
    index-expression is greater than the value of the second". Extended Pascal
    has no empty substring, so the ordinary way to drop a string's last
    character traps on a string of one -- and the header line that ends a
    frame's headers is exactly one character, a bare carriage return. }
  if (length(line) > 0) and (line[length(line)] = chr(13)) then
    if length(line) = 1 then line := ''
    else line := line[1..length(line) - 1];
  ReadHeaderLine := any
end;

function Lower(s: LspHeader): LspHeader;
var i: integer; t: LspHeader;
begin
  { PasStrings has this and is an Extended Pascal module, which ADR-0119 will
    not link into a dialect program. The duplication is the price of the two
    layers and is named in ADR-0120. }
  t := '';
  for i := 1 to length(s) do
    if (s[i] >= 'A') and (s[i] <= 'Z') then
      t := t + chr(ord(s[i]) + 32)
    else
      t := t + s[i];
  Lower := t
end;

{ The digits after `Content-Length:`, or -1. Written here rather than through
  PasParse.ParseInt for one reason: this header may be followed by anything a
  client cares to add, and a value with trailing text is a frame this module
  cannot honour rather than a number to be lenient about. }
function ContentLength(s: LspHeader): integer;
var i, n: integer; ok, any: boolean; head: LspHeader;
begin
  ContentLength := -1;
  head := 'content-length:';
  if length(s) > length(head) then
    if Lower(s[1..length(head)]) = head then begin
      i := length(head) + 1;
      while (i <= length(s)) and (s[i] = ' ') do i := i + 1;
      n := 0;
      any := false;
      ok := true;
      while (i <= length(s)) and ok do begin
        if (s[i] >= '0') and (s[i] <= '9') then begin
          { A length beyond this is a client that has lost its mind, and
            forming it would trap (ADR-0014) rather than report. }
          if n > 100000000 then ok := false
          else n := n * 10 + (ord(s[i]) - ord('0'));
          any := true
        end
        else if s[i] = ' ' then begin
          { Trailing blanks only. }
          while (i <= length(s)) and (s[i] = ' ') do i := i + 1;
          if i <= length(s) then ok := false;
          i := i - 1
        end
        else
          ok := false;
        i := i + 1
      end;
      if ok and any then ContentLength := n
    end
end;

function LspRead;
var line: LspHeader; e: ErrorCode; n, k, got: integer; c: char;
    going, sawAny: boolean;
begin
  e := errNone;
  n := -1;
  sawAny := false;
  going := true;
  while going do
    if not ReadHeaderLine(r, line, e) then begin
      { No line at all. Before any header that is the end of the stream; after
        one it is a frame that stopped in its headers. }
      going := false;
      if e = errNone then
        if sawAny then e := errSyntax else e := errAbsent
    end
    else begin
      sawAny := true;
      if line = '' then
        going := false
      else begin
        got := ContentLength(line);
        if got >= 0 then n := got
      end
    end;
  if (e = errNone) and (n < 0) then e := errSyntax;
  if e = errNone then begin
    k := 0;
    while (k < n) and (e = errNone) do
      if NextByte(r, c, e) then begin
        JsonCharsAdd(body, c);
        k := k + 1
      end
      else if e = errNone then
        { The input ended inside the body: the count was a promise. }
        e := errSyntax
  end;
  LspRead := e
end;

function LspWrite;
var hdr: IOLine; e: ErrorCode; n, k, m: integer;
    chunk: array [1..LspBufMax] of char;
begin
  n := JsonCharsLen(body);
  writestr(hdr, 'Content-Length: ', n:1, chr(13), chr(10), chr(13), chr(10));
  e := WriteText(fd, hdr);
  k := 0;
  while (k < n) and (e = errNone) do begin
    m := 0;
    while (k < n) and (m < LspBufMax) do begin
      k := k + 1;
      m := m + 1;
      chunk[m] := JsonCharsAt(body, k)
    end;
    e := WriteAll(fd, chunk[1..m])
  end;
  LspWrite := e
end;

end.
