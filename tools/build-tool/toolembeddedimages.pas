{ -*- buffer-read-only: t -*- }

{ Unit automatically generated by image2pascal tool,
  to embed images in Pascal source code.
  @exclude (Exclude this unit from PasDoc documentation.) }
unit ToolEmbeddedImages;

interface

uses CastleImages;

var
  DefaultIcon: TRGBAlphaImage;

implementation

uses SysUtils;

{ Actual image data is included from another file, with a deliberately
  non-Pascal file extension ".image_data". This way online code analysis
  tools will NOT consider this source code as an uncommented Pascal code
  (which would be unfair --- the image data file is autogenerated
  and never supposed to be processed by a human). }
{$I toolembeddedimages.image_data}

initialization
  DefaultIcon := TRGBAlphaImage.Create(DefaultIconWidth, DefaultIconHeight, DefaultIconDepth);
  Move(DefaultIconPixels, DefaultIcon.RawPixels^, SizeOf(DefaultIconPixels));
  DefaultIcon.URL := 'embedded-image:/DefaultIcon';
finalization
  FreeAndNil(DefaultIcon);
end.