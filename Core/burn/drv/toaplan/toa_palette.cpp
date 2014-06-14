#include "toaplan.h"
// Toaplan -- palette functions

UINT8* ToaPalSrc;			// Pointer to input palette
UINT8* ToaPalSrc2;
UINT32* ToaPalette;
UINT32* ToaPalette2;
INT32 nToaPalLen;

UINT8 ToaRecalcPalette;		// Set to 1 to force recalculation of the entire palette (not needed now)

INT32 ToaPalInit()
{
	return 0;
}

INT32 ToaPalExit()
{
	return 0;
}

inline static UINT32 CalcCol(UINT16 nColour)
{
	INT32 r = ((nColour & 0x001F) << 3) | r >> 5;	// Red
	INT32 g = ((nColour & 0x03E0) >> 2) | g >> 5;  	// Green
	INT32 b = ((nColour & 0x7C00) >> 7) | b >> 5;	// Blue

	return BurnHighCol(r, g, b, 0);
}

INT32 ToaPalUpdate()
{
	UINT16* ps = (UINT16*)ToaPalSrc;
	UINT32* pd = ToaPalette;
	
	pBurnDrvPalette = ToaPalette;

	for (INT32 i = 0; i < nToaPalLen; i++) {
      UINT16 nColour = BURN_ENDIAN_SWAP_INT16(ps[i]);
		pd[i] = CalcCol(nColour);
	}
	return 0;
}

INT32 ToaPal2Update()
{
	UINT16* ps = (UINT16*)ToaPalSrc2;
	UINT32* pd = ToaPalette2;
	
//	pBurnDrvPalette = ToaPalette2;

	for (INT32 i = 0; i < nToaPalLen; i++) {
      UINT16 nColour = BURN_ENDIAN_SWAP_INT16(ps[i]);
		pd[i] = CalcCol(nColour);
	}
	return 0;
}
