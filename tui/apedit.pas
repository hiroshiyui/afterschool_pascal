{ The editor, with no terminal in it.

  **This module is the whole of what the IDE decides**, and it decides it
  without reading a byte from a descriptor or writing one to it: a key comes
  in as a value, and what comes out is a *screen* -- rows by columns of
  characters, with the cursor's cell -- which the caller may put on a terminal
  or compare against a golden.

  That split is why the program is testable at all (ADR-0381). `ctest` has no
  terminal; a case that wanted one would need a pseudo-terminal binding, which
  ADR-0262 declined on the grounds that such a case becomes a test of the
  binding rather than of the program. Rendering to a buffer costs nothing and
  moves every decision this program makes to the side of the line a golden can
  reach: what is left outside is the shell, which reads `PasTerm.ReadKey` and
  writes `PasTerm.CursorTo`, and which `doc/sop.md` 7 says nothing checks.

  **The screen is the unit of comparison and not the buffer.** A test that
  asserted the buffer would pass on an editor that edits correctly and draws
  nothing; what a person notices is the drawing, so that is what a session
  diffs. The buffer is reached through the screen, which is the same
  arrangement `lsp/run.py` has with a document -- a conversation is compared,
  not an internal.

  **A key is decoded here too**, because which bytes mean which key is a
  question about a terminal and not about a descriptor: `PasTerm.ReadKey`
  answers one byte and says so, and an arrow arrives as three. The decoder is
  a state machine over bytes rather than a lookahead, since a program that is
  handed one byte at a time cannot look ahead.

  What is *not* here: display width, which AP 6.4.15 NOTE 14 leaves out of
  this language, so a column is a byte and a program drawing East Asian text
  will draw it wrongly and this says so; and any notion of the terminal's
  size changing, which is `SIGWINCH` and has no shape in this language --
  the caller passes the size it wants drawn on every render. }

module ApEdit;

export ApEdit = (ColsMax, RowsMax, LineMax, EditLine, ScreenRow, Screen,
                 KeyKind, kkNone, kkChar, kkEnter, kkBack, kkDelete,
                 kkLeft, kkRight, kkUp, kkDown, kkHome, kkEnd,
                 kkSave, kkQuit, kkBuild, kkUnknown,
                 Key, Decoder, Editor,
                 EditInit, EditFree, EditPush, EditKey, EditRender,
                 EditDirty, EditLines, EditLine_, EditRow, EditCol,
                 EditName, EditSetName, EditSay,
                 DecodeInit, DecodeByte);

import PasError;
       PasStrVec;

const
  { A screen wider or taller than this is drawn to these bounds and the rest
    of the terminal is left alone. 200x80 covers every terminal a person
    edits in; a fixed bound is what ADR-0012 asks for, and it is checked
    where the size arrives rather than trusted. }
  ColsMax = 400;
  RowsMax = 200;
  { A line longer than this cannot be held, which is `PasStrVec`'s own bound
    (`ItemMax`) and not a second one -- the buffer is a StrVec, so saying a
    larger number here would be saying it twice and wrongly. }
  LineMax = ItemMax;

type
  EditLine = StrItem;
  ScreenRow = string(ColsMax);

  { What the caller draws. `rows` and `cols` are what was asked for and are
    what a reader of a golden counts; `at` is the cell the cursor belongs in,
    in the same coordinates, so the shell writes one `CursorTo` and no
    arithmetic of its own. }
  Screen = record
    rows, cols: integer;
    line: array [1..RowsMax] of ScreenRow;
    atRow, atCol: integer
  end;

  { A key, after the bytes have been put back together. `kkUnknown` is an
    escape sequence this program does not know: it is reported rather than
    dropped, because a key that does nothing and a key that was misread look
    the same to a person and only one of them is a defect here. }
  KeyKind = (kkNone, kkChar, kkEnter, kkBack, kkDelete,
             kkLeft, kkRight, kkUp, kkDown, kkHome, kkEnd,
             kkSave, kkQuit, kkBuild, kkUnknown);

  Key = record
    kind: KeyKind;
    ch: char            { only when kind = kkChar }
  end;

  { The state between bytes. A terminal sends `ESC [ A` for an up arrow and
    `ESC` alone for the escape key, and nothing but the next byte -- or its
    absence -- tells them apart; this program takes the first reading, which
    is every editor's, and leaves the second to a caller that wants a
    timeout. }
  Decoder = record
    n: integer;         { how many bytes of a sequence are in hand }
    b: array [1..8] of char
  end;

  { The document and where the caller is in it. `top` is the first line drawn,
    so scrolling is a property of the render and not of the cursor. }
  Editor = record
    lines: StrVecPtr;
    row, col: integer;  { 1-based, in the document }
    top: integer;
    dirty: boolean;
    name: EditLine;
    says: EditLine      { the message line: what just happened }
  end;

{ An editor holding one empty line, which is what an empty document is: a
  buffer with no lines has no cursor position, and every operation below
  would need an arm for it. }
procedure EditInit(var ed: Editor);

{ Give back the buffer. A second call is harmless. }
procedure EditFree(var ed: Editor);

{ Append a line, as loading a file does. It does not move the cursor and does
  not mark the document dirty -- what is loaded is what is on disc. }
procedure EditPush(var ed: Editor; s: EditLine);

{ Apply one key. Everything the editor *does* is here, so a session that
  feeds keys and renders exercises all of it. }
procedure EditKey(var ed: Editor; k: Key);

{ Draw. `rows` and `cols` are the terminal's, clamped to the bounds above;
  the last row is the status line and the one before it is what the editor
  has to say, so a document is drawn into `rows - 2`. }
procedure EditRender(var ed: Editor; rows, cols: integer; var scr: Screen);

{ Answers about the editor, so a caller need not reach into the record. }
function EditDirty(var ed: Editor): boolean;
function EditLines(var ed: Editor): integer;
function EditRow(var ed: Editor): integer;
function EditCol(var ed: Editor): integer;
function EditName(var ed: Editor): EditLine;
function EditLine_(var ed: Editor; n: integer): EditLine;

{ The document's name, and what the editor is saying. Both are the shell's to
  set -- it is the half that knows about files and about running a compiler. }
procedure EditSetName(var ed: Editor; s: EditLine);
procedure EditSay(var ed: Editor; s: EditLine);

{ No bytes in hand. }
procedure DecodeInit(var d: Decoder);

{ Offer one byte. Answers true when `k` is a key, and false when more bytes
  are needed -- which is the whole of the interface, because a caller reading
  one byte at a time cannot be asked anything else. }
function DecodeByte(var d: Decoder; c: char; var k: Key): boolean;

end;

const
  Esc = 27;

procedure EditInit;
begin
  SVecNew(ed.lines, 64);
  SVecPush(ed.lines, '');
  ed.row := 1;
  ed.col := 1;
  ed.top := 1;
  ed.dirty := false;
  ed.name := '';
  ed.says := ''
end;

procedure EditFree;
begin
  SVecFree(ed.lines)
end;

procedure EditPush;
begin
  { The line an empty editor starts with is not a line of the document: the
    first push replaces it rather than sitting under it, or every loaded file
    would gain a blank first line. }
  if (SVecLen(ed.lines) = 1) and (SVecGet(ed.lines, 1) = '') then
    SVecSet(ed.lines, 1, s)
  else
    SVecPush(ed.lines, s)
end;

function EditDirty;
begin
  EditDirty := ed.dirty
end;

function EditLines;
begin
  EditLines := SVecLen(ed.lines)
end;

function EditRow;
begin
  EditRow := ed.row
end;

function EditCol;
begin
  EditCol := ed.col
end;

function EditName;
begin
  EditName := ed.name
end;

function EditLine_;
begin
  if (n < 1) or (n > SVecLen(ed.lines)) then EditLine_ := ''
  else EditLine_ := SVecGet(ed.lines, n)
end;

procedure EditSetName;
begin
  ed.name := s
end;

procedure EditSay;
begin
  ed.says := s
end;

{ The first `n` characters, and everything from the `i`th. Both answer the
  null-string where the standard's substring would not exist at all: 6.5.6
  requires an index and a length that name characters the value has, and
  every editing operation below is naturally written with an empty half at
  one end or the other. Writing the guard once here is what keeps `EditKey`
  readable, and it is the same reason `PasText` has `TrimStart`. }
function Left(s: EditLine; n: integer): EditLine;
begin
  if n <= 0 then Left := ''
  else if n >= length(s) then Left := s
  else Left := substr(s, 1, n)
end;

function From(s: EditLine; i: integer): EditLine;
begin
  if i <= 1 then From := s
  else if i > length(s) then From := ''
  else From := substr(s, i, length(s) - i + 1)
end;

{ Put the cursor somewhere that exists. Called after every movement rather
  than at each site, because the six ways to move share one rule -- a column
  is 1..length+1, the last being the position after the final character where
  typing appends. }
procedure Clamp(var ed: Editor);
var n: integer;
begin
  if ed.row < 1 then ed.row := 1;
  if ed.row > SVecLen(ed.lines) then ed.row := SVecLen(ed.lines);
  n := length(SVecGet(ed.lines, ed.row));
  if ed.col < 1 then ed.col := 1;
  if ed.col > n + 1 then ed.col := n + 1
end;

procedure EditKey;
var cur, rest: EditLine; k2: integer;
begin
  { **The message is about the last key**, so it is cleared here and set by
    whichever arm has something to say. The alternative -- leaving it until
    something replaces it -- was tried first and the session golden showed
    what is wrong with it: `unknown key` stayed on the screen while the person
    typed, describing a key two keystrokes ago. It also gives the shell the
    behaviour it wants for free: `saved` stands until the next key touches
    the document, which is exactly how long it is true. }
  ed.says := '';
  cur := SVecGet(ed.lines, ed.row);
  case k.kind of
    kkChar: begin
      { A line that is full swallows the key rather than losing its tail:
        `StrItem` is a fixed capacity and 6.4.6's assignment would truncate,
        which loses a character the person can see nothing of. Saying so is
        the message line's job. }
      if length(cur) >= LineMax then
        ed.says := 'line is full'
      else begin
        SVecSet(ed.lines, ed.row,
                Left(cur, ed.col - 1) + k.ch + From(cur, ed.col));
        ed.col := ed.col + 1;
        ed.dirty := true
      end
    end;
    kkEnter: begin
      { Split. The tail moves to a new line inserted after this one, which
        `PasStrVec` has no operation for -- so the lines below are pushed
        down by one and rewritten, which is what a vector costs and is
        invisible at the sizes an editor holds. }
      rest := From(cur, ed.col);
      SVecSet(ed.lines, ed.row, Left(cur, ed.col - 1));
      SVecPush(ed.lines, '');
      for k2 := SVecLen(ed.lines) - 1 downto ed.row + 1 do
        SVecSet(ed.lines, k2 + 1, SVecGet(ed.lines, k2));
      SVecSet(ed.lines, ed.row + 1, rest);
      ed.row := ed.row + 1;
      ed.col := 1;
      ed.dirty := true
    end;
    kkBack: begin
      if ed.col > 1 then begin
        SVecSet(ed.lines, ed.row, Left(cur, ed.col - 2) + From(cur, ed.col));
        ed.col := ed.col - 1;
        ed.dirty := true
      end
      else if ed.row > 1 then begin
        { Join with the line above, and the cursor lands where the join is
          rather than at either end -- which is where the person was
          looking. }
        rest := SVecGet(ed.lines, ed.row - 1);
        ed.col := length(rest) + 1;
        SVecSet(ed.lines, ed.row - 1, rest + cur);
        for k2 := ed.row to SVecLen(ed.lines) - 1 do
          SVecSet(ed.lines, k2, SVecGet(ed.lines, k2 + 1));
        rest := SVecPop(ed.lines);
        ed.row := ed.row - 1;
        ed.dirty := true
      end
    end;
    kkDelete: begin
      if ed.col <= length(cur) then begin
        SVecSet(ed.lines, ed.row, Left(cur, ed.col - 1) + From(cur, ed.col + 1));
        ed.dirty := true
      end
      else if ed.row < SVecLen(ed.lines) then begin
        SVecSet(ed.lines, ed.row, cur + SVecGet(ed.lines, ed.row + 1));
        for k2 := ed.row + 1 to SVecLen(ed.lines) - 1 do
          SVecSet(ed.lines, k2, SVecGet(ed.lines, k2 + 1));
        rest := SVecPop(ed.lines);
        ed.dirty := true
      end
    end;
    kkLeft: begin
      if ed.col > 1 then ed.col := ed.col - 1
      else if ed.row > 1 then begin
        ed.row := ed.row - 1;
        ed.col := length(SVecGet(ed.lines, ed.row)) + 1
      end
    end;
    kkRight: begin
      if ed.col <= length(cur) then ed.col := ed.col + 1
      else if ed.row < SVecLen(ed.lines) then begin
        ed.row := ed.row + 1;
        ed.col := 1
      end
    end;
    kkUp: ed.row := ed.row - 1;
    kkDown: ed.row := ed.row + 1;
    kkHome: ed.col := 1;
    kkEnd: ed.col := length(cur) + 1;
    { **The shell acts on these and the model does not**, which is what keeps
      the model free of files and processes: saving is a write and building
      is a `PasProcess.Execute`, and neither is a decision about a document.
      They are still `Key` values because they arrive as bytes among the
      others and the decoder is the one place that knows which. }
    kkSave, kkQuit, kkBuild: ;
    { A sequence nothing here knows. Reported, because a key that does
      nothing and a key that was misread look alike to a person. }
    kkUnknown: ed.says := 'unknown key';
    kkNone: ;
  end;
  Clamp(ed)
end;

procedure EditRender;
var r, h, n, wide: integer; s: EditLine; row: ScreenRow; num: EditLine;
begin
  { The size the caller asked for, held to what this can draw. Three rows is
    the least that has a document in it, the last two being the message and
    the status. }
  if rows > RowsMax then rows := RowsMax;
  if rows < 3 then rows := 3;
  if cols > ColsMax then cols := ColsMax;
  if cols < 8 then cols := 8;
  scr.rows := rows;
  scr.cols := cols;
  h := rows - 2;

  { Scroll so the cursor is on screen. This is why the editor is a `var`
    parameter of a routine that only draws: where the window sits is a
    property of the last drawing and not of the document, and keeping it
    anywhere else would mean the caller had to know the height. }
  if ed.row < ed.top then ed.top := ed.row;
  if ed.row > ed.top + h - 1 then ed.top := ed.row - h + 1;
  if ed.top < 1 then ed.top := 1;

  for r := 1 to h do begin
    n := ed.top + r - 1;
    if n > SVecLen(ed.lines) then s := '~'
    else s := SVecGet(ed.lines, n);
    { No horizontal scrolling: a line wider than the window is cut, and the
      cursor stops at the last column rather than following the text off the
      edge. It is a milestone-one limitation and a person meets it on a long
      line, so the *cursor* is what says so rather than a message. }
    scr.line[r] := Left(s, cols)
  end;

  scr.line[rows - 1] := Left(ed.says, cols);

  { The status line, and it is the same shape a Turbo Pascal one was: what is
    being edited, whether it has been changed, and where the cursor is. }
  s := ed.name;
  if s = '' then s := '(no name)';
  if ed.dirty then s := s + ' *';
  writestr(num, ed.row:1, ':', ed.col:1);
  wide := cols - length(num);
  if wide < 1 then wide := 1;
  row := Left(s, wide);
  while length(row) < wide do row := row + ' ';
  scr.line[rows] := Left(row + num, cols);

  scr.atRow := ed.row - ed.top + 1;
  scr.atCol := ed.col;
  if scr.atCol > cols then scr.atCol := cols
end;

procedure DecodeInit;
begin
  d.n := 0
end;

function DecodeByte;
var b: integer;
begin
  DecodeByte := false;
  k.kind := kkNone;
  k.ch := ' ';
  b := ord(c);

  { Inside a sequence: `ESC [` and then one byte says which key, or a digit
    and a `~`. Anything else ends the sequence as `kkUnknown` -- the state is
    dropped rather than kept, because a decoder that waits for a byte that
    never comes stops the editor. }
  if d.n > 0 then begin
    d.n := d.n + 1;
    if d.n > 8 then begin
      d.n := 0;
      k.kind := kkUnknown;
      DecodeByte := true
    end
    else if (d.n = 2) and (c <> '[') then begin
      d.n := 0;
      k.kind := kkUnknown;
      DecodeByte := true
    end
    else if d.n >= 3 then begin
      DecodeByte := true;
      d.n := 0;
      if c = 'A' then k.kind := kkUp
      else if c = 'B' then k.kind := kkDown
      else if c = 'C' then k.kind := kkRight
      else if c = 'D' then k.kind := kkLeft
      else if c = 'H' then k.kind := kkHome
      else if c = 'F' then k.kind := kkEnd
      else if (c >= '0') and (c <= '9') then begin
        { A parameter is still coming: `ESC [ 3 ~` is Delete. Stay in the
          sequence. }
        d.n := 3;
        d.b[3] := c;
        DecodeByte := false
      end
      else if c = '~' then begin
        if d.b[3] = '3' then k.kind := kkDelete
        else if d.b[3] = '1' then k.kind := kkHome
        else if d.b[3] = '4' then k.kind := kkEnd
        else k.kind := kkUnknown
      end
      else k.kind := kkUnknown
    end
  end
  else if b = Esc then begin
    d.n := 1;
    d.b[1] := c
  end
  else begin
    DecodeByte := true;
    { The control keys this editor binds. Ctrl-letter is the letter's ordinal
      less 64, which is how a terminal has sent it since ASCII, and the three
      chosen are the three a Turbo Pascal user reaches for: save, quit, and
      build. }
    if b = 19 then k.kind := kkSave           { Ctrl-S }
    else if b = 17 then k.kind := kkQuit      { Ctrl-Q }
    else if b = 2 then k.kind := kkBuild      { Ctrl-B }
    else if (b = 13) or (b = 10) then k.kind := kkEnter
    else if (b = 8) or (b = 127) then k.kind := kkBack
    else if b < 32 then k.kind := kkUnknown
    else begin
      k.kind := kkChar;
      k.ch := c
    end
  end
end;

end.
