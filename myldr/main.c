/* $File: //member/autrijus/PAR/myldr/main.c $ $Author: autrijus $
   $Revision: #15 $ $Change: 5902 $ $DateTime: 2003/05/16 17:12:13 $
   vim: expandtab shiftwidth=4
*/

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "my_par_pl.c"
#include "perlxsi.c"

/* Workaround for mapstart: the only op which needs a different ppaddr */
#undef Perl_pp_mapstart
#define Perl_pp_mapstart Perl_pp_grepstart
#undef OP_MAPSTART
#define OP_MAPSTART OP_GREPSTART

static PerlInterpreter *my_perl;

#ifdef HAS_PROCSELFEXE
/* This is a function so that we don't hold on to MAXPATHLEN
   bytes of stack longer than necessary
 */
STATIC void
S_procself_val(pTHX_ SV *sv, char *arg0)
{
    char buf[MAXPATHLEN];
    int len = readlink(PROCSELFEXE_PATH, buf, sizeof(buf) - 1);

    /* On Playstation2 Linux V1.0 (kernel 2.2.1) readlink(/proc/self/exe)
       includes a spurious NUL which will cause $^X to fail in system
       or backticks (this will prevent extensions from being built and
       many tests from working). readlink is not meant to add a NUL.
       Normal readlink works fine.
     */
    if (len > 0 && buf[len-1] == '\0') {
      len--;
    }

    /* FreeBSD's implementation is acknowledged to be imperfect, sometimes
       returning the text "unknown" from the readlink rather than the path
       to the executable (or returning an error from the readlink).  Any valid
       path has a '/' in it somewhere, so use that to validate the result.
       See http://www.freebsd.org/cgi/query-pr.cgi?pr=35703
    */
    if (len > 0 && memchr(buf, '/', len)) {
        sv_setpvn(sv,buf,len);
    }
    else {
        sv_setpv(sv,arg0);
    }
}
#endif /* HAS_PROCSELFEXE */


int main( int argc, char **argv, char **env )
{
    int exitstatus;
    int i;
    char **fakeargv;
    GV* tmpgv;
    int options_count;

    char *envtmp;
    const char *ld_library_path  = "LD_LIBRARY_PATH=";
    const char *par_tmp_dir      = "PAR_TMP_DIR=";
    const char *par_priv_tmp_dir = "PAR_TEMP=";
    const char *tmpval;
    const char *tmpdir;
    char *ltmpdir;
    char *ptmpdir;
    char *privptmpdir;
    char *stmpdir;
    char *cur_ld_library_path;
    Pid_t procid;
    DIR *partmp_dirp;
    Direntry_t *dp;
    char *subsubdir;

    const char *tmpenv[4] = { "TMPDIR", "TEMP", "TMP", "" };
    const char *knowntmp[4] = { "C:\\TEMP", "/tmp", "/", "" };

    const char *subdirbuf_prefix = "par_priv.";
    const char *subdirbuf_suffix = ".tmp";
    int maxlen_procid;

    tmpdir = NULL;
    maxlen_procid = 12; /* should suffice a while */

#ifndef WIN32
    for ( i = 0 ; tmpdir == NULL && strlen(tmpval = tmpenv[i]) > 0 ; i++ ) {
        /* fprintf(stderr, "%s: testing env var %s.\n", argv[0], tmpval); */
        if ( envtmp = PerlEnv_getenv(tmpval) )
        {
            if ( lstat(envtmp, &PL_statbuf) == 0 &&
                 ( S_ISDIR(PL_statbuf.st_mode) ||
                   S_ISLNK(PL_statbuf.st_mode) ) &&
                 access(envtmp, W_OK) == 0 ) {
                tmpdir = envtmp;
            }
        }
    }

    for ( i = 0 ; tmpdir == NULL && strlen(tmpval = knowntmp[i]) > 0 ; i++ ) {
        /* fprintf(stderr, "%s: testing env var %s.\n", argv[0], tmpval); */
        if ( lstat(tmpval, &PL_statbuf) == 0 &&
             ( S_ISDIR(PL_statbuf.st_mode) ||
               S_ISLNK(PL_statbuf.st_mode) ) &&
             access(tmpval, W_OK) == 0 ) {
            tmpdir = tmpval;
        }
    }

    if ( tmpdir == NULL ) {
        fprintf(stderr, "%s: no suitable temporary directory found - aborting.\n", argv[0]);
        return 2;
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
        sprintf(stmpdir, "%s/%s%u%s", tmpdir, subdirbuf_prefix, procid, subdirbuf_suffix); /* Unix */

        privptmpdir = (char *)malloc(strlen(par_priv_tmp_dir) + strlen(stmpdir) + 1);
        strcpy(privptmpdir, par_priv_tmp_dir);
        strcat(privptmpdir, stmpdir);
        /* fprintf(stderr, "%s\n", privptmpdir) */;
        putenv(privptmpdir);

        if ( ( cur_ld_library_path = getenv("LD_LIBRARY_PATH") ) == NULL ) {
            cur_ld_library_path = "";
        }
        if ( strlen(cur_ld_library_path) == 0 ) {
            ltmpdir = (char *)malloc(strlen(ld_library_path) + strlen(stmpdir) + 1);
            sprintf(ltmpdir, "%s%s", ld_library_path, stmpdir, cur_ld_library_path);
        }
        else {
            ltmpdir = (char *)malloc(strlen(ld_library_path) + strlen(stmpdir) + strlen(cur_ld_library_path) + 2);
            sprintf(ltmpdir, "%s%s:%s", ld_library_path, stmpdir, cur_ld_library_path);
        }
        /* fprintf(stderr, "%s\n", ltmpdir) */;
        putenv(ltmpdir);
    }

#endif

#if (defined(USE_5005THREADS) || defined(USE_ITHREADS)) && defined(HAS_PTHREAD_ATFORK)
    /* XXX Ideally, this should really be happening in perl_alloc() or
     * perl_construct() to keep libperl.a transparently fork()-safe.
     * It is currently done here only because Apache/mod_perl have
     * problems due to lack of a call to cancel pthread_atfork()
     * handlers when shared objects that contain the handlers may
     * be dlclose()d.  This forces applications that embed perl to
     * call PTHREAD_ATFORK() explicitly, but if and only if it hasn't
     * been called at least once before in the current process.
     * --GSAR 2001-07-20 */
    PTHREAD_ATFORK(Perl_atfork_lock,
                   Perl_atfork_unlock,
                   Perl_atfork_unlock);
#endif

    if (!PL_do_undump) {
        my_perl = perl_alloc();
        if (!my_perl)
            exit(1);
        perl_construct( my_perl );
        PL_perl_destruct_level = 0;
    }
#ifdef PERL_EXIT_DESTRUCT_END
    PL_exit_flags |= PERL_EXIT_DESTRUCT_END;
#endif /* PERL_EXIT_DESTRUCT_END */

#if (defined(CSH) && defined(PL_cshname))
    if (!PL_cshlen)
      PL_cshlen = strlen(PL_cshname);
#endif

#ifdef ALLOW_PERL_OPTIONS
#define EXTRA_OPTIONS 3
#else
#define EXTRA_OPTIONS 4
#endif /* ALLOW_PERL_OPTIONS */
    New(666, fakeargv, argc + EXTRA_OPTIONS + 1, char *);

    fakeargv[0] = argv[0];
    fakeargv[1] = "-e";
    fakeargv[2] = load_me_2;
    options_count = 3;

#ifndef ALLOW_PERL_OPTIONS
    fakeargv[options_count] = "--";
    ++options_count;
#endif /* ALLOW_PERL_OPTIONS */

    for (i = 1; i < argc; i++)
        fakeargv[i + options_count - 1] = argv[i];
    fakeargv[argc + options_count - 1] = 0;

    exitstatus = perl_parse(my_perl, xs_init, argc + options_count - 1,
                            fakeargv, (char **)NULL);

    if (exitstatus) {
        perl_destruct(my_perl);
        perl_free(my_perl);
        PERL_SYS_TERM();
        exit( exitstatus );
    }

    TAINT;

    if ((tmpgv = gv_fetchpv("0", TRUE, SVt_PV))) {/* $0 */
#ifdef HAS_PROCSELFEXE
        S_procself_val(aTHX_ GvSV(tmpgv), argv[0]);
#else
#ifdef OS2
        sv_setpv(GvSV(tmpgv), os2_execname(aTHX));
#else
        sv_setpv(GvSV(tmpgv), argv[0]);
#endif
#endif
        SvSETMAGIC(GvSV(tmpgv));
    }

    if ((tmpgv = gv_fetchpv("\030",TRUE, SVt_PV))) {/* $^X */
#ifdef WIN32
        sv_setpv(GvSV(tmpgv),"perl.exe");
#else
        sv_setpv(GvSV(tmpgv),"perl");
#endif
        SvSETMAGIC(GvSV(tmpgv));
    }

    TAINT_NOT;

    /* PL_main_cv = PL_compcv; */
    PL_compcv = 0;

#ifndef WIN32
    /* create temporary PAR directory */
    if ( (stmpdir != NULL) && (mkdir(stmpdir, S_IRWXU) != 0) ) {
        fprintf(stderr, "%s: creation of private temporary subdirectory %s failed - aborting.\n", argv[0], stmpdir);
        return 2;
    }
#endif

    exitstatus = perl_run( my_perl );
    perl_destruct( my_perl );
    perl_free( my_perl );

    PERL_SYS_TERM();

#ifndef WIN32
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
                sprintf(subsubdir, "%s/%s", stmpdir, dp->d_name); /* Unix */
                unlink(subsubdir);
                free(subsubdir);
                subsubdir = NULL;
            }
        }
        closedir(partmp_dirp);
        rmdir(stmpdir);
    }
#endif

    return exitstatus;
}

