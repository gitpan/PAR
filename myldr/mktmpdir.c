/* $File: //member/autrijus/PAR/myldr/mktmpdir.c $ $Author: autrijus $
   $Revision: #29 $ $Change: 9659 $ $DateTime: 2004/01/10 19:08:20 $
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

    if ( (val = (char *)getenv("PAR_TEMP")) ) return strdup(val);

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

    if ( tmpdir == NULL ) return NULL;

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

        putenv("PAR_CLEAN=1");
        sprintf(
            stmpdir,
            "%s%stemp-%u%s",
            stmpdir, dir_sep, getpid(), subdirbuf_suffix
        );
    }

    /* set dynamic loading path */
    par_temp_env = (char *)malloc(strlen(PAR_TEMP) + strlen(stmpdir) + 2);
    sprintf(par_temp_env, "%s=%s", PAR_TEMP, stmpdir);
    putenv(par_temp_env);

    for ( i = 0 ; strlen(key = ld_path_keys[i]) > 0 ; i++ ) {
        if ( (val = (char *)getenv(key)) == NULL ) continue;

        if ( strlen(val) == 0 ) {
            ld_path_env = (char *)malloc(strlen(key) + strlen(stmpdir) + 2);
            sprintf(ld_path_env, "%s=%s", key, stmpdir);
        }
        else {
            ld_path_env = (char *)malloc(
                strlen(key) +
                strlen(stmpdir) +
                strlen(path_sep) +
                strlen(val) + 2
            );
            sprintf(
                ld_path_env,
                "%s=%s%s%s",
                key, stmpdir, path_sep, val
            );
        }
        putenv(ld_path_env);
    }

    return(stmpdir);
}


#ifdef WIN32
void par_rmtmpdir ( char *stmpdir ) {
    struct _finddata_t cur_file;
    char *subsubdir = malloc(strlen(stmpdir) + 258);
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

    /* if (!(cur_file.attrib & _A_SUBDIR)) fprintf(stderr, "unlinking %s\n", subsubdir); */
    if (!(cur_file.attrib & _A_SUBDIR)) _unlink(subsubdir);
    while ( _findnext( hFile, &cur_file ) == 0 ) {
        if (!strstr(cur_file.name, "\\")) {
            sprintf(subsubdir, "%s\\%s", stmpdir, cur_file.name);
        }
        else {
            sprintf(subsubdir, "%s", cur_file.name);
        }

        /* if (!(cur_file.attrib & _A_SUBDIR)) fprintf(stderr, "unlinking %s\n", subsubdir); */
        if (!(cur_file.attrib & _A_SUBDIR)) {
            dll = GetModuleHandle(cur_file.name);
            tries = 0;
            while ( _unlink(subsubdir) && ( tries++ < 10 ) ) {
                if ( dll ) FreeLibrary(dll);
            };
        }
    }

    _findclose(hFile);
    _rmdir(stmpdir);
}

#else
void par_rmtmpdir ( char *stmpdir ) {
    DIR *partmp_dirp;
    Direntry_t *dp;
    char *subsubdir;

    /* remove temporary PAR directory */
    partmp_dirp = opendir(stmpdir);

    if ( partmp_dirp == NULL ) return;

    /* fprintf(stderr, "%s: removing private temporary subdirectory %s.\n", argv[0], stmpdir); */
    /* here we simply assume that PAR will NOT create any subdirectories ... */
    while ( ( dp = readdir(partmp_dirp) ) != NULL ) {
        if ( strcmp (dp->d_name, ".") != 0 && strcmp (dp->d_name, "..") != 0 )
        {
            subsubdir = malloc(strlen(stmpdir) + strlen(dp->d_name) + 2);
            sprintf(subsubdir, "%s/%s", stmpdir, dp->d_name);
            unlink(subsubdir);
            free(subsubdir);
            subsubdir = NULL;
        }
    }

    closedir(partmp_dirp);
    if (stmpdir) rmdir(stmpdir);
}
#endif

void par_cleanup (char *stmpdir) {
    if ( par_env_clean() ) {
        par_rmtmpdir(stmpdir);
        par_rmtmpdir(par_dirname(stmpdir));
    }
}

