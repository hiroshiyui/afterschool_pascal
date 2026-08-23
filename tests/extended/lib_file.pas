{ PasFile. Every name here is built from `fresh`, a program parameter the
  harness binds to a path of its own, and every file is written before it is
  read -- so the case does not depend on what an earlier run left behind, and
  the one name that must be absent is never created. The missing-file answers
  are the half that matters: they are what ADR-0172 made possible, and the
  alternative to answering false is stopping. }
program lib_file(output, fresh);

import PasFile;

var
  fresh: bindable text;
  base, p, q, absent: FilePath;
  n, size, seen: integer;
  l: FileLine;
  small: string(8);
  big, again: string(300);
  ok: boolean;

procedure show(line: FileLine);
begin
  seen := seen + 1;
  writeln('  ', seen:1, ': [', line, ']')
end;

begin
  base := binding(fresh).name;
  p := base + '.lib_file.p';
  q := base + '.lib_file.q';
  absent := base + '.lib_file.absent';

  { --- nothing there: every reader answers false and nothing stops --- }
  writeln('absent exists: ', FileExists(absent));
  n := -1;
  writeln('absent count: ', LineCount(absent, n), ' ', n:1);
  l := 'untouched';
  writeln('absent line: ', ReadLine(absent, 1, l), ' ', l);
  seen := 0;
  writeln('absent each: ', ForEachLine(absent, show), ' ', seen:1);
  size := -1;
  small := 'untouch';
  writeln('absent all: ', ReadAllText(absent, small, size), ' ', small, ' ',
          size:1);
  writeln('absent copy: ', CopyFile(absent, absent + '.copy'), ' ',
          FileExists(absent + '.copy'));

  { --- write, then read every way --- }
  WriteAllText(p, 'one' + chr(10) + 'two' + chr(10) + 'three' + chr(10));
  writeln('exists: ', FileExists(p));
  ok := LineCount(p, n);
  writeln('count: ', ok, ' ', n:1);
  ok := ReadLine(p, 2, l);
  writeln('line 2: ', ok, ' [', l, ']');
  ok := ReadLine(p, 4, l);
  writeln('line 4: ', ok, ' [', l, ']');
  ok := ReadLine(p, 0, l);
  writeln('line 0: ', ok);
  seen := 0;
  ok := ForEachLine(p, show);
  writeln('each: ', ok);

  { the whole text, into a string that holds it and one that does not }
  ok := ReadAllText(p, big, size);
  writeln('all: ', ok, ' size=', size:1, ' length=', length(big):1,
          ' fits=', size <= big.capacity);
  ok := ReadAllText(p, small, size);
  writeln('prefix: ', ok, ' size=', size:1, ' [', small, '] fits=',
          size <= small.capacity);

  { --- append, on a file that is there and on one that is not --- }
  AppendLine(p, 'four');
  AppendText(p, 'fi' + 've' + chr(10) + 'six' + chr(10));
  ok := LineCount(p, n);
  writeln('after append: ', n:1);
  ok := ReadLine(p, 6, l);
  writeln('line 6: [', l, ']');
  AppendLine(q, 'created by append');
  ok := ReadLine(q, 1, l);
  writeln('q: ', FileExists(q), ' [', l, ']');

  { --- one line, replacing whatever was there --- }
  WriteLine(q, 'replaced');
  ok := LineCount(q, n);
  writeln('q count: ', n:1);

  { --- copy --- }
  writeln('copy: ', CopyFile(p, q));
  ok := ReadAllText(p, big, size);
  ok := ReadAllText(q, again, size);
  writeln('copied size: ', size:1, ' same=', big = again);
  ok := ReadLine(q, 5, l);
  writeln('copied line 5: [', l, ']');

  { --- an unterminated last line is still a line (6.4.3.5) --- }
  WriteAllText(q, 'no newline');
  ok := LineCount(q, n);
  ok := ReadAllText(q, big, size);
  writeln('unterminated: lines=', n:1, ' size=', size:1,
          ' ends in newline=', big[size] = chr(10));

  { --- an empty file has no lines and no characters --- }
  WriteAllText(q, '');
  ok := LineCount(q, n);
  ok := ReadAllText(q, big, size);
  writeln('empty: lines=', n:1, ' size=', size:1)
end.
