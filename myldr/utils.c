/* $File: //member/autrijus/PAR/myldr/mktmpdir.c $ $Author: autrijus $
 * $Revision: #24 $ $Change: 9558 $ $DateTime: 2004/01/02 18:50:23 $
 * vim: expandtab shiftwidth=4
 *
 * Copyright (c) 1997 Todd C. Miller <Todd.Miller@courtesan.com>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

char *par_findprog(char *prog, char *path) {
    char *p, filename[MAXPATHLEN];
    char buf[MAXPATHLEN + 14];
    int proglen, plen;

#ifdef WIN32
    if ( GetModuleFileName(0, filename, MAXPATHLEN) ) {
        sprintf(buf, "PAR_PROGNAME=%s", filename); putenv(buf);
        return strdup(filename);
    }
#endif

    /* Special case if prog contains '/' */
    if (strstr(prog, dir_sep)) {
        sprintf(buf, "PAR_PROGNAME=%s", prog); putenv(buf);
        return(prog);
    }

    proglen = strlen(prog);
    p = strtok(path, path_sep);
    while ( p != NULL ) {
        if (*p == '\0') p = ".";

        plen = strlen(p);

        /* strip trailing '/' */
        while (p[plen-1] == *dir_sep) {
            p[--plen] = '\0';
        }

        if (plen + 1 + proglen >= MAXPATHLEN) {
            sprintf(buf, "PAR_PROGNAME=%s", prog); putenv(buf);
            return(prog);
        }

        sprintf(filename, "%s%s%s", p, dir_sep, prog);
        if ((stat(filename, &PL_statbuf) == 0) && S_ISREG(PL_statbuf.st_mode) &&
            access(filename, X_OK) == 0) {
                sprintf(buf, "PAR_PROGNAME=%s", filename); putenv(buf);
                return(strdup(filename));
        }
        p = strtok(NULL, path_sep);
    }

    sprintf(buf, "PAR_PROGNAME=%s", prog); putenv(buf);
    return(prog);
}

char *par_basename (const char *name) {
    const char *base = name;
    const char *p;

    for (p = name; *p; p++) {
        if (*p == *dir_sep) base = p + 1;
    }

    return (char *)base;
}

char *par_dirname (const char *path) {
    static char bname[MAXPATHLEN];
    register const char *endp;

    /* Empty or NULL string gets treated as "." */
    if (path == NULL || *path == '\0') {
        return(strdup("."));
    }

    /* Strip trailing slashes */
    endp = path + strlen(path) - 1;
    while (endp > path && *endp == *dir_sep) endp--;

    /* Find the start of the dir */
    while (endp > path && *endp != *dir_sep) endp--;

    /* Either the dir is "/" or there are no slashes */
    if (endp == path) {
        if (*endp == *dir_sep) {
            return strdup(".");
        }
        else {
            return strdup(dir_sep);
        }
    } else {
        do {
            endp--;
        } while (endp > path && *endp == *dir_sep);
    }

    if (endp - path + 2 > sizeof(bname)) {
        return(NULL);
    }

    strncpy(bname, path, endp - path + 1);
    return(bname);
}

void par_init_env () {
    char par_clean[] = "__ENV_PAR_CLEAN__               \0";
    char *par_var = (char *)malloc(256);
    char *buf;

    putenv("PAR_SPAWNED=");
    putenv("PAR_TEMP=");
    putenv("PAR_CLEAN=");
    putenv("PAR_DEBUG=");
    putenv("PAR_CACHE=");
    putenv("PAR_PROGNAME=");
    putenv("PAR_ARGC=");
    putenv("PAR_ARGV_0=");

    par_var[255] = '\0';

    if ( (buf = getenv("PAR_GLOBAL_TEMP")) != NULL ) {
        strcpy(par_var, "PAR_TEMP=");
        strncpy(par_var+9, buf, 254 - 9);
        putenv(par_var);
    }
    if ( (buf = getenv("PAR_GLOBAL_CLEAN")) != NULL ) {
        strcpy(par_var, "PAR_CLEAN=");
        strncpy(par_var+10, buf, 254 - 10);
        putenv(par_var);
    }
    if ( (buf = getenv("PAR_GLOBAL_DEBUG")) != NULL ) {
        strcpy(par_var, "PAR_DEBUG=");
        strncpy(par_var+10, buf, 254 - 10);
        putenv(par_var);
    }

    if ( getenv("PAR_GLOBAL_TEMP") != NULL ) {
        putenv("PAR_CLEAN=");
    }
    else if ( getenv("PAR_GLOBAL_CLEAN") == NULL ) {
        putenv(par_clean + 12 + strlen("CLEAN"));
    }

    putenv("PAR_INITIALIZED=1");
    return;
}

int par_env_clean () {
    static int rv = -1;

    if (rv == -1) {
        char *buf = getenv("PAR_CLEAN");
        rv = ( ((buf == NULL) || (*buf == '\0') || (*buf == '0')) ? 0 : 1);
    }

    return rv;
}

