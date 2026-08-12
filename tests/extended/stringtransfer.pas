{ ISO/IEC 10206:1991 §6.7.5.5's two string transfer procedures.

    readstr-parameter-list  = '(' string-expression ',' variable-access, ... ')'
    writestr-parameter-list = '(' string-variable ',' write-parameter, ... ')'

  The standard defines both *as* a sequence of ordinary file operations on
  "an auxiliary variable that the program does not otherwise contain, which
  possesses the required type text":

    readstr(e, v1, ..., vn)  =  rewrite(f); writeln(f, e); reset(f);
                                read(f, v1, ..., vn)
    writestr(s, p1, ..., pn) =  rewrite(f); writeln(f, p1, ..., pn); reset(f);
                                read(f, ss)

  This compiler implements that equivalence literally: the runtime supplies a
  memory-backed text file and every value is read and written by the same
  pas_read_* and pas_write_* calls an ordinary text file uses. So a field
  width means here exactly what it means in `write`, and reading a string here
  stops at the same places §6.10.1 says it stops. }
program StringTransfer(output);
type
  s20   = string(20);
  s8    = string(8);
  name8 = packed array [1..8] of char;
  colour = (red, green, blue);
  rec   = record tag: s20; n: integer end;
var
  s: s20; t: s8; fixed: name8; e: s20;
  i, j: integer; r: real; c: char; b: boolean;
  small: 1..9;
  line: s20; r2: rec;
  vec: array [1..3] of s8;
  k: integer;

{ A writestr into a var parameter, which is where the destination's capacity
  arrives with the actual rather than being written down (ADR-0040's
  descriptor). }
procedure label7(var into: s20; n: integer);
begin
  writestr(into, 'item ', n:1)
end;

{ A function whose body contains a writestr, called from inside another
  writestr's write-parameters. The auxiliary variable is allocated per
  statement rather than being one static, so the inner one cannot disturb the
  outer one -- which is the only reason this program is here. }
function tag(n: integer): s8;
var got: s8;
begin
  writestr(got, '<', n:1, '>');
  tag := got
end;

begin
  { §6.7.5.5's own example, NOTE 5: "S = ' 0.17    6'" for a capacity of at
    least 8. The field widths are write's, so 0.168:5:2 is five columns with
    two fraction digits and 6:3 is three columns. }
  writestr(s, 0.168:5:2, 6:3);
  writeln('note5  [', s, '] ', length(s):1);

  { ...and NOTE 2, the other example: E := '0.0-4'; readstr(E, R, C, I) yields
    R = 0.0, C = '-' and I = 4. The three variables have three different types
    and one string supplies all of them, which is the whole point of the
    procedure. }
  e := '0.0-4';
  readstr(e, r, c, i);
  writeln('note2  ', r:3:1, ' [', c, '] ', i:1);

  { Every kind of write-parameter §6.10.3 admits, since writestr's parameters
    *are* write-parameters. A boolean and a string among them, and a default
    width for each. }
  b := true;
  writestr(s, 'n=', 42:4, ' ', b, ' ', 'xy', ' ', 'q');
  writeln('kinds  [', s, ']');

  { The destination may be a fixed-string, and then §6.4.6's padding applies
    -- the store is the ordinary string store, so the rule needed no clause of
    its own. A shorter value is padded to the capacity. }
  writestr(fixed, 'ab', 7:1);
  writeln('fixed  [', fixed, ']');

  { A variable-string keeps exactly what was written, so its length is the
    number of characters and not the capacity. }
  writestr(t, 'ab', 7:1);
  writeln('var    [', t, '] ', length(t):1);

  { A substring-variable is a variable-access (§6.5.6), so it may be written
    into. Its capacity is hi - lo + 1 and the tail is padded, because §6.5.6
    makes it a fixed-string-type. }
  s := 'ABCDEFGH';
  writestr(s[3..6], 'zz');
  writeln('substr [', s, ']');

  { A component and a field are variable-accesses too. }
  writestr(vec[2], 'v', 2:1);
  writestr(r2.tag, 'r', 9:2);
  writeln('parts  [', vec[2], '] [', r2.tag, ']');

  { A var parameter, whose capacity the callee reads from its descriptor. }
  label7(line, 7);
  writeln('param  [', line, ']');

  { A writestr inside the write-parameters of a writestr. }
  writestr(s, tag(1), '-', tag(2));
  writeln('nested [', s, ']');

  { The string readstr reads from may be any string-expression: a literal, a
    variable, a concatenation, a substring, a substr, or a single char. }
  readstr('11 22', i, j);
  writeln('two    ', i:1, ' ', j:1);

  e := '5';
  readstr(e + '7', i);
  writeln('concat ', i:1);

  e := 'xx31yy';
  readstr(e[3..4], i);
  writeln('slice  ', i:1);

  readstr('8', i);
  writeln('char   ', i:1);

  { §6.10.1's list of what may be read: a char, an integer, a real, and -- in
    Extended Pascal -- a string. A string read takes at most the capacity and
    stops at the end of line, which here is the line marker writeln appended
    to the auxiliary file. }
  readstr('hello there', t);
  writeln('str    [', t, '] ', length(t):1);

  readstr('pad', fixed);
  writeln('strfix [', fixed, ']');

  { Reading into a subrange is a store like any other, so it is range-checked
    like any other (ADR-0018) -- 7 is inside 1..9. }
  readstr('7', small);
  writeln('sub    ', small:1);

  { A component, a field and a substring-variable as read targets. }
  readstr('12 34', r2.n, vec[1]);
  s := '........';
  readstr('QQ', s[2..3]);
  writeln('into   ', r2.n:1, ' [', vec[1], '] [', s, ']');

  { A string read is greedy to the end of the line (§6.10.1 e), so a second
    string variable after one gets the null-string rather than the rest --
    there is no rest. It is *not* an error: the line marker writeln appended
    is still unread, so eof is false when the statement completes. }
  readstr('c1 c2', vec[2], vec[3]);
  writeln('greedy [', vec[2], '] [', vec[3], '] ', length(vec[3]):1);

  { The characters are *copied* before anything is read, so a readstr may read
    into the very variable it reads from. Without the copy the source would
    change under the reader. }
  e := '3 4';
  readstr(e, i, e);
  writeln('self   ', i:1, ' [', e, '] ', length(e):1);

  { A readstr in a loop, which is what the two procedures are for: the string
    is where the representation is, and the file is nowhere. }
  s := '';
  for k := 1 to 3 do begin
    writestr(t, k:1, k * k:3);
    readstr(t, i, j);
    writestr(line, i:1, '^2=', j:1);
    s := line
  end;
  writeln('loop   [', s, ']')
end.
