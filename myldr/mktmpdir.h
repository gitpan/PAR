/* $File: /depot/local/PAR/trunk/myldr/mktmpdir.h $ $Author: autrijus $
   $Revision: #3 $ $Change: 11731 $ $DateTime: 2004-08-30T22:40:26.326020Z $
   vim: expandtab shiftwidth=4
*/

#include <stdlib.h>
#include <string.h>
#include <errno.h>
#ifdef WIN32
#include <windows.h>
#endif

#ifndef X_OK
#define X_OK 0x04
#endif

#ifndef S_ISREG
#define S_ISREG(x) 1
#endif

#ifndef MAXPATHLEN
#define MAXPATHLEN 32767
#endif

#ifdef HAS_LSTAT
#define par_lstat lstat
#else
#define par_lstat stat
#endif

#if defined(WIN32) || defined(OS2)
static const char *dir_sep = "\\";
static const char *path_sep = ";";
#else
static const char *dir_sep = "/";
static const char *path_sep = ":";
#endif

#ifndef PL_statbuf
static struct stat PL_statbuf;
#endif

#include "utils.c"
#include "sha1.c"
