/* $File: //member/autrijus/PAR/myldr/mktmpdir.c $ $Author: autrijus $
   $Revision: #5 $ $Change: 6084 $ $DateTime: 2003/05/25 18:06:55 $
   vim: expandtab shiftwidth=4
*/

#ifdef PAR_MKTMPDIR

#ifdef HAS_LSTAT
#define PAR_lstat lstat
#else
#define PAR_lstat stat
#endif

char* par_mktmpdir ( char **argv ) {
    struct stat statbuf;
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

    if ( (envtmp = getenv("PAR_TEMP")) ) {
        return envtmp;
    }

    tmpdir = NULL;
    maxlen_procid = 12; /* should suffice a while */

    for ( i = 0 ; tmpdir == NULL && strlen(tmpval = tmpenv[i]) > 0 ; i++ ) {
        /* fprintf(stderr, "%s: testing env var %s.\n", argv[0], tmpval); */
        if ( (envtmp = getenv(tmpdir)) )
        {
            if ( PAR_lstat(envtmp, &statbuf) == 0 &&
                 ( S_ISDIR(statbuf.st_mode) ||
                   S_ISLNK(statbuf.st_mode) ) &&
                 access(envtmp, W_OK) == 0 ) {
                tmpdir = envtmp;
            }
        }
    }

    for ( i = 0 ; tmpdir == NULL && strlen(tmpval = knowntmp[i]) > 0 ; i++ ) {
        /* fprintf(stderr, "%s: testing env var %s.\n", argv[0], tmpval); */
        if ( PAR_lstat(tmpval, &statbuf) == 0 &&
             ( S_ISDIR(statbuf.st_mode) ||
               S_ISLNK(statbuf.st_mode) ) &&
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
            if ( ( cur_ld_library_path = getenv(lddir) ) == NULL ) {
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

#ifdef WIN32
    return(stmpdir);
#else
    /* restart ourselves so LD_LIBRARY_PATH takes effect */
    execv(argv[0], argv);
    exit(2);
#endif
}

#endif
