/* $File: //member/autrijus/PAR/myldr/internals.c $ $Author: autrijus $
   $Revision: #3 $ $Change: 7298 $ $DateTime: 2003/08/02 10:05:51 $
   vim: expandtab shiftwidth=4
*/

XS(XS_Internals_PAR_BOOT) {
    GV* tmpgv;
    AV* tmpav;
    SV** svp;
    int i;
    int ok = 0;

    TAINT;

    if ((tmpgv = gv_fetchpv("ARGV", TRUE, SVt_PVAV))) {/* @ARGV */
        tmpav = GvAV(tmpgv);
        for (i = 1; i < options_count; i++) {
            svp = av_fetch(tmpav, i-1, 0);
            if (!svp) break;
            if (strcmp(fakeargv[i], SvPV_nolen(*svp))) break;
            ok++;
        }
        if (ok == options_count - 1) {
            for (i = 1; i < options_count; i++) {
                av_shift(tmpav);
            }
        }
    }

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
            sv_setpv(GvSV(tmpgv), fakeargv[0]);
        }
        else
#endif
#ifdef HAS_PROCSELFEXE
            S_procself_val(aTHX_ GvSV(tmpgv), fakeargv[0]);
#else
#ifdef OS2
            sv_setpv(GvSV(tmpgv), os2_execname(aTHX));
#else
            sv_setpv(GvSV(tmpgv), fakeargv[0]);
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
        stmpdir = par_mktmpdir( fakeargv );
#ifndef WIN32
        i = execvp(SvPV_nolen(GvSV(tmpgv)), fakeargv);
        croak("%s: execution of %s failed - aborting with %i.\n", fakeargv[0], SvPV_nolen(GvSV(tmpgv)), i);
        return;
#endif
    }

    i = PerlDir_mkdir(stmpdir, 0755);
    if ( (i != 0) && (i != EEXIST) && (i != -1) ) {
        croak("%s: creation of private temporary subdirectory %s failed - aborting with %i.\n", fakeargv[0], stmpdir, i);
        return;
    }
#endif
}

static void par_xs_init(pTHX)
{
    xs_init(aTHX);
    newXSproto("Internals::PAR::BOOT", XS_Internals_PAR_BOOT, "", "");
}

