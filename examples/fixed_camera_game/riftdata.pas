{
  Copyright 2007-2014 Michalis Kamburelis.

  This file is part of "the rift".

  "the rift" is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or
  (at your option) any later version.

  "the rift" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with "the rift"; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

  ----------------------------------------------------------------------------
}

{ }
unit RiftData;

interface

uses CastleXMLConfig;

var
  DataConfig: TCastleConfig;

{ If ARelativeURL is a URL relative to a location of our index.xml
  config file, this returns the full absolute URL of this file.
  It's OK if ARelativeURL is in fact absolute --- then it will
  be simply returned. }
function DataURLFromConfig(const ARelativeURL: string): string;

implementation

uses SysUtils, CastleFilesUtils, CastleURIUtils;

function DataURLFromConfig(const ARelativeURL: string): string;
begin
  Result := CombineURI(DataConfig.URL, ARelativeURL);
end;

initialization
  DataConfig := TCastleConfig.Create(nil);
  DataConfig.URL := ApplicationData('index.xml');
finalization
  FreeAndNil(DataConfig);
end.
