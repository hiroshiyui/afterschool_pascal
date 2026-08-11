{ ISO/IEC 10206:1991 §6.11.6, examples 1 to 5, with the standard's own
  comments kept. Three changes, all of them stated:

    * the underscores the reference document renders as spaces in identifiers;
    * `halt` is gone from `dequeue` — §6.7.5.4's required procedure is not
      implemented, and the program never dequeues from an empty queue;
    * a main program, since §6.13 requires exactly one and the examples give
      none.

  What the examples are *for* is the export- and import-machinery, and this
  keeps all of it: a minimal module-block (`end; end.`), re-exporting a value
  imported through another interface, `qualified` and `only` together, an
  export-list holding qualified names and renamings, a function-heading in the
  module-heading with its block in the module-block, and a module split into
  two program-components. }
module m1;
{ m1 exports one interface named i1, containing two values named low and high.
  The variable null is not exported. m1 has a minimal module-block. }
  export i1 = (low, high);

  const low = 0; high = 1;

  var null: record end;

end { of module-heading for m1 } ;
end { of module-block for m1 } .

module m2;
{ m2 exports two interfaces named i2 and j2. i2 contains a type called t; j2
  contains the two values (still named low and high) imported from m1 through
  interface i1. m2 also has a minimal module-block. }
  export
    i2 = (t);
    j2 = (low, high);
  import
    i1;
  type t = low..high;

end { of module-heading for m2 } ;
end { of module-block for m2 } .

module m3;
{ m3 exports one interface containing a function, a type, and two values. The
  function-heading is declared in the module-heading, and the function-block is
  declared in the module-block. }
  export
    i3 = (f, i2.f_range, i1.low => f_low, i1.high => f_high);
  import
    i1 qualified;
    i2 qualified only (t => f_range);
  function f(x: integer): i2.f_range;

end { of module-heading for m3 } ;
  function f;
  begin
    if x < i1.low then f := i1.low
    else if x > i1.high then f := i1.high
    else f := x
  end { f } ;

end { of module-block for m3 } .

module m4 interface;
{ m4 exports two interfaces named enq and deq. }
  export enq = (enqueue); deq = (dequeue, empty, range);

  import i3 only (f_range => range);

  procedure enqueue(e: range);
  procedure dequeue(var e: range);
  function empty: Boolean;

end { of module-heading for m4 } .

module m4 implementation;
  type
    qp = ^qnode;
    qnode = record next: qp; c: range end;

  var
    oldest: qp value nil;
    newest: qp;

  function empty;
  begin empty := (oldest = nil) end { empty } ;
  procedure enqueue;
  begin
    if empty then
      begin new(newest); oldest := newest end
    else
      begin new(newest^.next); newest := newest^.next end;
    newest^.c := e
  end { enqueue } ;

  procedure dequeue;
    var p: qp;
  begin
    e := oldest^.c; p := oldest;
    if oldest = newest then oldest := nil
    else oldest := oldest^.next;
    dispose(p)
  end { dequeue } ;

end { of module-block for m4 } .

program Examples(output);
import i3; enq; deq;
var v: range;
begin
  writeln(f(-5):1, f(0):1, f(1):1, f(9):1);
  writeln(f_low:1, f_high:1);
  enqueue(0); enqueue(1); enqueue(1);
  while not empty do begin
    dequeue(v);
    write(v:1)
  end;
  writeln
end.
