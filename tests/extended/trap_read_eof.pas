{ ISO/IEC 10206:1991 Annex D, D.97 (6.10.1): "When read is applied to text file
  f, it is an error if the buffer variable f^ is undefined, if f0.M is not
  Inspection or Update, if either f0.L or f0.R is undefined, or if f0.R=S()."

  f0.R=S() is end-of-file: there is nothing left to read. The clause is about
  `read` and not about one of its forms, and this compiler reported it for the
  char-type form -- which reaches the buffer variable through 6.10.1 b)'s
  `v := f^; get(f)` -- and for the numeric forms, whose "it shall be an error
  if s is empty" catches the same position. The two string forms of 6.10.1 e)
  and f) reached neither and answered with spaces and the null-string, so one
  read procedure gave two answers to one clause.

  What this is *not* about is end-of-line. NOTE 6 and NOTE 7 say "if eoln(f)
  is initially true, then no characters are read", and that stays: at
  end-of-line there is a line terminator still to read and at end-of-file
  there is not. The first read below is at end-of-line and answers with the
  null-string; only the one after readln is at end-of-file.

  Extended Pascal only: ISO 7185 has no string-type to read into. }
program trap_read_eof(input, output);
var s: string(10);
begin
  read(s);
  writeln('1=[', s, ']');
  read(s);
  writeln('2=[', s, '] -- still at end-of-line, not end-of-file');
  readln;
  writeln('eof=', eof);
  read(s);
  writeln('unreachable: [', s, ']')
end.
