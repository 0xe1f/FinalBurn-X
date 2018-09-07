FinalBurn X
===========

![Screenshot](http://i.imgur.com/9pCL8PA.png "Parodius")

FinalBurn X is a port of [FinalBurn Alpha](http://www.barryharris.me.uk/fba.php)
to OS X. The goal of FinalBurn is the emulation of Capcom Systems I, II, III and
SNK Neo Geo.

(The screenshot doesn't belong to any of the four,
[but I couldn't resist the reference](https://github.com/CocoaMSX/CocoaMSX/))

To Play
-------

1. Launch the emulator
2. Import ROM sets by dropping them into the Launcher window (see
[Limitations](#limitations) below).

Controls
--------

Controls are configurable per set for keyboard and other controllers. Default configuration:

6-button Capcom:
`1`,`5`,`A`,`S`,`D`,`Z`,`X`,`C` for 
`1P Start`,`1P Coin`,`Jab`,`Strong`,`Fierce`,`Short`,`Forward` and `Roundhouse`,
respectively.

All other games:
`1`,`5`,`A`,`S`,`D`,`F` for `1P Start`,`1P Coin`,`A`,`B`,`C` and `D`,
respectively.

Limitations
-----------


FinalBurn X will only import from ZIP-compressed archives, and only
[merged sets](https://docs.mamedev.org/usingmame/aboutromsets.html) are
currently supported. When dropping multiple sets, each must be supported by the
emulator, or none will be imported. Only CPS I, II, III and Neo-Geo sets are currently
supported.

Note that to play Neo Geo games, the Neo Geo BIOS (`neogeo.zip`) is required.
