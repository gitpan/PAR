/* $File: //member/autrijus/PAR/myldr/mktmpdir.c $ $Author: autrijus $
   $Revision: #34 $ $Change: 10300 $ $DateTime: 2004/03/03 04:07:09 $
   vim: expandtab shiftwidth=4
*/

#include "mktmpdir.h"

#define PAR_TEMP "PAR_TEMP"

#ifdef O_BINARY
#  define OPEN_O_BINARY O_BINARY
#else
#  define OPEN_O_BINARY 0
#endif

char *par_mktmpdir ( char **argv ) {
    int i;
    const char *tmpdir = NULL;
    const char *key = NULL , *val = NULL;

    const char *temp_dirs[4] = { "C:\\TEMP", "/tmp", ".", "" };
    const char *temp_keys[4] = { "TMPDIR", "TEMP", "TMP", "" };
    const char *user_keys[3] = { "USER", "USERNAME", "" };
    const char *ld_path_keys[6] = {
        "LD_LIBRARY_PATH", "LIBPATH", "LIBRARY_PATH",
        "PATH", "DYLD_LIBRARY_PATH", ""
    };

    const char *subdirbuf_prefix = "par-";
    const char *subdirbuf_suffix = "";

    char *progname = NULL, *username = NULL;
    char *ld_path_env, *par_temp_env;
    char *stmpdir;
    int f, j, k;
    char sha1[41];
    SHA_INFO sha_info;
    unsigned char buf[1000];
    unsigned char sha_data[20];

    if ( (val = (char *)getenv("PAR_TEMP")) && strlen(val) ) {
        return strdup(val);
    }

#ifdef WIN32
    {
        DWORD buflen = MAXPATHLEN;
        username = (char *)malloc(MAXPATHLEN);
        GetUserName((LPTSTR)username, &buflen);
    }
#else
    for ( i = 0 ; username == NULL && strlen(key = user_keys[i]) > 0 ; i++ ) {
        if ( (val = (char *)getenv(key)) ) {
            username = strdup(val);
        }
    }
#endif
    if ( username == NULL ) username = "SYSTEM";

    for ( i = 0 ; tmpdir == NULL && strlen(key = temp_keys[i]) > 0 ; i++ ) {
        if ( (val = (char *)getenv(key)) &&
             par_lstat(val, &PL_statbuf) == 0 &&
             ( S_ISDIR(PL_statbuf.st_mode) ||
               S_ISLNK(PL_statbuf.st_mode) ) &&
             access(val, W_OK) == 0 ) {
            tmpdir = strdup(val);
        }
    }

    for ( i = 0 ; tmpdir == NULL && strlen(val = temp_dirs[i]) > 0 ; i++ ) {
        if ( par_lstat(val, &PL_statbuf) == 0 &&
             ( S_ISDIR(PL_statbuf.st_mode) ||
               S_ISLNK(PL_statbuf.st_mode) ) &&
             access(val, W_OK) == 0 ) {
            tmpdir = strdup(val);
        }
    }

    /* "$TEMP/par-$USER" */
    stmpdir = malloc(
        strlen(tmpdir) +
        strlen(subdirbuf_prefix) +
        strlen(username) +
        strlen(subdirbuf_suffix) + 1024
    );
    sprintf(stmpdir, "%s%s%s%s", tmpdir, dir_sep, subdirbuf_prefix, username);
    mkdir(stmpdir, 0755);

    progname = par_findprog(argv[0], getenv("TEMP"));

    if ( !par_env_clean() && (f = open( progname, O_RDONLY | OPEN_O_BINARY ))) {
        /* "$TEMP/par-$USER/cache-$SHA1" */
        sha_init( &sha_info );
        while( ( j = read( f, buf, sizeof( buf ) ) ) > 0 )
        {
            sha_update( &sha_info, buf, j );
        }
        close( f );
        sha_final( sha_data, &sha_info );
        for( k = 0; k < 20; k++ )
        {
            sprintf( sha1+k*2, "%02x", sha_data[k] );
        }
        sprintf(
            stmpdir,
            "%s%scache-%s%s",
            stmpdir, dir_sep, sha1, subdirbuf_suffix
        );
    }
    else {
        /* "$TEMP/par-$USER/temp-$PID" */

        par_setenv("PAR_CLEAN", "1");
        sprintf(
            stmpdir,
            "%s%stemp-%u%s",
            stmpdir, dir_sep, getpid(), subdirbuf_suffix
        );
    }

    /* set dynamic loading path */
    par_temp_env = (char *)malloc(strlen(PAR_TEMP) + strlen(stmpdir) + 2);
    par_setenv(PAR_TEMP, stmpdir);

    for ( i = 0 ; strlen(key = ld_path_keys[i]) > 0 ; i++ ) {
        if ( (val = (char *)getenv(key)) == NULL ) continue;

        if ( strlen(val) == 0 ) {
            par_setenv(key, stmpdir);
        }
        else {
            ld_path_env = (char *)malloc(
                strlen(stmpdir) +
                strlen(path_sep) +
                strlen(val) + 2
            );
            sprintf(
                ld_path_env,
                "%s%s%s",
                stmpdir, path_sep, val
            );
            par_setenv(key, ld_path_env);
        }
    }

    return(stmpdir);
}


#ifdef WIN32
void par_rmtmpdir ( char *stmpdir, int recurse ) {
    struct _finddata_t cur_file;
    char *subsubdir = malloc(strlen(stmpdir) + 258);
    char *slashdot;
    long hFile;
	int tries = 0;
    HMODULE dll;

    if ((stmpdir == NULL) || !strlen(stmpdir)) return;

    sprintf(subsubdir, "%s\\*.*", stmpdir);
    hFile = _findfirst( subsubdir, &cur_file );
    if ( (hFile == ENOENT) || (hFile == EINVAL) ) return;

    if (!strstr(cur_file.name, "\\")) {
        sprintf(subsubdir, "%s\\%s", stmpdir, cur_file.name);
    }
    else {
        sprintf(subsubdir, "%s", cur_file.name);
    }

    if (!(slashdot = strstr(subsubdir, "\\.")) || (strcmp(slashdot,"\\.") && strcmp(slashdot,"\\.."))) {
        if ((cur_file.attrib & _A_SUBDIR) && recurse) {
            par_rmtmpdir( subsubdir, 1 );
        }
        /* if (!(cur_file.attrib & _A_SUBDIR)) fprintf(stderr, "unlinking %s\n", subsubdir); */
        else {
            dll = GetModuleHandle(cur_file.name);
            tries = 0;
            while ( _unlink(subsubdir) && ( tries++ < 10 ) ) {
                if ( dll ) FreeLibrary(dll);
            };
        }
    }
    while ( _findnext( hFile, &cur_file ) == 0 ) {
        if (!strstr(cur_file.name, "\\")) {
            sprintf(subsubdir, "%s\\%s", stmpdir, cur_file.name);
        }
        else {
            sprintf(subsubdir, "%s", cur_file.name);
        }

        if (!(slashdot = strstr(subsubdir, "\\.")) || (strcmp(slashdot,"\\.") && strcmp(slashdot,"\\.."))) {
            if ((cur_file.attrib & _A_SUBDIR) && recurse) {
                par_rmtmpdir( subsubdir, 1 );
            }
            /* if (!(cur_file.attrib & _A_SUBDIR)) fprintf(stderr, "unlinking %s\n", subsubdir); */
            else {
                dll = GetModuleHandle(cur_file.name);
                tries = 0;
                while ( _unlink(subsubdir) && ( tries++ < 10 ) ) {
                    if ( dll ) FreeLibrary(dll);
                };
            }
        }
    }

    _findclose(hFile);
    _rmdir(stmpdir);
}

#else
void par_rmtmpdir ( char *stmpdir, int recurse ) {
    DIR *partmp_dirp;
    Direntry_t *dp;
    char *subsubdir;
    struct stat stbuf;

    /* remove temporary PAR directory */
    partmp_dirp = opendir(stmpdir);

    if ( partmp_dirp == NULL ) return;

    /* fprintf(stderr, "%s: removing private temporary subdirectory %s.\n", argv[0], stmpdir); */
    while ( ( dp = readdir(partmp_dirp) ) != NULL ) {
        if ( strcmp (dp->d_name, ".") != 0 && strcmp (dp->d_name, "..") != 0 )
        {
            subsubdir = malloc(strlen(stmpdir) + strlen(dp->d_name) + 2);
            sprintf(subsubdir, "%s/%s", stmpdir, dp->d_name);
            if (stat(subsubdir, &stbuf) != -1 && S_ISDIR(stbuf.st_mode) && recurse) {
                par_rmtmpdir(subsubdir, 1);
            }
            else {
                unlink(subsubdir);
            }
            free(subsubdir);
            subsubdir = NULL;
        }
    }

    closedir(partmp_dirp);
    if (stmpdir) rmdir(stmpdir);
}
#endif

void par_cleanup (char *stmpdir) {
    char *dirname = par_dirname(stmpdir);
    char *basename = par_basename(dirname);
    if ( par_env_clean() && stmpdir != NULL && strlen(stmpdir)) {
        if ( strstr(basename, "par-") == basename ) {
            par_rmtmpdir(stmpdir, 1);
            par_rmtmpdir(dirname, 0);
        }
    }
}
