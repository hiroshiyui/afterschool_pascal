{ Three productions of FallMod's schema, named the way `lib/` names its result
  types, and one routine answering each. The program that imports this never
  imports the schema's name, which is what the case is about. }
module FallProd;

export FallProd = (Short, Point, IntResult, ShortResult, PointResult,
                   AnInt, AShort, APoint);

import FallMod;

type
  Short = string(8);
  Point = record x, y: integer end;
  IntResult = Fallible(integer);
  ShortResult = Fallible(Short);
  PointResult = Fallible(Point);

function AnInt(good: boolean) = r: IntResult;
function AShort(good: boolean) = r: ShortResult;
function APoint(good: boolean) = r: PointResult;

end;

function AnInt;
begin
  if good then r := 7 else r := failed
end;

function AShort;
begin
  if good then r := 'short' else r := refused
end;

function APoint;
var p: Point;
begin
  p.x := 3; p.y := 4;
  if good then r := p else r := failed
end;

end.
