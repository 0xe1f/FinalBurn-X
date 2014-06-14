#include "burner.h"

TCHAR szAppHiscorePath[MAX_PATH];
TCHAR szAppSamplesPath[MAX_PATH];

CDEmuStatusValue CDEmuStatus;

bool bDoIpsPatch;

void IpsApplyPatches(UINT8 *, char *)
{
}

char *LabelCheck(char *, char *)
{
    return 0;
}

int QuoteRead(char **, char **, char*)
{
    return 1;
}

TCHAR* GetIsoPath()
{
    return NULL;
}

INT32 CDEmuInit()
{
    return 0;
}

INT32 CDEmuExit()
{
    return 0;
}

INT32 CDEmuStop()
{
    return 0;
}

INT32 CDEmuPlay(UINT8 M, UINT8 S, UINT8 F)
{
    return 0;
}

INT32 CDEmuLoadSector(INT32 LBA, char* pBuffer)
{
    return 0;
}

UINT8* CDEmuReadTOC(INT32 track)
{
    return 0;
}

UINT8* CDEmuReadQChannel()
{
    return 0;
}

INT32 CDEmuGetSoundBuffer(INT16* buffer, INT32 samples)
{
    return 0;
}

void Reinitialise(void)
{
}

void wav_pause(bool bResume)
{
}
