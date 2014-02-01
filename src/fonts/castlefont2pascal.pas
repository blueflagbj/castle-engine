{
  Copyright 2004-2014 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Converting fonts (TOutlineFontData or TTextureFontData) to Pascal source code. }
unit CastleFont2Pascal;

interface

uses CastleOutlineFontData, CastleTextureFontData, Classes;

{ @noAutoLinkHere }
procedure Font2Pascal(const Font: TOutlineFontData;
  const UnitName, PrecedingComment, FontFunctionName: string; Stream: TStream);
  overload;

{ @noAutoLinkHere }
procedure Font2Pascal(const Font: TOutlineFontData;
  const UnitName, PrecedingComment, FontFunctionName: string;
  const OutURL: string); overload;

{ @noAutoLinkHere }
procedure Font2Pascal(const Font: TTextureFontData;
  const UnitName, PrecedingComment, FontFunctionName: string; Stream: TStream);
  overload;

{ @noAutoLinkHere }
procedure Font2Pascal(const Font: TTextureFontData;
  const UnitName, PrecedingComment, FontFunctionName: string;
  const OutURL: string); overload;

implementation

uses SysUtils, CastleUtils, CastleStringUtils, CastleClassUtils, CastleDownload;

{ WriteUnit* ---------------------------------------------------------- }

procedure WriteUnitBegin(Stream: TStream; const UnitName, PrecedingComment,
  UsesUnitName, FontFunctionName, FontTypeName: string);
begin
  WriteStr(Stream,
    '{ -*- buffer-read-only: t -*- }' +NL+
    NL+
    '{ Unit automatically generated by ' + ApplicationName + ',' +NL+
    '  to embed font data in Pascal source code.' +NL+
    '  @exclude (Exclude this unit from PasDoc documentation.)' +NL+
    NL+
    PrecedingComment+
    '}' +NL+
    'unit ' + UnitName + ';' +NL+
    NL+
    'interface'+NL+
    NL+
    'uses ' + UsesUnitName + ';' +NL+
    NL+
    'function ' + FontFunctionName + ': ' + FontTypeName + ';' +NL+
    NL+
    'implementation' +NL+
    NL+
    'uses SysUtils, CastleImages;' + NL+
    NL+
    'var' +NL+
    '  FFont: ' + FontTypeName + ';' +NL+
    '' +NL+
    'function ' + FontFunctionName + ': ' + FontTypeName + ';' +NL+
    'begin' +NL+
    '  Result := FFont;' +NL+
    'end;' +NL+
    nl
    );
end;

{ Font2Pascal ----------------------------------------------------- }

procedure Font2Pascal(const Font: TOutlineFontData;
  const UnitName, PrecedingComment, FontFunctionName: string; Stream: TStream);

  procedure WriteOutlineChar(Stream: TStream; c: char; TTChar: POutlineChar);

    function PolygonKindToString(PolygonKind: TPolygonKind): string;
    begin
      case PolygonKind of
        pkNewPolygon : Result := 'pkNewPolygon';
        pkLines : Result := 'pkLines';
        pkBezier : Result := 'pkBezier';
        pkPoint : Result := 'pkPoint';
        else raise EInternalError.Create(
          'PolygonKindToString: Undefined value of TPolygonKind');
      end;
    end;

  var
    CharName: string;
    I, WrittenInLine, WriteItemsCount: Cardinal;
  begin
    case c of
      ' ':CharName := 'space = ';
      '}':CharName := 'right curly brace = ';
      else
        (* Avoid C = '{' or '}', to not activate accidentaly
           ObjFpc nested comments feature. *)
        if c in ([' '..#255] - ['{', '}']) then
          CharName := ''''+c+''' = ' else
          CharName := '';
    end;
    WriteStr(Stream, Format('  Char%d : packed record { %s#%d }' +nl,
      [Ord(c), CharName, Ord(c)]));

    if TTChar^.Info.ItemsCount = 0 then
      WriteItemsCount := 1 else
      WriteItemsCount := TTChar^.Info.ItemsCount;

    WriteStr(Stream, Format(
      '    Info : TOutlineCharInfo;'+NL+
      '    Items : array[0..%d] of TOutlineCharItem;'+NL+
      '  end ='+NL+
      '  ( Info : ( MoveX: %g; MoveY: %g; Height: %g;'+NL+
      '             PolygonsCount: %d;'+NL+
      '             ItemsCount: %d );' +NL+
      '    Items :'+NL+
      '    ( ',
      [ WriteItemsCount-1,
        TTChar^.Info.MoveX, TTChar^.Info.MoveY, TTChar^.Info.Height,
        TTChar^.Info.PolygonsCount,
        TTChar^.Info.ItemsCount ]));

    if TTChar^.Info.ItemsCount = 0 then
      WriteStr(Stream, '(Kind: pkPoint; x:0; y:0) { dummy item }') else
    begin
      WrittenInLine := 0;
      { TTChar^.Info.ItemsCount > 0 so TTChar^.Info.ItemsCount-1 >= 0.
        So i may be Cardinal. }
      for i := 0 to TTChar^.Info.ItemsCount-1 do
      begin
        WriteStr(Stream, '(Kind: ' + PolygonKindToString(TTChar^.Items[i].Kind) + '; ');
        if TTChar^.Items[i].Kind = pkPoint then
         WriteStr(Stream, Format('x: %g; y: %g)', [TTChar^.Items[i].x, TTChar^.Items[i].y])) else
         WriteStr(Stream, Format('Count: %d)', [TTChar^.Items[i].Count]));

        Inc(WrittenInLine);
        if i < TTChar^.Info.ItemsCount-1 then
        begin
          WriteStr(Stream, ', ');
          if TTChar^.Items[i+1].Kind <> pkPoint then
            begin WriteStr(Stream, NL+'      '); WrittenInLine := 0 end else
          if WrittenInLine mod 30 = 0 then
            begin WriteStr(Stream, NL+'          '); WrittenInLine := 0 end;
        end;
      end;
    end;
    WriteStr(Stream, NL+'    )'+NL+'  );'+NL+nl);
  end;

  procedure WriteUnitEnd(Stream: TStream; const FontFunctionName, FontTypeName: string);
  var
    i: Integer;
  begin
    WriteStr(Stream, '  Data : ' + FontTypeName + 'Array = (' +NL+
      '    ');
    for i := 0 to 255 do
    begin
      WriteStr(Stream, '@Char' + IntToStr(i));
      if i < 255 then WriteStr(Stream, ', ');
      if (i+1) mod 20 = 0 then WriteStr(Stream, NL+'    ');
    end;

    WriteStr(Stream, ');' +NL+
       '' +NL+
       'initialization' +NL+
       '  FFont := ' + FontTypeName + '.Create;' +NL+
       '  FFont.Data := Data;' +NL+
       'finalization' +NL+
       '  FreeAndNil(FFont);' +NL+
       'end.' +nl);
  end;

var
  c: char;
begin
  WriteUnitBegin(Stream, UnitName, PrecedingComment,
    'CastleOutlineFontData', FontFunctionName, 'TOutlineFontData');

  WriteStr(Stream, 'const' +nl);
  for c := #0 to #255 do
  begin
    WriteOutlineChar(Stream, c, Font.Data[c]);
  end;

  WriteUnitEnd(Stream, FontFunctionName, 'TOutlineFontData');
end;

procedure Font2Pascal(const Font: TTextureFontData;
  const UnitName, PrecedingComment, FontFunctionName: string; Stream: TStream);
var
  C: char;
  G: TTextureFontData.TGlyph;
  ImageInterface, ImageImplementation, ImageInitialization, ImageFinalization: string;
begin
  WriteUnitBegin(Stream, UnitName, PrecedingComment,
    'CastleTextureFontData', FontFunctionName, 'TTextureFontData');

  ImageInterface := '';
  ImageImplementation := '';
  ImageInitialization := '';
  ImageFinalization := '';
  Font.Image.SaveToPascalCode('FontImage', true,
    ImageInterface, ImageImplementation, ImageInitialization, ImageFinalization);

  WriteStr(Stream,
    'procedure DoInitialization;' +NL+
    'var' +NL+
    '  Glyphs: TTextureFontData.TGlyphDictionary;' +NL+
    '  G: TTextureFontData.TGlyph;' +NL+
    ImageInterface +
    ImageImplementation +
    'begin' +NL+
    ImageInitialization +
    '  FontImage.TreatAsAlpha := true;' +NL+
    NL+
    '  FillByte(Glyphs, SizeOf(Glyphs), 0);' +NL+
    NL);

  for C in char do
  begin
    G := Font.Glyph(C);
    if G <> nil then
    begin
      WriteStr(Stream,
        '  G := TTextureFontData.TGlyph.Create;' +NL+
        '  G.X := ' + IntToStr(G.X) + ';' +NL+
        '  G.Y := ' + IntToStr(G.Y) + ';' +NL+
        '  G.AdvanceX := ' + IntToStr(G.AdvanceX) + ';' +NL+
        '  G.AdvanceY := ' + IntToStr(G.AdvanceY) + ';' +NL+
        '  G.Width := ' + IntToStr(G.Width) + ';' +NL+
        '  G.Height := ' + IntToStr(G.Height) + ';' +NL+
        '  G.ImageX := ' + IntToStr(G.ImageX) + ';' +NL+
        '  G.ImageY := ' + IntToStr(G.ImageY) + ';' +NL+
        '  Glyphs[Chr(' + IntToStr(Ord(C)) + ')] := G;' +NL+
        NL);
    end;
  end;

  WriteStr(Stream,
    '  FFont := TTextureFontData.CreateFromData(Glyphs, FontImage, ' +
      IntToStr(Font.Size) + ', ' +
      LowerCase(BoolToStr[Font.AntiAliased]) + ');' +NL+
    'end;' +NL+
    NL+
    'initialization' +NL+
    '  DoInitialization;' +NL+
    'finalization' +NL+
    '  FreeAndNil(FFont);' +NL+
    'end.' + NL);
end;

{ OutURL versions ---------------------------------------------------- }

procedure Font2Pascal(const Font: TOutlineFontData;
  const UnitName, PrecedingComment, FontFunctionName: string;
  const OutURL: string); overload;
var
  Stream: TStream;
begin
  Stream := URLSaveStream(OutURL);
  try
    Font2Pascal(Font, UnitName, PrecedingComment, FontFunctionName, Stream);
  finally Stream.Free end;
end;

procedure Font2Pascal(const Font: TTextureFontData;
  const UnitName, PrecedingComment, FontFunctionName: string;
  const OutURL: string); overload;
var
  Stream: TStream;
begin
  Stream := URLSaveStream(OutURL);
  try
    Font2Pascal(Font, UnitName, PrecedingComment, FontFunctionName, Stream);
  finally Stream.Free end;
end;

end.
