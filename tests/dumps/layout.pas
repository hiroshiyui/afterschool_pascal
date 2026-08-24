{ --dump-layout (ADR-0185): what this compiler decided every record in a source
  looks like. It is the compiler's half of the foreign-layout gate, where the
  other half is a C compiler holding the real header -- but the flag is
  ordinary and works on any program, which is what this case pins.

  Covered here: the alignment holes a field of a wider type opens, a fixed
  array, a nested record, a `packed` one that is laid out exactly as the
  unpacked one is, and a record with a variant part -- reported as a line and
  not walked, an arm's storage being this compiler's own shape (ADR-0028) and
  not a layout C is asked about. }
program layout(output);

type
  { Two holes: one after `flag` and one after the array, because `wide` and
    `d` each want eight-byte alignment. }
  Holes = record
    flag: char;
    wide: int64;
    small: integer;
    text: array [1..3] of char;
    d: real
  end;

  { A nested record contributes its own alignment to the outer one. }
  Inner = record x, y: integer end;
  Outer = record head: char; body: Inner; tail: int64 end;

  { `packed` does not affect layout here (ISO 7185 6.4.3.1 permits that), so
    this is byte for byte what `Inner` is. }
  Packed_ = packed record x, y: integer end;

  Sel = 1..2;
  Varying = record
    common: integer;
    case tag: Sel of
      1: (a: real);
      2: (b: char)
  end;

var h: Holes; o: Outer; p: Packed_; v: Varying;

begin
  h.flag := 'x';
  o.head := 'y';
  p.x := 1;
  v.common := 2;
  writeln(h.flag, o.head, p.x:1, v.common:1)
end.
