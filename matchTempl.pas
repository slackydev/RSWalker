{$loadlib ../Includes/OSRWalker/libMatchTempl.dll}
const
  TM_SQDIFF        = 0;
  TM_SQDIFF_NORMED = 1;
  TM_CCORR         = 2;
  TM_CCORR_NORMED  = 3;
  TM_CCOEFF        = 4;
  TM_CCOEFF_NORMED = 5; 


{-------------------------------------------------------------------------------]
 Raw base for MatchTemplate
[-------------------------------------------------------------------------------}
{$IFNDEF CODEINSIGHT}
type CVMat = record Data:Pointer; cols,rows:Int32; end; 

function __cvLoadFromMatrix(var Mat:T2DIntArray): CVMat;
var
  w,h,y:Int32;
  data:TIntegerArray;
begin
  W := Length(Mat[0]);
  H := Length(Mat);
  SetLength(Data, W*H);
  for y:=0 to H-1 do
    MemMove(Mat[y][0], data[y*W], 4*W);

  Result.Data := nil;
  cv_MatFromData(PChar(data), W,H, Result.Data);
  Result.Cols := W;
  Result.Rows := H;
  SetLength(data, 0);
end;


procedure __cvFreeMatrix(var Matrix:CVMat);
begin
  cv_FreeImage(Matrix.data);
  Matrix.cols := 0;
  Matrix.rows := 0;
end;


function __MatchTemplate(var img, templ:CVMat; Algo: Int8;
                         Normed:Boolean=True): T2DFloatArray;
type 
  PFloat32 = ^Single;
var
  res:Pointer;
  Ptr:PFloat32;
  i,j,W,H:Int32;
begin
  if (img.data = nil) or (templ.Data = nil) then begin
    RaiseException('One or both the images are empty!');
    Exit();
  end;

  if (templ.rows > img.rows) or (templ.cols > templ.cols) then begin
    RaiseException('Sub cannot be larger then Image');
    Exit();
  end;

  W := img.cols - templ.cols + 1;
  H := img.rows - templ.rows + 1;
  SetLength(Result, H,W);

  Ptr := PFloat32(cv_MatchTemplate(img.Data, templ.Data, algo, normed, res));
  if (Ptr = nil) then Exit();

  for i:=0 to H-1 do
    MemMove(Ptr[i*W]^, Result[i][0], 4*W);

  cv_FreeImage(res);
end;
{$ENDIF}
{-------------------------------------------------------------------------------]
[-------------------------------------------------------------------------------}


function w_MatchTemplate(Image, Templ:T2DIntArray; MatchAlgo: UInt8; Normalize:Boolean=False): T2DFloatArray; overload;
var
  W,H:Int32;
  patch,img:CVMat;
begin
  img := __cvLoadFromMatrix(Image);
  patch := __cvLoadFromMatrix(Templ);

  Result := __MatchTemplate(img,patch,MatchAlgo,Normalize);

  __cvFreeMatrix(img);
  __cvFreeMatrix(patch);
end;
