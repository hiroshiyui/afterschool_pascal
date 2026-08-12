{ Four of the five are required *identifiers*, so ISO 7185 leaves the names
  free — and this is a legal ISO 7185 program that declares its own `halt` and
  `card` and uses `maxchar` as a variable. ADR-0033's reason for making the
  standard a property of the source, made concrete once more.

  The fifth, `><`, is not an identifier and cannot be shadowed; it is refused
  by `required_iso_symdiff.pas`, in a file of its own because a lexical
  refusal stops the parser. }
program RequiredIso(output);
var maxchar: integer;

function card(n: integer): integer;
begin card := n * 2 end;

procedure halt(n: integer);
begin writeln('halt ', n:1) end;

begin
  maxchar := 7;
  writeln(card(maxchar):1);
  halt(3)
end.
