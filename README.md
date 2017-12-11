RSWalker
========
This library is meant for Simba, it gives your bot "map-walking"-functionality in *Oldschool Runescape*.
RSWalker is quite accuracte, and quickly able to determine your current position in the given map.

RSWalker doesn't rely on any particular include, so it can be made to work with other includes than SRL.
For RSWalker to work with your include you need to "hook" `onClickEvent` or override `w_clickMouse`.

For more information see: https://villavu.com/forum/showthread.php?t=111914

Example
--------
Example requires https://github.com/SRL/SRL

```pascal
{$I SRL/OSR.simba}
{$I RSWalker/Walker.simba}
var
  RSW:TRSWalker;
  path:TPointArray;
begin
  RSW.Init('world.png');
  AddOnTerminate(@RSW.Free);     //automatic free on termination
  
  //a random path ex... 
  path := [Point(2127, 2099), Point(2101, 2085), Point(2068, 2085), Point(2035, 2082)];
  RSW.WalkPath(path);
end.
```
