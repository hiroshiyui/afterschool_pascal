{ Every required identifier of ISO/IEC 10206:1991, used for its purpose.

  Annex C enumerates the required identifiers and the clause that defines each.
  There are 94, and this program touches all of them: the required constants
  and types of 6.4.2.2, the required record types of 6.4.3.4 and their field
  identifiers, the required schema of 6.4.3.3.3 and its discriminant, the
  required procedures of 6.7.5, the required functions of 6.7.6, the required
  variables of 6.10 and the required interfaces of 6.11.4.2.

  It exists because *this* is the list that has failed here before. 6.6.5.4's
  pack and unpack and 6.9.5's page were missing from the ISO 7185 compiler
  while three separate documents asserted that standard was complete: the names
  were in `isRequiredName` so a required procedure could be refused as a
  parameter, and nowhere else. Every oracle agreed, because no program in the
  corpus had ever written one (ADR-0067). A name that resolves is not a feature;
  a name that does its job is, and every line below checks an answer rather
  than checking that something compiled.

  What it deliberately does not do is assert the *values* of things that are
  not fixed. maxreal, minreal and epsreal are checked by the property 6.4.2.2 b)
  defines them by, because printed digits would pass with any nearby value
  (ADR-0076). The clock is fixed by required_identifiers.epoch, which is what
  lets date and time be compared at all (ADR-0065).

  The identifiers that cannot appear in a main-program-block -- StandardInput
  and StandardOutput, which 6.11.4.2 makes interfaces -- are exercised by the
  module below, this file being a program-block of two components (6.13). }

module required;

export reqiface = (moduleWrote, moduleSawInput);

{ 6.11.4.2's two required interfaces. A module reaches the required text files
  through these or through its module-parameters and in no other way, which is
  what makes importing them the way to exercise them. }
import StandardOutput;
       StandardInput;

function moduleWrote: Boolean;
function moduleSawInput: Boolean;
end;

function moduleWrote;
begin
  writeln(output, 'StandardOutput: a module reached output');
  moduleWrote := true
end;

function moduleSawInput;
begin
  moduleSawInput := not eof(input)
end;

end.

program RequiredIdentifiers(input, output);

import reqiface;

type
  ptr = ^integer;
  unpacked = array [1..4] of char;
  packedArr = packed array [1..2] of char;

var
  { the required simple types of 6.4.2.2 }
  i: integer;
  r: real;
  c: char;
  b: Boolean;
  z: complex;
  { 6.4.3.5's required file type, and 6.4.3.6's direct-access one }
  t: text;
  d: file [1..4] of integer;
  { 6.4.3.3.3's required schema, and 6.4.3.4's two required record types }
  s: string(12);
  stamp: TimeStamp;
  bnd: BindingType;
  bf: bindable text;
  q: ptr;
  ua: unpacked;
  pa: packedArr;

begin
  { --- 6.4.2.2: the required constants --------------------------------- }
  writeln('maxint > 0: ', maxint > 0);
  writeln('maxchar: ', ord(maxchar));
  { 6.4.2.2 b) defines these three by a property, so a property is what is
    asserted: printed digits would pass with any value nearby. }
  writeln('maxreal > minreal: ', maxreal > minreal);
  writeln('minreal > 0: ', minreal > 0.0);
  writeln('epsreal: ', (1.0 + epsreal > 1.0) and (1.0 + epsreal / 2.0 = 1.0));
  b := true;
  writeln('true, false: ', b, ' ', false);

  { --- 6.4.2.2, 6.4.3.5: the required simple types and text ------------- }
  i := 6;
  r := 2.5;
  c := 'k';
  writeln('integer, real, char: ', i:1, ' ', r:3:1, ' ', c);

  { --- 6.7.6.2: the arithmetic functions -------------------------------- }
  writeln('abs, sqr: ', abs(-7):1, ' ', sqr(5):1);
  writeln('sqrt, exp, ln: ', sqrt(9.0):3:1, ' ', exp(0.0):3:1, ' ',
          ln(1.0):3:1);
  writeln('sin, cos, arctan: ', sin(0.0):3:1, ' ', cos(0.0):3:1, ' ',
          arctan(0.0):3:1);

  { --- 6.4.2.2 e), 6.7.6.2: complex ------------------------------------- }
  z := cmplx(3.0, 4.0);
  writeln('cmplx, re, im: ', re(z):3:1, ' ', im(z):3:1);
  writeln('abs of complex: ', abs(z):3:1);
  z := polar(1.0, 0.0);
  writeln('polar, arg: ', re(z):3:1, ' ', arg(z):3:1);

  { --- 6.7.6.3, 6.7.6.4: transfer and ordinal functions ----------------- }
  writeln('trunc, round: ', trunc(3.7):1, ' ', round(3.5):1);
  writeln('ord, chr: ', ord('A'):1, ' ', chr(66));
  writeln('card: ', card([1, 2, 3, 5]):1);
  { the two-argument forms are 6.7.6.4's, and are not ISO 7185's }
  writeln('succ, pred: ', succ(4):1, ' ', succ(4, 3):1, ' ', pred(4):1, ' ',
          pred(9, 3):1);

  { --- 6.7.6.5: the Boolean functions ----------------------------------- }
  writeln('odd: ', odd(7));

  { --- 6.7.6.7: the string functions ------------------------------------ }
  s := 'abcdef';
  writeln('length, capacity: ', length(s):1, ' ', s.capacity:1);
  writeln('substr, index: ', substr(s, 2, 3), ' ', index(s, 'cd'):1);
  s := 'ab';
  writeln('trim: ', length(trim(s)):1);
  { 6.7.6.7's comparisons compare lengths as well, which the relational
    operators of 6.8.3.5 do not -- see schema_string_compare.pas }
  writeln('EQ, NE: ', EQ('a', 'a'), ' ', NE('a', 'b'));
  writeln('LT, GT: ', LT('a', 'b'), ' ', GT('b', 'a'));
  writeln('LE, GE: ', LE('a', 'a'), ' ', GE('a', 'a'));

  { --- 6.7.5.5: the string transfer procedures -------------------------- }
  readstr('84', i);
  writeln('readstr: ', i:1);
  writestr(s, 4, 2);
  writeln('writestr: ', s);

  { --- 6.7.5.3: dynamic allocation -------------------------------------- }
  new(q);
  q^ := 11;
  writeln('new: ', q^:1);
  dispose(q);
  writeln('dispose: done');

  { --- 6.7.5.4: the transfer procedures --------------------------------- }
  ua[1] := 'w'; ua[2] := 'x'; ua[3] := 'y'; ua[4] := 'z';
  pack(ua, 2, pa);
  writeln('pack: ', pa);
  pa := 'mn';
  unpack(pa, ua, 3);
  writeln('unpack: ', ua[3], ua[4]);

  { --- 6.7.5.2, 6.9.5: the file procedures, on a local text file -------- }
  rewrite(t);
  write(t, 'p');
  writeln(t);
  page(t);
  reset(t);
  writeln('eof, eoln of a written file: ', eof(t), ' ', eoln(t));
  c := t^;
  get(t);
  writeln('get, buffer variable: ', c);
  extend(t);
  writeln(t, 'more');
  writeln('extend: done');
  rewrite(t);
  t^ := 'z';
  put(t);
  writeln('put: done');

  { --- 6.7.5.2, 6.7.6.6: the direct-access file ------------------------- }
  rewrite(d);
  writeln('empty: ', empty(d));
  d^ := 10; put(d);
  d^ := 20; put(d);
  SeekRead(d, 2);
  writeln('SeekRead, position: ', d^:1, ' ', position(d):1);
  writeln('LastPosition: ', LastPosition(d):1);
  SeekUpdate(d, 1);
  d^ := 99;
  update(d);
  SeekRead(d, 1);
  writeln('SeekUpdate, update: ', d^:1);
  SeekWrite(d, 3);
  d^ := 30;
  put(d);
  SeekRead(d, 3);
  writeln('SeekWrite: ', d^:1);

  { --- 6.7.5.6, 6.7.6.8: binding ---------------------------------------- }
  bnd := binding(bf);
  writeln('binding of an unbound file: ', bnd.bound, ' ', length(bnd.name):1);
  bnd.name := '/tmp/apascal_required.txt';
  bind(bf, bnd);
  { E.16 (ADR-0172): bound to an external entity when the entity exists, so
    the file is created before binding is asked }
  rewrite(bf);
  bnd := binding(bf);
  writeln('bind: ', bnd.bound, ' ', bnd.name);
  unbind(bf);
  writeln('unbind: ', binding(bf).bound);

  { --- 6.7.5.8, 6.7.6.9: the time procedures and functions -------------- }
  { The clock is fixed by required_identifiers.epoch, which is the only way a
    golden file can name a date (ADR-0065). }
  GetTimeStamp(stamp);
  writeln('DateValid, TimeValid: ', stamp.DateValid, ' ', stamp.TimeValid);
  writeln('year, month, day: ', stamp.year:1, ' ', stamp.month:1, ' ',
          stamp.day:1);
  writeln('hour, minute, second: ', stamp.hour:1, ' ', stamp.minute:1, ' ',
          stamp.second:1);
  writeln('date, time: ', date(stamp), ' ', time(stamp));

  { --- 6.10, 6.11.4.2: the required variables and interfaces ------------ }
  writeln(output, 'output: named explicitly');
  read(i);
  readln(r);
  writeln('read, readln from input: ', i:1, ' ', r:3:1);
  writeln('eof(input): ', eof(input));
  b := moduleWrote;
  writeln('StandardInput: a module read input: ', moduleSawInput);

  { --- 6.7.5.7: halt, last, because it terminates ----------------------- }
  writeln('halt: about to');
  halt
end.
