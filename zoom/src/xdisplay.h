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
 * Display for X-Windows
 */

#ifndef __XDISPLAY_H
#define __XDISPLAY_H

#include <X11/Xlib.h>
#include <X11/Xatom.h>
#include <X11/Xutil.h>
#include <X11/Xresource.h>
#include <X11/keysym.h>

#ifdef HAVE_XFT
#include <X11/Xft/Xft.h>
#endif

/* Globals */

extern Display*      x_display;
extern int           x_screen;

extern Window        x_mainwin;
extern GC            x_wingc;
extern GC            x_caretgc;
extern GC            x_pixgc;

extern Pixmap        x_pix;
extern XColor        x_colour[];

#ifdef HAVE_XFT
extern XftColor xft_colour[];
extern XftDraw* xft_drawable;
#endif

extern long int xdisplay_get_pixel_value(int colour);
#ifdef HAVE_XFT
extern XftColor* xdisplay_get_xft_colour(int colour);
#endif

#endif
