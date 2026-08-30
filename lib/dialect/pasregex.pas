{ PasRegex -- a pattern matched against a subject in a time the caller can
  compute in advance.

  doc/roadmap.md names this as the largest of the library gaps and as the only
  one where the right answer is not obvious: "a backtracking matcher and a DFA
  are different programs with different failure modes". That sentence is the
  whole of the design work, so the answer is written down here rather than
  left to be inferred from the code.

  **The construction is a Thompson NFA driven by a Pike VM.** A pattern
  compiles to a small program -- match a byte, match a class, split, jump,
  record a position, succeed -- and the subject is walked once, left to right,
  carrying every program counter that is still alive at the current byte. The
  set of live counters is deduplicated at each byte, so one byte costs at most
  one visit per instruction, and the run costs at most the length of the
  program times the length of the subject. `RegexSteps` reports the visits the
  last run actually made, so the bound is a number a caller can assert rather
  than a promise it has to believe.

  **Why not a backtracking matcher**, which is the shape almost every regular
  expression library has. Backtracking explores one path at a time and
  re-explores what it has already refuted: `(a|a)*b` against a run of a's with
  no b takes two paths through every a, which is two to the power of the input
  length. That is not slow, it is unbounded -- and this project is built the
  other way round. A subscript outside its bounds stops the program, integer
  overflow stops the program, a case-statement with no matching label stops
  the program (ADR-0014, ADR-0017, ADR-0018): every one of those is a *bound*,
  and a program either stays inside it or is stopped at the moment it leaves.
  A matcher that is exponential in its input has no such bound and cannot be
  given one after the fact. It does not fail, it does not report, it does not
  return; it runs, and no oracle in this repository can see that -- every gate
  here compares what a program printed, and a program that has not finished
  has printed nothing. `tests/dialect/lib_regex.pas` matches exactly that
  pattern against exactly that input, and it is there to be timed rather than
  to be read.

  **Why not a DFA.** A DFA is this same NFA with the live sets cached, and it
  is the faster program: it is what to reach for if this is ever measured and
  found wanting. It is not what to reach for first. Its worst case moves from
  time into *space* -- the subset construction has two-to-the-instructions
  states -- and the standard answer is a bounded cache that is flushed and
  rebuilt, which is a second bound to size and a second failure mode to
  explain. And a DFA state is a set of positions with no memory of how it got
  there, so it can say a match happened and not where any part of it began.
  The Pike VM gives submatch capture for the same single walk, because a live
  counter can carry the positions it has passed, and the number of live
  counters is bounded by the length of the program.

  **So capture is supported, and it is supported because the construction
  affords it in bounded time.** Each live thread carries the whole slot array,
  which multiplies the bound above by a constant -- `SlotMax`, twenty -- and
  by nothing else. `RegexGroupStart`, `RegexGroupStop` and `RegexGroupInto`
  are the readers; group 0 is the whole match, so the same three routines
  answer for it.

  One capture answer here differs from a backtracking library's, and it is the
  one place the construction shows through, so it is stated rather than
  discovered. A repeat whose body can match *nothing* -- a group with an empty
  alternative in it, under a star -- gets one fewer round here: a backtracker
  takes a final empty turn through the body and the group ends up holding the
  empty match at the end, where this stops as soon as a turn consumes no
  input, and the group holds the last turn that did. The *extent* of the match
  is the same either way; only which empty position that one group names
  differs. It was measured rather than assumed -- fifty-seven thousand
  pattern-and-subject pairs against another implementation agreed on every
  match extent, and disagreed on that group and nothing else.

  **What the construction costs is back-references, and they are refused by
  name.** `\1` -- "whatever group one matched, again" -- is not a regular
  language, and deciding a pattern that has one is NP-hard, so no construction
  with a bound has them and none ever will. A digit escape is therefore a
  *reported* fault, `rxBackReference` with `errRange`: the pattern is well
  formed, and it is outside what this can represent. It is not read as a
  literal digit and it is not quietly ignored. ADR-0067's rule is that a claim
  nothing names is a claim nothing checks, and a feature that looks supported
  and is not is worse than one that is refused where the caller can see it.

  **Matching is over bytes, and that is a decision.** `pasjson.pas` made the
  same one and half its reasons carry over: a subject arrives from a socket or
  a file, AP 6.4.15 assignment to a text establishes Normalization Form C, and
  matching a value the program never held is the wrong answer however tidy.
  The other half is this module's own. A character class here is a
  `set of char`, two hundred and fifty-six bits tested in one instruction; a
  class over code points would be a list of ranges and a search per byte, and
  the class is on the innermost path of the whole matcher. What follows has to
  be said plainly, because it is where a caller will be surprised:

  - `.` matches one **byte**. A multi-byte character is two to four of them,
    so `.` will match a piece of one, and a pattern anchored at both ends
    around a single `.` does not match a single accented letter.
  - a class matches one byte, so `[a-z]` cannot be extended to a non-ASCII
    letter by writing the letter in it -- that puts its two bytes in the set,
    and either one alone will then match.
  - a **literal** in a pattern is exact, whatever its bytes: a multi-byte
    character compiles to that many byte instructions in a row and matches
    itself and nothing else. Searching for a word is the ordinary case and it
    is correct.

  A caller that needs classes over characters wants `PasUnicode`'s scalar walk
  and a different module; this one says what it is.

  **Every bound is fixed and every one is reported** (ADR-0012). A pattern
  needing more than `ProgMax` instructions is `rxPatternTooLong` and one with
  more than `GroupMax` groups is `rxTooManyGroups` -- each an `errFull` with
  the position in the pattern where the bound was reached. Nothing here
  truncates a pattern and nothing here halts: a compile that fails leaves a
  `Regex` that matches nothing, so a caller that ignores the code gets no
  match rather than a wrong one.

  There is no third bound on how deeply the pattern compiler may recurse, and
  its absence is the argument rather than an omission. A group is the only
  construct that nests, so the recursion is `GroupMax` deep plus a constant
  and cannot be made deeper by any pattern -- and a limit that no input can
  reach is a branch no test can enter, which is how a catalogue comes to
  describe a program that is not there. Where the check would have gone, this
  paragraph says why it is not needed.

  **What is deliberately absent**, so that nobody looks for it: counted
  repetition, lazy quantifiers, non-capturing groups, word boundaries,
  case-insensitive matching, and line-anchored `^` and `$` -- the two anchors
  here are anchors of the *subject*, and `.` matches a line feed like any
  other byte, because a rule about lines with no companion rule about lines
  would be the surprising half of a feature. Each of those is an addition to
  the pattern compiler and none of them changes the bound. }

module PasRegex;

export PasRegex = (ProgMax, GroupMax, SlotMax,
                   RegexFault, rxNone, rxUnclosedGroup, rxUnopenedGroup,
                   rxDanglingRepeat, rxUnterminatedClass, rxEmptyClass,
                   rxBadRange, rxTrailingEscape, rxUnknownEscape,
                   rxBackReference, rxPatternTooLong, rxTooManyGroups,
                   FaultText, Regex, RegexMatch,

                   RegexCompile, RegexFaultOf, RegexFaultText,
                   RegexGroups, RegexLength, RegexSteps,

                   RegexMatches, RegexSearch, RegexSearchFrom,
                   RegexGroupStart, RegexGroupStop, RegexGroupInto);

import PasError;

const
  { Instructions, not pattern characters: a pattern costs between one and
    three of these per character it is written with, so the bound a caller
    feels is a pattern of a few hundred characters. It is stated in
    instructions because that is what the matcher's own bound is stated in,
    and two numbers for one limit is one too many. }
  ProgMax = 768;

  { Capturing groups. Nine because that is what every notation for naming one
    can spell, and because each one costs every live thread two more integers
    to carry -- the bound below is this number doubled and then some, and it
    multiplies the cost of every byte. }
  GroupMax = 9;

  { Two positions per group, and group 0 is the whole match. }
  SlotMax = 2 * (GroupMax + 1);

type
  { What was wrong with a pattern, at the grain a caller can act on. It is a
    second vocabulary beside `ErrorCode` and not a replacement for it: the
    code says which *kind* of failure this was, so a caller can branch, and
    this says which sentence to print. `PasError`'s set is deliberately closed
    (ADR-0120) and "a parenthesis is not closed" is exactly the finer detail
    that record says belongs in the message rather than in the code. }
  RegexFault = (rxNone,
                rxUnclosedGroup,      { an opening parenthesis is not closed }
                rxUnopenedGroup,      { a closing one opened nothing }
                rxDanglingRepeat,     { a repeat with nothing before it }
                rxUnterminatedClass,  { a class is not closed }
                rxEmptyClass,         { a class that can match nothing }
                rxBadRange,           { a range that runs backwards }
                rxTrailingEscape,     { the pattern ends in a backslash }
                rxUnknownEscape,      { a letter escape with no meaning }
                rxBackReference,      { a digit escape; see the heading }
                rxPatternTooLong,     { more than ProgMax instructions }
                rxTooManyGroups);     { more than GroupMax groups }

  FaultText = string(64);

  CharSet = set of char;

  { The compiled program. A caller never reads one and never names an
    instruction; `Regex` is exported so that a caller has something to
    declare, and the readers below are the whole of what it can ask. }
  InstKind = (iChar, iAny, iClass, iSplit, iJump, iSave, iBol, iEol, iMatch);

  Inst = record
    case kind: InstKind of
      iChar:  (ch: char);
      iClass: (cls: CharSet);
      iSplit: (x, y: integer);
      iJump:  (dest: integer);
      iSave:  (slot: integer);
      iAny, iBol, iEol, iMatch: ()
  end;

  Slots = array [1..SlotMax] of integer;

  { One byte's worth of live threads. `mark` against `gen` is what makes a
    program counter enter the list once per byte however many ways the pattern
    offers of reaching it -- it is the whole reason this is linear rather than
    exponential, and it is three lines. `gen` counts up instead of `mark`
    being cleared, so a byte costs nothing for the instructions it does not
    reach. }
  ThreadList = record
    n, gen: integer;
    mark: array [1..ProgMax] of integer;
    pc: array [1..ProgMax] of integer;
    sl: array [1..ProgMax] of Slots
  end;

  Regex = record
    n: integer;            { instructions in use; 0 after a failed compile }
    groups: integer;
    fault: RegexFault;
    steps: integer;        { visits made by the last match, for RegexSteps }
    code: array [1..ProgMax] of Inst
  end;

  { Where a match and each of its groups began and ended. `start` and `stop`
    are group 0 and are here because reading them is the common case; `stop`
    is one *past* the last byte, so `stop - start` is the length and a match
    of nothing has `stop = start`. }
  RegexMatch = record
    start, stop: integer;
    groups: integer;
    slot: Slots
  end;

{ Compile `pat` into `re`. `errNone` and `re` is ready; otherwise `re` matches
  nothing, `at` is the 1-based position in `pat` where the trouble was
  noticed, and `RegexFaultOf(re)` says which trouble it was. On success `at`
  is one past the end of the pattern.

  The code is the category: `errSyntax` for a pattern that is not one,
  `errRange` for a back-reference -- well formed, and outside what a bounded
  matcher can represent -- and `errFull` for one of this module's own
  capacities. }
function RegexCompile(var re: Regex; pat: string; var at: integer): ErrorCode;

{ Why the last compile failed, or `rxNone`. }
function RegexFaultOf(var re: Regex): RegexFault;

{ A sentence for a fault, for a caller assembling a message. `rxNone` has one
  too, for the same reason `PasError.ErrorText` gives `errNone` one. }
function RegexFaultText(f: RegexFault): FaultText;

{ How many capturing groups the pattern has, which is the largest `n` the
  three group readers will answer for. }
function RegexGroups(var re: Regex): integer;

{ How many instructions it compiled to -- the other half of the bound below,
  and how a caller sees how much of `ProgMax` a pattern spent. }
function RegexLength(var re: Regex): integer;

{ Instruction visits made by the last match or search on this `Regex`.

  This is the claim the construction is here for, and it is a number rather
  than a sentence so that a test can assert it:

      RegexSteps(re) <= 2 * RegexLength(re) * (length(s) + 2)

  for every pattern and every subject, with no exceptions and no pattern that
  is the bad case. }
function RegexSteps(var re: Regex): integer;

{ Whether the whole of `s` matches -- not a prefix of it and not a part.
  A pattern that has an alternative reaching the end of `s` matches, even
  where an earlier alternative matched a shorter prefix, so this asks what it
  says rather than asking whether the leftmost match happens to cover `s`. }
function RegexMatches(var re: Regex; s: string): boolean;

{ The leftmost match in `s`, reported in `m`. False when there is none, and
  `m` is then all zeroes.

  Leftmost first: among the matches beginning at the earliest position, the
  one the pattern's alternatives reach first wins, with a repeat preferring to
  match. This is the rule a person reading `a|ab` expects, and it is not the
  longest match. }
function RegexSearch(var re: Regex; s: string; var m: RegexMatch): boolean;

{ The same, beginning the search at byte `from`, which is how a caller walks
  every match: search again from `m.stop`, and from `m.stop + 1` when the
  match was empty, or a pattern that can match nothing will not advance. }
function RegexSearchFrom(var re: Regex; s: string; from: integer;
                         var m: RegexMatch): boolean;

{ Where group `n` began and ended in the subject, `n` = 0 being the whole
  match. 0 from both when the group took no part in the match -- which is an
  ordinary answer for a group inside an alternative that was not taken, and is
  why the two are asked rather than a length being offered. }
function RegexGroupStart(var m: RegexMatch; n: integer): integer;
function RegexGroupStop(var m: RegexMatch; n: integer): integer;

{ The text of group `n`, copied out of the subject it was matched against.
  `errAbsent` when the group took no part, `errFull` when the text does not
  fit `out`, and `out` is untouched unless the answer is `errNone`. The
  subject must be the one the match was made against; nothing here remembers
  it, because a copy of the subject in every match record is a copy of a
  document per match. }
function RegexGroupInto(var m: RegexMatch; s: string; n: integer;
                        var out: string): ErrorCode;

end;

{ --- what a fault is ------------------------------------------------------ }

{ The category a caller branches on. Written once, beside the enumeration it
  reads, so a fault added later cannot be given a code in one place and a
  sentence in another. }
function FaultCode(f: RegexFault): ErrorCode;
begin
  case f of
    rxNone: FaultCode := errNone;
    rxUnclosedGroup, rxUnopenedGroup, rxDanglingRepeat, rxUnterminatedClass,
    rxEmptyClass, rxBadRange, rxTrailingEscape, rxUnknownEscape:
      FaultCode := errSyntax;
    rxBackReference: FaultCode := errRange;
    rxPatternTooLong, rxTooManyGroups: FaultCode := errFull
  end
end;

function RegexFaultText;
begin
  case f of
    rxNone:              RegexFaultText := 'no fault';
    rxUnclosedGroup:     RegexFaultText := 'a group is not closed';
    rxUnopenedGroup:     RegexFaultText := 'a group is closed that never opened';
    rxDanglingRepeat:    RegexFaultText := 'a repeat with nothing to repeat';
    rxUnterminatedClass: RegexFaultText := 'a character class is not closed';
    rxEmptyClass:        RegexFaultText := 'a character class with nothing in it';
    rxBadRange:          RegexFaultText := 'a range that runs backwards';
    rxTrailingEscape:    RegexFaultText := 'the pattern ends in an escape';
    rxUnknownEscape:     RegexFaultText := 'an escape with no meaning';
    rxBackReference:     RegexFaultText := 'a back reference has no bounded match';
    rxPatternTooLong:    RegexFaultText := 'the pattern needs more instructions than there are';
    rxTooManyGroups:     RegexFaultText := 'more groups than can be captured'
  end
end;

{ The first fault is the one reported. A later one is a consequence of it, and
  its position would be past where the caller has to look. }
procedure Fail(var re: Regex; f: RegexFault; var e: ErrorCode;
               var at: integer; pos: integer);
begin
  if e = errNone then begin
    re.fault := f;
    e := FaultCode(f);
    at := pos
  end
end;

{ --- character sets ------------------------------------------------------- }

{ Every byte, which is what a negated class is subtracted from. `char` is a
  byte here and nothing consults a locale, which is `PasStrings`' own
  documented choice and the one this module inherits. }
function AllBytes: CharSet;
begin
  AllBytes := [chr(0)..chr(255)]
end;

function WordSet: CharSet;
begin
  WordSet := ['0'..'9', 'a'..'z', 'A'..'Z', '_']
end;

function SpaceSet: CharSet;
begin
  SpaceSet := [' ', chr(9), chr(10), chr(11), chr(12), chr(13)]
end;

{ --- emitting ------------------------------------------------------------- }

{ Room for one more instruction, or 0 and the fault recorded. Every caller
  tests the answer, which is what makes `ProgMax` a report rather than a
  truncation. }
function NewInst(var re: Regex; var e: ErrorCode; var at: integer;
                 pos: integer): integer;
begin
  if re.n >= ProgMax then begin
    Fail(re, rxPatternTooLong, e, at, pos);
    NewInst := 0
  end
  else begin
    re.n := re.n + 1;
    NewInst := re.n
  end
end;

{ Make room at `where` for an instruction that has to come *before* code
  already emitted -- which is what a star, a query and an alternation each
  need, the split they begin with not being writable until the thing it guards
  has been read.

  Everything from `where` up moves one place, so the targets have to be
  repaired -- and the position `where` itself means two different things to
  the two halves of the program, which is the whole subtlety here and cost a
  defect before it was written down.

  To the code *before* `where`, a target of exactly `where` is an exit label:
  "carry on after the thing that ended here". The new instruction is the
  beginning of what comes next, so that label must stay put, and only targets
  past `where` move. Reading it the other way makes an optional item followed
  by an optional item jump over the second one's split and into its body --
  which is a pattern that quietly matches the wrong thing rather than a
  pattern that fails.

  To the code being *moved*, the same number is a position inside itself: a
  repeat's jump back is a target of exactly `where`, and it has to follow the
  split it loops to. So there the comparison includes `where`.

  A target still waiting to be filled in is 0, which is below every position,
  so both halves leave it alone. }
procedure Insert(var re: Regex; where: integer; var e: ErrorCode;
                 var at: integer; pos: integer);
var j: integer;
begin
  if re.n >= ProgMax then
    Fail(re, rxPatternTooLong, e, at, pos)
  else begin
    re.n := re.n + 1;
    for j := re.n downto where + 1 do
      re.code[j] := re.code[j - 1];
    for j := 1 to where - 1 do
      case re.code[j].kind of
        iSplit: begin
          if re.code[j].x > where then re.code[j].x := re.code[j].x + 1;
          if re.code[j].y > where then re.code[j].y := re.code[j].y + 1
        end;
        iJump:
          if re.code[j].dest > where then
            re.code[j].dest := re.code[j].dest + 1;
        iChar, iAny, iClass, iSave, iBol, iEol, iMatch: ;
      end;
    for j := where + 1 to re.n do
      case re.code[j].kind of
        iSplit: begin
          if re.code[j].x >= where then re.code[j].x := re.code[j].x + 1;
          if re.code[j].y >= where then re.code[j].y := re.code[j].y + 1
        end;
        iJump:
          if re.code[j].dest >= where then
            re.code[j].dest := re.code[j].dest + 1;
        iChar, iAny, iClass, iSave, iBol, iEol, iMatch: ;
      end;
    { The caller fills this in next. Until it does the slot holds a copy of
      what moved out of it, and a duplicated tag is worse than a harmless
      one. }
    re.code[where].kind := iJump;
    re.code[where].dest := 0
  end
end;

{ --- reading a pattern ---------------------------------------------------- }

{ An escape, from the backslash. It answers either a character or a set,
  because a tab escape and a digit-class escape stand in the same places and a
  caller of this would otherwise have to ask twice.

  The rule for what a backslash may precede is worth stating: a letter or a
  digit means something or is refused, and anything else is itself. That is
  the way round that lets any punctuation be escaped without a table of which
  of it is special this year, and that refuses an unknown letter instead of
  silently reading it as itself -- a pattern with one in it meant something,
  and it was not the bare letter. }
procedure ScanEscape(var re: Regex; pat: string; var i: integer;
                     var e: ErrorCode; var at: integer;
                     var c: char; var st: CharSet; var isSet: boolean);
var k: char; from: integer;
begin
  from := i;
  c := ' ';
  st := [];
  isSet := false;
  i := i + 1;
  if i > length(pat) then
    Fail(re, rxTrailingEscape, e, at, from)
  else begin
    k := pat[i];
    i := i + 1;
    if k = 'n' then c := chr(10)
    else if k = 't' then c := chr(9)
    else if k = 'r' then c := chr(13)
    else if k = 'f' then c := chr(12)
    else if k = 'd' then begin st := ['0'..'9']; isSet := true end
    else if k = 'D' then begin st := AllBytes - ['0'..'9']; isSet := true end
    else if k = 'w' then begin st := WordSet; isSet := true end
    else if k = 'W' then begin st := AllBytes - WordSet; isSet := true end
    else if k = 's' then begin st := SpaceSet; isSet := true end
    else if k = 'S' then begin st := AllBytes - SpaceSet; isSet := true end
    else if (k >= '1') and (k <= '9') then
      Fail(re, rxBackReference, e, at, from)
    else if ((k >= 'a') and (k <= 'z')) or ((k >= 'A') and (k <= 'Z'))
            or ((k >= '0') and (k <= '9')) then
      Fail(re, rxUnknownEscape, e, at, from)
    else
      c := k
  end
end;

{ A bracketed class, from the opening bracket.

  Two readings this makes and states rather than leaves to be discovered. A
  closing bracket first in a class is *not* a literal here -- write it
  escaped -- which is what leaves a class with nothing in it free to be the
  reported `rxEmptyClass` rather than the first half of an unterminated one.
  And emptiness is asked before negation, so a negated empty class is the same
  fault: a caller that wrote one meant something, and "every byte" is not
  it. }
function ParseClass(var re: Regex; pat: string; var i: integer;
                    var e: ErrorCode; var at: integer): CharSet;
var cls, st: CharSet; neg, isSet, going: boolean;
    lo, hi: char; opened: integer;
begin
  opened := i;
  i := i + 1;
  neg := false;
  if i <= length(pat) then
    if pat[i] = '^' then begin
      neg := true;
      i := i + 1
    end;
  cls := [];
  going := true;
  while going and (e = errNone) do
    if i > length(pat) then begin
      Fail(re, rxUnterminatedClass, e, at, opened);
      going := false
    end
    else if pat[i] = ']' then begin
      i := i + 1;
      going := false
    end
    else begin
      lo := pat[i];
      isSet := false;
      st := [];
      if pat[i] = '\' then ScanEscape(re, pat, i, e, at, lo, st, isSet)
      else i := i + 1;
      if e = errNone then
        if isSet then
          cls := cls + st
        else if (i + 1 <= length(pat)) and (pat[i] = '-')
                and (pat[i + 1] <> ']') then begin
          i := i + 1;
          hi := pat[i];
          if pat[i] = '\' then ScanEscape(re, pat, i, e, at, hi, st, isSet)
          else i := i + 1;
          if e = errNone then
            if isSet or (ord(hi) < ord(lo)) then
              Fail(re, rxBadRange, e, at, i - 1)
            else
              cls := cls + [lo..hi]
        end
        else
          cls := cls + [lo]
    end;
  if e = errNone then
    if cls = [] then Fail(re, rxEmptyClass, e, at, opened);
  if neg then cls := AllBytes - cls;
  ParseClass := cls
end;

procedure ParseAlt(var re: Regex; pat: string; var i: integer;
                   var e: ErrorCode; var at: integer); forward;

procedure ParseAtom(var re: Regex; pat: string; var i: integer;
                    var e: ErrorCode; var at: integer);
var g, k: integer; c: char; st: CharSet; isSet: boolean;
begin
  c := pat[i];
  if c = '(' then begin
    i := i + 1;
    if re.groups >= GroupMax then
      Fail(re, rxTooManyGroups, e, at, i - 1)
    else begin
      re.groups := re.groups + 1;
      g := re.groups;
      k := NewInst(re, e, at, i);
      if k > 0 then begin
        re.code[k].kind := iSave;
        re.code[k].slot := 2 * g + 1
      end;
      if e = errNone then ParseAlt(re, pat, i, e, at);
      if e = errNone then
        if i > length(pat) then Fail(re, rxUnclosedGroup, e, at, i)
        else if pat[i] <> ')' then Fail(re, rxUnclosedGroup, e, at, i)
        else begin
          i := i + 1;
          k := NewInst(re, e, at, i);
          if k > 0 then begin
            re.code[k].kind := iSave;
            re.code[k].slot := 2 * g + 2
          end
        end
    end
  end
  else if (c = '*') or (c = '+') or (c = '?') then
    Fail(re, rxDanglingRepeat, e, at, i)
  else if c = '.' then begin
    i := i + 1;
    k := NewInst(re, e, at, i);
    if k > 0 then re.code[k].kind := iAny
  end
  else if c = '^' then begin
    i := i + 1;
    k := NewInst(re, e, at, i);
    if k > 0 then re.code[k].kind := iBol
  end
  else if c = '$' then begin
    i := i + 1;
    k := NewInst(re, e, at, i);
    if k > 0 then re.code[k].kind := iEol
  end
  else if c = '[' then begin
    st := ParseClass(re, pat, i, e, at);
    if e = errNone then begin
      k := NewInst(re, e, at, i);
      if k > 0 then begin
        re.code[k].kind := iClass;
        re.code[k].cls := st
      end
    end
  end
  else if c = '\' then begin
    ScanEscape(re, pat, i, e, at, c, st, isSet);
    if e = errNone then begin
      k := NewInst(re, e, at, i);
      if k > 0 then
        if isSet then begin
          re.code[k].kind := iClass;
          re.code[k].cls := st
        end
        else begin
          re.code[k].kind := iChar;
          re.code[k].ch := c
        end
    end
  end
  else begin
    i := i + 1;
    k := NewInst(re, e, at, i);
    if k > 0 then begin
      re.code[k].kind := iChar;
      re.code[k].ch := c
    end
  end
end;

{ An atom and the repeats stacked on it. The three shapes are the textbook
  ones and the arithmetic is the part to read carefully -- a star is a split
  before the body and a jump back after it, a plus is a split after the body
  alone, and a query is the star without the jump.

  `aStart` is where the atom's code begins and stays right across a stack of
  repeats, because `Insert` moves the code up and the beginning stays put. }
procedure ParseRepeat(var re: Regex; pat: string; var i: integer;
                      var e: ErrorCode; var at: integer);
var aStart, k: integer; q: char;
begin
  aStart := re.n + 1;
  ParseAtom(re, pat, i, e, at);
  while (e = errNone) and (i <= length(pat))
        and ((pat[i] = '*') or (pat[i] = '+') or (pat[i] = '?')) do begin
    q := pat[i];
    i := i + 1;
    if q = '+' then begin
      k := NewInst(re, e, at, i);
      if k > 0 then begin
        re.code[k].kind := iSplit;
        re.code[k].x := aStart;
        re.code[k].y := k + 1
      end
    end
    else begin
      Insert(re, aStart, e, at, i);
      if e = errNone then begin
        re.code[aStart].kind := iSplit;
        re.code[aStart].x := aStart + 1;
        re.code[aStart].y := 0;
        if q = '*' then begin
          k := NewInst(re, e, at, i);
          if k > 0 then begin
            re.code[k].kind := iJump;
            re.code[k].dest := aStart
          end
        end;
        if e = errNone then re.code[aStart].y := re.n + 1
      end
    end
  end
end;

{ A sequence, which ends at an alternation bar, at a closing parenthesis or at
  the end of the pattern. An empty one is legal and emits nothing, so a
  pattern whose last alternative is empty matches nothing at all as well --
  the alternative was written and it is empty, which is a thing a pattern may
  say. }
procedure ParseConcat(var re: Regex; pat: string; var i: integer;
                      var e: ErrorCode; var at: integer);
begin
  while (e = errNone) and (i <= length(pat)) and (pat[i] <> '|')
        and (pat[i] <> ')') do
    ParseRepeat(re, pat, i, e, at)
end;

procedure ParseAlt;
var aStart, jumpPc, bStart: integer;
begin
  aStart := re.n + 1;
  ParseConcat(re, pat, i, e, at);
  while (e = errNone) and (i <= length(pat)) and (pat[i] = '|') do begin
    i := i + 1;
    Insert(re, aStart, e, at, i);
    if e = errNone then begin
      re.code[aStart].kind := iSplit;
      re.code[aStart].x := aStart + 1;
      re.code[aStart].y := 0;
      jumpPc := NewInst(re, e, at, i);
      if jumpPc > 0 then begin
        re.code[jumpPc].kind := iJump;
        re.code[jumpPc].dest := 0
      end;
      if e = errNone then begin
        bStart := re.n + 1;
        ParseConcat(re, pat, i, e, at);
        if e = errNone then begin
          re.code[jumpPc].dest := re.n + 1;
          re.code[aStart].y := bStart
        end
      end
    end
  end
end;

function RegexCompile;
var k, i: integer; e: ErrorCode;
begin
  re.n := 0;
  re.groups := 0;
  re.fault := rxNone;
  re.steps := 0;
  e := errNone;
  i := 1;
  at := 1;
  { Group 0's two positions are recorded by the same instruction every other
    group uses, so the whole match needs no special case anywhere below. }
  k := NewInst(re, e, at, 1);
  if k > 0 then begin
    re.code[k].kind := iSave;
    re.code[k].slot := 1
  end;
  if e = errNone then ParseAlt(re, pat, i, e, at);
  { ParseConcat stops at a closing parenthesis and ParseAlt consumes every
    bar, so the only thing that can be left over is a parenthesis that closed
    nothing. }
  if e = errNone then
    if i <= length(pat) then Fail(re, rxUnopenedGroup, e, at, i);
  if e = errNone then begin
    k := NewInst(re, e, at, i);
    if k > 0 then begin
      re.code[k].kind := iSave;
      re.code[k].slot := 2
    end
  end;
  if e = errNone then begin
    k := NewInst(re, e, at, i);
    if k > 0 then re.code[k].kind := iMatch
  end;
  if e = errNone then at := i
  else re.n := 0;
  RegexCompile := e
end;

{ --- matching ------------------------------------------------------------- }

{ Add a thread at `pc`, following everything that costs no input -- a jump, a
  split, a recorded position, an anchor -- until an instruction that reads a
  byte, or succeeds, is reached. That instruction is what goes in the list.

  `mark` against `gen` is the whole of the bound: a program counter enters a
  list once per byte, so however many ways the pattern offers of arriving
  here, the work is one visit. It is also what makes a repeat whose body can
  match nothing terminate rather than loop.

  A slot is set, followed, and put back: the thread that continues past a save
  sees the new position and every sibling reached afterwards sees the old one,
  which is what makes one array serve every path through this walk.

  The range test on `pc` guards a subscript rather than a defect: every target
  this module emits is inside the program, and a subscript outside its bounds
  would stop a caller's program where answering no match is the honest
  thing. }
procedure AddThread(var re: Regex; var l: ThreadList; pc, sp, len: integer;
                    var saved: Slots);
var old, which, k: integer;
begin
  if (pc >= 1) and (pc <= re.n) then
    if l.mark[pc] <> l.gen then begin
      l.mark[pc] := l.gen;
      re.steps := re.steps + 1;
      case re.code[pc].kind of
        iJump: AddThread(re, l, re.code[pc].dest, sp, len, saved);
        iSplit: begin
          AddThread(re, l, re.code[pc].x, sp, len, saved);
          AddThread(re, l, re.code[pc].y, sp, len, saved)
        end;
        iSave: begin
          which := re.code[pc].slot;
          old := saved[which];
          saved[which] := sp;
          AddThread(re, l, pc + 1, sp, len, saved);
          saved[which] := old
        end;
        iBol: if sp = 1 then AddThread(re, l, pc + 1, sp, len, saved);
        iEol: if sp = len + 1 then AddThread(re, l, pc + 1, sp, len, saved);
        iChar, iAny, iClass, iMatch: begin
          l.n := l.n + 1;
          l.pc[l.n] := pc;
          for k := 1 to SlotMax do l.sl[l.n][k] := saved[k]
        end
      end
    end
end;

{ One walk of the subject, and the only one in this module.

  `anchored` starts threads at `from` and nowhere else; without it a fresh
  thread is started at every byte until something matches, and it is started
  *last*, which is what makes an earlier start beat a later one.

  `whole` makes success mean success at the end of the subject: a thread that
  reaches the end of the program earlier simply dies, and the walk carries on
  down the alternatives. It is the difference between "does this match" and
  "does this match here", and it is one condition rather than a second
  matcher.

  Success cuts the threads below it in the list. They are the alternatives the
  pattern offered later and the starts it offered further right, and both lose
  to what has already matched -- which is what leftmost-first means, spelled
  as an operation on the list. }
function Run(var re: Regex; s: string; from: integer;
             anchored, whole: boolean; var m: RegexMatch): boolean;
var lists: array [1..2] of ThreadList;
    saved: Slots;
    cur, nxt, sp, i, pc, k, len, swap: integer;
    matched, going: boolean;
begin
  len := length(s);
  re.steps := 0;
  for k := 1 to SlotMax do begin
    m.slot[k] := 0;
    saved[k] := 0
  end;
  m.start := 0;
  m.stop := 0;
  m.groups := re.groups;
  matched := false;
  for k := 1 to ProgMax do begin
    lists[1].mark[k] := 0;
    lists[2].mark[k] := 0
  end;
  lists[1].n := 0;
  lists[2].n := 0;
  lists[1].gen := 1;
  lists[2].gen := 0;
  cur := 1;
  nxt := 2;
  sp := from;
  if sp < 1 then sp := 1;
  going := sp <= len + 1;
  while going do begin
    if not matched then
      if (not anchored) or (sp = from) then begin
        for k := 1 to SlotMax do saved[k] := 0;
        AddThread(re, lists[cur], 1, sp, len, saved)
      end;
    lists[nxt].n := 0;
    lists[nxt].gen := lists[nxt].gen + 1;
    i := 1;
    while i <= lists[cur].n do begin
      pc := lists[cur].pc[i];
      re.steps := re.steps + 1;
      case re.code[pc].kind of
        iChar:
          if sp <= len then
            if s[sp] = re.code[pc].ch then
              AddThread(re, lists[nxt], pc + 1, sp + 1, len, lists[cur].sl[i]);
        iAny:
          if sp <= len then
            AddThread(re, lists[nxt], pc + 1, sp + 1, len, lists[cur].sl[i]);
        iClass:
          if sp <= len then
            if s[sp] in re.code[pc].cls then
              AddThread(re, lists[nxt], pc + 1, sp + 1, len, lists[cur].sl[i]);
        iMatch:
          if (not whole) or (sp = len + 1) then begin
            matched := true;
            for k := 1 to SlotMax do m.slot[k] := lists[cur].sl[i][k];
            i := lists[cur].n
          end;
        iSplit, iJump, iSave, iBol, iEol: ;
      end;
      i := i + 1
    end;
    swap := cur;
    cur := nxt;
    nxt := swap;
    sp := sp + 1;
    if sp > len + 1 then going := false
    else if lists[cur].n = 0 then
      if matched or anchored then going := false
  end;
  if matched then begin
    m.start := m.slot[1];
    m.stop := m.slot[2];
    m.groups := re.groups
  end;
  Run := matched
end;

function RegexMatches;
var m: RegexMatch;
begin
  RegexMatches := Run(re, s, 1, true, true, m)
end;

function RegexSearchFrom;
begin
  RegexSearchFrom := Run(re, s, from, false, false, m)
end;

function RegexSearch;
begin
  RegexSearch := Run(re, s, 1, false, false, m)
end;

{ --- reading a Regex and a RegexMatch ------------------------------------- }

function RegexFaultOf;
begin
  RegexFaultOf := re.fault
end;

function RegexGroups;
begin
  RegexGroups := re.groups
end;

function RegexLength;
begin
  RegexLength := re.n
end;

function RegexSteps;
begin
  RegexSteps := re.steps
end;

function RegexGroupStart;
begin
  if (n < 0) or (n > GroupMax) then RegexGroupStart := 0
  else RegexGroupStart := m.slot[2 * n + 1]
end;

function RegexGroupStop;
begin
  if (n < 0) or (n > GroupMax) then RegexGroupStop := 0
  else RegexGroupStop := m.slot[2 * n + 2]
end;

function RegexGroupInto;
var a, b, k: integer;
begin
  a := RegexGroupStart(m, n);
  b := RegexGroupStop(m, n);
  if (a = 0) or (b = 0) or (b < a) then
    RegexGroupInto := errAbsent
  else if b - a > out.capacity then
    RegexGroupInto := errFull
  else begin
    { Built into `out` itself rather than through a local, which is
      `JsonCharsInto`'s lesson: an accumulator of some other capacity makes
      the guard above a claim about the wrong string. }
    out := '';
    for k := a to b - 1 do
      out := out + s[k];
    RegexGroupInto := errNone
  end
end;

end.
