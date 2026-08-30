{ PasTerm: the terminal, asked about from a program that has not got one.

  **This case runs with no terminal, and that is designed for rather than
  worked around.** ctest redirects standard output into a file and standard
  input from `lib_term.in`, so every descriptor this program holds is a
  regular file. A case that needed a terminal would need a pseudo-terminal to
  be opened, which is a whole further binding, and would then be a test of
  that binding; what is left without one is the *negative* path, and the
  negative path is the one a program gets wrong. So this asserts that
  `IsTerminal` is false for a redirected descriptor, that `TermSize` says
  `errAbsent` rather than answering a plausible number, and that `EnterRaw`
  refuses instead of changing anything -- and then that `LeaveRaw` on a
  terminal nobody entered is `errAbsent` and not a restore of settings never
  saved.

  **The escape sequences are checked exactly**, because they are strings and
  need no terminal at all: that is why they are strings rather than calls.
  `Shown` renders the control characters so the golden is ordinary text --
  a golden holding a literal ESC would be a file no diff reads aloud.

  **What this case therefore does not cover** (a doc/sop.md §7 shape):

  - Raw mode itself. That the flags cleared are the right ones, that a read
    then answers on one keystroke rather than on a line, and that the settings
    put back are the settings taken, are all asserted by nothing here. They
    need a real terminal, and the only oracle for them is a person using a
    program.
  - The `atexit` restore. It fires only where raw mode was entered, which is
    never here.
  - A real window size, and the size *changing*.
  - `EnterRaw` twice, which is the `errFull` arm: the first one has to succeed
    to reach it, and the first one cannot succeed here. The arm is reached in
    neither direction, so `errFull` is a documented answer nothing has
    observed.
  - `ReadKey` reads a byte here, which is the ordinary unbuffered read and not
    a key: what raw mode changes is *when* the byte arrives, not what
    `ReadKey` does with it. }
program lib_term(output);

import PasError;
       PasIO;
       PasTerm;

var
  rows, cols: integer;
  e: ErrorCode;
  ch: char;

{ An escape sequence as readable text: every character below a blank written
  as its ordinal in angle brackets. The golden then holds no control
  character, and a wrong byte is named rather than being invisible. }
function Shown(seq: TermSeq): IOLine;
var k: integer; out: IOLine; num: IOLine;
begin
  out := '';
  for k := 1 to length(seq) do
    if ord(seq[k]) < 32 then begin
      writestr(num, ord(seq[k]):1);
      out := out + '<' + num + '>'
    end
    else
      out := out + seq[k];
  Shown := out
end;

begin
  { Not a terminal, on any of the three: output and input are redirected by
    the harness, and the error stream is inherited but is not asked about --
    a case that asked would answer differently under ctest and under a shell. }
  writeln('isatty out:  ', IsTerminal(StdOut));
  writeln('isatty in:   ', IsTerminal(StdIn));

  { And so there is no window. What matters is that this is `errAbsent` --
    a code the caller can act on -- and not a pair of numbers invented from
    an environment variable. }
  rows := 999;
  cols := 999;
  e := TermSize(StdOut, rows, cols);
  writeln('size:        ', ErrorText(e), ', rows=', rows:1, ' cols=', cols:1);

  { Raw mode on something that is not a terminal is refused, and refused
    before anything is saved: `RawActive` is false on both sides of it. }
  writeln('raw before:  ', RawActive);
  e := EnterRaw(StdIn);
  writeln('enter raw:   ', ErrorText(e));
  writeln('raw after:   ', RawActive);

  { And leaving one nobody entered is `errAbsent` rather than a restore of
    settings that were never taken. This is the arm a `defer LeaveRaw` on a
    path that never entered raw mode reaches. }
  e := LeaveRaw;
  writeln('leave raw:   ', ErrorText(e));

  { The sequences, which need no terminal because they are strings. }
  writeln('home:        ', Shown(CursorTo(1, 1)));
  writeln('cursor:      ', Shown(CursorTo(12, 40)));
  writeln('clamped:     ', Shown(CursorTo(0, -3)));
  writeln('clear:       ', Shown(ClearScreen));
  writeln('clear line:  ', Shown(ClearLine));
  writeln('hide:        ', Shown(HideCursor));
  writeln('show:        ', Shown(ShowCursor));

  { A byte off the redirected input. Outside raw mode this is what `read`
    would have got, one character at a time and unbuffered -- so the file
    holds two characters and the third answer is the end of it.

    `input` is deliberately **not** a program-parameter of this program:
    §6.11.4.2 makes it the standard input file, which the runtime opens and
    reads ahead on, and it would then have taken the very bytes this asks the
    descriptor for. The two readers cannot share a descriptor, which is what
    PasTerm's own comment says, and the way to say so in a test is to have
    only one of them. }
  e := ReadKey(StdIn, ch);
  writeln('key 1:       ', ErrorText(e), ' [', ch, ']');
  e := ReadKey(StdIn, ch);
  writeln('key 2:       ', ErrorText(e), ' [', ch, ']');
  e := ReadKey(StdIn, ch);
  writeln('key 3:       ', ErrorText(e), ' [', ord(ch):1, ']')
end.
