#include "burner.h"

int bDrvSaveAll=0;
int nAppVirtualFps = 6000; // App fps * 100
bool bDoIpsPatch;
bool bRunPause=0;
int bDrvOkay = 0;
bool bAlwaysProcessKeyboardInput = 0;
TCHAR szAppHiscorePath[MAX_PATH];
TCHAR szAppSamplesPath[MAX_PATH];

bool AppProcessKeyboardInput()
{
	return true;
}

void IpsApplyPatches(UINT8 *, char *)
{
}

TCHAR* GetIsoPath()
{
    return NULL;
}

void Reinitialise(void)
{
}

void wav_pause(bool bResume)
{
}


struct AudOut AudOutCocoa = {
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	"Stub",
};

struct VidOut VidOutCocoa = {
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	"Stub",
};

struct InputInOut InputInOutCocoa = {
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	NULL,
	"Stub",
};

static void InpDIPSWGetOffset()
{
}

void InpDIPSWResetDIPs()
{
}

void NeoCDInfo_Exit()
{
}
