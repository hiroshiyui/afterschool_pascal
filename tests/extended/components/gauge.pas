{ A second separately translated program-component, and it exists to pin one
  thing: a linkage name is per *interface*.

  This module exports a variable called `tally`, and so does
  components/counter.pas. Both are legal and they are different variables --
  6.2.2.2 makes each interface a region of its own, disjoint from every other
  -- so the names two translations agree on cannot be built from the
  constituent's spelling alone. They are built from the interface's name and
  the constituent's, which is what keeps these two apart.

  The importing component reaches this one's under another spelling (6.11.3's
  rename), which is the case that shows the interface is what disambiguates
  rather than the importer's choice of word: renaming happens at the import
  and the storage was named at the export. }
module gauge;

export gauging = (tally, sample);

var
  tally: integer;
procedure sample(v: integer);
end;

procedure sample;
begin
  tally := tally + v * 2
end;

to begin do
  tally := 7;

end.
