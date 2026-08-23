{ The wall two records described, come down. ADR-0122 and ADR-0130 both closed
  by saying a binding module answers `errIO` and cannot say which failure it
  was; PasOS says which.

  What it demonstrates is the division of labour that replaces the wall: the
  binding module gives a **code** a caller can branch on, from PasError's small
  closed set, and PasOS gives the **sentence**, which nothing here can classify
  because ENOENT and EACCES are numbers in a header this compiler cannot read.

  The scratch path comes from a program-parameter's binding (6.5.1 and 6.7.6.8
  NOTE 2); the file at it is removed first, because what is being reported is
  its absence. }
program lib_os(output, scratch, missing);

import PasError;
       PasFS;
       PasIO;
       PasOS;

var scratch, missing: text;
    here, gone: PathName;
    o: FdResult;
    e: ErrorCode;

procedure yes(what: string(16); b: boolean);
begin
  write(what);
  if b then writeln('yes') else writeln('no')
end;

begin
  here := binding(scratch).name;
  gone := binding(missing).name;

  { An earlier case in the same run may have left a file here. }
  e := Remove(gone);

  { The failing open, and the two halves of the answer. }
  o := OpenRead(gone);
  yes('open failed   = ', not o.ok);
  writeln('code          = ', ErrorText(o.cause));
  writeln('why           = ', LastErrorText);
  yes('number set    = ', LastErrorNumber <> 0);

  { A second failure with a *different* reason, so the sentence is the last
    call's and not a constant -- and one code covering two reasons is exactly
    what this increment is for. A file is made by Pascal and then asked to be
    removed as though it were a directory. }
  rewrite(scratch);
  writeln(scratch, 'not a directory');
  reset(scratch);
  e := RemoveDirectory(here);
  yes('rmdir failed  = ', Failed(e));
  writeln('code          = ', ErrorText(e));
  writeln('why           = ', LastErrorText);

  { strerror is specified to answer a sentence for every number, including one
    it does not know. The text of that one is libc's business, so what is
    asserted here is that there is some. }
  yes('unknown has a = ', length(ErrorNumberText(31337)) > 0);

  { And the number a caller reports is the one it reads, not one this module
    remembered: nothing here caches it. }
  writeln('same twice    = ', ErrorNumberText(LastErrorNumber));

  { The code and the sentence are different vocabularies on purpose. This one
    is the closed set a `case` can cover (6.4.3.3 with ADR-0096); the other is
    a string nothing here classifies. }
  if o.cause = errIO then writeln('branched      = errIO')
end.
