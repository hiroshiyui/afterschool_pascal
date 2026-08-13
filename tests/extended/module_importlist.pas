{ An import-part with more than one specification, and an import-list with
  more than one name.

  §6.2.1 writes the import-part as the word `import`, one import-specification
  terminated by a semicolon, and then a repetition of the same — so `import` is
  written once and the repetition is not comma-separated. The comma belongs to
  §6.11.3's import-list inside the qualifier's parentheses instead. The
  production is described rather than quoted, because §6.1.8 lets a comment end
  at either closing delimiter whichever one opened it, so a grammar's
  metasymbols cannot be written inside one.

  Nothing in the corpus had ever written the repetition, and the only
  multi-name import-lists were in `module_errors.pas` and
  `module_badimportitem.pas`, where the program is refused before anything
  runs. So both productions were uncompiled on the path where they succeed —
  ADR-0067's lesson again.

  What this pins: three specifications under one `import`, a selective list of
  several names, a rename inside such a list, `qualified` beside `only`, and
  the interaction that makes the last two worth writing together — a renamed
  name in a qualified import is written under its new spelling. }
module numbers(output);
  { §6.11.2 spells the interface-specification-part the way §6.2.1 spells the
    import-part — the word once, then a repetition each terminated by its own
    semicolon. The comma inside the parentheses separates export-clauses and
    nothing larger, so `export a = (..), b = (..)` is not a sentence. }
  export
    small = (one, two, three, small_t);
    large = (hundred, thousand);
  type
    small_t = 1..9;
  const
    one = 1;
    two = 2;
    three = 3;
    hundred = 100;
    thousand = 1000;
end;
end.

module letters(output);
  export alpha = (first, last);
  const
    first = 'a';
    last  = 'z';
end;
end.

program module_importlist(output);

{ Three specifications in one part. The first takes some of an interface and
  renames one of them; the second takes another interface whole; the third
  takes a third interface qualified, so its names arrive dotted. }
import small only (one, three => tri, small_t);
       alpha;
       large qualified;

var
  n: small_t;

begin
  { The names the selective list admitted, one of them under its new spelling.
    `two` was in the interface and not in the list, so it is not here — that
    half is what `module_errors.pas` refuses. }
  n := one;
  writeln('selected ', n:1, tri:1);

  { A whole interface, imported by the second specification. }
  writeln('whole    ', first, last);

  { And the qualified one: §6.11.3 makes these names reachable only as `i.x`,
    which is what distinguishes this specification from the second. }
  writeln('qualified ', large.hundred:1, ' ', large.thousand:1);

  { The renamed name is the interface's, so the type imported alongside it
    still denotes the same type and a value moves between them. }
  n := tri;
  writeln('renamed  ', n:1)
end.
