global assert, gemdos, require

local <const> Wind = require("gembindl.utility.wind")

gemdos.Cconws("Testing rcconstrain\r\n")

-- Testing rcconstrain
----------------------

-- constrain rectangle 2 within rectangle 1 by adjusting
-- rectangle 2's x and y position.
-- Second rectangle overlapping top left
local xx, yy, ww, hh =
  Wind.rcconstrain(
    0, 0, 10, 10,
    -3, -3, 5, 5)
assert(xx == 0)
assert(yy == 0)
assert(ww == 5)
assert(hh == 5)

-- Second rectangle overlapping top right
-- rectangle 2's x and y position
xx, yy, ww, hh =
  Wind.rcconstrain(
    0, 0, 10, 10,
    8, -3, 5, 5)
assert(xx == 5)
assert(yy == 0)
assert(ww == 5)
assert(hh == 5)

-- Second rectangle overlapping bottom right
-- rectangle 2's x and y position
xx, yy, ww, hh =
  Wind.rcconstrain(
    0, 0, 10, 10,
    8, 8, 5, 5)
assert(xx == 5)
assert(yy == 5)
assert(ww == 5)
assert(hh == 5)

-- Second rectangle overlapping bottom left
-- rectangle 2's x and y position
xx, yy, ww, hh =
  Wind.rcconstrain(
    0, 0, 10, 10,
    -3, 8, 5, 5)
assert(xx == 0)
assert(yy == 5)
assert(ww == 5)
assert(hh == 5)

-- If rectangle 2 is bigger than rectangle 1, rectangle 2's origin
-- will be adjusted to the left and/or above rectangle 1. This is
-- because rcconstrain moves the origin of rectangle 2, but does not
-- change the size.
xx, yy, ww, hh =
  Wind.rcconstrain(
    1, 2, 10, 10,
    5, 5, 20, 20)
-- Rectangle 2 now overlays rectangle 1. The bottom right corner of
-- rectangle 2 is at the bottom right corner of rectangle 1. The top
-- left of rectangle 2 is to the left and above the top left of
-- rectangle 1.
assert(xx == -9)
assert(yy == -8)
assert(ww == 20)
assert(hh == 20)

gemdos.Cconws("Testing rcintersect\r\n")

-- Now intersect rectangle 2 with rectangle 1
local intersect
intersect, xx, yy, ww, hh =
  Wind.rcintersect(1, 2, 10, 10, xx, yy, ww, hh)
-- The intersection is rectangle 1
assert(intersect == true)
assert(xx == 1)
assert(yy == 2)
assert(ww == 10)
assert(hh == 10)

-- testing rcintersect with overlaps
------------------------------------

-- intersect rectangle 2 within rectangle 1
-- Second rectangle overlapping top left
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    0, 0, 10, 10,
    -3, -3, 5, 5)
assert(intersect == true)
assert(xx == 0)
assert(yy == 0)
assert(ww == 2)
assert(hh == 2)

-- intersect rectangle 2 within rectangle 1
-- Second rectangle overlapping top right
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    0, 0, 10, 10,
    8, -3, 5, 5)
assert(intersect == true)
assert(xx == 8)
assert(yy == 0)
assert(ww == 2)
assert(hh == 2)

-- intersect rectangle 2 within rectangle 1
-- Second rectangle overlapping bottom right
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    0, 0, 10, 10,
    8, 8, 5, 5)
assert(intersect == true)
assert(xx == 8)
assert(yy == 8)
assert(ww == 2)
assert(hh == 2)

-- intersect rectangle 2 within rectangle 1
-- Second rectangle overlapping bottom left
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    0, 0, 10, 10,
    -3, 8, 5, 5)
assert(intersect == true)
assert(xx == 0)
assert(yy == 8)
assert(ww == 2)
assert(hh == 2)

-- test touching non-intersections
----------------------------------

-- Vertex touching is not an intersection
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    -5, -5, 5, 5,
    0, 0, 5, 5)
assert(intersect == false)
assert(xx == 0)
assert(yy == 0)
assert(ww == 0)
assert(hh == 0)

-- Vertex touching is not an intersection
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    5, -5, 5, 5,
    0, 0, 5, 5)
assert(intersect == false)
assert(xx == 5)
assert(yy == 0)
assert(ww == 0)
assert(hh == 0)

-- Vertex touching is not an intersection
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    5, 5, 5, 5,
    0, 0, 5, 5)
assert(intersect == false)
assert(xx == 5)
assert(yy == 5)
assert(ww == 0)
assert(hh == 0)

-- Vertex touching is not an intersection
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    -5, 5, 5, 5,
    0, 0, 5, 5)
assert(intersect == false)
assert(xx == 0)
assert(yy == 5)
assert(ww == 0)
assert(hh == 0)

-- line touching is not an intersection
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    -5, 0, 5, 5,
    0, 0, 5, 5)
assert(intersect == false)
assert(xx == 0)
assert(yy == 0)
assert(ww == 0)
assert(hh == 5)

-- line touching is not an intersection
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    0, -5, 5, 5,
    0, 0, 5, 5)
assert(intersect == false)
assert(xx == 0)
assert(yy == 0)
assert(ww == 5)
assert(hh == 0)

-- line touching is not an intersection
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    5, 0, 5, 5,
    0, 0, 5, 5)
assert(intersect == false)
assert(xx == 5)
assert(yy == 0)
assert(ww == 0)
assert(hh == 5)

-- line touching is not an intersection
intersect, xx, yy, ww, hh =
  Wind.rcintersect(
    0, 5, 5, 5,
    0, 0, 5, 5)
assert(intersect == false)
assert(xx == 0)
assert(yy == 5)
assert(ww == 5)
assert(hh == 0)

-- test detached non-intersections
----------------------------------

-- detached rectangles are not an intersection
intersect, xx, yy, ww, hh =
Wind.rcintersect(
  -10, -10, 5, 5,
  0, 0, 5, 5)
assert(intersect == false)
assert(xx == 0)
assert(yy == 0)
assert(ww == -5)
assert(hh == -5)

-- detached rectangles are not an intersection
intersect, xx, yy, ww, hh =
Wind.rcintersect(
  10, -10, 5, 5,
  0, 0, 5, 5)
assert(intersect == false)
assert(xx == 10)
assert(yy == 0)
assert(ww == -5)
assert(hh == -5)

-- detached rectangles are not an intersection
intersect, xx, yy, ww, hh =
Wind.rcintersect(
  10, 10, 5, 5,
  0, 0, 5, 5)
assert(intersect == false)
assert(xx == 10)
assert(yy == 10)
assert(ww == -5)
assert(hh == -5)

-- detached rectangles are not an intersection
intersect, xx, yy, ww, hh =
Wind.rcintersect(
  -10, 10, 5, 5,
  0, 0, 5, 5)
assert(intersect == false)
assert(xx == 0)
assert(yy == 10)
assert(ww == -5)
assert(hh == -5)

gemdos.Cconws("Testing rc done\r\n")
