{ PasProcess's ArgV.Execute -- a command carried as words rather than as a line
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
  t: int64;

{ The words assembled somewhere other than where the command is run, which is
  the shape a driver has: a handle crosses as a `var` parameter. }
procedure AddPath(protected var av: ArgV; p: string);
var junk: ErrorCode;
begin
  junk := av.Add('--import-path');
  junk := av.Add(p)
end;

begin
  dump := 'execute_dump.txt';

  { 1. The ordinary case, with the child's streams this program's. `hello`
       is written before the line below it because the flush happens before
       the child starts and this program then waits for it. }
  e := v.Init;
  e := v.Add('echo');
  e := v.Add('hello');
  r := v.Execute;
  writeln('1 ok=', r.ok, ' code=', r.val:1, ' words=', v.Len:1);

  { 2. The point. Nothing here is expanded, split, redirected or run. }
  e := v.Init;
  e := v.Add('echo');
  e := v.Add('a''; touch PWNED; echo ''b');
  e := v.Add('$HOME `id` * | wc');
  r := v.ExecuteInto(out);
  write('2 [', out, ']');

  { 3. A command that is not there. No shell ran, so there is no shell to
       exit 127: the failure is that nothing started. }
  e := v.Init;
  e := v.Add('no-such-program-anywhere');
  r := v.Execute;
  writeln('3 ok=', r.ok, ' cause=', ErrorText(r.cause));

  { 4. A status of the child's own. }
  e := v.Init;
  e := v.Add('sh');
  e := v.Add('-c');
  e := v.Add('exit 3');
  r := v.Execute;
  writeln('4 ', r.val:1);

  { 5. No words at all -- there is no argv[0] to run. }
  e := v.Init;
  r := v.Execute;
  writeln('5 ok=', r.ok, ' cause=', ErrorText(r.cause));

  { 6. An argument longer than a name. ADR-0291 says a path may be, and a
       vector of StrItem would have cut this at 255. }
  big := '/tmp';
  for i := 1 to 40 do big := big + '/0123456789abcde';
  e := v.Add(big);
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
  e := v.Init;
  e := v.Add('sh');
  e := v.Add('-c');
  e := v.Add('exec 2>/dev/null; echo out; echo err >&2');
  r := v.ExecuteInto(out);
  write('7 [', out, ']');

  { 8. ...and both together, which is what `2>&1` was for and what no caller
       can write where no shell reads it. }
  e := v.Init;
  e := v.Add('sh');
  e := v.Add('-c');
  e := v.Add('echo out; echo err >&2');
  r := v.ExecuteBoth(out);
  write('8 [', out, ']');

  { 9. A field, filled through a `var` parameter. }
  e := j.args.Init;
  AddPath(j.args, '/opt/apascal/lib/afterschool');
  writeln('9 words=', j.args.Len:1);

  { 10. The vector is not consumed: the same words run twice. }
  e := v.Init;
  e := v.Add('true');
  r := v.Execute;
  r := v.Execute;
  writeln('10 ok=', r.ok);

  { 11. Capture's contract: what does not fit is read and dropped, so the
        command still runs to its end and the code is still its own. }
  e := v.Init;
  e := v.Add('echo');
  e := v.Add('far more than eight characters');
  r := v.ExecuteInto(j.name);
  writeln('11 ok=', r.ok, ' code=', r.val:1, ' [', j.name, ']');

  { 12. Both streams a line at a time, which is what a caller reading a
        compiler's diagnostics needs and what `2>&1` used to buy. }
  e := v.Init;
  e := v.Add('sh');
  e := v.Add('-c');
  e := v.Add('echo one; echo two >&2');
  SVecNew(lines, 8);
  r := v.ExecuteLines(lines);
  writeln('12 lines=', lines.Len:1, ' [', lines.At(1),
          '][', lines.At(2), ']');

  { 13. And straight to a file, for an answer too large to hold. }
  e := v.Init;
  e := v.Add('sh');
  e := v.Add('-c');
  e := v.Add('echo written; echo also >&2');
  r := v.ExecuteToFile(dump);
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
        `Len` for the mark and `Drop` for the reset. }
  e := v.Init;
  e := v.Add('echo');
  i := v.Len;
  e := v.Add('one');
  e := v.Add('two');
  writeln('14 pushed=', v.Len:1, ' back to ', v.Drop(i):1);
  e := v.Add('kept');
  r := v.ExecuteInto(out);
  write('14 [', out, ']');

  { 15. The bound is a diagnostic and not a limit reached in silence
        (ADR-0012's claim, and this library's version of it). }
  e := v.Init;
  i := 0;
  repeat
    e := v.Add('w');
    i := i + 1
  until Failed(e) or (i > 5000);
  writeln('15 ', ErrorText(e), ' at ', i:1, ' words=', v.Len:1);

  { 16. Emptied by hand rather than at the end of the block (AP 6.4.12.4).
        A vector that holds nothing has no words, and nothing can be added to
        one -- the far side answers for the empty vector, so there is no
        second opinion here to disagree with it. }
  v := nil;
  writeln('16 words=', v.Len:1, ' add=', ErrorText(v.Add('x')),
          ' drop=', v.Drop(0):1, ' deadline=', ErrorText(v.Deadline(1)));

  { 17. A word holding chr(0) is a code, not a stopped program (ADR-0363):
        ADR-0122 makes the crossing a run-time error, and a value that came
        from outside must be refused before it gets there. }
  e := v.Init;
  e := v.Add('echo');
  writeln('17 nul word=', ErrorText(v.Add('a' + chr(0) + 'b')),
          ' nul path=', ErrorText(v.ExecuteToFile('x' + chr(0)).cause),
          ' words=', v.Len:1);

  { 18. A symbolic link at the dump path is refused and what it names is left
        alone -- the audit overwrote a file through one. The link is made by
        a child, this library having no way to make one and needing none. }
  e := v.Init;
  e := v.Add('sh');
  e := v.Add('-c');
  e := v.Add('echo precious > victim.txt && ln -sf victim.txt link.txt');
  r := v.Execute;
  e := v.Init;
  e := v.Add('echo');
  e := v.Add('overwritten');
  r := v.ExecuteToFile('link.txt');
  writeln('18 through link ok=', r.ok, ' cause=', ErrorText(r.cause));
  b := binding(f);
  b.name := 'victim.txt';
  bind(f, b);
  reset(f);
  readln(f, line);
  unbind(f);
  writeln('18 victim still [', line, ']');

  { 19. A deadline: a child that outlives it is killed and the run is a
        failure, and a grandchild that keeps the pipe open after it cannot
        hold this side either -- which is the case the audit timed at the
        grandchild's whole life. Timed coarsely: seconds, and the bound is
        generous, because this is a claim about *not waiting for ever* and not
        about how fast the machine is. }
  e := v.Init;
  e := v.Add('sh');
  e := v.Add('-c');
  e := v.Add('echo before; sleep 30 & sleep 30; echo after');
  e := v.Deadline(1);
  t := Seconds;
  r := v.ExecuteInto(out);
  t := Seconds - t;
  writeln('19 ok=', r.ok, ' cause=', ErrorText(r.cause),
          ' captured=[', out[1..6], '] under 10s=', t < 10,
          ' bad deadline=', ErrorText(v.Deadline(-1)));

  { 20. What this program holds open, a child does not see: the audit found
        every open file of the parent in the child's /proc/self/fd. `f` is
        open on victim.txt for reading here, on purpose. }
  b := binding(f);
  b.name := 'victim.txt';
  bind(f, b);
  reset(f);
  e := v.Init;
  e := v.Add('sh');
  e := v.Add('-c');
  e := v.Add('ls -l /proc/self/fd 2>/dev/null | grep -c victim.txt; exit 0');
  r := v.ExecuteInto(out);
  unbind(f);
  write('20 inherited=', out);

  { What this program made, it takes away. **A case is run in a directory of
    its own since ADR-0406** and this no longer keeps the checkout clean --
    but it was doing something else as well, and that is why the sweep is
    kept: two copies of this program in one directory raced here, one
    removing `victim.txt` while the other was opening it, and the shape a
    cleanup has is the shape a race has. }
  e := v.Init;
  e := v.Add('rm');
  e := v.Add('-f');
  e := v.Add(dump);
  e := v.Add('victim.txt');
  e := v.Add('link.txt');
  r := v.Execute;

  lines.Free
end.
