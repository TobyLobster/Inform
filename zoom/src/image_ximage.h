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
 * Routines for turning images into XImages
 *
 * Groan, moan, grah, mutter, X.
 */

#ifndef __IMAGE_XIMAGE_H
#define __IMAGE_XIMAGE_H

# include "../config.h"

# if WINDOW_SYSTEM == 1

#  include "ztypes.h"
#  include "image.h"

#  include <X11/Xlib.h>

#  ifdef HAVE_XRENDER
#   include <X11/extensions/Xrender.h>
#  endif

extern XImage* image_to_ximage_truecolour(image_data* img,
					  Display*    display,
					  Visual*     visual);
extern XImage* image_to_mask_truecolour  (XImage*     orig,
					  image_data* img,
					  Display*    display,
					  Visual*     visual);
extern void    image_plot_X              (image_data* img,
					  Display*  display,
					  Drawable  draw,
					  GC        gc,
					  int x, int y,
					  int n, int d);
#  ifdef HAVE_XRENDER
extern XImage* image_to_ximage_render(image_data* img,
				      Display*    display,
				      Visual*     visual);
extern void    image_plot_Xrender    (image_data* img,
				      Display*  display,
				      Picture   pic,
				      int x, int y,
				      int n, int d);
#  endif

# endif

#endif
