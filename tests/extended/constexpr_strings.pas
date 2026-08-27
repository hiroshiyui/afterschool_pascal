{ ISO/IEC 10206:1991 §6.8.2's constant-expression, where the value is a string.

  §6.8.2 makes an expression nonvarying unless it contains a
  variable-identifier, a schema-discriminant, a bound-identifier, a
  field-designator-identifier, a non-static type-name, or a function-identifier
  declared by the program or naming `eof` or `eoln`; NOTE 1 adds `empty`,
  `position` and `LastPosition`, and says why -- they need a variable as a
  parameter. Every other required function therefore belongs in a
  constant-expression, and §6.3.2's own worked example depends on it:

    hex_alpha = hex_string[index(hex_string,'A')..index(hex_string,'F')];

  None of the forms below was folded until ADR-0226, and each was refused with
  *the value of constant 'k' is not a compile-time constant* -- a complaint
  about the program, for a program the clause admits.

  **Every value here is printed beside the same computation made at run time.**
  That is the point of the case rather than a flourish: the folder and the code
  generator are two implementations of one clause, and a case that only printed
  the folded answer would pass while they disagreed. §6.8.3.5's padded
  comparison and §6.7.6.7's length-sensitive EQ are where they would.

  The two are *different rules* and this case pins the difference: `'ab' = 'ab '`
  is true because the operator extends the shorter with spaces, and
  `eq('ab','ab ')` is false because EQ asks the lengths as well. Getting one of
  those right and the other wrong is the obvious way to fail this clause pair. }
program ConstExprStrings(output);

const
  { §6.8.3.6: "a value of the canonical-string-type whose length shall be equal
    to the sum of the length of a and the length of b". Both operands may be a
    char, which §6.4.3.3.1 gives "length 1 and capacity 1". }
  cat1 = 'ab' + 'cd';
  cat2 = 'a' + 'b';
  cat3 = '' + 'x';
  cat4 = 'x' + 'y' + 'z';

  { §6.8.3.5's relational operators, which pad the shorter with spaces. All six
    are written out: they are six arms of one case-statement, and a corpus
    exercising two of them says nothing about the other four. }
  op1 = 'ab' = 'ab ';
  op2 = '' = ' ';
  op3 = '' < ' ';
  op4 = 'abc' < 'abd';
  op5 = 'abc' <> 'abd';
  op6 = 'b' > 'ab';
  op7 = 'ab' >= 'ab ';
  op8 = 'ab' <= 'abc';

  { These two are what make the padding *observable*, and the case did not have
    them until a mutation survived. Comparing only the characters both values
    have gives the same answer as padding whenever the longer value's tail is
    spaces -- which is every comparison above. It differs only where that tail
    is something else: padded, `'ab'` becomes `'ab '` and a space is below `c`,
    so `'ab' = 'abc'` is false and `'ab' < 'abc'` is true; truncated to the
    common prefix both would compare equal. }
  op9  = 'ab' = 'abc';
  op10 = 'ab' < 'abc';

  { §6.7.6.7's EQ and LT, which do not pad -- EQ is
    "( (s1v = s2v) and (n1 = n2) )" and LT is defined over prefixes. }
  fn1 = eq('ab', 'ab ');
  fn2 = eq('ab', 'ab');
  fn3 = lt('ab', 'abc');
  fn4 = ge('ab', 'ab');
  fn5 = ne('ab', 'ab ');
  fn6 = gt('b', 'ab');
  fn7 = le('ab', 'ab');

  { §6.7.6.7's substr in both its forms, and trim. `substr(s, i)` is
    "equivalent to substr(sv,iv,length(sv)-(iv)+1)". }
  sub1 = substr('abcde', 2, 3);
  sub2 = substr('abcde', 2);
  sub3 = substr('abcde', 2, 0);
  sub4 = substr('abcde', 6, 0);
  trm1 = trim('ab  ');
  trm2 = trim('   ');
  trm3 = trim('ab');

  { A one-character literal is a *char* (§6.1.9), not a string of length one,
    and a char constant keeps its character in the symbol rather than in the
    pool -- so these are the one path through the fold that has to *write* a
    character rather than narrow a run that is already there. }
  chr1 = trim('x');
  chr2 = trim(' ');
  chr3 = substr('x', 1, 1);
  chr4 = substr('x', 1, 0);
  chr5 = 'a' = 'a ';

  { And the fold composed with itself, which is what makes it a folder rather
    than four special cases. }
  mix = trim(substr('  hello  ', 3, 6)) + '!';

var a, b: string(10);

begin
  a := 'ab'; b := 'cd';
  writeln('cat  ', cat1, ' ', cat2, ' ', cat3, ' ', cat4,
          '   run ', a + b);

  a := 'ab'; b := 'ab ';
  writeln('op   ', op1, ' ', op2, ' ', op3, ' ', op4, ' ',
          op5, ' ', op6, ' ', op7, ' ', op8, '   run ', a = b);
  a := 'ab'; b := 'abc';
  writeln('pad  ', op9, ' ', op10, '   run ', a = b, ' ', a < b);

  writeln('fn   ', fn1, ' ', fn2, ' ', fn3, ' ', fn4, ' ',
          fn5, ' ', fn6, ' ', fn7,
          '   run ', eq('ab', 'ab '), ' ', eq('ab', 'ab'));

  a := 'abcde';
  writeln('sub  [', sub1, '][', sub2, '][', sub3, '][', sub4,
          ']  run [', substr(a, 2, 3), '][', substr(a, 2), ']');

  a := 'ab  ';
  writeln('trim [', trm1, '][', trm2, '][', trm3, ']  run [', trim(a), ']');

  writeln('chr  [', chr1, '][', chr2, '][', chr3, '][', chr4, '] ', chr5);
  writeln('mix  [', mix, ']')
end.
