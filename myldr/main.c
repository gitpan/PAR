/* $File: //member/autrijus/PAR/myldr/main.c $ $Author: autrijus $
   $Revision: #25 $ $Change: 7242 $ $DateTime: 2003/07/29 14:29:24 $
   vim: expandtab shiftwidth=4
*/

#ifndef PAR_MKTMPDIR
#define PAR_MKTMPDIR 1
#endif

/* #define PAR_CLEARSTACK 1 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "perlxsi.c"

/* Workaround for mapstart: the only op which needs a different ppaddr */
#undef Perl_pp_mapstart
#define Perl_pp_mapstart Perl_pp_grepstart
#undef OP_MAPSTART
#define OP_MAPSTART OP_GREPSTART

static PerlInterpreter *my_perl;
extern char * name_load_me_2;
extern unsigned long size_load_me_2;
extern char load_me_2[];

#include "mktmpdir.c"

#ifdef PAR_CLEARSTACK
XS(XS_Internals_PAR_CLEARSTACK) {
    dounwind(0); ENTER;
    SAVEDESTRUCTOR(exit, NULL); ENTER;
}
#endif

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

int main ( int argc, char **argv, char **env )
{
    int exitstatus;
    int i;
    char **fakeargv;
    GV* tmpgv;
    int options_count;
#ifdef PAR_MKTMPDIR
    char *stmpdir;
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

    if ((tmpgv = gv_fetchpv("\030",TRUE, SVt_PV))) {/* $^X */
#ifdef WIN32
        sv_setpv(GvSV(tmpgv),"perl.exe");
#else
        sv_setpv(GvSV(tmpgv),"perl");
#endif
        SvSETMAGIC(GvSV(tmpgv));
    }

    if ((tmpgv = gv_fetchpv("0", TRUE, SVt_PV))) {/* $0 */
#ifdef PAR_MKTMPDIR
        if ( ( stmpdir = getenv("PAR_TEMP") ) ) {
            sv_setpv(GvSV(tmpgv), argv[0]);
        }
        else
#endif
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

    TAINT_NOT;

    /* PL_main_cv = PL_compcv; */
    PL_compcv = 0;

#ifdef PAR_MKTMPDIR
    /* create temporary PAR directory */
    stmpdir = getenv("PAR_TEMP");
    if ( stmpdir == NULL ) {
        stmpdir = par_mktmpdir( argv );
#ifndef WIN32
        i = execvp(SvPV_nolen(GvSV(tmpgv)), argv);
        PerlIO_printf(PerlIO_stderr(), "%s: execution of %s failed - aborting with %i.\n", argv[0], SvPV_nolen(GvSV(tmpgv)), i);
        return 2;
#endif
    }

    i = PerlDir_mkdir(stmpdir, 0755);
    if ( (i != 0) && (i != EEXIST) && (i != -1) ) {
        PerlIO_printf(PerlIO_stderr(), "%s: creation of private temporary subdirectory %s failed - aborting with %i.\n", argv[0], stmpdir, i);
        return 2;
    }
#endif

#ifdef PAR_CLEARSTACK
    newXSproto("Internals::PAR_CLEARSTACK", XS_Internals_PAR_CLEARSTACK, "", "");
#endif
    exitstatus = perl_run( my_perl );
    perl_destruct( my_perl );

#ifdef PAR_MKTMPDIR
    par_rmtmpdir(stmpdir);
#endif

    perl_free( my_perl );
    PERL_SYS_TERM();

    return exitstatus;
}

