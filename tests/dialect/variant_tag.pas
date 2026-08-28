{ ADR-0118: in the dialect a variant's tag cannot lie about which arm holds the
  payload. Two rules, and every path through them is here except the trap
  itself, which is tests/dialect/trap_variant_read.pas.

    a write to a variant's field makes that variant active;
    a read of a field whose variant is not active traps.

  §6.5.3.3 makes the second an *error* -- Annex D.2, listed in
  doc/implementation-defined.md among the ones this compiler deliberately
  leaves unreported -- and §3.1 lets a processor leave an error undetected. So
  a conforming program never does either, and detecting them changes the
  meaning of nothing correct. That is what lets this be a dialect feature
  without weakening ADR-0117's containment, and it is why the same source under
  a Pascal without ADR-0118's rule prints the same thing wherever it does not
  depend on the tag.

  The cases are separated because each reaches the guard by a different route,
  and three of them are where a careless implementation goes wrong. }
program VariantTag(output);

type
  Outcome = (ok, bad);
  { one label per arm -- the shape a sum type has, and the lone shape where a
    write can decide what to activate }
  Res = record
    case tag: Outcome of
      ok:  (num: integer);
      bad: (msg: string(32))
    end;

  Outer = (one, two);
  Inner = (xx, yy);
  { activity is a *chain*: reaching `p` crosses two variant parts, so a write
    must activate both and a read must check both }
  Nest = record
    case t: Outer of
      one: (a: integer);
      two: (case u: Inner of
              xx: (p: integer);
              yy: (q: real))
    end;

  Three = (aa, bb, cc);
  { two labels on one arm: a write cannot decide between aa and bb, so it is
    checked like a read instead of activating }
  Multi = record
    case which: Three of
      aa, bb: (i: integer);
      cc:     (r: real)
    end;

  Four = (p1, p2, p3, p4);
  { §6.4.3.3's completer (ADR-0034) has no labels of its own -- what it accepts
    is the complement of the others', so the check is a negation }
  Compl = record
    case sel: Four of
      p1: (lone: integer);
      otherwise (rest: real)
    end;

  Nine = 1..9;
  { labels that are *ranges* rather than single values, which Extended Pascal
    allows in a variant part (see tests/extended/case_ranges.pas). A range
    cannot activate -- there is no single value to store -- so a write is
    checked, and the check is a pair of comparisons rather than an equality.
    The second arm has two ranges, so the check is their union. }
  Ranged = record
    case n: Nine of
      1..3:      (small: integer);
      4..6, 8..9: (large: real);
      7:         (exact: char)
    end;

  { no tag field at all (§6.4.3.3 permits it). There is nothing to compare
    against, so this stays an unchecked union exactly as in the conformance
    modes -- the hole ADR-0118 records and doc/sop.md §7 carries. }
  Tagless = record
    common: integer;
    case Outcome of
      ok:  (ti: integer);
      bad: (tr: real)
    end;

var
  r: Res;
  v: Nest;
  m: Multi;
  c: Compl;
  g: Tagless;
  d: Ranged;

begin
  { a write activates, so construction needs no tag assignment and cannot get
    it wrong }
  r.num := 42;
  writeln('res tag=', ord(r.tag):1, ' num=', r.num:1);
  r.msg := 'nope';
  writeln('res tag=', ord(r.tag):1, ' msg=', r.msg);

  { the chain: one write sets both tags }
  v.p := 5;
  writeln('nest t=', ord(v.t):1, ' u=', ord(v.u):1, ' p=', v.p:1);
  v.a := 9;
  writeln('nest t=', ord(v.t):1, ' a=', v.a:1);

  { two labels: the tag is set first and the write is checked against it }
  m.which := aa;
  m.i := 7;
  writeln('multi which=', ord(m.which):1, ' i=', m.i:1);
  m.which := bb;
  m.i := 8;
  writeln('multi which=', ord(m.which):1, ' i=', m.i:1);

  { the completer accepts everything the named arm does not }
  c.lone := 3;
  writeln('compl sel=', ord(c.sel):1, ' lone=', c.lone:1);
  c.sel := p3;
  c.rest := 1.5;
  writeln('compl sel=', ord(c.sel):1, ' rest=', c.rest:3:1);

  { tagless: unchecked, and reading the other arm is permitted as before }
  g.common := 1;
  g.ti := 42;
  writeln('tagless common=', g.common:1, ' ti=', g.ti:1);

  { ranges: a write cannot activate one, so the tag is set first and both the
    write and the read are checked against it }
  d.n := 2;
  d.small := 11;
  writeln('ranged n=', d.n:1, ' small=', d.small:1);
  d.n := 9;
  d.large := 2.5;
  writeln('ranged n=', d.n:1, ' large=', d.large:3:1);
  { a single value inside a ranged variant part still activates }
  d.exact := 'z';
  writeln('ranged n=', d.n:1, ' exact=', d.exact);

  writeln('done')
end.
