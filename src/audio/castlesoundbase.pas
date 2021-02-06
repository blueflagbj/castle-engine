{
  Copyright 2010-2019 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Sound engine basic types. }
unit CastleSoundBase;

{$I castleconf.inc}

interface

uses SysUtils, Generics.Collections;

type
  ENoMoreSources = class(Exception);
  ESoundFileError = class(Exception);

  TSoundDistanceModel = (dmNone,
    dmInverseDistance , dmInverseDistanceClamped,
    dmLinearDistance  , dmLinearDistanceClamped,
    dmExponentDistance, dmExponentDistanceClamped);

  TSoundDevice = class
  private
    FName, FCaption: String;
  public
    { Short device name, used for @link(TSoundEngine.Device). }
    property Name: String read FName;
    { Nice device name to show user. }
    property Caption: String read FCaption;
    property NiceName: String read FCaption; deprecated 'use Caption';
  end;

  TSoundDeviceList = class({$ifdef CASTLE_OBJFPC}specialize{$endif} TObjectList<TSoundDevice>)
    procedure Add(const AName, ACaption: String); reintroduce;
  end;

  { Sound sample format.

    8-bit data is unsigned.
    Just like in case of 8-bit WAV files, and OpenAL AL_FORMAT_MONO8 / AL_FORMAT_STEREO8:
    It is expressed as an unsigned value over the range 0 to 255, 128 being an audio output level of zero.

    16-bit data is signed.
    Just like in case of 16-bit WAV files, and OpenAL AL_FORMAT_MONO16 / AL_FORMAT_STEREO16:
    It is expressed as a signed value over the range -32768 to 32767, 0 being an audio output level of zero.

    Stereo data is expressed in an interleaved format, left channel sample followed by the right channel sample.
  }
  TSoundDataFormat = (
    sfMono8,
    sfMono16,
    sfStereo8,
    sfStereo16
  );

  { How to load a sound buffer. }
  TSoundLoading = (
    { Load entire sound file at once.
      The advantage is that once the sound buffer is loaded, there's zero overhead at runtime
      for playing it, and loading the sound buffer multiple times uses the cache properly.
      The disadvantage is that loading time may be long, for longer files. }
    slComplete,

    { Decompress the sound (like OggVorbis) during playback.
      It allows for much quicker sound loading (almost instant, if you use streaming
      for everything) but means that sounds will be loaded (in parts)
      during playback.
      In general case, we advise to use it for longer sounds (like music tracks). }
    slStreaming
  );

function DataFormatToStr(const DataFormat: TSoundDataFormat): String;

implementation

{ TSoundDeviceList ----------------------------------------------------------- }

procedure TSoundDeviceList.Add(const AName, ACaption: String);
var
  D: TSoundDevice;
begin
  D := TSoundDevice.Create;
  D.FName := AName;
  D.FCaption := ACaption;
  inherited Add(D);
end;

{ global functions ----------------------------------------------------------- }

function DataFormatToStr(const DataFormat: TSoundDataFormat): String;
const
  DataFormatStr: array [TSoundDataFormat] of String = (
    'mono 8',
    'mono 16',
    'stereo 8',
    'stereo 16'
  );
begin
  Result := DataFormatStr[DataFormat];
end;

end.
