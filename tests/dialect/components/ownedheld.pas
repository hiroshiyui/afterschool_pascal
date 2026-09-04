{ A module holding an owned pointer, so that AP 6.4.14.7 can be asked of a
  variable named by a **qualified** identifier (§6.11.3).

  It is the one shape the rule's walk to the entire-variable reaches through a
  field-designator rather than a name: `OwnedHeld.Held` is an nkField carrying
  a qualifier, and the walk stops there because a qualified name *is* the
  entire-variable. Nothing else in the corpus takes that arm. }
module OwnedHeld;

export OwnedHeld = (HeldNode, HeldPtr, Held);

type HeldPtr = owned ^HeldNode;
     HeldNode = record v: integer end;

var Held: HeldPtr;

end;

end.
