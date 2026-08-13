{ §6.1.8's comment, which is one production and not two.

  Both standards write it as an opening delimiter that is either a brace or a
  star-paren, a commentary, and a closing delimiter that is again either — and
  NOTE 1 then says in as many words that a comment may commence with a brace
  and end with a star-paren, or commence with a star-paren and end with a
  brace.

  This compiler had two loops instead, one per delimiter pair, so a comment had
  to close with the delimiter that opened it. Both mixed forms were rejected as
  an unterminated comment, in both standards, since §6.1.8 is identical in
  each. Nothing caught it: no program in the corpus mixed them, and a comment
  is invisible to every stage after the lexer, so the token dumps that
  difftest compares would agree whatever a comment did (ADR-0073).

  The consequence a reader should carry away is the one this file's own
  comments have to obey. Because either delimiter closes a commentary, neither
  pair can quote the other's characters, and a grammar quotation cannot be
  written inside a Pascal comment at all — which is why every production
  mentioned in this corpus is described in words.

  This comment opened with a brace and closes with a star-paren.
*)

(* This one opened with a star-paren and closes with a brace. }

program comments(output);

var
  n: integer;

(* NOTE 2 is the asymmetry, and it follows from the same rule: an opening
   star-paren cannot occur in a commentary, because there is no way to write
   one that does not also end the comment. A lone right parenthesis ) may,
   and so may a lone right bracket ] and a lone asterisk * . *)

begin
  n := 0;

  { An ordinary comment. }
  n := n + 1;

  (* And the other ordinary one. *)
  n := n + 2;

  { Mixed, one way. *)
  n := n + 4;

  (* Mixed, the other. }
  n := n + 8;

  { A right parenthesis ) and a right bracket ] end nothing. }
  n := n + 16;

  writeln('total ', n:1);

  { §6.1.8 makes a comment a token separator, so one may sit anywhere a space
    may — inside an expression, and between an operator and its operand. }
  n := 1 { one } + 2 (* two *) + 3;
  writeln('inline ', n:1);

  { A brace and a star-paren inside a character-string are ordinary
    characters, because §6.1.8 excludes an opening delimiter that occurs
    within one. Neither of these starts a comment. }
  writeln('braces {} and stars (* *)')
end.
