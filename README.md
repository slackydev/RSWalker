RSWalker
========
This library is ment for Simba, as a tool for "map-walking" in *Oldschool Runescape*.
RSWalker offers high accuracy, and is very quickly able to determine your current position in the world map.


Example
--------

  {$I SRL/OSR.simba}
  {$I OSRWalker/Walker.simba}
  var
    RSW:TRSWalker;
    path:TPointArray;
  begin
    //if SMART then use smart.PID/SmartGetClientPID() instead of w_getClientPID()
    RSW.Init('Includes\OSRWalker\maps\world.png', w_getClientPID());
    
    AddOnTerminate(@RSW.Free);       //important
    RSW.anyAngle  := True;           //walk at any angle (else it's only compass(north)-only)
    
    //a path - starts at varroc-east bank and walks a couple of steps
    path := [Point(2127, 2099), Point(2101, 2085), Point(2068, 2085), Point(2035, 2082)];
    RSW.WalkPath(path);
  end.
