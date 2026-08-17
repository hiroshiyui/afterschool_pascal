{ PasStrings, exercised through the interface an importer actually sees.

  Every string argument is a *variable*, and that is not a stylistic choice: a
  variable-string may not be a value parameter (ADR-0052), so the formals are
  schematic `protected s: string` and an actual must be a variable produced from
  that schema. `StartsWith(s, 'Hello')` does not compile, and neither does
  `Upper(Reverse(s))`. This program is what that costs, written out. }
program lib_strings(output);

import PasStrings;

var
  s, prefix, suffix, needle, repl, empty, result_: Line;
  hay, pin: Line;

begin
  s := 'Hello, World';

  writeln(Upper(s));
  writeln(Lower(s));

  { A prefix and a suffix that match, and one of each that does not. }
  prefix := 'Hello';
  writeln(StartsWith(s, prefix));
  prefix := 'World';
  writeln(StartsWith(s, prefix));
  suffix := 'World';
  writeln(EndsWith(s, suffix));
  suffix := 'Hello';
  writeln(EndsWith(s, suffix));

  { A prefix longer than the string cannot be one, and asking must not index
    past the end. }
  prefix := 'Hello, World and then some';
  writeln(StartsWith(s, prefix));

  { IndexOf: present, absent, at the very start, at the very end, and the null
    needle, which occurs at 1 so that `IndexOf(s, n) > 0` answers "is n a
    substring". }
  needle := 'o, W';
  writeln(IndexOf(s, needle):1);
  needle := 'zebra';
  writeln(IndexOf(s, needle):1);
  needle := 'H';
  writeln(IndexOf(s, needle):1);
  needle := 'd';
  writeln(IndexOf(s, needle):1);
  empty := '';
  writeln(IndexOf(s, empty):1);

  { The first of two occurrences, so a scan that returned the last would fail
    here rather than agreeing. }
  hay := 'abcabc';
  pin := 'bc';
  writeln(IndexOf(hay, pin):1);

  { Padding, including the width already reached -- these pad and never
    truncate, so a string longer than the width comes back whole. }
  needle := 'ab';
  writeln('[', PadLeft(needle, 5), ']');
  writeln('[', PadRight(needle, 5), ']');
  writeln('[', PadLeft(needle, 2), ']');
  writeln('[', PadLeft(needle, 1), ']');

  writeln('[', Times(needle, 3), ']');
  writeln('[', Times(needle, 0), ']');
  writeln('[', Times(needle, -1), ']');

  writeln(Reverse(s));
  writeln('[', Reverse(empty), ']');

  { Replace: every occurrence, one that is not there, a replacement longer than
    what it replaces and one shorter, and the null needle, which matches
    nothing rather than inserting between every pair of characters. }
  needle := 'o';
  repl := '0';
  writeln(Replace(s, needle, repl));
  needle := 'l';
  repl := '';
  writeln(Replace(s, needle, repl));
  needle := 'World';
  repl := 'Afterschool Pascal';
  writeln(Replace(s, needle, repl));
  needle := 'zebra';
  repl := '!';
  writeln(Replace(s, needle, repl));
  repl := 'x';
  writeln(Replace(s, empty, repl));

  { A replacement containing the needle is not rescanned, so this terminates and
    doubles each 'a' exactly once. }
  hay := 'aaa';
  needle := 'a';
  repl := 'aa';
  writeln(Replace(hay, needle, repl));

  { The operations compose only through a named variable, which is the
    deviation's whole cost in one line. }
  result_ := Reverse(s);
  writeln(Upper(result_))
end.
