{ What ISO/IEC 10206:1991 §6.11 refuses. Sema accumulates, so one run reports
  every one of these. }
{ The enumerated type whose constants the range below cannot all reach. }
{ This one lists `output`, so the required text file exists from here on —
  which is what makes `silent` below a test of §6.11.4.2's *per block*
  accessibility rather than of whether the file was ever created. }
module hue interface(output);
  export hue = (shade, red, green, blue);
  type shade = (red, green, blue);
end.

module hue implementation;
end.

module lib interface;
  export
    { §6.11.2: an export-clause names something the module declares. }
    good = (v, f, colour, red..green, protected v => guarded,
            { the same variable again, protected and *not* renamed: an import
              of it must still arrive protected, and the module's own name for
              it is not the one that carries that }
            protected w,
            { one interface may not have two constituents of one spelling }
            colour => guarded);
    { ...and the same interface name may not be introduced twice }
    good = (v);
    bad = (nowhere,
           { `protected` qualifies a variable-name, and only one }
           protected f,
           { a protected variable's type must be protectable (§6.4.1): a file
             or a pointer inside it would let the importer change what it
             reaches without ever writing to the variable }
           protected handle,
           { an export-range runs between two values of one *enumerated* type }
           one..two,
           { ...and the first must not come after the last }
           green..red,
           { an interface is not a constituent of an interface }
           good);
  const one = 1; two = 2;
  type colour = (red, green, blue);
  var v: integer;
      w: integer;
      handle: ^integer;
  function f: integer;
end.

module lib implementation;
  { §6.11.1: a heading in the module-heading promises a body here. }
end.

{ Two more, each needing a module of its own. §6.11.2 makes an *interface*
  something an import-specification introduces a name for, and that name is not
  a constituent of anything; and an export-range exports the principal
  identifiers of the values in it, which a redeclaration takes away. }
module reexport interface;
  export
    { §6.11.2's exportable-name list has no interface-name in it }
    r1 = (hue);
    { §6.11.2 a): the range must be within the scope of a defining-point of an
      identifier that is a principal identifier of the value. §6.11.2 NOTE 2
      says exporting a type-identifier does *not* export the constants of an
      enumerated type, so an importer that asks `only` for two of the three has
      no name at all for the one in between. }
    r2 = (red..blue);
  import hue only (red, blue);
end.

module reexport implementation;
end.

{ §6.11.1: an interface-directive occurs "if and only if a module-block does
  not occur in the module-declaration", so this heading needs an
  implementation somewhere and never gets one. }
module orphan interface;
  export nothing = (x);
  var x: integer;
end.

{ §6.11.4.2 makes `output` implicitly accessible in a block only when that
  block asked for it — by a module-parameter-list or by importing
  StandardOutput. It is a property of the block, so another module having it
  is no help. }
module silent interface;
  export si = (shout);
  procedure shout;
end.

module silent implementation;
  procedure shout;
  begin writeln('...') end;
end.

{ §6.11.1: "For any two distinct modules A and B such that A supplies B and B
  supplies A, neither the module-block of A nor the module-block of B shall
  contain an initialization-part; neither module-block shall contain a
  finalization-part." Mutual supply is reachable only through a *split*
  module — `each`'s heading supplies `other`, and `other` supplies `each`'s
  block, which is a later program-component (NOTE 2). It is the one case
  §6.2.3.6 leaves no order for, which is why the standard takes the ordered
  parts away rather than picking one. }
module each interface;
  export e1 = (p);
  var p: integer;
end.

module other;
  export e2 = (q);
  import e1;
  var q: integer;
end;
  to begin do q := p + 1;
end.

module each implementation;
  import e2;
  to end do p := q;
end.

module twice interface;
  export t2 = (y);
  var y: integer;
end.
module twice interface;
  export t3 = (y);
  var y: integer;
end.

program ModuleErrors(output);
import
  { no such interface }
  missing;
  { the whole of `good`, so the protected constituent arrives }
  good;
  { §6.11.3: `only` names what to import, so a name not in the interface is an
    error, and nothing else from that interface arrives at all }
  bad only (v, absent);
  { and one imported qualified is not reachable bare }
  t2 qualified;
var z: integer;
begin
  { §6.11.2: `protected` makes the constituent unwritable through this name,
    and §6.9.4's threats are what that means — whether or not the import
    renamed it }
  guarded := 1;
  w := 1;
  { §6.11.3 NOTE 2: a qualified import's names are written the long way only }
  y := 2;
  writeln(t2.y:1, ' ', good.v:1);
  { the qualifier must name an interface... }
  z := v.something;
  { ...and the name must be one the import brought }
  writeln(t2.absent:1);
  { what is reached through an interface keeps what it is }
  writeln(good.v(1):1);
  good.f
end.
