/*
 *  A Z-Machine
 *  Copyright (C) 2000 Andrew Hunter
 *
 *  This library is free software; you can redistribute it and/or
 *  modify it under the terms of the GNU Lesser General Public
 *  License as published by the Free Software Foundation; either
 *  version 2.1 of the License, or (at your option) any later version.
 *
 *  This library is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 *  Lesser General Public License for more details.
 *
 *  You should have received a copy of the GNU Lesser General Public
 *  License along with this library; if not, write to the Free Software
 *  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
 */

/*
 * Version 6 display
 */

/*
 * Note to porters: In order to support v6, you'll need to support
 * the 'Pixmap display' functions; they aren't used for other display
 * styles. The v6 display code itself is actually device independant.
 */

#ifndef __V6DISPLAY_H
#define __V6DISPLAY_H

extern void v6_startup      (void);
extern void v6_reset        (void);
extern void v6_reset_windows(void);

extern void v6_scale_image  (BlorbImage* img, 
			     int* img_n, 
			     int* img_d);

extern void v6_prints       (const int* text);
extern void v6_prints_c     (const char* text);

extern void v6_erase_window (void);
extern void v6_erase_line   (int);
extern void v6_scroll_window(int window,
			     int amount);

extern int  v6_split_point  (int* text,
			     int  text_len,
			     int  width,
			     int* width_out);
extern int  v6_measure_text (int* text,
			     int text_len);

extern int  v6_set_style    (int);
extern void v6_set_colours  (int fg, int bg);
extern int  v6_get_window   (void);
extern void v6_set_window   (int window);
extern void v6_define_window(int window,
			     int x, int y,
			     int lmargin, int rmargin,
			     int width, int height);
extern void v6_set_scroll   (int flag);
extern void v6_set_more     (int window, int flag);
extern void v6_set_wrap     (int window, int flag);
extern void v6_set_cursor   (int x, int y);

extern int  v6_get_cursor_x (void);
extern int  v6_get_cursor_y (void);

extern void v6_set_caret    (void);
extern void v6_set_mouse_win(int win);

extern int  v6_get_fg_colour(void);
extern int  v6_get_bg_colour(void);

extern void v6_set_newline_function(int (*func)(const int * remaining,
						int rem_len));

#endif
