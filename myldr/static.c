/* $File: //member/autrijus/PAR/myldr/static.c $ $Author: autrijus $
   $Revision: #16 $ $Change: 9465 $ $DateTime: 2003/12/28 05:01:09 $
   vim: expandtab shiftwidth=4
*/

#ifdef WIN32
#   include <io.h>
#   include <process.h>
#   include <direct.h>
#   include <errno.h>
#   include <string.h>
#   undef mkdir
#   define mkdir(x, y) _mkdir(x)
#   define W_OK 2
#   define S_ISDIR(x) 1
#   define ISSLASH(C) ((C) == '\\')
#else
#   include <unistd.h>
#   include <sys/errno.h>
#   include <dirent.h>
    typedef struct dirent Direntry_t;
#   define ISSLASH(C) ((C) == '/')
#endif

typedef int Pid_t;

#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>

#ifndef S_ISLNK
#  define S_ISLNK(x) 0
#endif

#ifdef O_BINARY
#  define OPEN_O_BINARY O_BINARY
#else
#  define OPEN_O_BINARY 0
#endif

#include "mktmpdir.c"
#include "my_perl.c"
#include "my_par.c"

/*
extern char * name_load_me_0;
extern char * name_load_me_1;
extern unsigned long size_load_me_0;
extern unsigned long size_load_me_1;
extern char load_me_0[];
extern char load_me_1[];
*/

static char *my_file;

int my_mkfile (char* argv0, char* stmpdir, const char* name) {
    int i;

    my_file = (char *)malloc(strlen(stmpdir) + strlen(name) + 1);
    sprintf(my_file, "%s/%s", stmpdir, name);
    i = open(my_file, O_CREAT | O_WRONLY | OPEN_O_BINARY);
    if (i == -1) {
        fprintf(stderr, "%s: creation of %s failed - aborting with %i.\n", argv0, my_file, errno);
        return 0;
    }

    return i;
}

char *_basename (const char *name) {
    const char *base = name;
    const char *p;

    for (p = name; *p; p++) {
        if (ISSLASH (*p)) base = p + 1;
    }

    return (char *)base;
}

int main ( int argc, char **argv, char **env )
{
    int i;
    char *stmpdir;
    char *buf;

    par_mktmpdir( argv );
    stmpdir = (char *)getenv("PAR_TEMP");
    if ( stmpdir != NULL ) {
        i = mkdir(stmpdir, 0755);
        if ( (i != 0) && (i != EEXIST) && (i != -1) ) {
            fprintf(stderr, "%s: creation of private temporary subdirectory %s failed - aborting with %i.\n", argv[0], stmpdir, errno);
            return 2;
        }
    }

    i = my_mkfile( argv[0], stmpdir, name_load_me_0 );
    if (!i) return 2;
    WRITE_load_me_0(i);
    close(i); chmod(my_file, 0755);

	my_file = _basename(argv[0]);
#ifdef WIN32
	i = strlen(my_file);
	if (
		(strlen(my_file) < 4) ||
		(strcmpi((char *)(my_file + strlen(my_file) - 4), ".exe") != 0)
	) {
		strcat(my_file, ".exe");
	}
#endif
    i = my_mkfile( argv[0], stmpdir, my_file);
    if (!i) return 2;
    WRITE_load_me_1(i);
    close(i); chmod(my_file, 0755);

    buf = (char *)malloc(127);
    sprintf(buf, "PAR_ARGC=%i", argc);
    putenv(buf);
    for (i = 0; i < argc; i++) {
        buf = (char *)malloc(strlen(argv[i]) + 14);
        sprintf(buf, "PAR_ARGV_%i=%s", i, argv[i]);
        putenv(buf);
    }

#ifdef WIN32
	sprintf(buf, "PAR_SPAWNED=1", argc);
    putenv(buf);
    i = spawnvp(P_WAIT, my_file, argv);
#else
    execvp(my_file, argv);
    return 2;
#endif

    par_rmtmpdir(stmpdir);
    return i;
}
