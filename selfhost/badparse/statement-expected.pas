{ ISO 7185 6.8.1's statement has a fixed set of first tokens, and an operator
  is in none of them: no expression begins a statement, which is what lets the
  parser decide a leading integer can only be a label without any lookahead.
  What is left when none of them matches is this message. }
program p(output);
begin
  +
end.
