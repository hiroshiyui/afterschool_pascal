{ PasRegex: every construct matching and not matching, every way a pattern can
  be bad, and the case the whole design decision rests on.

  The roadmap said the right answer here was not obvious. The module's heading
  is the answer -- a Thompson NFA simulated by a Pike VM rather than a
  backtracking matcher -- and the last section of this program is the evidence
  for it: a pattern and a subject that take a backtracking matcher a number of
  steps exponential in the length of the input, run here against a stated
  bound. It is the one section whose value is that the program *ends*. }
program lib_regex(output);

import PasError; PasRegex;

var re: Regex; m: RegexMatch; e: ErrorCode; at, i: integer;
    s: string(64); tiny: string(2); big: string(2048);

{ Two answers on one line, because every construct here has to be shown
  refusing as well as accepting: a matcher that says yes to everything passes
  half a test suite. }
procedure Both(pat, yes, no: string);
var c: ErrorCode; p: integer; r: Regex;
begin
  c := RegexCompile(r, pat, p);
  write(pat, ' ':14 - length(pat), '| ');
  if c <> errNone then
    writeln('compile ', ErrorText(c))
  else
    writeln(yes, '=', RegexMatches(r, yes), '  ', no, '=', RegexMatches(r, no),
            '  code=', RegexLength(r):1)
end;

{ Every way a pattern can be bad: the code a caller branches on, the position
  it has to point at, and the sentence it prints. }
procedure Bad(pat: string);
var c: ErrorCode; p: integer; r: Regex;
begin
  c := RegexCompile(r, pat, p);
  writeln(pat, ' ':10 - length(pat), '| ', ErrorText(c), ' at ', p:1,
          ': ', RegexFaultText(RegexFaultOf(r)))
end;

begin
  { --- every construct, matching and not matching ------------------------ }
  Both('abc', 'abc', 'abd');
  Both('a.c', 'axc', 'ac');
  Both('a*c', 'aaac', 'aab');
  Both('a+c', 'ac', 'c');
  Both('a?c', 'c', 'aac');
  Both('a|bc', 'bc', 'b');
  Both('(ab)+', 'abab', 'aba');
  Both('[abc]+', 'cab', 'abd');
  Both('[a-c1-3]+', 'a3b', 'a4b');
  Both('[^a-c]+', 'xyz', 'xay');
  Both('\d+', '907', '9o7');
  Both('\w+', 'a_9', 'a-9');
  Both('a\.c', 'a.c', 'abc');
  Both('a\\c', 'a\c', 'abc');
  Both('[\d-]+', '1-2', '1x2');

  { --- anchors, at both ends --------------------------------------------- }
  { They anchor the subject, so what they refuse is a match that is really
    there somewhere else in it -- which is the only way to tell an anchor
    from a literal that happens not to occur. }
  e := RegexCompile(re, '^ab', at);
  writeln('^ab       | in abx=', RegexSearch(re, 'abx', m),
          '  in xab=', RegexSearch(re, 'xab', m));
  e := RegexCompile(re, 'ab$', at);
  writeln('ab$       | in xab=', RegexSearch(re, 'xab', m),
          '  in abx=', RegexSearch(re, 'abx', m));
  e := RegexCompile(re, '^$', at);
  writeln('^$        | in empty=', RegexSearch(re, '', m),
          '  in a=', RegexSearch(re, 'a', m));

  { --- a search reports where it began and ended ------------------------- }
  e := RegexCompile(re, '[0-9]+', at);
  if RegexSearch(re, 'x 12 y 345', m) then
    writeln('search    | start=', m.start:1, ' stop=', m.stop:1);
  { and it can be walked to the end of the subject }
  write('walk      |');
  i := 1;
  while RegexSearchFrom(re, 'a12b345c6', i, m) do begin
    e := RegexGroupInto(m, 'a12b345c6', 0, s);
    write(' ', s);
    if m.stop > m.start then i := m.stop else i := m.stop + 1
  end;
  writeln;

  { --- capture, which the construction affords in bounded time ----------- }
  e := RegexCompile(re, '(\w+)=([0-9]+)', at);
  writeln('capture   | groups=', RegexGroups(re):1);
  if RegexSearch(re, 'set width=1920 now', m) then begin
    e := RegexGroupInto(m, 'set width=1920 now', 1, s);
    write('          | 1=[', s, ']');
    e := RegexGroupInto(m, 'set width=1920 now', 2, s);
    write(' 2=[', s, ']');
    e := RegexGroupInto(m, 'set width=1920 now', 0, s);
    writeln(' 0=[', s, ']');
    { A group that does not fit is reported and nothing is written, which is
      the other direction of the same guard. }
    e := RegexGroupInto(m, 'set width=1920 now', 1, tiny);
    writeln('into tiny | ', ErrorText(e))
  end;
  { A group in an alternative that was not taken took no part, and says so
    with 0 rather than with an empty span at some position it never reached. }
  e := RegexCompile(re, '(x)|(y)', at);
  if RegexSearch(re, 'y', m) then begin
    e := RegexGroupInto(m, 'y', 1, s);
    writeln('untaken   | 1 start=', RegexGroupStart(m, 1):1,
            ' code=', ErrorText(e),
            '  2 start=', RegexGroupStart(m, 2):1)
  end;

  { --- every way a pattern can be bad ------------------------------------ }
  Bad('a(b');
  Bad('a)b');
  Bad('*a');
  Bad('a[bc');
  Bad('a[]b');
  Bad('a[z-a]');
  Bad('ab\');
  Bad('a\qb');
  { A back reference is the feature this construction gives up, so it is the
    one bad pattern that is not a syntax error: errRange says the pattern is
    well formed and outside what a bounded matcher can represent. }
  Bad('(a)\1');

  { --- and the bounds, which report rather than truncate ------------------ }
  big := '';
  for i := 1 to 400 do big := big + 'ab';
  e := RegexCompile(re, big, at);
  writeln('800 chars | ', ErrorText(e), ' at ', at:1, ': ',
          RegexFaultText(RegexFaultOf(re)));
  e := RegexCompile(re, '(a)(b)(c)(d)(e)(f)(g)(h)(i)(j)', at);
  writeln('10 groups | ', ErrorText(e), ' at ', at:1, ': ',
          RegexFaultText(RegexFaultOf(re)));
  { A pattern that was refused matches nothing, so a caller that ignored the
    code above gets no match rather than a wrong one. }
  writeln('refused   | matches=', RegexMatches(re, 'abcdefghij'),
          ' searches=', RegexSearch(re, 'abcdefghij', m));

  { --- why this module is not a backtracking matcher ---------------------- }
  { `(a|a)*b` against a run of a's with no b is the standard demonstration: a
    backtracking matcher tries both branches at every a and so takes two to
    the power of the input length steps before it can say no. Two thousand
    a's would be a number with six hundred digits in it, and the program
    would not end.

    Here the work is bounded by the length of the program times the length of
    the subject, so what this section asserts is a number against that bound.
    The test is that the program reaches the next line. }
  e := RegexCompile(re, '(a|a)*b', at);
  big := '';
  for i := 1 to 2000 do big := big + 'a';
  writeln('blowup    | match=', RegexMatches(re, big),
          ' within bound=',
          RegexSteps(re) <= 2 * RegexLength(re) * (length(big) + 2));
  { The other classic shape, and the same claim. }
  e := RegexCompile(re, 'a?a?a?a?a?a?a?a?a?a?aaaaaaaaaa', at);
  big := '';
  for i := 1 to 10 do big := big + 'a';
  writeln('a?xN      | match=', RegexMatches(re, big),
          ' within bound=',
          RegexSteps(re) <= 2 * RegexLength(re) * (length(big) + 2))
end.
