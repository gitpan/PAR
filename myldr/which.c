/*	$OpenBSD: which.c,v 1.11 2003/06/17 21:56:26 millert Exp $	*/

/*
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
 */

char *
findprog(char *prog, char *path)
{
	char *p, filename[MAXPATHLEN];
	int proglen, plen;

#ifdef WIN32
        if ( GetModuleFileName(0, filename, MAXPATHLEN) ) {
		return strdup(filename);
	}
#endif
	/* Special case if prog contains '/' */
	if (strstr(prog, dir_sep)) return(prog);

	proglen = strlen(prog);
	p = strtok(path, path_sep);
	while ( p != NULL ) {
		if (*p == '\0')
			p = ".";

		plen = strlen(p);
		while (p[plen-1] == *dir_sep)
			p[--plen] = '\0';	/* strip trailing '/' */

		if (plen + 1 + proglen >= MAXPATHLEN) {
			return(prog);
		}

		sprintf(filename, "%s%s%s", p, dir_sep, prog);
		if ((stat(filename, &PL_statbuf) == 0) && S_ISREG(PL_statbuf.st_mode) &&
		    access(filename, X_OK) == 0) {
			return(strdup(filename));
		}
		p = strtok(NULL, path_sep);
	}

	return(prog);
}
