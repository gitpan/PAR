/* $File: //member/autrijus/PAR/myldr/main.c $ $Author: autrijus $
   $Revision: #1 $ $Change: 1985 $ $DateTime: 2002/11/05 14:10:43 $ */

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
    SV* tmpsv;
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
	tmpsv = GvSV(tmpgv);
	sv_setpv(tmpsv, argv[0]);
	SvSETMAGIC(tmpsv);
    }

    if ((tmpgv = gv_fetchpv("\030",TRUE, SVt_PV))) {/* $^X */
        tmpsv = GvSV(tmpgv);
#ifdef WIN32
        sv_setpv(tmpsv,"perl.exe");
#else
        sv_setpv(tmpsv,"perl");
#endif
        SvSETMAGIC(tmpsv);
    }

    TAINT_NOT;

    /* PL_main_cv = PL_compcv; */
    PL_compcv = 0;

    exitstatus = perl_run( my_perl );

    eval_pv( load_me_2, 0 );
    croak(Nullch);

    perl_destruct( my_perl );
    perl_free( my_perl );

    PERL_SYS_TERM();

    exit( exitstatus );

    return 0;
}

