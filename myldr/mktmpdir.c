/* $File: //member/autrijus/PAR/myldr/mktmpdir.c $ $Author: autrijus $
   $Revision: #12 $ $Change: 7267 $ $DateTime: 2003/07/30 13:43:29 $
   vim: expandtab shiftwidth=4
*/

#ifdef PAR_MKTMPDIR
#include <stdlib.h>
#include <string.h>

#ifdef HAS_LSTAT
#define PAR_lstat lstat
#else
#define PAR_lstat stat
#endif

char* par_mktmpdir ( char **argv ) {
#ifndef PL_statbuf
    struct stat PL_statbuf;
#endif
    int i;
    const char *par_tmp_dir      = "PAR_TMP_DIR=";
    const char *par_priv_tmp_dir = "PAR_TEMP=";
    const char *tmpval;
    const char *tmpdir;
    const char *lddir;
    char *ltmpdir;
    char *ptmpdir;
    char *stmpdir;
    char *privptmpdir;
    char *cur_ld_library_path;
    Pid_t procid;
    char *envtmp;

    const char *tmpenv[4] = { "TMPDIR", "TEMP", "TMP", "" };
    const char *knowntmp[4] = { "C:\\TEMP", "/tmp", "/", "" };
    const char *ldlibpthname[5] = { "LD_LIBRARY_PATH", "LIBPATH", "LIBRARY_PATH", "PATH", "DYLD_LIBRARY_PATH" };

    const char *subdirbuf_prefix = "par_priv.";
    const char *subdirbuf_suffix = ".tmp";
    int maxlen_procid;

    if ( (envtmp = (char *)getenv("PAR_TEMP")) ) {
        return envtmp;
    }

    tmpdir = NULL;
    maxlen_procid = 12; /* should suffice a while */

    for ( i = 0 ; tmpdir == NULL && strlen(tmpval = tmpenv[i]) > 0 ; i++ ) {
        /* fprintf(stderr, "%s: testing env var %s.\n", argv[0], tmpval); */
        if ( (envtmp = (char *)getenv(tmpval)) )
        {
            if ( PAR_lstat(envtmp, &PL_statbuf) == 0 &&
                 ( S_ISDIR(PL_statbuf.st_mode) ||
                   S_ISLNK(PL_statbuf.st_mode) ) &&
                 access(envtmp, W_OK) == 0 ) {
                tmpdir = envtmp;
            }
        }
    }

    for ( i = 0 ; tmpdir == NULL && strlen(tmpval = knowntmp[i]) > 0 ; i++ ) {
        /* fprintf(stderr, "%s: testing env var %s.\n", argv[0], tmpval); */
        if ( PAR_lstat(tmpval, &PL_statbuf) == 0 &&
             ( S_ISDIR(PL_statbuf.st_mode) ||
               S_ISLNK(PL_statbuf.st_mode) ) &&
             access(tmpval, W_OK) == 0 ) {
            tmpdir = tmpval;
        }
    }

    if ( tmpdir == NULL ) {
        fprintf(stderr, "no suitable temporary directory found - aborting.\n");
        return NULL;
    }
    else {
        /* fprintf(stderr, "%s: found tmpdir %s.\n", argv[0], tmpdir); */

        ptmpdir = (char *)malloc(strlen(par_tmp_dir) + strlen(tmpdir) + 1);
        strcpy(ptmpdir, par_tmp_dir);
        strcat(ptmpdir, tmpdir);
        /* fprintf(stderr, "%s\n", ptmpdir) */;
        putenv(ptmpdir);

        /* construct our private temporary directory under the newly found tmp dir */
        procid = getpid();
        stmpdir = (char *)malloc(strlen(ptmpdir) + strlen(subdirbuf_prefix) + strlen(subdirbuf_suffix) + maxlen_procid + 2);
#ifdef WIN32
        sprintf(stmpdir, "%s\\%s%u%s", tmpdir, subdirbuf_prefix, procid, subdirbuf_suffix);
#else
        sprintf(stmpdir, "%s/%s%u%s", tmpdir, subdirbuf_prefix, procid, subdirbuf_suffix);
#endif

        privptmpdir = (char *)malloc(strlen(par_priv_tmp_dir) + strlen(stmpdir) + 1);
        strcpy(privptmpdir, par_priv_tmp_dir);
        strcat(privptmpdir, stmpdir);
        /* fprintf(stderr, "%s\n", privptmpdir) */;
        putenv(privptmpdir);

        for ( i = 0 ; i < 5 ; i++ ) {
            lddir = ldlibpthname[i];
            if ( ( cur_ld_library_path = (char *)getenv(lddir) ) == NULL ) {
                cur_ld_library_path = "";
            }
            if ( strlen(cur_ld_library_path) == 0 ) {
                ltmpdir = (char *)malloc(strlen(lddir) + strlen(stmpdir) + 2);
                sprintf(ltmpdir, "%s=%s", lddir, stmpdir);
            }
            else {
                ltmpdir = (char *)malloc(strlen(lddir) + strlen(stmpdir) + strlen(cur_ld_library_path) + 3);
#ifdef WIN32
                sprintf(ltmpdir, "%s=%s;%s", lddir, stmpdir, cur_ld_library_path);
#else
                sprintf(ltmpdir, "%s=%s:%s", lddir, stmpdir, cur_ld_library_path);
#endif
            }
            /* fprintf(stderr, "setting %s\n", ltmpdir); */
            putenv(ltmpdir);
        }
    }

    return(stmpdir);
}

#ifdef WIN32
void par_rmtmpdir ( char *stmpdir ) {
    struct _finddata_t cur_file;
    char *subsubdir = malloc(strlen(stmpdir) + 258);
    long hFile;

    if (!stmpdir || !strlen(stmpdir)) return;

    sprintf(subsubdir, "%s\\*.*", stmpdir);

    if ( ( hFile = _findfirst( subsubdir, &cur_file ) )  == -1L ) {
        return;
    }

    if (!strstr(cur_file.name, "\\")) {
        sprintf(subsubdir, "%s\\%s", stmpdir, cur_file.name);
    }
    else {
        sprintf(subsubdir, "%s", cur_file.name);
    }

    /*if (!(cur_file.attrib & _A_SUBDIR)) fprintf(stderr, "unlinking %s\n", subsubdir);*/
    if (!(cur_file.attrib & _A_SUBDIR)) unlink(subsubdir);
    while ( _findnext( hFile, &cur_file ) == 0 ) {
        if (!strstr(cur_file.name, "\\")) {
            sprintf(subsubdir, "%s\\%s", stmpdir, cur_file.name);
        }
        else {
            sprintf(subsubdir, "%s", cur_file.name);
        }
        /*if (!(cur_file.attrib & _A_SUBDIR)) fprintf(stderr, "unlinking %s\n", subsubdir);*/
        if (!(cur_file.attrib & _A_SUBDIR)) unlink(subsubdir);
        unlink(subsubdir);
    }

    rmdir(stmpdir);
}

#else
void par_rmtmpdir ( char *stmpdir ) {
    DIR *partmp_dirp;
    Direntry_t *dp;
    char *subsubdir;

    fprintf(stderr, "trying to get rid of %s\n", stmpdir);
    /* remove temporary PAR directory */
    partmp_dirp = opendir(stmpdir);

    if ( partmp_dirp != NULL )
    {
        /* fprintf(stderr, "%s: removing private temporary subdirectory %s.\n", argv[0], stmpdir); */
        /* here we simply assume that PAR will NOT create any subdirectories ... */
        while ( ( dp = readdir(partmp_dirp) ) != NULL ) {
            if ( strcmp (dp->d_name, ".") != 0 && strcmp (dp->d_name, "..") != 0 )
            {
                subsubdir = malloc(strlen(stmpdir) + strlen(dp->d_name) + 2);
                sprintf(subsubdir, "%s/%s", stmpdir, dp->d_name);
                fprintf(stderr, "unlinking %s\n", subsubdir);
                unlink(subsubdir);
                free(subsubdir);
                subsubdir = NULL;
            }
        }
        closedir(partmp_dirp);
        rmdir(stmpdir);
    }
}
#endif

#endif
