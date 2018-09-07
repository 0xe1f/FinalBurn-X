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
[Limitations](#limitations) below)

Neo Geo games will additionally require the Neo Geo BIOS set (`neogeo.zip`).

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

ROM sets must be:

* ZIP-compressed
* [Merged sets](https://docs.mamedev.org/usingmame/aboutromsets.html)
* Belong to CPS I, II, III or Neo Geo

When dropping multiple sets into the launcher window, each of the files must meet the
above conditions, or none will be imported.

License
-------

```
Copyright (c) Akop Karapetyan

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```

For Final Burn Alpha license information, see
[FB Alpha License](https://www.fbalpha.com/license/)
