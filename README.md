RSWalker
========
This library is ment for Simba, it gives your bot "map-walking"-functionality in *Oldschool Runescape*.
RSWalker is highly accuracte, and very quickly able to determine your current position in the world map.

RSWalker doesn't rely on any particular include, so it can be made to work with other includes than SRL.
For RSWalker to work with your include you need to "hook" `onClickEvent` or override `w_clickMouse`.

See: https://villavu.com/forum/showthread.php?t=111914

Example
--------
Example requires https://github.com/Olly-/SRL

```pascal
{$I SRL/OSR.simba}
{$I OSRWalker/Walker.simba}
var
  RSW:TRSWalker;
  path:TPointArray;
begin
  //if SMART then use smart.PID instead of w_GetClientPID()
  RSW.Init('world.png', w_GetClientPID());
  
  AddOnTerminate(@RSW.Free);     //free on termination
  RSW.anyAngle := True;          //walk at any angle (else it's compass(north)-only)
  
  //a random path ex... 
  path := [Point(2127, 2099), Point(2101, 2085), Point(2068, 2085), Point(2035, 2082)];
  RSW.WalkPath(path);
end.
```