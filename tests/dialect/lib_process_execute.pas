{ PasProcess.Execute -- a command carried as words rather than as a line
  (ADR-0362).

  What is pinned here is the property the whole construct exists for: an
  argument means nothing to anybody. Case 2 is the one that matters -- the
  words in it are a shell's entire vocabulary, and every one of them comes
  back the way it went in. Under `Run` the same string would have run three
  commands.

  The rest is the surface: where the words come from, where the output goes,
  what an empty vector does, what a command that is not there does, and the
  positions a handle can be written in -- a record field, a `var` parameter,
  and a variable emptied by hand. }
program lib_process_execute(output);

import PasError;
       PasProcess;
       PasStrVec;

type
  { a handle in a record, which is a position and not a convenience: a program
    running several commands holds them somewhere }
  Job = record
    name: string(8);
    args: ArgV
  end;

var
  v: ArgV;
  e: ErrorCode;
  r: RunResult;
  out: string(4096);
  big: string(700);
  i: integer;
  j: Job;
  lines: StrVecPtr;
  f: bindable text;
  b: BindingType;
  line: string(255);
  dump: string(255);

{ The words assembled somewhere other than where the command is run, which is
  the shape a driver has: a handle crosses as a `var` parameter. }
procedure AddPath(var av: ArgV; p: string);
var junk: ErrorCode;
begin
  junk := AddArg(av, '--import-path');
  junk := AddArg(av, p)
end;

begin
  dump := 'execute_dump.txt';

  { 1. The ordinary case, with the child's streams this program's. `hello`
       is written before the line below it because the flush happens before
       the child starts and this program then waits for it. }
  e := NewArgs(v);
  e := AddArg(v, 'echo');
  e := AddArg(v, 'hello');
  r := Execute(v);
  writeln('1 ok=', r.ok, ' code=', r.val:1, ' words=', ArgsLen(v):1);

  { 2. The point. Nothing here is expanded, split, redirected or run. }
  e := NewArgs(v);
  e := AddArg(v, 'echo');
  e := AddArg(v, 'a''; touch PWNED; echo ''b');
  e := AddArg(v, '$HOME `id` * | wc');
  r := ExecuteInto(v, out);
  write('2 [', out, ']');

  { 3. A command that is not there. No shell ran, so there is no shell to
       exit 127: the failure is that nothing started. }
  e := NewArgs(v);
  e := AddArg(v, 'no-such-program-anywhere');
  r := Execute(v);
  writeln('3 ok=', r.ok, ' cause=', ErrorText(r.cause));

  { 4. A status of the child's own. }
  e := NewArgs(v);
  e := AddArg(v, 'sh');
  e := AddArg(v, '-c');
  e := AddArg(v, 'exit 3');
  r := Execute(v);
  writeln('4 ', r.val:1);

  { 5. No words at all -- there is no argv[0] to run. }
  e := NewArgs(v);
  r := Execute(v);
  writeln('5 ok=', r.ok, ' cause=', ErrorText(r.cause));

  { 6. An argument longer than a name. ADR-0291 says a path may be, and a
       vector of StrItem would have cut this at 255. }
  big := '/tmp';
  for i := 1 to 40 do big := big + '/0123456789abcde';
  e := AddArg(v, big);
  writeln('6 ', ErrorText(e), ' len=', length(big):1);

  { 7. Standard output captured and standard error not.

       **The child is told where to put its standard error and that is not
       incidental**: `ExecuteInto` leaves that stream this program's, so
       without the `exec` the child would write into the golden beside the
       program -- two writers on one stream, whose order is the harness's and
       not this program's. It was written the other way first and
       `selfhost-codegen` and `run_test.sh` disagreed about where the line
       landed. What is claimed here is that `out` holds `out` and not `err`;
       case 8 runs the same command with both streams taken and shows the
       difference. }
  e := NewArgs(v);
  e := AddArg(v, 'sh');
  e := AddArg(v, '-c');
  e := AddArg(v, 'exec 2>/dev/null; echo out; echo err >&2');
  r := ExecuteInto(v, out);
  write('7 [', out, ']');

  { 8. ...and both together, which is what `2>&1` was for and what no caller
       can write where no shell reads it. }
  e := NewArgs(v);
  e := AddArg(v, 'sh');
  e := AddArg(v, '-c');
  e := AddArg(v, 'echo out; echo err >&2');
  r := ExecuteBoth(v, out);
  write('8 [', out, ']');

  { 9. A field, filled through a `var` parameter. }
  e := NewArgs(j.args);
  AddPath(j.args, '/opt/apascal/lib/afterschool');
  writeln('9 words=', ArgsLen(j.args):1);

  { 10. The vector is not consumed: the same words run twice. }
  e := NewArgs(v);
  e := AddArg(v, 'true');
  r := Execute(v);
  r := Execute(v);
  writeln('10 ok=', r.ok);

  { 11. Capture's contract: what does not fit is read and dropped, so the
        command still runs to its end and the code is still its own. }
  e := NewArgs(v);
  e := AddArg(v, 'echo');
  e := AddArg(v, 'far more than eight characters');
  r := ExecuteInto(v, j.name);
  writeln('11 ok=', r.ok, ' code=', r.val:1, ' [', j.name, ']');

  { 12. Both streams a line at a time, which is what a caller reading a
        compiler's diagnostics needs and what `2>&1` used to buy. }
  e := NewArgs(v);
  e := AddArg(v, 'sh');
  e := AddArg(v, '-c');
  e := AddArg(v, 'echo one; echo two >&2');
  SVecNew(lines, 8);
  r := ExecuteLines(v, lines);
  writeln('12 lines=', SVecLen(lines):1, ' [', SVecGet(lines, 1),
          '][', SVecGet(lines, 2), ']');

  { 13. And straight to a file, for an answer too large to hold. }
  e := NewArgs(v);
  e := AddArg(v, 'sh');
  e := AddArg(v, '-c');
  e := AddArg(v, 'echo written; echo also >&2');
  r := ExecuteToFile(v, dump);
  writeln('13 ok=', r.ok, ' code=', r.val:1);
  b := binding(f);
  b.name := dump;
  bind(f, b);
  reset(f);
  while not eof(f) do begin
    readln(f, line);
    writeln('13 [', line, ']')
  end;
  unbind(f);

  { 14. Speculation and the way back out of it: a caller that pushed a
        candidate's words and then found it was the wrong candidate has
        `ArgsLen` for the mark and `DropArgs` for the reset. }
  e := NewArgs(v);
  e := AddArg(v, 'echo');
  i := ArgsLen(v);
  e := AddArg(v, 'one');
  e := AddArg(v, 'two');
  writeln('14 pushed=', ArgsLen(v):1, ' back to ', DropArgs(v, i):1);
  e := AddArg(v, 'kept');
  r := ExecuteInto(v, out);
  write('14 [', out, ']');

  { 15. The bound is a diagnostic and not a limit reached in silence
        (ADR-0012's claim, and this library's version of it). }
  e := NewArgs(v);
  i := 0;
  repeat
    e := AddArg(v, 'w');
    i := i + 1
  until Failed(e) or (i > 5000);
  writeln('15 ', ErrorText(e), ' at ', i:1, ' words=', ArgsLen(v):1);

  { 16. Emptied by hand rather than at the end of the block (AP 6.4.12.4).
        A vector that holds nothing has no words, and nothing can be added to
        one -- the far side answers for the empty vector, so there is no
        second opinion here to disagree with it. }
  v := nil;
  writeln('16 words=', ArgsLen(v):1, ' add=', ErrorText(AddArg(v, 'x')),
          ' drop=', DropArgs(v, 0):1);

  SVecFree(lines)
end.
