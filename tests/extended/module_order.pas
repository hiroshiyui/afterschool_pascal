{ ISO/IEC 10206:1991 §6.2.3.6, and the four things about a module that only a
  *running* program can show.

  "The order of any two distinct commencements shall be implementation-
  dependent unless the order is specified by the following sentence. Within an
  activation of a program-block, for each module or main-program-block A and
  for each module B other than A, if B supplies A and A does not supply B, then
  the commencement of the activation of B shall precede the commencement of the
  activation of A."

  ...and, read the other way for termination: "the termination of the
  activation of A shall precede the action specified by the finalization of the
  activation of B".

  So the initializations run in written order — which §6.2.2.9 makes a legal
  one, since a module-heading precedes everything that imports its interface —
  and the finalizations run in the reverse. Both halves are printed here,
  because the order is the whole of what the standard fixes. }
module first(output);
  export f = (mark_first, level, low..high);
  { An export-range: §6.11.2 NOTE 6 makes it shorthand for the *principal*
    identifier of every value between the two named, so `middle` is exported
    without being written, and the two ends are exported because they happen
    to be principal identifiers of themselves. }
  type level = (low, middle, high, unreachable);
  procedure mark_first;
end;
  procedure mark_first;
  begin writeln('first was here') end;
  to begin do writeln('1 commences');
  to end do writeln('1 finalises');
end.

module second(output);
  export s = (mark_second);
  { `second` imports `f`, so §6.2.2.13 makes `first` supply it and §6.2.3.6
    puts `first`'s commencement before this one's. }
  import f;
  procedure mark_second;
end;
  procedure mark_second;
  begin mark_first; writeln('second was here') end;
  to begin do writeln('2 commences');
  to end do writeln('2 finalises');
end.

{ A module nothing imports supplies nothing (§6.2.2.13), so §6.2.3.6 never
  activates it: neither of these lines is ever written. It is compiled all the
  same — an unactivated module is not an unchecked one. }
module unused(output);
  export u = (never);
  var never: integer;
end;
  to begin do writeln('unused commences');
  to end do writeln('unused finalises');
end.

program ModuleOrder(output);
import
  { §6.11.3's import-renaming, which is the other end of §6.11.2's: the module
    exported `mark_second` and this program calls it `go`. }
  s (mark_second => go);
  { every value of the export-range, under the names the type gave them }
  f (level => rank);
var r: rank;
begin
  go;
  for r := low to high do
    write(ord(r):1, ' ');
  writeln;
  writeln('program body done')
end.
