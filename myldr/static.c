/* $File: //member/autrijus/PAR/myldr/static.c $ $Author: autrijus $
   $Revision: #31 $ $Change: 10299 $ $DateTime: 2004/03/03 01:01:23 $
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
#else
#   include <unistd.h>
#   include <sys/errno.h>
#   include <dirent.h>
    typedef struct dirent Direntry_t;
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

char *my_file;

int my_mkfile (char* argv0, char* stmpdir, const char* name) {
    int i;
#ifndef PL_statbuf
    struct stat PL_statbuf;
#endif

    my_file = (char *)malloc(strlen(stmpdir) + strlen(name) + 5);
    sprintf(my_file, "%s/%s", stmpdir, name);

    i = open(my_file, O_CREAT | O_WRONLY | OPEN_O_BINARY);

    if (i == -1) {
        if ( par_lstat(my_file, &PL_statbuf) == 0 ) return -2;
        fprintf(stderr, "%s: creation of %s failed - aborting with %i.\n", argv0, my_file, errno);
        return 0;
    }

    return i;
}

int main ( int argc, char **argv, char **env )
{
    int i;
    char *stmpdir;
    char *buf = (char *)malloc(127);

    par_init_env();
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
    if ( !i ) return 2;
    if ( i != -2 ) {
        WRITE_load_me_0(i);
        close(i); chmod(my_file, 0755);
    }

    my_file = par_basename(par_findprog(argv[0], getenv("PATH")));

    i = my_mkfile( argv[0], stmpdir, my_file );
    if ( !i ) return 2;
    if ( i != -2 ) {
        WRITE_load_me_1(i);
        close(i); chmod(my_file, 0755);
    }

    sprintf(buf, "%i", argc);
    par_setenv("PAR_ARGC", buf);
    for (i = 0; i < argc; i++) {
        buf = (char *)malloc(strlen(argv[i]) + 14);
        sprintf(buf, "PAR_ARGV_%i", i);
        par_setenv(buf, argv[i]);
    }

#ifdef WIN32
    par_setenv("PAR_SPAWNED", "1");
    i = spawnvpe(P_WAIT, my_file, argv, environ);
#else
    execvp(my_file, argv);
    return 2;
#endif

    par_cleanup(stmpdir);
    return i;
}
