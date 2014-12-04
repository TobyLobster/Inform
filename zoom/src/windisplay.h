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
 * Display for Win32
 */

#ifndef __WINDISPLAY_H
#define __WINDISPLAY_H

#include <windows.h>

extern HWND     mainwin;
extern HDC      mainwindc;
extern HBRUSH   winbrush[14];
extern HPEN     winpen  [14];
extern COLORREF wincolour[14];

extern int xfont_x, xfont_y;

extern void display_int_apply(void);

#endif
