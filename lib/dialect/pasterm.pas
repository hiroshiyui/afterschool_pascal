{ PasTerm -- the terminal a program was started from: what it is, how big it
  is, and how to read a key rather than a line.

  Neither standard models a terminal. ISO/IEC 10206:1991 §6.11.4.2 gives a
  program `input` and `output`, and a text file says nothing about the device
  behind it: whether what a user types is echoed, whether it is assembled
  into lines before the program sees any of it, and how many columns there
  are to draw in are all questions §6.4.3.6 has no room for. They are `termios`', and this
  module is the Pascal over the runtime's binding to it, with the numbers each
  answer means made meaningful.

  **Nothing here declares a struct, and that is why the runtime is involved at
  all.** `struct termios` and `struct winsize` are layouts a library module may
  not carry (ADR-0185's fifth decision): `c_cc` is 32 elements on Linux and 20
  on macOS, and the *bit* each flag names differs as well as the offset, so a
  module holding either would be one platform's header written out as a
  constant. The five `pasx_term_*` routines are compiled by the C compiler of
  the machine being built for, which is where that question has a known answer
  (ADR-0186).

  **The saved settings are the runtime's, and there is one set of them.**
  `EnterRaw` cannot hand them back -- there is no type here that could hold
  them -- so the runtime keeps them and `LeaveRaw` puts them back. A second
  `EnterRaw` while one is outstanding is refused with `errFull` rather than
  counted: it would save the *raw* settings as though they were the original,
  and the restore after it would leave the user a shell that does not echo.
  `RawActive` is the question a caller cannot answer for itself.

  **And they are put back at exit**, by the runtime, whether or not a program
  remembers to. Raw mode is a property of the terminal and not of the process,
  so a program that stops without restoring hands its user a shell whose only
  remedy is `stty sane` typed blind. `halt`, a runtime error and an ordinary
  end of the program-block all reach it; a fatal signal does not, and nothing
  portable could make it. **Note also that raw mode clears the signal
  characters**: while it is entered, the interrupt character is a byte
  `ReadKey` answers and not a way for the user to stop the program, so a
  program that reads keys owes its user a way out.

  **Cursor movement and clearing are strings, not calls.** They are ANSI
  escape sequences -- bytes written to a stream -- and not system calls at all,
  so putting them in C would have bought nothing and would have taken from the
  caller the choice of *where* they go: `write(output, ClearScreen)` and
  `PasIO.WriteText(StdOut, ClearScreen)` are both right, for programs that
  differ in whether they mix with §6.10's buffered output. It is also what
  makes them checkable with no terminal present, which is most of what
  `tests/dialect/lib_term.pas` can do.

  **What is not here.** No terminfo, so a terminal that does not understand the
  sequences above is neither detected nor accommodated -- every terminal
  emulator in use understands them, and reading a compiled database is a
  library and not a module. No colour, which is the same sequences and can be
  added when a program needs one. No `tcsendbreak`, no modem control, and no
  notification that the window was resized: that is `SIGWINCH`, and a signal
  has no shape in this language. A caller that redraws asks `TermSize` again. }

module PasTerm;

export PasTerm = (SeqMax, TermSeq,
                  IsTerminal, TermSize, EnterRaw, LeaveRaw, RawActive,
                  ReadKey,
                  CursorTo, ClearScreen, ClearLine, HideCursor, ShowCursor);

{ 6.11.1 puts the import-part inside the module-block, after the export-part.
  `PasIO` supplies the descriptors and the one read: a key is a byte off a
  descriptor, and a module of its own for that would be a second binding of
  `read`. }
import PasError;
       PasIO;

const
  { The longest sequence below is six characters, and a cursor address with two
    four-figure coordinates is twelve. Twenty-four is room for both and for
    whatever a caller concatenates onto one. }
  SeqMax = 24;

type
  TermSeq = string(SeqMax);

{ Whether this descriptor is a terminal. A question about the world, and so a
  `boolean` (lib/dialect/README.md): `isatty` fails exactly when the answer is
  no, and there is no third outcome to report.

  It is asked of a *descriptor* because the answer differs between them -- a
  program whose output is redirected into a file still has a terminal on its
  error stream -- so a program deciding whether to draw asks about the
  descriptor it would draw on. }
function IsTerminal(fd: integer): boolean;

{ The window, in character cells, both counted from 1.

  `errAbsent` where the descriptor is not a terminal, or is one that does not
  know its own size -- an unsized pseudo-terminal answers zero for both, which
  is a size in the sense an empty string is a name. `errIO` where the system
  refused. `rows` and `cols` are 0 on every answer but `errNone`.

  POSIX has no window size at all; this is `TIOCGWINSZ`, which is BSD-derived
  and on every Unix. The alternative is the `COLUMNS` environment variable,
  which is a shell's opinion recorded before the window was last resized. }
function TermSize(fd: integer; var rows: integer;
                  var cols: integer): ErrorCode;

{ Enter raw mode on `fd`: no echo, no line assembly, no signal characters, no
  flow control, no output post-processing, and a read that answers as soon as
  one byte has arrived.

  `errAbsent` where the descriptor is not a terminal -- which is what a program
  whose input is redirected gets, and is an answer about where it is running
  rather than a failure of anything it did. `errFull` where raw mode is already
  entered: the runtime holds one set of saved settings and it is in use, and
  **nothing has been changed**. `errIO` where the system refused.

  What the terminal was is remembered by the runtime. See the module comment
  for why it is remembered there, and for what happens if the program never
  asks for it back. }
function EnterRaw(fd: integer): ErrorCode;

{ Leave raw mode, putting back what the terminal was.

  It takes no descriptor on purpose: the runtime knows which one it saved, and
  a caller passing another would be asking to write one terminal's settings
  onto a different one. `errAbsent` where raw mode was not entered, which is
  the harmless case a `defer LeaveRaw` reaches on a path that never entered it;
  `errIO` where the system refused. }
function LeaveRaw: ErrorCode;

{ Whether raw mode is entered. The state is the runtime's, so this is not a
  question a caller could answer by remembering. }
function RawActive: boolean;

{ The next byte from `fd`, as a character.

  In raw mode that is a key as soon as it is struck; outside it, this is an
  ordinary unbuffered read and a byte arrives only when the line does. A key
  that sends several bytes -- an arrow, a function key -- arrives as the
  several bytes it is, `chr(27)` first, and assembling those into a name is the
  caller's, because which sequence means which key is the terminal's business
  and not POSIX's.

  `errAbsent` at the end of the input, which for a terminal means the user
  closed it; `errIO` where the read was refused. `ch` is `chr(0)` on either.

  **It does not share a descriptor with §6.10's `read`.** This is a descriptor
  and unbuffered, and `input` is a runtime stream that reads ahead; a program
  mixing them loses characters to whichever buffered first, which is PasIO's
  own limitation met again and cannot be fixed from this side. }
function ReadKey(fd: integer; var ch: char): ErrorCode;

{ The escape sequence that moves the cursor to `row` and `col`, both counted
  from 1 as the terminal counts them. A coordinate below 1 is written as 1,
  there being no such cell and no way to report one from a routine that answers
  a string.

  These five are ANSI sequences and not system calls: what they answer is a
  string, and the caller decides where it goes. }
function CursorTo(row: integer; col: integer) = s: TermSeq;

{ Erase the whole window. It does not move the cursor -- `CursorTo(1, 1)` is
  the other half of what a caller usually wants. }
function ClearScreen = s: TermSeq;

{ Erase the line the cursor is on. }
function ClearLine = s: TermSeq;

{ Stop drawing the cursor, and draw it again. A program that redraws a whole
  screen hides it first, or the terminal shows it at every intermediate
  position. }
function HideCursor = s: TermSeq;
function ShowCursor = s: TermSeq;

end;

{ The directive, kept to this module. Every one of these is the runtime's
  rather than the operating system's, because every one of them would need a
  struct this module may not declare (ADR-0185, ADR-0186). }

{ 1 or 0, and never an error. }
function ExtIsTty(fd: integer): integer; external 'pasx_term_isatty';

{ Two out-parameters rather than a `struct winsize`. 0 with both, 1 not a
  terminal or a terminal of unknown size, 2 refused. }
function ExtSize(fd: integer; var rows: integer;
                 var cols: integer): integer; external 'pasx_term_size';

{ 0 entered, 1 not a terminal, 2 refused, 3 already entered and nothing
  changed. }
function ExtRaw(fd: integer): integer; external 'pasx_term_raw';

{ 0 restored, 1 nothing was saved, 2 refused. No descriptor: the runtime knows
  which one it took the settings from. }
function ExtRestore: integer; external 'pasx_term_restore';

function ExtRawActive: integer; external 'pasx_term_raw_active';

const
  { 6.1.9 gives no way to write a control character in a character-string, so
    every sequence below is assembled by `writestr` from `chr`. }
  Esc = 27;

function IsTerminal;
begin
  IsTerminal := ExtIsTty(fd) = 1
end;

function TermSize;
var status: integer;
begin
  rows := 0;
  cols := 0;
  status := ExtSize(fd, rows, cols);
  if status = 0 then TermSize := errNone
  else if status = 1 then TermSize := errAbsent
  else TermSize := errIO
end;

function EnterRaw;
var status: integer;
begin
  status := ExtRaw(fd);
  if status = 0 then EnterRaw := errNone
  else if status = 1 then EnterRaw := errAbsent
  else if status = 3 then EnterRaw := errFull
  else EnterRaw := errIO
end;

function LeaveRaw;
var status: integer;
begin
  status := ExtRestore;
  if status = 0 then LeaveRaw := errNone
  else if status = 1 then LeaveRaw := errAbsent
  else LeaveRaw := errIO
end;

function RawActive;
begin
  RawActive := ExtRawActive = 1
end;

function ReadKey;
var
  b: array [1..1] of char;
  r: CountResult;
begin
  ch := chr(0);
  b[1] := chr(0);
  { One byte, and the slice is what says so: the count `read` is given is
    computed from the designator (ADR-0129), so a key cannot be asked for in
    any quantity but one. }
  r := ReadInto(fd, b[1..1]);
  if not r.ok then
    ReadKey := r.cause
  else if r.val = 0 then
    ReadKey := errAbsent
  else begin
    ch := b[1];
    ReadKey := errNone
  end
end;

{ A coordinate the terminal could act on. Not exported: it is this module's
  rounding of a caller's mistake and not a service. }
function AtLeastOne(n: integer): integer;
begin
  if n < 1 then AtLeastOne := 1 else AtLeastOne := n
end;

function CursorTo;
begin
  { `writestr` is 6.10's own formatting (ADR-0057), so nothing here decides
    how an integer is written. `:1` is what stops §6.10.3.1's default width
    padding the number with blanks the terminal would read as part of the
    sequence. }
  writestr(s, chr(Esc), '[', AtLeastOne(row):1, ';', AtLeastOne(col):1, 'H')
end;

function ClearScreen;
begin
  writestr(s, chr(Esc), '[2J')
end;

function ClearLine;
begin
  writestr(s, chr(Esc), '[2K')
end;

function HideCursor;
begin
  writestr(s, chr(Esc), '[?25l')
end;

function ShowCursor;
begin
  writestr(s, chr(Esc), '[?25h')
end;

end.
