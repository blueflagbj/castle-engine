{
  Copyright 2003-2005 Michalis Kamburelis.

  This file is part of "Kambi's 3dmodels Pascal units".

  "Kambi's 3dmodels Pascal units" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "Kambi's 3dmodels Pascal units" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "Kambi's 3dmodels Pascal units"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
}

{ @abstract(Ten modul ma zawierac implementacje roznorakich rownan lokalnych modeli
  oswietlenia i BRDFow po to zeby (chociaz czasami, kiedy bedzie to mozliwe)
  oddzielic implementacje tych rzeczy od implementacji roznych ray tracerow
  (i ew. innych rendererow).)  }

unit IllumModels;

interface

uses VectorMath, VRMLNodes, VRMLTriangleOctree, Math, KambiUtils;

{ Ponizej implementujemy mniej wiecej model oswietlenia ze specyfikacji VRMLa 97.
  To jest normalny model osw. Phonga. Pewne rzeczy ktore sa (niektore tylko
  chwilowo) zaimplementowane niezgodnie z ta specyfikacja to :
  - zle uwzgledniamy attenuation swiatel ktore sa umieszczone pod jakas
    transformacja (TODO)
  - skupienie spot light liczymy troche inaczej bo mamy do dyspozycji inne
    dane (mamy pola z VRMLa 1.0 ktore okreslaja spot inaczej niz w VRMLu 97).
    Uzywamy wiec dla spota rownan uzywanych w OpenGLu.
  - nie obliczamy AmbientFactor w LightContribution bo nie mamy ambientIntensity
    z VRMLa 97 w light nodes a jest ono niezbedne zeby rownanie dzialalo sensownie.
    (TODO: dodac ambientIntensity do swiatel i odkomentarzowac w
    VRML97LightContribution kod realizujacy AmbientFactor)
  - w VRML97EmissionColor jezeli not LightingCalculationOn to
    robimy cos speszial, zupelnie niezgodnie z modelem oswietlenia - bierzemy
    kolor diffuse materialu. Wszystko dlatego ze sam kolor Emission jest
    zazwyczaj czarny i obrazek narysowany tylko kolorem Emission raczej nie
    jest zbyt ciekawy. Jezeli LightingCalculationOn to zwracamy poprawnie
    kolor emission.
  - O ile dobrze zrozumialem, rownania oswietlenia VMRLa 97 proponuja oswietlac
    powierzchnie tylko z jednej strony, tam gdzie wskazuje podany wektor
    normalny (tak jak w OpenGLu przy TWO_SIDED_LIGHTING OFF).
    (patrz definicja "modified dot product" w specyfikacji oswietlenia VRMLa 97)
    Dla mnie jest to bez sensu i oswietlam powierzchnie z obu stron, tak jakby
    kazda powierzchnia byla DWOMA powierzchniami, kazda z nich o przeciwnym
    wektorze normalnym (tak jak w OpenGLu przy TWO_SIDED_LIGHTING ON).

  Jeszcze slowo : wszystkie funkcje zwracaja kolor w postaci RGB ale NIE
  clamped do (0, 1) (robienie clamp przez te funkcje byloby czysta strata
  czasu, i tak te funkcje sa zazwyczaj opakowane w wiekszy kod liczacy
  kolory i ten nadrzedny kod musi robic clamp - o ile chce, np. raytracer
  zapisujacy kolory do rgbe nie musi nigdzie robic clamp). }
function VRML97Emission(const IntersectNode: TOctreeItem;
  LightingCalculationOn: boolean): TVector3Single;
function VRML97LightContribution(const Light: TActiveLight;
  const Intersection: TVector3Single; const IntersectNode: TOctreeItem;
  const CamPosition: TVector3Single): TVector3Single;

{ Bardzo specjalna wersja VRML97LightContribution, stworzona na potrzeby
  VRMLLightMap. Idea jest taka ze mamy punkt (Point) w scenie,
  wiemy ze lezy on na jakiejs plaszczyznie ktorej kierunek (znormalizowany)
  to PointPlaneNormal, mamy zadane Light w tej scenie i chcemy
  policzyc lokalny wplyw swiatla na punkt. Zeby uscislic :
  w przeciwienstwie do VRML97LightContribution NIE MAMY
  - CameraPos w scenie (ani zadnego CameraDir/Up)
  - materialu z ktorego wykonany jest material.

  Mamy wiec wyjatkowa sytuacje. Mimo to, korzystajac z rownan oswietlenia,
  mozemy policzyc calkiem sensowne light contribution:
  - odczucamy komponent Specular (zostawiamy sobie tylko ambient i diffuse)
  - kolor diffuse materialu przyjmujemy po prostu jako podany MaterialDiffuseColor

  Przy takich uproszczeniach mozemy zrobic odpowiednik VRML97LightContribution
  ktory wymaga mniej danych a generuje wynik niezalezny od polozenia
  kamery (i mozemy go wykonac dla kazdego punktu sceny, nie tylko tych
  ktore leza na jakichs plaszczyznach sceny). To jest wlasnie ta funkcja. }
function VRML97LightContribution_CameraIndependent(const Light: TActiveLight;
  const Point, PointPlaneNormal, MaterialDiffuseColor: TVector3Single): TVector3Single;

{ FogNode jak zwykle moze byc = nil aby powiedziec ze nie uzywamy mgly.
  Jak zwykle mamy tutaj FogTransformedVisibilityRange, podobnie jak w
  TVRMLFlatScene.

  FogType: Integer musi byc poprzednio wyliczone przez VRML97FogType.
  (to po to zeby VRMLFog() nie musiala za kazdym razem porownywac stringow,
  co jest raczej wazne gdy np. uzywasz jej jako elementu raytracera).
  Jesli FogType = -1 to wiesz ze mgla nie bedzie uwzgledniana przez VRML97Fog
  (byc moze bo FogNode = nil, byc moze bo FogNode.FogType bylo nieznane ale
  VRMLNonFatalError pozwolilo nam kontynuowac, byc moze
  FogNode.FdVisibilityRange = 0 itp.), tzn. VRML97Fog
  zwroci wtedy po prostu Color. Mozesz wtedy przekazac
  cokolwiek do DistanceFromCamera (tzn. nie musisz liczyc DistanceFromCamera,
  co zazwyczaj jest czasochlonne bo wiaze sie z pierwiastkowaniem)
  no i mozesz naturalnie w ogole nie wywolywac VRML97Fog.

  Podany Color to suma VRML97Emission i VRML97LightContribution dla
  kazdego swiatla oswietlajacego element. Ta funkcja uwzgledni node mgly
  i ew. zrobi VLerp pomiedzy kolorem mgly a podanym Color. }
function VRML97FogType(FogNode: TNodeFog): Integer;
function VRML97Fog(const Color: TVector3Single; const DistanceFromCamera: Single;
  FogNode: TNodeFog; const FogTransformedVisibilityRange: Single; FogType: Integer):
  TVector3Single;

implementation

{$I VectorMathInlines.inc}

function VRML97Emission(const IntersectNode: TOctreeItem;
  LightingCalculationOn: boolean): TVector3Single;
begin
 if LightingCalculationOn then
  result := IntersectNode.State.LastNodes.Material.EmissiveColor3Single(IntersectNode.MatNum) else
  result := IntersectNode.State.LastNodes.Material.DiffuseColor3Single(IntersectNode.MatNum);
end;

function VRML97LightContribution(const Light: TActiveLight;
  const Intersection: TVector3Single; const IntersectNode: TOctreeItem;
  const CamPosition: TVector3Single): TVector3Single;
{$I illummodels_vrml97lightcontribution.inc}

function VRML97LightContribution_CameraIndependent(const Light: TActiveLight;
  const Point, PointPlaneNormal, MaterialDiffuseColor: TVector3Single)
  :TVector3Single;
{$define CAMERA_INDEP}
{$I illummodels_vrml97lightcontribution.inc}
{$undef CAMERA_INDEP}

function VRML97FogType(FogNode: TNodeFog): Integer;
begin
 if (FogNode = nil) or (FogNode.FdVisibilityRange.Value = 0.0) then Exit(-1);

 result := ArrayPosStr(FogNode.FdFogType.Value, ['LINEAR', 'EXPONENTIAL']);
 if result = -1 then
  VRMLNonFatalError('Unknown fog type '''+FogNode.FdFogType.Value+'''');
end;

function VRML97Fog(const Color: TVector3Single; const DistanceFromCamera: Single;
  FogNode: TNodeFog; const FogTransformedVisibilityRange: Single; FogType: Integer):
  TVector3Single;
var f: Single;
begin
 if FogType <> -1 then
 begin
  if DistanceFromCamera >= FogTransformedVisibilityRange-SingleEqualityEpsilon then
   result := FogNode.FdColor.Value else
  begin
   case FogType of
    0: f:=(FogTransformedVisibilityRange - DistanceFromCamera) / FogTransformedVisibilityRange;
    1: f := Exp(-DistanceFromCamera / (FogTransformedVisibilityRange - DistanceFromCamera));
   end;
   result := VLerp(f, FogNode.FdColor.Value, Color);
  end;
 end else
  result := Color;
end;

end.
