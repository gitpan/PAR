/* $File: //member/autrijus/PAR/myldr/static.c $ $Author: autrijus $
   $Revision: #6 $ $Change: 7184 $ $DateTime: 2003/07/28 08:21:28 $
   vim: expandtab shiftwidth=4
*/

#define PAR_MKTMPDIR

#ifdef WIN32
#include <io.h>
#include <process.h>
#include <direct.h>
#include <errno.h>

#undef mkdir
#define mkdir(x, y) _mkdir(x)
#define W_OK 2
#define S_ISDIR(x) 1
#define S_ISLNK(x) 0

#else
#include <unistd.h>
#include <sys/errno.h>
#include <dirent.h>
typedef struct dirent Direntry_t;
#endif

typedef int Pid_t;

#include <fcntl.h>
#include <stdio.h>
#include <sys/stat.h>
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

char * my_mkfile (char* argv0, char* stmpdir, const char* name, unsigned long size, const char* data) {
    int i;
    char *my_file;

    my_file = (char *)malloc(strlen(stmpdir) + strlen(name) + 1);
#ifdef WIN32
    sprintf(my_file, "%s\\%s", stmpdir, name);
    i = open(my_file, O_CREAT | O_WRONLY | O_BINARY);
#else
    sprintf(my_file, "%s/%s", stmpdir, name);
    i = open(my_file, O_CREAT | O_WRONLY);
#endif
    if (i == -1) {
        fprintf(stderr, "%s: creation of %s failed - aborting with %i.\n", argv0, my_file, errno);
        return NULL;
    }
    write(i, data, (size_t)size);
    close(i);

    chmod(my_file, 0755);
    return my_file;
}

int main ( int argc, char **argv, char **env )
{
    int i;
    char *stmpdir;
    char *my_par;

    par_mktmpdir( argv );
    stmpdir = (char *)getenv("PAR_TEMP");
    if ( stmpdir != NULL ) {
        i = mkdir(stmpdir, 0755);
        if ( (i != 0) && (i != EEXIST) && (i != -1) ) {
            fprintf(stderr, "%s: creation of private temporary subdirectory %s failed - aborting with %i.\n", argv[0], stmpdir, errno);
            return 2;
        }
    }

    i = 2;
    my_mkfile( argv[0], stmpdir, name_load_me_0, size_load_me_0, load_me_0 ) &&
    (my_par = (char *)my_mkfile( argv[0], stmpdir, name_load_me_1, size_load_me_1, load_me_1 )) &&
#ifdef WIN32
    (i = spawnvp(P_WAIT, my_par, argv));
#else
    execvp(my_par, argv);
    return 2;
#endif

    par_rmtmpdir(stmpdir);
    return i;
}

