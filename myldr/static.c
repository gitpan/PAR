/* $File: //member/autrijus/PAR/myldr/static.c $ $Author: autrijus $
   $Revision: #1 $ $Change: 7151 $ $DateTime: 2003/07/27 08:31:51 $
   vim: expandtab shiftwidth=4
*/

#define PAR_MKTMPDIR

#include <fcntl.h>
#include <unistd.h>
#include <stdio.h>
#include <sys/stat.h>
#include <sys/errno.h>
#include "mktmpdir.c"

extern char * name_load_me_0;
extern char * name_load_me_1;
extern unsigned long size_load_me_0;
extern unsigned long size_load_me_1;
extern char load_me_0[];
extern char load_me_1[];

char * my_mkfile (char* argv0, char* stmpdir, char* name, unsigned long size, char* data) {
    int i;
    char *my_file;

    my_file = (char *)malloc(strlen(stmpdir) + strlen(name) + 1);
    sprintf(my_file, "%s/%s", stmpdir, name);
    i = open(my_file, O_CREAT | O_WRONLY);
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

    my_mkfile( argv[0], stmpdir, name_load_me_0, size_load_me_0, load_me_0 ) &&
    (my_par = (char *)my_mkfile( argv[0], stmpdir, name_load_me_1, size_load_me_1, load_me_1 )) &&
    execv(my_par, argv);

    return 2;
}

