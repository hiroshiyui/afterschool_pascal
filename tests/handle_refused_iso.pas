{ Annex B of doc/afterschool-pascal-spec.md: AP 6.4.12's handle-type is an
  identifier followed by `external` and a string where a type-denoter ends,
  which no program of either standard can write -- the parser stops where
  the definition should have ended. `handle` itself is nobody's word. }
program handle_refused_iso(output);
type Dir = handle external 'closedir';
begin
  writeln('not reached')
end.
