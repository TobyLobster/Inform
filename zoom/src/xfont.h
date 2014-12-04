/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This program is free software; you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation; either version 2 of the License, or
 *  (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program; if not, write to the Free Software
 *  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
 */

/*
 * Font handling for X-Windows
 */

#ifndef __XFONT_H
#define __XFONT_H

#include "../config.h"

#if WINDOW_SYSTEM == 3
# include <Carbon/Carbon.h>

# include "carbondisplay.h"
# if defined(USE_QUARTZ) || defined(USE_ATS)
#  define XFONT_MEASURE float
# else
#  define XFONT_MEASURE int
# endif
#else
# define XFONT_MEASURE float
#endif

struct xfont;

typedef struct xfont xfont;

extern void    xfont_initialise    (void);
extern void    xfont_shutdown      (void);

extern xfont*  xfont_load_font     (char* font);
extern void    xfont_release_font  (xfont*);

extern void    xfont_set_colours   (int,
				    int);
extern XFONT_MEASURE xfont_get_width     (xfont*);
extern XFONT_MEASURE xfont_get_height    (xfont*);
extern XFONT_MEASURE xfont_get_ascent    (xfont*);
extern XFONT_MEASURE xfont_get_descent   (xfont*);
extern XFONT_MEASURE xfont_get_text_width(xfont*,
					  const int*,
					  int);
#if WINDOW_SYSTEM==1

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <X11/Xresource.h>
#include <X11/keysym.h>

extern void    xfont_plot_string   (xfont*,
				    Drawable,
				    GC,
				    int, int,
				    const int*,
				    int);
#elif WINDOW_SYSTEM==2
extern void xfont_plot_string(xfont*,
			      HDC,
			      int, int,
			      const int*,
			      int);

extern void xfont_choose_new_font(xfont*,
				  int);
#elif WINDOW_SYSTEM==3
extern void xfont_plot_string(xfont*,
			      XFONT_MEASURE, XFONT_MEASURE,
			      const int*,
			      int);
#endif

#endif
