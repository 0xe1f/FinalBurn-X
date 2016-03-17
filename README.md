FinalBurn X
===========

![Screenshot](http://i.imgur.com/WpXkUlQ.png "Windows")

FinalBurn X is a port of [FinalBurn Alpha](http://www.barryharris.me.uk/fba.php)
to OS X. The goal of FinalBurn X is the emulation of Capcom Systems I, II, III
and SNK Neo Geo.

The emulator is currently in experimental stage, with the ultimate goal of
running multiple instances of FinalBurn, each in a separate process. It does
this by launching a process for each emulator window and coordinating the 
interaction via the
[OpenEmuXPCCommunicator](https://github.com/OpenEmu/OpenEmuXPCCommunicator),
library, written by the [OpenEmu](https://github.com/OpenEmu) team. Video
rendering is done via IOSurface and both sound and input are handled by the
emulation process locally.

The emulator is usable, but you have to use the stable binary (the alpha
release) to add new sets.


Controls
--------

Capcom:
`1`,`5`,`A`,`S`,`D`,`Z`,`X`,`C` for 
`1P Start`,`1P Coin`,`Jab`,`Strong`,`Fierce`,`Short`,`Forward` and `Roundhouse`,
respectively.

Neo Geo:
`1`,`5`,`A`,`S`,`D`,`Z` for `1P Start`,`1P Coin`,`A`,`B`,`C` and `D`,
respectively.
