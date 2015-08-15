{=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=]
 Copyright (c) 2013, Jarl K. <Slacky> Holta || http://github.com/WarPie
 All rights reserved.
[=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=}
{$ifndecl cv_MatFromData} {$include_once libloader.inc} {$endif}
type
  cvCrossCorrAlgo = (
    CV_TM_SQDIFF, CV_TM_SQDIFF_NORMED, CV_TM_CCORR, CV_TM_CCORR_NORMED,
    CV_TM_CCOEFF, CV_TM_CCOEFF_NORMED
  );
  cvMatrix2D = record Data:Pointer; cols,rows:Int32; end; 
  LibCV = type Pointer;

{-------------------------------------------------------------------------------]
 Raw base for MatchTemplate
[-------------------------------------------------------------------------------}
function LibCV.__cvLoadFromMatrix(var Mat:T2DIntArray): cvMatrix2D;
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


procedure LibCV.__cvFreeMatrix(var Matrix:cvMatrix2D);
begin
  cv_FreeImage(Matrix.data);
  Matrix.cols := 0;
  Matrix.rows := 0;
end;


function LibCV.__MatchTemplate(var img, templ:cvMatrix2D; algo: cvCrossCorrAlgo;
                               normed:Boolean=True): T2DFloatArray;
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

  Ptr := PFloat32(cv_MatchTemplate(img.Data, templ.Data, ord(algo), normed, res));
  if (Ptr = nil) then Exit();

  for i:=0 to H-1 do
    MemMove(Ptr[i*W]^, Result[i][0], 4*W);

  cv_FreeImage(res);
end;
{-------------------------------------------------------------------------------]
[-------------------------------------------------------------------------------}


function LibCV.MatchTemplate(image, templ:T2DIntArray; matchAlgo: cvCrossCorrAlgo; normalize:Boolean=False): T2DFloatArray; overload;
var
  W,H:Int32;
  patch,img:cvMatrix2D;
begin
  img := Self.__cvLoadFromMatrix(Image);
  patch := Self.__cvLoadFromMatrix(Templ);
  Result := Self.__MatchTemplate(img,patch,matchAlgo,normalize);
  Self.__cvFreeMatrix(img);
  Self.__cvFreeMatrix(patch);
end;
