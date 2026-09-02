{ PasStrings, exercised through the interface an importer actually sees.

  **The golden beside this file did not change when this program was rewritten**,
  and that is the point of the rewrite. Every argument here used to have to be a
  string *variable* -- a variable-string could not be a value parameter
  (ADR-0052), so `StartsWith(s, 'Hello')` and `UpperAscii(Reverse(s))` did not
  compile and the earlier version of this program assigned to a named
  intermediate before every call. ADR-0115 made the callee convert its
  argument, so the literals and the nesting below are written directly and the
  library computes exactly what it computed before. }
program lib_strings(output);

import PasStrings;

var s: Line;

begin
  s := 'Hello, World';

  writeln(UpperAscii(s));
  writeln(LowerAscii(s));

  { A prefix and a suffix that match, and one of each that does not. }
  writeln(StartsWith(s, 'Hello'));
  writeln(StartsWith(s, 'World'));
  writeln(EndsWith(s, 'World'));
  writeln(EndsWith(s, 'Hello'));

  { A prefix longer than the string cannot be one, and asking must not index
    past the end. }
  writeln(StartsWith(s, 'Hello, World and then some'));

  { IndexOf: present, absent, at the very start, at the very end, and the null
    needle, which occurs at 1 so that `IndexOf(s, n) > 0` answers "is n a
    substring". }
  writeln(IndexOf(s, 'o, W'):1);
  writeln(IndexOf(s, 'zebra'):1);
  writeln(IndexOf(s, 'H'):1);
  writeln(IndexOf(s, 'd'):1);
  writeln(IndexOf(s, ''):1);

  { The first of two occurrences, so a scan that returned the last would fail
    here rather than agreeing. }
  writeln(IndexOf('abcabc', 'bc'):1);

  { Padding, including the width already reached -- these pad and never
    truncate, so a string longer than the width comes back whole. }
  writeln('[', PadLeft('ab', 5), ']');
  writeln('[', PadRight('ab', 5), ']');
  writeln('[', PadLeft('ab', 2), ']');
  writeln('[', PadLeft('ab', 1), ']');

  writeln('[', Times('ab', 3), ']');
  writeln('[', Times('ab', 0), ']');
  writeln('[', Times('ab', -1), ']');

  writeln(Reverse(s));
  writeln('[', Reverse(''), ']');

  { Replace: every occurrence, one that is not there, a replacement longer than
    what it replaces and one shorter, and the null needle, which matches
    nothing rather than inserting between every pair of characters. }
  writeln(Replace(s, 'o', '0'));
  writeln(Replace(s, 'l', ''));
  writeln(Replace(s, 'World', 'Afterschool Pascal'));
  writeln(Replace(s, 'zebra', '!'));
  writeln(Replace(s, '', 'x'));

  { A replacement containing the needle is not rescanned, so this terminates and
    doubles each 'a' exactly once. }
  writeln(Replace('aaa', 'a', 'aa'));

  { One function's result as another's argument, which is the composition the
    old interface could not express at all. }
  writeln(UpperAscii(Reverse(s)))
end.
