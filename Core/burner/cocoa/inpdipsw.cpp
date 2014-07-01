// Burner DipSwitches Dialog module
#include "burner.h"

static int nDIPOffset;
static bool bOK;

static void InpDIPSWGetOffset()
{
	BurnDIPInfo bdi;

	nDIPOffset = 0;
	for (int i = 0; BurnDrvGetDIPInfo(&bdi, i) == 0; i++) {
		if (bdi.nFlags == 0xF0) {
			nDIPOffset = bdi.nInput;
			break;
		}
	}
}

void InpDIPSWResetDIPs()
{
	int i = 0;
	BurnDIPInfo bdi;
	struct GameInp* pgi;

	InpDIPSWGetOffset();

	while (BurnDrvGetDIPInfo(&bdi, i) == 0) {
		if (bdi.nFlags == 0xFF) {
			pgi = GameInp + bdi.nInput + nDIPOffset;
			pgi->Input.Constant.nConst = (pgi->Input.Constant.nConst & ~bdi.nMask) | (bdi.nSetting & bdi.nMask);
		}
		i++;
	}
}

int InpDIPSWCreate()
{
	if (bDrvOkay == 0) {									// No game is loaded
		return 1;
	}

	bOK = false;

	return 0;
}
