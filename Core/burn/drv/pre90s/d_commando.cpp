// FB Alpha Commando driver module
// Based on MAME driver by Nicola Salmoria

#include "tiles_generic.h"
#include "z80_intf.h"
#include "burn_ym2203.h"

static UINT8 DrvInputPort0[8] = {0, 0, 0, 0, 0, 0, 0, 0};
static UINT8 DrvInputPort1[8] = {0, 0, 0, 0, 0, 0, 0, 0};
static UINT8 DrvInputPort2[8] = {0, 0, 0, 0, 0, 0, 0, 0};
static UINT8 DrvDip[2]        = {0, 0};
static UINT8 DrvInput[3]      = {0x00, 0x00, 0x00};
static UINT8 DrvReset         = 0;

static UINT8 *Mem                 = NULL;
static UINT8 *MemEnd              = NULL;
static UINT8 *RamStart            = NULL;
static UINT8 *RamEnd              = NULL;
static UINT8 *DrvZ80Rom1          = NULL;
static UINT8 *DrvZ80Rom1Op        = NULL;
static UINT8 *DrvZ80Rom2          = NULL;
static UINT8 *DrvZ80Ram1          = NULL;
static UINT8 *DrvZ80Ram2          = NULL;
static UINT8 *DrvFgVideoRam       = NULL;
static UINT8 *DrvFgColourRam      = NULL;
static UINT8 *DrvBgVideoRam       = NULL;
static UINT8 *DrvBgColourRam      = NULL;
static UINT8 *DrvSpriteRam        = NULL;
static UINT8 *DrvSpriteRamBuffer  = NULL;
static UINT8 *DrvPromRed          = NULL;
static UINT8 *DrvPromGreen        = NULL;
static UINT8 *DrvPromBlue         = NULL;
static UINT8 *DrvChars            = NULL;
static UINT8 *DrvTiles            = NULL;
static UINT8 *DrvSprites          = NULL;
static UINT8 *DrvTempRom          = NULL;
static UINT32 *DrvPalette         = NULL;

static UINT8 DrvRecalc;

static UINT8 DrvBgScrollX[2];
static UINT8 DrvBgScrollY[2];
static UINT8 DrvFlipScreen;
static UINT8 DrvSoundLatch;

static bool bFirstOpCodeEncrypted = false;

static struct BurnInputInfo DrvInputList[] =
{
	{"Coin 1"            , BIT_DIGITAL  , DrvInputPort0 + 6, "p1 coin"   },
	{"Start 1"           , BIT_DIGITAL  , DrvInputPort0 + 0, "p1 start"  },
	{"Coin 2"            , BIT_DIGITAL  , DrvInputPort0 + 7, "p2 coin"   },
	{"Start 2"           , BIT_DIGITAL  , DrvInputPort0 + 1, "p2 start"  },

	{"Up"                , BIT_DIGITAL  , DrvInputPort1 + 3, "p1 up"     },
	{"Down"              , BIT_DIGITAL  , DrvInputPort1 + 2, "p1 down"   },
	{"Left"              , BIT_DIGITAL  , DrvInputPort1 + 1, "p1 left"   },
	{"Right"             , BIT_DIGITAL  , DrvInputPort1 + 0, "p1 right"  },
	{"Fire 1"            , BIT_DIGITAL  , DrvInputPort1 + 4, "p1 fire 1" },
	{"Fire 2"            , BIT_DIGITAL  , DrvInputPort1 + 5, "p1 fire 2" },
	
	{"Up (Cocktail)"     , BIT_DIGITAL  , DrvInputPort2 + 3, "p2 up"     },
	{"Down (Cocktail)"   , BIT_DIGITAL  , DrvInputPort2 + 2, "p2 down"   },
	{"Left (Cocktail)"   , BIT_DIGITAL  , DrvInputPort2 + 1, "p2 left"   },
	{"Right (Cocktail)"  , BIT_DIGITAL  , DrvInputPort2 + 0, "p2 right"  },
	{"Fire 1 (Cocktail)" , BIT_DIGITAL  , DrvInputPort2 + 4, "p2 fire 1" },
	{"Fire 2 (Cocktail)" , BIT_DIGITAL  , DrvInputPort2 + 5, "p2 fire 2" },

	{"Reset"             , BIT_DIGITAL  , &DrvReset        , "reset"     },
	{"Dip 1"             , BIT_DIPSWITCH, DrvDip + 0       , "dip"       },
	{"Dip 2"             , BIT_DIPSWITCH, DrvDip + 1       , "dip"       },
};


STDINPUTINFO(Drv)

static inline void DrvClearOpposites(UINT8* nJoystickInputs)
{
	if ((*nJoystickInputs & 0x03) == 0x03) {
		*nJoystickInputs &= ~0x03;
	}
	if ((*nJoystickInputs & 0x0c) == 0x0c) {
		*nJoystickInputs &= ~0x0c;
	}
}

static inline void DrvMakeInputs()
{
	// Reset Inputs
	DrvInput[0] = DrvInput[1] = DrvInput[2] = 0x00;

	// Compile Digital Inputs
	for (INT32 i = 0; i < 8; i++) {
		DrvInput[0] |= (DrvInputPort0[i] & 1) << i;
		DrvInput[1] |= (DrvInputPort1[i] & 1) << i;
		DrvInput[2] |= (DrvInputPort2[i] & 1) << i;
	}

	// Clear Opposites
	DrvClearOpposites(&DrvInput[1]);
	DrvClearOpposites(&DrvInput[2]);
}

static struct BurnDIPInfo DrvDIPList[]=
{
	// Default Values
	{0x11, 0xff, 0xff, 0xff, NULL                     },
	{0x12, 0xff, 0xff, 0x1f, NULL                     },
	
	// Dip 1
	{0   , 0xfe, 0   , 4   , "Starting Area"          },
	{0x11, 0x01, 0x03, 0x03, "0 (Forest 1)"           },
	{0x11, 0x01, 0x03, 0x01, "2 (Forest 1)"           },
	{0x11, 0x01, 0x03, 0x02, "4 (Forest 2)"           },
	{0x11, 0x01, 0x03, 0x00, "6 (Forest 2)"           },
	
	{0   , 0xfe, 0   , 4   , "Lives"                  },
	{0x11, 0x01, 0x0c, 0x04, "2"                      },
	{0x11, 0x01, 0x0c, 0x0c, "3"                      },
	{0x11, 0x01, 0x0c, 0x08, "4"                      },
	{0x11, 0x01, 0x0c, 0x00, "5"                      },
	
	{0   , 0xfe, 0   , 4   , "Coin A"                 },
	{0x11, 0x01, 0xc0, 0x00, "2 Coins 1 Play"         },
	{0x11, 0x01, 0xc0, 0xc0, "1 Coin  1 Play"         },
	{0x11, 0x01, 0xc0, 0x40, "1 Coin  2 Plays"        },
	{0x11, 0x01, 0xc0, 0x80, "1 Coin  3 Plays"        },
	
	{0   , 0xfe, 0   , 4   , "Coin B"                 },
	{0x11, 0x01, 0x30, 0x00, "4 Coins 1 Play"         },
	{0x11, 0x01, 0x30, 0x20, "3 Coins 1 Play"         },
	{0x11, 0x01, 0x30, 0x10, "2 Coins 1 Play"         },
	{0x11, 0x01, 0x30, 0x30, "1 Coin  1 Play"         },
	
	// Dip 2
	{0   , 0xfe, 0   , 8   , "Bonus Life"             },
	{0x12, 0x01, 0x07, 0x07, "10k  50k+"              },
	{0x12, 0x01, 0x07, 0x03, "10k  60k+"              },
	{0x12, 0x01, 0x07, 0x05, "20k  60k+"              },
	{0x12, 0x01, 0x07, 0x01, "20k  70k+"              },
	{0x12, 0x01, 0x07, 0x06, "30k  70k+"              },
	{0x12, 0x01, 0x07, 0x02, "30k  80k+"              },
	{0x12, 0x01, 0x07, 0x04, "40k  100k+"             },
	{0x12, 0x01, 0x07, 0x00, "None"                   },
	
	{0   , 0xfe, 0   , 2   , "Demo Sounds"            },
	{0x12, 0x01, 0x08, 0x00, "Off"                    },
	{0x12, 0x01, 0x08, 0x08, "On"                     },
	
	{0   , 0xfe, 0   , 2   , "Difficulty"             },
	{0x12, 0x01, 0x10, 0x10, "Normal"                 },
	{0x12, 0x01, 0x10, 0x00, "Difficult"              },
	
	{0   , 0xfe, 0   , 2   , "Flip Screen"            },
	{0x12, 0x01, 0x20, 0x00, "Off"                    },
	{0x12, 0x01, 0x20, 0x20, "On"                     },
		
	{0   , 0xfe, 0   , 3   , "Cabinet"                },
	{0x12, 0x01, 0xc0, 0x00, "Upright"                },
	{0x12, 0x01, 0xc0, 0x40, "Upright 2 Players"      },
	{0x12, 0x01, 0xc0, 0xc0, "Cocktail"               },
};

STDDIPINFO(Drv)

static struct BurnRomInfo DrvRomDesc[] = {
	{ "cm04.9m",       0x08000, 0x8438b694, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "cm03.8m",       0x04000, 0x35486542, BRF_ESS | BRF_PRG }, //	 1
	
	{ "cm02.9f",       0x04000, 0xf9cc4a74, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program 
	
	{ "vt01.5d",       0x04000, 0x505726e0, BRF_GRA },	     //  3	Characters
	
	{ "vt11.5a",       0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles
	{ "vt12.6a",       0x04000, 0x81b417d3, BRF_GRA },	     //  5
	{ "vt13.7a",       0x04000, 0x5612dbd2, BRF_GRA },	     //  6
	{ "vt14.8a",       0x04000, 0x2b2dee36, BRF_GRA },	     //  7
	{ "vt15.9a",       0x04000, 0xde70babf, BRF_GRA },	     //  8
	{ "vt16.10a",      0x04000, 0x14178237, BRF_GRA },	     //  9
	
	{ "vt05.7e",       0x04000, 0x79f16e3d, BRF_GRA },	     //  10	Sprites
	{ "vt06.8e",       0x04000, 0x26fee521, BRF_GRA },	     //  11
	{ "vt07.9e",       0x04000, 0xca88bdfd, BRF_GRA },	     //  12
	{ "vt08.7h",       0x04000, 0x2019c883, BRF_GRA },	     //  13
	{ "vt09.8h",       0x04000, 0x98703982, BRF_GRA },	     //  14
	{ "vt10.9h",       0x04000, 0xf069d2f8, BRF_GRA },	     //  15
	
	{ "vtb1.1d",       0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb2.2d",       0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb3.3d",       0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb4.1h",       0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb5.6l",       0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb6.6e",       0x00100, 0x0eaf5158, BRF_GRA },	     //  21
};

STD_ROM_PICK(Drv)
STD_ROM_FN(Drv)

static struct BurnRomInfo DrvuRomDesc[] = {
	{ "u4-f.9m",       0x08000, 0xa6118935, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "u3-f.8m",       0x04000, 0x24f49684, BRF_ESS | BRF_PRG }, //	 1
	
	{ "cm02.9f",       0x04000, 0xf9cc4a74, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program 
	
	{ "vt01.5d",       0x04000, 0x505726e0, BRF_GRA },	     //  3	Characters
	
	{ "vt11.5a",       0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles
	{ "vt12.6a",       0x04000, 0x81b417d3, BRF_GRA },	     //  5
	{ "vt13.7a",       0x04000, 0x5612dbd2, BRF_GRA },	     //  6
	{ "vt14.8a",       0x04000, 0x2b2dee36, BRF_GRA },	     //  7
	{ "vt15.9a",       0x04000, 0xde70babf, BRF_GRA },	     //  8
	{ "vt16.10a",      0x04000, 0x14178237, BRF_GRA },	     //  9
	
	{ "vt05.7e",       0x04000, 0x79f16e3d, BRF_GRA },	     //  10	Sprites
	{ "vt06.8e",       0x04000, 0x26fee521, BRF_GRA },	     //  11
	{ "vt07.9e",       0x04000, 0xca88bdfd, BRF_GRA },	     //  12
	{ "vt08.7h",       0x04000, 0x2019c883, BRF_GRA },	     //  13
	{ "vt09.8h",       0x04000, 0x98703982, BRF_GRA },	     //  14
	{ "vt10.9h",       0x04000, 0xf069d2f8, BRF_GRA },	     //  15
	
	{ "vtb1.1d",       0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb2.2d",       0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb3.3d",       0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb4.1h",       0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb5.6l",       0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb6.6e",       0x00100, 0x0eaf5158, BRF_GRA },	     //  21
};

STD_ROM_PICK(Drvu)
STD_ROM_FN(Drvu)

static struct BurnRomInfo Drvu2RomDesc[] = {
	{ "uc4.9m",        0x08000, 0x89ee8e17, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "uc3.8m",        0x04000, 0x72a1a529, BRF_ESS | BRF_PRG }, //	 1
	
	{ "cd02.9f",       0x04000, 0xf9cc4a74, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program 
	
	{ "vt01.5d",       0x04000, 0x505726e0, BRF_GRA },	     //  3	Characters
	
	{ "vt11.5a",       0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles
	{ "vt12.6a",       0x04000, 0x81b417d3, BRF_GRA },	     //  5
	{ "vt13.7a",       0x04000, 0x5612dbd2, BRF_GRA },	     //  6
	{ "vt14.8a",       0x04000, 0x2b2dee36, BRF_GRA },	     //  7
	{ "vt15.9a",       0x04000, 0xde70babf, BRF_GRA },	     //  8
	{ "vt16.10a",      0x04000, 0x14178237, BRF_GRA },	     //  9
	
	{ "vt05.7e",       0x04000, 0x79f16e3d, BRF_GRA },	     //  10	Sprites
	{ "vt06.8e",       0x04000, 0x26fee521, BRF_GRA },	     //  11
	{ "vt07.9e",       0x04000, 0xca88bdfd, BRF_GRA },	     //  12
	{ "vt08.7h",       0x04000, 0x2019c883, BRF_GRA },	     //  13
	{ "vt09.8h",       0x04000, 0x98703982, BRF_GRA },	     //  14
	{ "vt10.9h",       0x04000, 0xf069d2f8, BRF_GRA },	     //  15
	
	{ "vtb-1.1d",      0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb-2.2d",      0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb-3.3d",      0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb-4.1h",      0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb-5.6l",      0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb-6.6e",      0x00100, 0x0eaf5158, BRF_GRA },	     //  21
};

STD_ROM_PICK(Drvu2)
STD_ROM_FN(Drvu2)

static struct BurnRomInfo DrvjRomDesc[] = {
	{ "so04.9m",       0x08000, 0xd3f2bfb3, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "so03.8m",       0x04000, 0xed01f472, BRF_ESS | BRF_PRG }, //	 1
	
	{ "so02.9f",       0x04000, 0xca20aca5, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program 
	
	{ "vt01.5d",       0x04000, 0x505726e0, BRF_GRA },	     //  3	Characters
	
	{ "vt11.5a",       0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles
	{ "vt12.6a",       0x04000, 0x81b417d3, BRF_GRA },	     //  5
	{ "vt13.7a",       0x04000, 0x5612dbd2, BRF_GRA },	     //  6
	{ "vt14.8a",       0x04000, 0x2b2dee36, BRF_GRA },	     //  7
	{ "vt15.9a",       0x04000, 0xde70babf, BRF_GRA },	     //  8
	{ "vt16.10a",      0x04000, 0x14178237, BRF_GRA },	     //  9
	
	{ "vt05.7e",       0x04000, 0x79f16e3d, BRF_GRA },	     //  10	Sprites
	{ "vt06.8e",       0x04000, 0x26fee521, BRF_GRA },	     //  11
	{ "vt07.9e",       0x04000, 0xca88bdfd, BRF_GRA },	     //  12
	{ "vt08.7h",       0x04000, 0x2019c883, BRF_GRA },	     //  13
	{ "vt09.8h",       0x04000, 0x98703982, BRF_GRA },	     //  14
	{ "vt10.9h",       0x04000, 0xf069d2f8, BRF_GRA },	     //  15
	
	{ "vtb1.1d",       0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb2.2d",       0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb3.3d",       0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb4.1h",       0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb5.6l",       0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb6.6e",       0x00100, 0x0eaf5158, BRF_GRA },	     //  21
};

STD_ROM_PICK(Drvj)
STD_ROM_FN(Drvj)

static struct BurnRomInfo DrvbRomDesc[] = {
	{ "commandob_04_9m_27256.bin", 0x08000, 0x348a7654, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "cm03.8m",       0x04000, 0x35486542, BRF_ESS | BRF_PRG }, //	 1
	
	{ "cm02.9f",       0x04000, 0xf9cc4a74, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program 
	
	{ "vt01.5d",       0x04000, 0x505726e0, BRF_GRA },	     //  3	Characters
	
	{ "vt11.5a",       0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles
	{ "vt12.6a",       0x04000, 0x81b417d3, BRF_GRA },	     //  5
	{ "vt13.7a",       0x04000, 0x5612dbd2, BRF_GRA },	     //  6
	{ "vt14.8a",       0x04000, 0x2b2dee36, BRF_GRA },	     //  7
	{ "vt15.9a",       0x04000, 0xde70babf, BRF_GRA },	     //  8
	{ "vt16.10a",      0x04000, 0x14178237, BRF_GRA },	     //  9
	
	{ "vt05.7e",       0x04000, 0x79f16e3d, BRF_GRA },	     //  10	Sprites
	{ "vt06.8e",       0x04000, 0x26fee521, BRF_GRA },	     //  11
	{ "vt07.9e",       0x04000, 0xca88bdfd, BRF_GRA },	     //  12
	{ "vt08.7h",       0x04000, 0x2019c883, BRF_GRA },	     //  13
	{ "vt09.8h",       0x04000, 0x98703982, BRF_GRA },	     //  14
	{ "vt10.9h",       0x04000, 0xf069d2f8, BRF_GRA },	     //  15
	
	{ "vtb1.1d",       0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb2.2d",       0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb3.3d",       0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb4.1h",       0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb5.6l",       0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb6.6e",       0x00100, 0x0eaf5158, BRF_GRA },	     //  21
	
	{ "commandob_pal16l8a.bin", 0x00104, 0x00000000, BRF_OPT | BRF_NODUMP },		// 22 PLDs
};

STD_ROM_PICK(Drvb)
STD_ROM_FN(Drvb)

static struct BurnRomInfo Drvb2RomDesc[] = {
	{ "10", 		   0x08000, 0xab5d1469, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "11",       	   0x04000, 0xd1a43ba1, BRF_ESS | BRF_PRG }, //	 1
	
	{ "8,so02.9f",    0x04000, 0xca20aca5, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program 
	
	{ "7,vt01.5d",    0x04000, 0x505726e0, BRF_GRA },	     //  3	Characters
	
	{ "17,vt11.5a",   0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles
	{ "16,vt12.6a",   0x04000, 0x81b417d3, BRF_GRA },	     //  5
	{ "15,vt13.7a",   0x04000, 0x5612dbd2, BRF_GRA },	     //  6
	{ "14,vt14.8a",   0x04000, 0x2b2dee36, BRF_GRA },	     //  7
	{ "13,vt15.9a",   0x04000, 0xde70babf, BRF_GRA },	     //  8
	{ "12,vt16.10a",  0x04000, 0x14178237, BRF_GRA },	     //  9
	
	{ "3,vt05.7e",    0x04000, 0x79f16e3d, BRF_GRA },	     //  10	Sprites
	{ "2,vt06.8e",    0x04000, 0x26fee521, BRF_GRA },	     //  11
	{ "1,vt07.9e",    0x04000, 0xca88bdfd, BRF_GRA },	     //  12
	{ "6,vt08.7h",    0x04000, 0x2019c883, BRF_GRA },	     //  13
	{ "5,vt09.8h",    0x04000, 0x98703982, BRF_GRA },	     //  14
	{ "4,vt10.9h",    0x04000, 0xf069d2f8, BRF_GRA },	     //  15
	
	{ "vtb1.1d",       0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb2.2d",       0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb3.3d",       0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb4.1h",       0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb5.6l",       0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb6.6e",       0x00100, 0x0eaf5158, BRF_GRA },	     //  21
	
	{ "commandob2_pal16l8.bin", 0x00104, 0xbdbcaf02, BRF_OPT },		// 22 PLDs
};

STD_ROM_PICK(Drvb2)
STD_ROM_FN(Drvb2)

static struct BurnRomInfo Drvb3RomDesc[] = {
	{ "b5.10n",        0x04000, 0xdf8f4e9a, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "b4.9n",         0x04000, 0xaca99905, BRF_ESS | BRF_PRG }, //	 1
	{ "b3.8n",         0x04000, 0x35486542, BRF_ESS | BRF_PRG }, //	 1
	
	{ "b2.9f",         0x04000, 0xf9cc4a74, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program // 2c.9f
	
	{ "b1.5d",         0x04000, 0x505726e0, BRF_GRA },	     //  3	Characters
	
	{ "b12.5a",        0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles   // 11c.5a
	{ "b13.6a",        0x04000, 0x81b417d3, BRF_GRA },	     //  5	        // 12c.6a
	{ "b14.7a",        0x04000, 0x5612dbd2, BRF_GRA },	     //  6		    // 13c.7a
	{ "b15.8a",        0x04000, 0x2b2dee36, BRF_GRA },	     //  7          // 14c.8a
	{ "b16.9a",        0x04000, 0xde70babf, BRF_GRA },	     //  8          // 15c.9a
	{ "b17.10a",       0x04000, 0x14178237, BRF_GRA },	     //  9          // 16c.10a
	
	{ "b6.7e",         0x04000, 0x79f16e3d, BRF_GRA },	     //  10	Sprites // 5c.7e
	{ "b7.8e",         0x04000, 0x26fee521, BRF_GRA },	     //  11         // 6c.8e
	{ "b8.9e",         0x04000, 0xca88bdfd, BRF_GRA },	     //  12         // 7c.9e
	{ "b9.7h",         0x04000, 0x2019c883, BRF_GRA },	     //  13         // 8c.7h
	{ "b10.8h",        0x04000, 0x98703982, BRF_GRA },	     //  14         // 9c.8h
	{ "b11.9h",        0x04000, 0xf069d2f8, BRF_GRA },	     //  15         // 10c.9h
	
	{ "vtb1.1d",       0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb2.2d",       0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb3.3d",       0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb4.1h",       0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb5.6l",       0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb6.6e",       0x00100, 0x0eaf5158, BRF_GRA },	     //  21
};

STD_ROM_PICK(Drvb3)
STD_ROM_FN(Drvb3)

static struct BurnRomInfo SinvasnRomDesc[] = {
	{ "sp04.9m",       0x08000, 0x33f9601e, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "sp03.8m",       0x04000, 0xc7fb43b3, BRF_ESS | BRF_PRG }, //	 1
	
	{ "u2.9f",         0x04000, 0xcbf8c40e, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program 
	
	{ "u1.5d",         0x04000, 0xf477e13a, BRF_GRA },	     //  3	Characters
	
	{ "vt11.5a",       0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles
	{ "vt12.6a",       0x04000, 0x81b417d3, BRF_GRA },	     //  5
	{ "vt13.7a",       0x04000, 0x5612dbd2, BRF_GRA },	     //  6
	{ "vt14.8a",       0x04000, 0x2b2dee36, BRF_GRA },	     //  7
	{ "vt15.9a",       0x04000, 0xde70babf, BRF_GRA },	     //  8
	{ "vt16.10a",      0x04000, 0x14178237, BRF_GRA },	     //  9
	
	{ "u5.e7",         0x04000, 0x2a97c933, BRF_GRA },	     //  10	Sprites
	{ "sp06.e8",       0x04000, 0xd7887212, BRF_GRA },	     //  11
	{ "sp07.e9",       0x04000, 0x9abe7a20, BRF_GRA },	     //  12
	{ "u8.h7",         0x04000, 0xd6b4aa2e, BRF_GRA },	     //  13
	{ "sp09.h8",       0x04000, 0x3985b318, BRF_GRA },	     //  14
	{ "sp10.h9",       0x04000, 0x3c131b0f, BRF_GRA },	     //  15
	
	{ "vtb1.1d",       0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb2.2d",       0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb3.3d",       0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb4.1h",       0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb5.6l",       0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb6.6e",       0x00100, 0x0eaf5158, BRF_GRA },	     //  21
};

STD_ROM_PICK(Sinvasn)
STD_ROM_FN(Sinvasn)

static struct BurnRomInfo SinvasnbRomDesc[] = {
	{ "u4",            0x08000, 0x834ba0de, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "u3",            0x04000, 0x07e4ee3a, BRF_ESS | BRF_PRG }, //	 1
	
	{ "u2",            0x04000, 0xcbf8c40e, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program 
	
	{ "u1",            0x04000, 0xf477e13a, BRF_GRA },	     //  3	Characters
	
	{ "vt11.5a",       0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles
	{ "vt12.6a",       0x04000, 0x81b417d3, BRF_GRA },	     //  5
	{ "vt13.7a",       0x04000, 0x5612dbd2, BRF_GRA },	     //  6
	{ "vt14.8a",       0x04000, 0x2b2dee36, BRF_GRA },	     //  7
	{ "vt15.9a",       0x04000, 0xde70babf, BRF_GRA },	     //  8
	{ "vt16.10a",      0x04000, 0x14178237, BRF_GRA },	     //  9
	
	{ "u5",            0x04000, 0x2a97c933, BRF_GRA },	     //  10	Sprites
	{ "vt06.e8",       0x04000, 0x26fee521, BRF_GRA },	     //  11
	{ "vt07.e9",       0x04000, 0xca88bdfd, BRF_GRA },	     //  12
	{ "u8",            0x04000, 0xd6b4aa2e, BRF_GRA },	     //  13
	{ "vt09.h8",       0x04000, 0x98703982, BRF_GRA },	     //  14
	{ "vt10.h9",       0x04000, 0xf069d2f8, BRF_GRA },	     //  15
	
	{ "vtb1.1d",       0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb2.2d",       0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb3.3d",       0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb4.1h",       0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb5.6l",       0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb6.6e",       0x00100, 0x0eaf5158, BRF_GRA },	     //  21
};

STD_ROM_PICK(Sinvasnb)
STD_ROM_FN(Sinvasnb)

static struct BurnRomInfo MercenarioRomDesc[] = {
	{ "4ac.bin",       0x04000, 0x59ebf408, BRF_ESS | BRF_PRG }, //  0	Z80 #1 Program Code
	{ "4bc.bin",       0x04000, 0xaca99905, BRF_ESS | BRF_PRG }, //	 1
	{ "b3.8n",         0x04000, 0xf998d08a, BRF_ESS | BRF_PRG }, //	 1
	
	{ "cm02.9f",       0x04000, 0xf9cc4a74, BRF_ESS | BRF_PRG }, //  2	Z80 #2 Program // 2c.9f
	
	{ "1c.5d",         0x04000, 0xfe3ebe35, BRF_GRA },	     //  3	Characters
	
	{ "vt11.5a",       0x04000, 0x7b2e1b48, BRF_GRA },	     //  4	Tiles   // 11c.5a
	{ "vt12.6a",       0x04000, 0x81b417d3, BRF_GRA },	     //  5	        // 12c.6a
	{ "vt13.7a",       0x04000, 0x5612dbd2, BRF_GRA },	     //  6		    // 13c.7a
	{ "vt14.8a",       0x04000, 0x2b2dee36, BRF_GRA },	     //  7          // 14c.8a
	{ "vt15.9a",       0x04000, 0xde70babf, BRF_GRA },	     //  8          // 15c.9a
	{ "vt16.10a",      0x04000, 0x14178237, BRF_GRA },	     //  9          // 16c.10a
	
	{ "vt05.7e",       0x04000, 0x79f16e3d, BRF_GRA },	     //  10	Sprites // 5c.7e
	{ "vt06.8e",       0x04000, 0x26fee521, BRF_GRA },	     //  11         // 6c.8e
	{ "vt07.9e",       0x04000, 0xca88bdfd, BRF_GRA },	     //  12         // 7c.9e
	{ "vt08.7h",       0x04000, 0x2019c883, BRF_GRA },	     //  13         // 8c.7h
	{ "vt09.8h",       0x04000, 0x98703982, BRF_GRA },	     //  14         // 9c.8h
	{ "vt10.9h",       0x04000, 0xf069d2f8, BRF_GRA },	     //  15         // 10c.9h
	
	{ "vtb1.1d",       0x00100, 0x3aba15a1, BRF_GRA },	     //  16	PROMs
	{ "vtb2.2d",       0x00100, 0x88865754, BRF_GRA },	     //  17
	{ "vtb3.3d",       0x00100, 0x4c14c3f6, BRF_GRA },	     //  18
	{ "vtb4.1h",       0x00100, 0xb388c246, BRF_GRA },	     //  19
	{ "vtb5.6l",       0x00100, 0x712ac508, BRF_GRA },	     //  20
	{ "vtb6.6e",       0x00100, 0x0eaf5158, BRF_GRA },	     //  21
};

STD_ROM_PICK(Mercenario)
STD_ROM_FN(Mercenario)

static INT32 MemIndex()
{
	UINT8 *Next; Next = Mem;

	DrvZ80Rom1             = Next; Next += 0x0c000;
	DrvZ80Rom1Op           = Next; Next += 0x0c000;
	DrvZ80Rom2             = Next; Next += 0x04000;
	DrvPromRed             = Next; Next += 0x00100;
	DrvPromGreen           = Next; Next += 0x00100;
	DrvPromBlue            = Next; Next += 0x00100;
	
	RamStart               = Next;

	DrvZ80Ram1             = Next; Next += 0x01e00;
	DrvZ80Ram2             = Next; Next += 0x00800;
	DrvSpriteRam           = Next; Next += 0x00200;
	DrvSpriteRamBuffer     = Next; Next += 0x00180;
	DrvBgVideoRam          = Next; Next += 0x00400;
	DrvBgColourRam         = Next; Next += 0x00400;
	DrvFgVideoRam          = Next; Next += 0x00400;
	DrvFgColourRam         = Next; Next += 0x00400;

	RamEnd                 = Next;

	DrvChars               = Next; Next += 0x400 * 8 * 8;
	DrvTiles               = Next; Next += 0x400 * 16 * 16;
	DrvSprites             = Next; Next += 0x300 * 16 * 16;
	DrvPalette             = (UINT32*)Next; Next += 0x00100 * sizeof(UINT32);

	MemEnd                 = Next;

	return 0;
}

static INT32 DrvDoReset()
{
	ZetOpen(0);
	ZetReset();
	ZetClose();

	ZetOpen(1);
	ZetReset();
	BurnYM2203Reset();
	ZetClose();
	
	DrvBgScrollX[0] = DrvBgScrollX[1] = 0;
	DrvBgScrollY[0] = DrvBgScrollY[1] = 0;
	DrvFlipScreen = 0;
	DrvSoundLatch = 0;

	HiscoreReset();
	
	return 0;
}

static UINT8 __fastcall CommandoRead1(UINT16 a)
{
	switch (a) {
		case 0xc000: {
			return 0xff - DrvInput[0];
		}
		
		case 0xc001: {
			return 0xff - DrvInput[1];
		}
		
		case 0xc002: {
			return 0xff - DrvInput[2];
		}
		
		case 0xc003: {
			return DrvDip[0];
		}
		
		case 0xc004: {
			return DrvDip[1];
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("Z80 #1 Read => %04X\n"), a);
		}
	}

	return 0;
}

static void __fastcall CommandoWrite1(UINT16 a, UINT8 d)
{
	switch (a) {
		case 0xc800: {
			DrvSoundLatch = d;
			return;
		}
		
		case 0xc804: {
			DrvFlipScreen = d & 0x80;
			
			if (d & 0x10) {
				ZetReset(1);
			}
			
			return;
		}
		
		case 0xc806: {
			// ???
			return;
		}
		
		case 0xc808: {
			DrvBgScrollX[0] = d;
			return;
		}
		
		case 0xc809: {
			DrvBgScrollX[1] = d;
			return;
		}
		
		case 0xc80a: {
			DrvBgScrollY[0] = d;
			return;
		}
		
		case 0xc80b: {
			DrvBgScrollY[1] = d;
			return;
		}
		
		
		default: {
			bprintf(PRINT_NORMAL, _T("Z80 #1 Write => %04X, %02X\n"), a, d);
		}
	}
}

static UINT8 __fastcall CommandoRead2(UINT16 a)
{
	switch (a) {
		case 0x6000: {
			ZetSetIRQLine(0, CPU_IRQSTATUS_NONE);
			return DrvSoundLatch;
		}
		
		default: {
			bprintf(PRINT_NORMAL, _T("Z80 #2 Read => %04X\n"), a);
		}
	}

	return 0;
}

static void __fastcall CommandoWrite2(UINT16 a, UINT8 d)
{
	switch (a) {
		case 0x8000: {
			BurnYM2203Write(0, 0, d);
			return;
		}
		
		case 0x8001: {
			BurnYM2203Write(0, 1, d);
			return;
		}
		
		case 0x8002: {
			BurnYM2203Write(1, 0, d);
			return;
		}
		
		case 0x8003: {
			BurnYM2203Write(1, 1, d);
			return;
		}

		default: {
			bprintf(PRINT_NORMAL, _T("Z80 #2 Write => %04X, %02X\n"), a, d);
		}
	}
}

static tilemap_callback( bg )
{
	INT32 Attr = DrvBgColourRam[offs];
	INT32 Code = DrvBgVideoRam[offs] + ((Attr & 0xc0) << 2);

	TILE_SET_INFO(0, Code, Attr, TILE_FLIPYX(Attr >> 4));
}

static tilemap_callback( fg )
{
	INT32 Attr = DrvFgColourRam[offs];
	INT32 Code = DrvFgVideoRam[offs] + ((Attr & 0xc0) << 2);

	TILE_SET_INFO(1, Code, Attr, TILE_FLIPYX(Attr >> 4));
}

static INT32 CharPlaneOffsets[2]   = { 4, 0 };
static INT32 CharXOffsets[8]       = { 0, 1, 2, 3, 8, 9, 10, 11 };
static INT32 CharYOffsets[8]       = { 0, 16, 32, 48, 64, 80, 96, 112 };
static INT32 TilePlaneOffsets[3]   = { 0, 0x40000, 0x80000 };
static INT32 TileXOffsets[16]      = { 0, 1, 2, 3, 4, 5, 6, 7, 128, 129, 130, 131, 132, 133, 134, 135 };
static INT32 TileYOffsets[16]      = { 0, 8, 16, 24, 32, 40, 48, 56, 64, 72, 80, 88, 96, 104, 112, 120 };
static INT32 SpritePlaneOffsets[4] = { 0x60004, 0x60000, 4, 0 };
static INT32 SpriteXOffsets[16]    = { 0, 1, 2, 3, 8, 9, 10, 11, 256, 257, 258, 259, 264, 265, 266, 267 };
static INT32 SpriteYOffsets[16]    = { 0, 16, 32, 48, 64, 80, 96, 112, 128, 144, 160, 176, 192, 208, 224, 240 };

static INT32 DrvInit()
{
	INT32 nRet = 0, nLen;

	// Allocate and Blank all required memory
	Mem = NULL;
	MemIndex();
	nLen = MemEnd - (UINT8 *)0;
	if ((Mem = (UINT8 *)BurnMalloc(nLen)) == NULL) return 1;
	memset(Mem, 0, nLen);
	MemIndex();

	DrvTempRom = (UINT8 *)BurnMalloc(0x18000);

	// Load Z80 #1 Program Roms
	nRet = BurnLoadRom(DrvZ80Rom1 + 0x00000, 0, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvZ80Rom1 + 0x08000, 1, 1); if (nRet != 0) return 1;
	
	if (bFirstOpCodeEncrypted) {
		for (INT32 A = 0; A < 0xc000; A++) {
			INT32 src;

			src = DrvZ80Rom1[A];
			DrvZ80Rom1Op[A] = (src & 0x11) | ((src & 0xe0) >> 4) | ((src & 0x0e) << 4);
		}
	} else {
		DrvZ80Rom1Op[0] = DrvZ80Rom1[0];
		for (INT32 A = 1; A < 0xc000; A++) {
			INT32 src;

			src = DrvZ80Rom1[A];
			DrvZ80Rom1Op[A] = (src & 0x11) | ((src & 0xe0) >> 4) | ((src & 0x0e) << 4);
		}
	}
	
	// Load Z80 #2 Program Roms
	nRet = BurnLoadRom(DrvZ80Rom2 + 0x00000, 2, 1); if (nRet != 0) return 1;
	
	// Load and decode the chars
	nRet = BurnLoadRom(DrvTempRom, 3, 1); if (nRet != 0) return 1;
	GfxDecode(0x400, 2, 8, 8, CharPlaneOffsets, CharXOffsets, CharYOffsets, 0x80, DrvTempRom, DrvChars);
	
	// Load and decode the tiles
	memset(DrvTempRom, 0, 0x18000);
	nRet = BurnLoadRom(DrvTempRom + 0x00000,  4, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x04000,  5, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x08000,  6, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x0c000,  7, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x10000,  8, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x14000,  9, 1); if (nRet != 0) return 1;
	GfxDecode(0x400, 3, 16, 16, TilePlaneOffsets, TileXOffsets, TileYOffsets, 0x100, DrvTempRom, DrvTiles);
	
	// Load and decode the sprites
	memset(DrvTempRom, 0, 0x18000);
	nRet = BurnLoadRom(DrvTempRom + 0x00000, 10, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x04000, 11, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x08000, 12, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x0c000, 13, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x10000, 14, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x14000, 15, 1); if (nRet != 0) return 1;
	GfxDecode(0x300, 4, 16, 16, SpritePlaneOffsets, SpriteXOffsets, SpriteYOffsets, 0x200, DrvTempRom, DrvSprites);

	// Load the PROMs
	nRet = BurnLoadRom(DrvPromRed,           16, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvPromGreen,         17, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvPromBlue,          18, 1); if (nRet != 0) return 1;
	
	BurnFree(DrvTempRom);
	
	// Setup the Z80 emulation
	ZetInit(0);
	ZetOpen(0);
	ZetMapMemory(DrvZ80Rom1,		0x0000, 0xbfff, MAP_ROM);
	ZetMapMemory(DrvZ80Rom1Op,		0x0000, 0xbfff, MAP_FETCHOP);
	ZetMapMemory(DrvFgVideoRam,		0xd000, 0xd3ff, MAP_RAM);
	ZetMapMemory(DrvFgColourRam,		0xd400, 0xd7ff, MAP_RAM);
	ZetMapMemory(DrvBgVideoRam,		0xd800, 0xdbff, MAP_RAM);
	ZetMapMemory(DrvBgColourRam,		0xdc00, 0xdfff, MAP_RAM);
	ZetMapMemory(DrvZ80Ram1,		0xe000, 0xfdff, MAP_RAM);
	ZetMapMemory(DrvSpriteRam,		0xfe00, 0xffff, MAP_RAM);
	ZetSetReadHandler(CommandoRead1);
	ZetSetWriteHandler(CommandoWrite1);
	ZetClose();
	
	ZetInit(1);
	ZetOpen(1);
	ZetMapMemory(DrvZ80Rom2,		0x0000, 0x3fff, MAP_ROM);
	ZetMapMemory(DrvZ80Ram2,		0x4000, 0x47ff, MAP_RAM);
	ZetSetReadHandler(CommandoRead2);
	ZetSetWriteHandler(CommandoWrite2);
	ZetClose();
	
	BurnYM2203Init(2, 1500000, NULL, 0);
	BurnTimerAttachZet(3000000);
	BurnYM2203SetAllRoutes(0, 0.15, BURN_SND_ROUTE_BOTH);
	BurnYM2203SetAllRoutes(1, 0.15, BURN_SND_ROUTE_BOTH);
	
	GenericTilesInit();
	GenericTilemapInit(0, TILEMAP_SCAN_COLS, bg_map_callback, 16, 16, 32, 32);
	GenericTilemapInit(1, TILEMAP_SCAN_ROWS, fg_map_callback,  8,  8, 32, 32);
	GenericTilemapSetGfx(0, DrvTiles, 3, 16, 16, 0x40000, 0x00, 0xf);
	GenericTilemapSetGfx(1, DrvChars, 2,  8,  8, 0x10000, 0xc0, 0xf);
	GenericTilemapSetOffsets(TMAP_GLOBAL, 0, -16);
	GenericTilemapSetTransparent(1, 3);

	// Reset the driver
	DrvDoReset();

	return 0;
}

static INT32 Drvb3Init()
{
	INT32 nRet = 0, nLen;

	// Allocate and Blank all required memory
	Mem = NULL;
	MemIndex();
	nLen = MemEnd - (UINT8 *)0;
	if ((Mem = (UINT8 *)BurnMalloc(nLen)) == NULL) return 1;
	memset(Mem, 0, nLen);
	MemIndex();

	DrvTempRom = (UINT8 *)BurnMalloc(0x18000);

	// Load Z80 #1 Program Roms
	nRet = BurnLoadRom(DrvZ80Rom1 + 0x00000, 0, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvZ80Rom1 + 0x04000, 1, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvZ80Rom1 + 0x08000, 2, 1); if (nRet != 0) return 1;
	
	if (bFirstOpCodeEncrypted) {
		for (INT32 A = 0; A < 0xc000; A++) {
			INT32 src;

			src = DrvZ80Rom1[A];
			DrvZ80Rom1Op[A] = (src & 0x11) | ((src & 0xe0) >> 4) | ((src & 0x0e) << 4);
		}
	} else {
		DrvZ80Rom1Op[0] = DrvZ80Rom1[0];
		for (INT32 A = 1; A < 0xc000; A++) {
			INT32 src;

			src = DrvZ80Rom1[A];
			DrvZ80Rom1Op[A] = (src & 0x11) | ((src & 0xe0) >> 4) | ((src & 0x0e) << 4);
		}
	}
	
	// Load Z80 #2 Program Roms
	nRet = BurnLoadRom(DrvZ80Rom2 + 0x00000, 3, 1); if (nRet != 0) return 1;
	
	// Load and decode the chars
	nRet = BurnLoadRom(DrvTempRom, 4, 1); if (nRet != 0) return 1;
	GfxDecode(0x400, 2, 8, 8, CharPlaneOffsets, CharXOffsets, CharYOffsets, 0x80, DrvTempRom, DrvChars);
	
	// Load and decode the tiles
	memset(DrvTempRom, 0, 0x18000);
	nRet = BurnLoadRom(DrvTempRom + 0x00000,  5, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x04000,  6, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x08000,  7, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x0c000,  8, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x10000,  9, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x14000, 10, 1); if (nRet != 0) return 1;
	GfxDecode(0x400, 3, 16, 16, TilePlaneOffsets, TileXOffsets, TileYOffsets, 0x100, DrvTempRom, DrvTiles);
	
	// Load and decode the sprites
	memset(DrvTempRom, 0, 0x18000);
	nRet = BurnLoadRom(DrvTempRom + 0x00000, 11, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x04000, 12, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x08000, 13, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x0c000, 14, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x10000, 15, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x14000, 16, 1); if (nRet != 0) return 1;
	GfxDecode(0x300, 4, 16, 16, SpritePlaneOffsets, SpriteXOffsets, SpriteYOffsets, 0x200, DrvTempRom, DrvSprites);

	// Load the PROMs
	nRet = BurnLoadRom(DrvPromRed,           17, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvPromGreen,         18, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvPromBlue,          19, 1); if (nRet != 0) return 1;
	
	BurnFree(DrvTempRom);
	
	// Setup the Z80 emulation	
	ZetInit(0);
	ZetOpen(0);
	ZetMapMemory(DrvZ80Rom1,		0x0000, 0xbfff, MAP_ROM);
	ZetMapMemory(DrvZ80Rom1Op,		0x0000, 0xbfff, MAP_FETCHOP);
	ZetMapMemory(DrvFgVideoRam,		0xd000, 0xd3ff, MAP_RAM);
	ZetMapMemory(DrvFgColourRam,		0xd400, 0xd7ff, MAP_RAM);
	ZetMapMemory(DrvBgVideoRam,		0xd800, 0xdbff, MAP_RAM);
	ZetMapMemory(DrvBgColourRam,		0xdc00, 0xdfff, MAP_RAM);
	ZetMapMemory(DrvZ80Ram1,		0xe000, 0xfdff, MAP_RAM);
	ZetMapMemory(DrvSpriteRam,		0xfe00, 0xffff, MAP_RAM);
	ZetSetReadHandler(CommandoRead1);
	ZetSetWriteHandler(CommandoWrite1);
	ZetClose();
	
	ZetInit(1);
	ZetOpen(1);
	ZetMapMemory(DrvZ80Rom2,		0x0000, 0x3fff, MAP_ROM);
	ZetMapMemory(DrvZ80Ram2,		0x4000, 0x47ff, MAP_RAM);
	ZetSetReadHandler(CommandoRead2);
	ZetSetWriteHandler(CommandoWrite2);
	ZetClose();
	
	BurnYM2203Init(2, 1500000, NULL, 0);
	BurnTimerAttachZet(3000000);
	BurnYM2203SetAllRoutes(0, 0.15, BURN_SND_ROUTE_BOTH);
	BurnYM2203SetAllRoutes(1, 0.15, BURN_SND_ROUTE_BOTH);
	
	GenericTilesInit();
	GenericTilemapInit(0, TILEMAP_SCAN_COLS, bg_map_callback, 16, 16, 32, 32);
	GenericTilemapInit(1, TILEMAP_SCAN_ROWS, fg_map_callback,  8,  8, 32, 32);
	GenericTilemapSetGfx(0, DrvTiles, 3, 16, 16, 0x40000, 0x00, 0xf);
	GenericTilemapSetGfx(1, DrvChars, 2,  8,  8, 0x10000, 0xc0, 0xf);
	GenericTilemapSetOffsets(TMAP_GLOBAL, 0, -16);
	GenericTilemapSetTransparent(1, 3);

	// Reset the driver
	DrvDoReset();

	return 0;
}

static INT32 MercenarioInit()
{
	INT32 nRet = 0, nLen;

	// Allocate and Blank all required memory
	Mem = NULL;
	MemIndex();
	nLen = MemEnd - (UINT8 *)0;
	if ((Mem = (UINT8 *)BurnMalloc(nLen)) == NULL) return 1;
	memset(Mem, 0, nLen);
	MemIndex();

	DrvTempRom = (UINT8 *)BurnMalloc(0x18000);

	// Load Z80 #1 Program Roms
	nRet = BurnLoadRom(DrvZ80Rom1 + 0x00000, 0, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvZ80Rom1 + 0x04000, 1, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvZ80Rom1 + 0x08000, 2, 1); if (nRet != 0) return 1;
		
	for (INT32 A = 0; A < 0xc000; A++) 
	{
		INT32 src = DrvZ80Rom1[A];
		DrvZ80Rom1Op[A] = (src & 0x11) | ((src & 0xe0) >> 4) | ((src & 0x0e) << 4);
	}
			
	// Load Z80 #2 Program Roms
	nRet = BurnLoadRom(DrvZ80Rom2 + 0x00000, 3, 1); if (nRet != 0) return 1;
	
	// Load and decode the chars
	nRet = BurnLoadRom(DrvTempRom, 4, 1); if (nRet != 0) return 1;
	GfxDecode(0x400, 2, 8, 8, CharPlaneOffsets, CharXOffsets, CharYOffsets, 0x80, DrvTempRom, DrvChars);
	
	// Load and decode the tiles
	memset(DrvTempRom, 0, 0x18000);
	nRet = BurnLoadRom(DrvTempRom + 0x00000,  5, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x04000,  6, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x08000,  7, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x0c000,  8, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x10000,  9, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x14000, 10, 1); if (nRet != 0) return 1;
	GfxDecode(0x400, 3, 16, 16, TilePlaneOffsets, TileXOffsets, TileYOffsets, 0x100, DrvTempRom, DrvTiles);
	
	// Load and decode the sprites
	memset(DrvTempRom, 0, 0x18000);
	nRet = BurnLoadRom(DrvTempRom + 0x00000, 11, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x04000, 12, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x08000, 13, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x0c000, 14, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x10000, 15, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvTempRom + 0x14000, 16, 1); if (nRet != 0) return 1;
	GfxDecode(0x300, 4, 16, 16, SpritePlaneOffsets, SpriteXOffsets, SpriteYOffsets, 0x200, DrvTempRom, DrvSprites);

	// Load the PROMs
	nRet = BurnLoadRom(DrvPromRed,           17, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvPromGreen,         18, 1); if (nRet != 0) return 1;
	nRet = BurnLoadRom(DrvPromBlue,          19, 1); if (nRet != 0) return 1;
	
	BurnFree(DrvTempRom);
	
	// Setup the Z80 emulation	
	ZetInit(0);
	ZetOpen(0);
	ZetMapMemory(DrvZ80Rom1,		0x0000, 0xbfff, MAP_ROM);
	ZetMapMemory(DrvZ80Rom1Op,		0x0000, 0xbfff, MAP_FETCHOP);
	ZetMapMemory(DrvFgVideoRam,		0xd000, 0xd3ff, MAP_RAM);
	ZetMapMemory(DrvFgColourRam,		0xd400, 0xd7ff, MAP_RAM);
	ZetMapMemory(DrvBgVideoRam,		0xd800, 0xdbff, MAP_RAM);
	ZetMapMemory(DrvBgColourRam,		0xdc00, 0xdfff, MAP_RAM);
	ZetMapMemory(DrvZ80Ram1,		0xe000, 0xfdff, MAP_RAM);
	ZetMapMemory(DrvSpriteRam,		0xfe00, 0xffff, MAP_RAM);
	ZetSetReadHandler(CommandoRead1);
	ZetSetWriteHandler(CommandoWrite1);
	ZetClose();
	
	ZetInit(1);
	ZetOpen(1);
	ZetMapMemory(DrvZ80Rom2,		0x0000, 0x3fff, MAP_ROM);
	ZetMapMemory(DrvZ80Ram2,		0x4000, 0x47ff, MAP_RAM);
	ZetSetReadHandler(CommandoRead2);
	ZetSetWriteHandler(CommandoWrite2);
	ZetClose();
	
	BurnYM2203Init(2, 1500000, NULL, 0);
	BurnTimerAttachZet(3000000);
	BurnYM2203SetAllRoutes(0, 0.15, BURN_SND_ROUTE_BOTH);
	BurnYM2203SetAllRoutes(1, 0.15, BURN_SND_ROUTE_BOTH);
	
	GenericTilesInit();
	GenericTilemapInit(0, TILEMAP_SCAN_COLS, bg_map_callback, 16, 16, 32, 32);
	GenericTilemapInit(1, TILEMAP_SCAN_ROWS, fg_map_callback,  8,  8, 32, 32);
	GenericTilemapSetGfx(0, DrvTiles, 3, 16, 16, 0x40000, 0x00, 0xf);
	GenericTilemapSetGfx(1, DrvChars, 2,  8,  8, 0x10000, 0xc0, 0xf);
	GenericTilemapSetOffsets(TMAP_GLOBAL, 0, -16);
	GenericTilemapSetTransparent(1, 3);

	// Reset the driver
	DrvDoReset();

	return 0;
}

static INT32 BootlegInit()
{
	bFirstOpCodeEncrypted = true;
	
	return DrvInit();
}

static INT32 DrvExit()
{
	ZetExit();
	BurnYM2203Exit();
	
	GenericTilesExit();
	
	BurnFree(Mem);
	
	DrvBgScrollX[0] = DrvBgScrollX[1] = 0;
	DrvBgScrollY[0] = DrvBgScrollY[1] = 0;
	DrvFlipScreen = 0;
	DrvSoundLatch = 0;
	
	bFirstOpCodeEncrypted = false;

	return 0;
}

static void DrvCalcPalette()
{
	for (INT32 i = 0; i < 256; i++) {
		INT32 bit0, bit1, bit2, bit3, r, g, b;
		
		bit0 = (DrvPromRed[i] >> 0) & 0x01;
		bit1 = (DrvPromRed[i] >> 1) & 0x01;
		bit2 = (DrvPromRed[i] >> 2) & 0x01;
		bit3 = (DrvPromRed[i] >> 3) & 0x01;
		r = 0x0e * bit0 + 0x1f * bit1 + 0x43 * bit2 + 0x8f * bit3;
		
		bit0 = (DrvPromGreen[i] >> 0) & 0x01;
		bit1 = (DrvPromGreen[i] >> 1) & 0x01;
		bit2 = (DrvPromGreen[i] >> 2) & 0x01;
		bit3 = (DrvPromGreen[i] >> 3) & 0x01;
		g = 0x0e * bit0 + 0x1f * bit1 + 0x43 * bit2 + 0x8f * bit3;
		
		bit0 = (DrvPromBlue[i] >> 0) & 0x01;
		bit1 = (DrvPromBlue[i] >> 1) & 0x01;
		bit2 = (DrvPromBlue[i] >> 2) & 0x01;
		bit3 = (DrvPromBlue[i] >> 3) & 0x01;
		b = 0x0e * bit0 + 0x1f * bit1 + 0x43 * bit2 + 0x8f * bit3;
		
		DrvPalette[i] = BurnHighCol(r, g, b, 0);
	}
}

static void DrvRenderSprites()
{
	for (INT32 Offset = 0x180 - 4; Offset >= 0; Offset -= 4) {
		INT32 Attr = DrvSpriteRamBuffer[Offset + 1];
		INT32 Bank = (Attr & 0xc0) >> 6;
		INT32 Code = DrvSpriteRamBuffer[Offset + 0] + (Bank << 8);
		INT32 Colour = (Attr & 0x30) >> 4;
		INT32 xFlip = Attr & 0x04;
		INT32 yFlip = Attr & 0x08;
		INT32 x = DrvSpriteRamBuffer[Offset + 3] - ((Attr & 0x01) << 8);
		INT32 y = DrvSpriteRamBuffer[Offset + 2];
		
		y -= 16;
		
		if (DrvFlipScreen) {
			x = 240 - x;
			y = 208 - y;
			xFlip = !xFlip;
			yFlip = !yFlip;
		}
				
		if (Bank < 3) {
			if (x > 0 && x < 240 && y > 0 && y < 208) {
				if (xFlip) {
					if (yFlip) {
						Render16x16Tile_Mask_FlipXY(pTransDraw, Code, x, y, Colour, 4, 0x0f, 128, DrvSprites);
					} else {
						Render16x16Tile_Mask_FlipX(pTransDraw, Code, x, y, Colour, 4, 0x0f, 128, DrvSprites);
					}
				} else {
					if (yFlip) {
						Render16x16Tile_Mask_FlipY(pTransDraw, Code, x, y, Colour, 4, 0x0f, 128, DrvSprites);
					} else {
						Render16x16Tile_Mask(pTransDraw, Code, x, y, Colour, 4, 0x0f, 128, DrvSprites);
					}
				}
			} else {
				if (xFlip) {
					if (yFlip) {
						Render16x16Tile_Mask_FlipXY_Clip(pTransDraw, Code, x, y, Colour, 4, 0x0f, 128, DrvSprites);
					} else {
						Render16x16Tile_Mask_FlipX_Clip(pTransDraw, Code, x, y, Colour, 4, 0x0f, 128, DrvSprites);
					}
				} else {
					if (yFlip) {
						Render16x16Tile_Mask_FlipY_Clip(pTransDraw, Code, x, y, Colour, 4, 0x0f, 128, DrvSprites);
					} else {
						Render16x16Tile_Mask_Clip(pTransDraw, Code, x, y, Colour, 4, 0x0f, 128, DrvSprites);
					}
				}
			}
		}
	}
}

static INT32 DrvDraw()
{
	if (DrvRecalc) {
		DrvCalcPalette();
	}

	GenericTilemapSetScrollX(0, DrvBgScrollX[0] + (DrvBgScrollX[1] * 256));
	GenericTilemapSetScrollY(0, DrvBgScrollY[0] + (DrvBgScrollY[1] * 256));

	if (~nBurnLayer & 1) BurnTransferClear();

	if ( nBurnLayer & 1) GenericTilemapDraw(0, pTransDraw, 0);

	if ( nSpriteEnable & 1) DrvRenderSprites();

	if ( nBurnLayer & 2) GenericTilemapDraw(1, pTransDraw, 0);
	
	BurnTransferCopy(DrvPalette);

	return 0;
}

static INT32 DrvFrame()
{
	INT32 nInterleave = 256;

	if (DrvReset) DrvDoReset();

	DrvMakeInputs();

	INT32 nCyclesDone[2] = { 0, 0 };
	INT32 nCyclesTotal[2] = { 4000000 / 60, 3000000 / 60 };
	INT32 nCyclesSegment;

	ZetNewFrame();

	for (INT32 i = 0; i < nInterleave; i++) {
		INT32 nCurrentCPU, nNext;

		// Run Z80 #1
		nCurrentCPU = 0;
		ZetOpen(nCurrentCPU);
		nNext = (i + 1) * nCyclesTotal[nCurrentCPU] / nInterleave;
		nCyclesSegment = nNext - nCyclesDone[nCurrentCPU];
		nCyclesDone[nCurrentCPU] += ZetRun(nCyclesSegment);
		if (i == 240) {
			memcpy(DrvSpriteRamBuffer, DrvSpriteRam, 0x180); // copy on rising edge of vblank
			ZetSetVector(0xd7);
			ZetSetIRQLine(0, CPU_IRQSTATUS_HOLD);
		}
		ZetClose();

		// Run Z80 #2
		nCurrentCPU = 1;
		ZetOpen(nCurrentCPU);
		BurnTimerUpdate((i + 1) * (nCyclesTotal[nCurrentCPU] / nInterleave));
		// execute IRQ quarterly
		if (i%(nInterleave/4) == (nInterleave/4)-1) ZetSetIRQLine(0, CPU_IRQSTATUS_HOLD);
		ZetClose();
	}

	ZetOpen(1);
	BurnTimerEndFrame(nCyclesTotal[1]);
	if (pBurnSoundOut) {
		BurnYM2203Update(pBurnSoundOut, nBurnSoundLen);
	}
	ZetClose();

	if (pBurnDraw) DrvDraw();
	

	return 0;
}

static INT32 DrvScan(INT32 nAction, INT32 *pnMin)
{
	struct BurnArea ba;
	
	if (pnMin != NULL) {			// Return minimum compatible version
		*pnMin = 0x029693;
	}

	if (nAction & ACB_MEMORY_RAM) {
		memset(&ba, 0, sizeof(ba));
		ba.Data	  = RamStart;
		ba.nLen	  = RamEnd-RamStart;
		ba.szName = "All Ram";
		BurnAcb(&ba);
	}

	if (nAction & ACB_DRIVER_DATA) {
		ZetScan(nAction);			// Scan Z80
		BurnYM2203Scan(nAction, pnMin);

		// Scan critical driver variables
		SCAN_VAR(DrvSoundLatch);
		SCAN_VAR(DrvBgScrollX);
		SCAN_VAR(DrvBgScrollY);
		SCAN_VAR(DrvFlipScreen);
	}

	return 0;
}

struct BurnDriver BurnDrvCommando = {
	"commando", NULL, NULL, NULL, "1985",
	"Commando (World)\0", NULL, "Capcom", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_ORIENTATION_VERTICAL | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, DrvRomInfo, DrvRomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};

struct BurnDriver BurnDrvCommandu = {
	"commandou", "commando", NULL, NULL, "1985",
	"Commando (US, set 1)\0", NULL, "Capcom (Data East USA license)", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, DrvuRomInfo, DrvuRomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};

struct BurnDriver BurnDrvCommandu2 = {
	"commandou2", "commando", NULL, NULL, "1985",
	"Commando (US, set 2)\0", NULL, "Capcom (Data East USA license)", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, Drvu2RomInfo, Drvu2RomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};

struct BurnDriver BurnDrvCommandj = {
	"commandoj", "commando", NULL, NULL, "1985",
	"Senjou no Ookami\0", NULL, "Capcom", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, DrvjRomInfo, DrvjRomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};

struct BurnDriver BurnDrvCommandb = {
	"commandob", "commando", NULL, NULL, "1985",
	"Commando (bootleg set 1)\0", NULL, "bootleg", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL | BDF_BOOTLEG | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, DrvbRomInfo, DrvbRomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	BootlegInit, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};

struct BurnDriver BurnDrvCommandb2 = {
	"commandob2", "commando", NULL, NULL, "1985",
	"Commando (bootleg set 2)\0", NULL, "bootleg", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL | BDF_BOOTLEG | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, Drvb2RomInfo, Drvb2RomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};

struct BurnDriver BurnDrvCommandb3 = {
	"commandob3", "commando", NULL, NULL, "1985",
	"Commando (bootleg set 3)\0", NULL, "bootleg", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL | BDF_BOOTLEG | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, Drvb3RomInfo, Drvb3RomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	Drvb3Init, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};

struct BurnDriver BurnDrvSinvasn = {
	"sinvasn", "commando", NULL, NULL, "1985",
	"Space Invasion (Europe)\0", NULL, "Capcom", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, SinvasnRomInfo, SinvasnRomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	DrvInit, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};

struct BurnDriver BurnDrvSinvasnb = {
	"sinvasnb", "commando", NULL, NULL, "1985",
	"Space Invasion (bootleg)\0", NULL, "bootleg", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL | BDF_BOOTLEG | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, SinvasnbRomInfo, SinvasnbRomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	BootlegInit, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};

struct BurnDriver BurnDrvMercenario = {
	"mercenario", "commando", NULL, NULL, "1985",
	"Mercenario (Commando bootleg)\0", NULL, "bootleg", "Miscellaneous",
	NULL, NULL, NULL, NULL,
	BDF_GAME_WORKING | BDF_CLONE | BDF_ORIENTATION_VERTICAL | BDF_BOOTLEG | BDF_HISCORE_SUPPORTED, 2, HARWARE_CAPCOM_MISC, GBF_RUNGUN, 0,
	NULL, MercenarioRomInfo, MercenarioRomName, NULL, NULL, NULL, NULL, DrvInputInfo, DrvDIPInfo,
	MercenarioInit, DrvExit, DrvFrame, DrvDraw, DrvScan,
	&DrvRecalc, 0x100, 224, 256, 3, 4
};
