/* $File: //member/autrijus/PAR/myldr/main.c $ $Author: autrijus $
   $Revision: #3 $ $Change: 2026 $ $DateTime: 2002/11/06 23:01:32 $ */

#define PERL_NO_GET_CONTEXT
#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>

/* expletive */
#undef malloc
#undef free

#include "my_par_pl.c"
#include "perlxsi.c"

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


char** prepare_args( int argc, char** argv, int* my_argc )
{
    int i, count = ( argc ? argc : 1 ) + 3;
    char** my_argv = (char**) malloc( ( count + 1 ) * sizeof(char**) );

    my_argv[0] = strdup( argc ? argv[0] : "" );
    my_argv[1] = strdup( "-e" );
    my_argv[2] = strdup( "" );

    for( i = 4; i < count; ++i )
    {
        my_argv[i] = strdup( argv[ i - 3 ] );
    }

    my_argv[ count + 1 ] = NULL;

    *my_argc = count;
    return my_argv;
}

int main( int argc, char **argv, char **env )
{
    int exitstatus;
    int i;
    char **fakeargv;
    GV* tmpgv;
    int options_count;

    if (!PL_do_undump) {
        my_perl = perl_alloc();
        if (!my_perl)
            exit(1);
        perl_construct( my_perl );
        PL_perl_destruct_level = 0;
    }

#ifdef CSH
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
    fakeargv[2] = "";
    options_count = 3;

#ifndef ALLOW_PERL_OPTIONS
    fakeargv[options_count] = "--";
    ++options_count;
#endif /* ALLOW_PERL_OPTIONS */

    for (i = 1; i < argc; i++)
        fakeargv[i + options_count - 1] = argv[i];
    fakeargv[argc + options_count - 1] = 0;

    exitstatus = perl_parse(my_perl, xs_init, argc + options_count - 1,
                            fakeargv, NULL);

    if (exitstatus)
        exit( exitstatus );

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

    exitstatus = perl_run( my_perl );

    eval_pv( load_me_2, 1 );

    perl_destruct( my_perl );
    perl_free( my_perl );

    PERL_SYS_TERM();

    exit( exitstatus );

    return 0;
}

