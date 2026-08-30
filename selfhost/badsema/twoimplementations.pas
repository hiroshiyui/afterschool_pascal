{ 6.13 lets a program-component hold several module-declarations, and 6.11.1
  gives a module one implementation. Two in the same component is the shape
  this refuses; two in *different* components is the same question asked of
  the interface table, which outlives a translation. }
module twoimpl;

export twoimpl = (x);

var x: integer;

end;

end.

module twoimpl implementation;

end.
