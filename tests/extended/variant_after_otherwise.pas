{ ISO/IEC 10206:1991 §6.4.3.3 puts the variant-part-completer at the end of the
  variant-list, so nothing may follow it -- the same shape as the otherwise-part
  of a case statement, and for the same reason: an arm after "everything else"
  could never be selected. }
program VariantAfterOtherwise(output);
type
  r = record
    case tag: integer of
      1: (a: integer);
      otherwise (b: char);
      2: (c: boolean)
  end;
var v: r;
begin
  v.tag := 1
end.
