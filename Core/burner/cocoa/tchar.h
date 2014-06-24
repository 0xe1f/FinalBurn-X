/*****************************************************************************
 **
 ** FinalBurn X: Port of FinalBurn to OS X
 ** https://github.com/pokebyte/FinalBurnX
 ** Copyright (C) 2014 Akop Karapetyan
 **
 ** This program is free software; you can redistribute it and/or modify
 ** it under the terms of the GNU General Public License as published by
 ** the Free Software Foundation; either version 2 of the License, or
 ** (at your option) any later version.
 **
 ** This program is distributed in the hope that it will be useful,
 ** but WITHOUT ANY WARRANTY; without even the implied warranty of
 ** MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 ** GNU General Public License for more details.
 **
 ** You should have received a copy of the GNU General Public License
 ** along with this program; if not, write to the Free Software
 ** Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.
 **
 ******************************************************************************
 */
#ifdef _UNICODE

#include <wchar.h>
#define	__TEXT(q)	L##q

typedef	wchar_t	TCHAR;
typedef wchar_t _TCHAR;

#else


#define	__TEXT(q)	q

#ifndef RC_INVOKED
typedef char	TCHAR;
typedef char	_TCHAR;
#endif

#define wcslen(void)

#define _tcslen     strlen
#define _tcscpy     strcpy
#define _tcsncpy    strncpy

#define _tprintf    printf
#define _vstprintf  vsprintf
#define _vsntprintf vsnprintf
#define _stprintf   sprintf
#define _sntprintf  snprintf
#define _ftprintf   fprintf
#define _tsprintf   sprintf

#define _tcscmp     strcmp
#define _tcsncmp    strncmp
#define _tcsicmp    strcasecmp
#define _tcsnicmp   strncasecmp
#define _tcstol     strtol

#define _tcsstr     strstr

#define _fgetts     fgets
#define _fputts     fputs

#define	_istspace	isspace

#define _tfopen     fopen

#define _stricmp strcmp
#define _strnicmp strncmp

#define dprintf(...) fprintf (stderr, __VA_ARGS__)

#endif

#define _TEXT(x)	__TEXT(x)
#define	_T(x)		__TEXT(x)

