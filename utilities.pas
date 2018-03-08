type
  TRSWUtils = type Pointer;
  
  TWebGraph = record
    Nodes: TPointArray;
    Paths: T2DIntArray;
    Names: TStringArray;
  end;
  
var
  MM_AREA: TBox := [570,12,714,156];//[570,9,714,159];
  MM_CROP: TBox := [0,0,MM_AREA.X2-MM_AREA.X1,MM_AREA.Y2-MM_AREA.Y1];
  MM_RAD: Int32 := 64;
  
  RSWUtils: TRSWUtils;


function TRSWUtils.InPoly(p:TPoint; const Poly:TPointArray): Boolean; static;
var j,i,H: Int32;
begin
  H := High(poly);
  j := H;
  Result := False;
  for i:=0 to H do begin
    if ((poly[i].y < p.y) and (poly[j].y >= p.y) or (poly[j].y < p.y) and (poly[i].y >= p.y)) then
      if (poly[i].x+(p.y-poly[i].y) / (poly[j].y-poly[i].y) * (poly[j].x-poly[i].x) < p.x) then
        Result := not(Result);
    j := i;
  end;
end;

function TRSWUtils.DistToLine(Pt, sA, sB: TPoint): Double; static;
var
  dx,dy,d:Int32;
  f: Single;
  qt:TPoint;
begin
  dx := sB.x - sA.x;
  dy := sB.y - sA.y;
  d := dx*dx + dy*dy;
  if (d = 0) then Exit(Hypot(pt.x-sA.x, pt.y-sA.y));
  f := ((pt.x - sA.x) * (dx) + (pt.y - sA.y) * (dy)) / d;
  if (f < 0) then Exit(Hypot(pt.x-sA.x, pt.y-sA.y));
  if (f > 1) then Exit(Hypot(pt.x-sB.x, pt.y-sB.y));
  qt.x := Round(sA.x + f * dx);
  qt.y := Round(sA.y + f * dy);
  Result := Hypot(pt.x-qt.x, pt.y-qt.y);
end;

function TRSWUtils.LinesIntersect(p,q:array[0..1] of TPoint; out i:TPoint): Boolean; static;
var
  dx,dy,d: TPoint;
  dt,s,t: Double;
  function Det(a,b: TPoint): Int64;
  begin
    Result := a.x*b.y - a.y*b.x;
  end;
begin
  dx := [p[0].x - p[1].x, q[0].x - q[1].x];
  dy := [p[0].y - p[1].y, q[0].y - q[1].y];
  dt := det(dx, dy);
  if dt = 0 then Exit(False);
  d := [Det(p[0],p[1]), Det(q[0],q[1])];
  i.x := Round(Det(d, dx) / dt);
  i.y := Round(Det(d, dy) / dt);
  s := (dx.x * (q[0].y-p[0].y) + dy.x * (p[0].x-q[0].x)) / dt;
  t := (dx.y * (p[0].y-q[0].y) + dy.y * (q[0].x-p[0].x)) / (-dt);
  Result := (s > 0) and (s < 1) and (t > 0) and (t < 1);
end;

function TRSWUtils.PathLength(Path: TPointArray): Double; static;
var j,i,H: Int32;
begin
  for i:=0 to High(path)-1 do begin
    Result += Hypot(path[i].x-path[i+1].x, path[i].y-path[i+1].y);
  end;
end;

function TRSWUtils.BuildPath(TPA: TPointArray; minStep,maxStep:Int32): TPointArray; static;
var
  i,j,l: Int32;
  tmp: TPointArray;
begin
  for i:=1 to High(TPA) do
  begin
    tmp := TPAFromLine(TPA[i-1].x,TPA[i-1].y, TPA[i].x,TPA[i].y);
    j := 0;
    while j < High(tmp) do
    begin
      Result += tmp[j];
      Inc(j, Random(minStep, maxStep));
    end;
  end;
  Result += TPA[High(TPA)];
end;


function TRSWUtils.MinBoxInRotated(B: TBox; Angle: Double): TBox; static;
var
  sinA,cosA,ss,ls,wr,hr: Double;
  W,H: Int32;
begin
  W := B.x2-B.x1+1;
  H := B.y2-B.y1+1;
  ls := W;
  ss := H;
  if w < h then Swap(ls,ss);

  sinA := Abs(Sin(Angle));
  cosA := Abs(Cos(Angle));
  if (ss <= 2.0*sinA*cosA*ls) or (abs(sinA-cosA) < 0.00001) then
  begin
    wr := (0.5*ss)/sinA;
    hr := (0.5*ss)/cosA;
    if (w < h) then Swap(wr,hr);
  end else
  begin
    wr := (W*cosA - H*sinA) / (Sqr(cosA) - Sqr(sinA));
    hr := (H*cosA - W*sinA) / (Sqr(cosA) - Sqr(sinA));
  end;

  with B.Middle() do
  begin
    Result := [Trunc(X-wr/2), Trunc(Y-hr/2), Ceil(X+wr/2), Ceil(Y+hr/2)];
    Result.LimitTo(B);
  end;
end;

function TRSWUtils.GetMinimap(Smooth, Sample: Boolean; ratio:Int32=1): T2DIntArray; static;
var
  bmp: PtrUInt;
  B: TBox;
  th: Double;

  procedure ClearCorners();
  var
    i: Int32;
    TPA: TPointArray;
  begin
    TPA := TPAFromPolygon(Minimap.MaskPoly);
    TPA := TPA.Invert();
    FilterPointsBox(TPA, MM_AREA.X1,MM_AREA.Y1+1,MM_AREA.X2,MM_AREA.Y2);
    TPA.Offset(Point(-MM_AREA.X1,-MM_AREA.Y1));
    DrawTPABitmap(BMP, TPA, 0);
    TPA.SortByY(True);
    for i:=0 to High(TPA) do
      FastSetPixel(bmp, TPA[i].x,TPA[i].y, FastGetPixel(bmp,TPA[i].x,TPA[i].y-1));
  end;
begin
  th  := Minimap.GetCompassAngle(False);
  BMP := BitmapFromClient(MM_AREA.x1, MM_AREA.y1, MM_AREA.x2, MM_AREA.y2);
  ClearCorners();
  Result := BitmapToMatrix(BMP);
  FreeBitmap(BMP);
  Result := w_ImRotate(Result, th, False, Smooth);
  B := RSWUtils.MinBoxInRotated(MM_CROP, th);
  while B.Width  > 112 do begin B.x2 -= 1; B.x1 += 1; end;
  while B.Height > 100 do begin B.y2 -= 1; B.y1 += 1; end;
  Result := w_GetArea(Result, B.x1,B.y1,B.x2,B.y2);

  if Sample then
    Result := w_ImSample(Result, ratio);
end;



// -----------------------------------------------------------------------------
// TWebGraph - A web for any runescape map so you can walk everywhere on it.

function TWebGraph.FindNode(Name: String): Int32;
begin
  for Result:=0 to High(Self.Names) do
    if Pos(Name, Self.Names[Result]) <> 0 then
      Exit(Result);
  Result := -1;
end;

function TWebGraph.FindPath(Start, Goal: Int32; Rnd:Double=0): TIntArray; constref;
type
  TNode = record
    Indices: TIntArray;
    Score: Double;
  end;
var
  queue: array of TNode;
  visited: TBoolArray;
  cIdx, pathIdx, n: Int32;
  current, node: TNode;
  altPaths: array of TIntArray;
  p,q: TPoint;
  hyp: Double;

  function GetNextShortest(): TNode;
  var i,node: Int32;
  begin
    Result := queue[0];
    for i:=0 to High(queue) do
      if queue[i].Score < Result.Score then
      begin
        node   := i;
        Result := queue[i];
      end;
    Delete(queue, node, 1);
  end;
begin
  queue   := [[[start],0]];
  SetLength(visited, Length(Self.Nodes));

  while Length(queue) <> 0 do
  begin
    current := GetNextShortest();
    cIdx := current.Indices[High(current.Indices)];
    if Visited[cIdx] then Continue; //skip overwrapping paths..
    Visited[cIdx] := True;

    if (cIdx = Goal) then
    begin
      Exit(current.Indices);
    end;

    p := Self.Nodes[cIdx];
    for pathIdx in Self.Paths[cIdx] do
    begin
      if not Visited[pathIdx] then
      begin
        q := Self.Nodes[pathIdx];
        node.Indices := current.Indices + pathIdx;

        hyp := Hypot(p.x-q.x, p.y-q.y);
        node.Score   := current.Score + hyp + (hyp*Random()*Rnd-Rnd/2);
        queue += node;
      end;
    end;
  end;
end;

function TWebGraph.FindNearestNode(P: TPoint): Int32; constref;
var 
  i,j: Int32;
  d,best,dn1,dn2: Double;
begin
  best := $FFFFFF;
  for i:=0 to High(Self.Paths) do
    for j in Self.Paths[i] do
    begin
      d := RSWUtils.DistToLine(P, Self.Nodes[i], Self.Nodes[j]);
      if d < best then
      begin
        best := d;
        dn1 := Hypot(Self.Nodes[i].x-P.x, Self.Nodes[i].y-P.y);
        dn2 := Hypot(Self.Nodes[j].x-P.x, Self.Nodes[j].y-P.y);
        if dn1 < dn2 then 
          Result := i
        else  
          Result := j;
      end;
    end;
end;

function TWebGraph.NodesToPoints(NodeList: TIntArray): TPointArray; constref;
var node: Int32;
begin
  for node in NodeList do
    Result += Self.Nodes[node];
end;

function TWebGraph.PathBetween(p,q: TPoint; Rnd:Double=0): TPointArray; constref;
var
  i,n1,n2: Int32;
  nodes: TIntArray;
begin
  n1 := Self.FindNearestNode(p);
  n2 := Self.FindNearestNode(q);
  nodes := Self.FindPath(n1,n2,Rnd);
  if (Length(nodes) = 0) then
    RaiseException('Points `'+ToStr(p)+'` and `'+ToStr(q)+'` does not connect');

  Result += p;
  Result += NodesToPoints(nodes);
  Result += q;
end;

function TWebGraph.InvalidConnection(p,q: TPoint): Boolean;
var
  i,n: Int32;
  l1,l2: array[0..1] of TPoint;
  _: TPoint;
begin
  l1 := [p,q];
  for i:=0 to High(self.Paths) do
  begin
    l2[0] := self.Nodes[i];
    for n in self.Paths[i] do
    begin
      l2[1] := self.Nodes[n];
      if (l1[0] = l2[0]) and (l1[1] = l2[1]) then
        Continue;
      if RSWUtils.LinesIntersect(l1,l2,_) then
        Exit(True);
    end;
  end;
end;

function TWebGraph.AddNode(p: TPoint; FromNode: Int32): Boolean;
var
  c: Int32;
begin
  if (FromNode <> -1) and (InvalidConnection(p, Self.Nodes[FromNode])) then
    Exit(False);

  c := Length(Self.Nodes);
  SetLength(Self.Nodes, c+1);
  SetLength(Self.Paths, c+1);
  Self.Nodes[c] := p;

  if FromNode <> -1 then
  begin
    Self.Paths[FromNode] += c;
    Self.Paths[c] += FromNode;
  end;

  Result := True;
end;

function TWebGraph.ConnectNodes(a,b: Int32): Boolean;
var
  i,n: Int32;
  p: TPoint;
  l1,l2: array[0..1] of TPoint;
begin
  if InIntArray(Self.Paths[a], b) then
  begin
    Self.Paths[a].Remove(b);
    Self.Paths[b].Remove(a);
  end else
  begin
    if (Self.InvalidConnection(Self.Nodes[a], Self.Nodes[b])) then
      Exit(False);

    Self.Paths[a] += b;
    Self.Paths[b] += a;
  end;

  Result := True;
end;

function TWebGraph.DeleteNode(node: Int32): Int32;
var
  i,j,n,curr: Int32;
  marked: TIntArray;
begin
  marked += node;
  repeat
    curr := marked.Pop();

    for n in Self.Paths[curr] do
    begin
      Self.Paths[n].Remove(curr, True);
      if Length(Self.Paths[n]) = 0 then
        marked += n;
    end;

    // offset remainding nodes
    for i:=0 to High(Self.Paths) do
      for j:=0 to High(Self.Paths[i]) do
        if Self.Paths[i][j] > curr then
          Dec(Self.Paths[i][j]);

    for i:=0 to High(marked) do
      if marked[i] > curr then Dec(marked[i]);

    // remove the node itself
    Delete(Self.Paths, curr, 1);
    Delete(Self.Nodes, curr, 1);
    Result += 1;
  until Length(marked) = 0;
end;


{$i world.graph}
var 
  RSW_Graph: TWebGraph := WorldGraph;




