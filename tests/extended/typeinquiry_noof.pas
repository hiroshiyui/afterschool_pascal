{ §6.4.9 spells the construct `'type' 'of' type-inquiry-object` — two
  word-symbols and then a name. The parser stops at the first thing it cannot
  make sense of, so this file carries the missing `of` alone. }
program TypeInquiryNoOf(output);
var n: integer;
    m: type n;
begin
  n := 1; m := n; writeln(m:1)
end.
