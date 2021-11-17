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
 * Display prototypes
 */

/*
 * Ah, this was once a great ole display library. Unfortunately, my 
 * changing demands made it a bit of a mess. Some of these functions
 * are architecture-specific, and some aren't any more.
 */

#ifndef __DISPLAY_H
#define __DISPLAY_H

#include "image.h"
#include "blorb.h"

/***                           ----// 888 \\----                           ***/

/* Printing & housekeeping functions */
extern void printf_debug(const char* format, ...) __printflike(1, 2);
extern void printf_info (const char* format, ...) __printflike(1, 2);
extern void printf_info_done(void);
extern void printf_error(const char* format, ...) __printflike(1, 2);
extern void printf_error_done(void);

extern void display_exit(int code) __dead2;

/***                           ----// 888 \\----                           ***/

/* Architecture-independant functions (display.c/format.c) */
/* NOTE: display.c/format.c are NOT used in the Cocoa port (we use NSTextView instead) */

/* Output functions */
extern void display_clear     (void);
extern void display_prints    (const int*);
extern void display_prints_c  (const char*);
extern void display_printc    (int);
extern void display_printf    (const char*, ...) __printflike(1, 2);

extern void display_sanitise  (void);
extern void display_desanitise(void);

extern void display_has_restarted(void);

/* Version 1-5 display */
extern void display_is_v6       (void);
extern void display_erase_window(void);
extern void display_erase_line  (int val);
extern int  display_set_font    (int font);
extern int  display_set_style   (int style);
extern void display_set_colour  (int fore, int back);
extern void display_split       (int lines, int window);
extern void display_join        (int win1, int win2);
extern void display_set_window  (int window);
extern int  display_get_window  (void);
extern void display_set_cursor  (int x, int y);
extern int  display_get_cur_x   (void);
extern int  display_get_cur_y   (void);
extern void display_force_fixed (int window, int val);

/***                           ----// 888 \\----                           ***/

/* Architecture-dependant functions */

/* Misc functions */
extern void display_initialise  (void); /* Called on startup */
extern void display_reinitialise(void); /* Called on startup */
extern void display_finalise    (void); /* Called on shutdown */

/***                           ----// 888 \\----                           ***/

/* Output functions */
extern int  display_check_char(int);

/* Input functions */
extern int  display_readline(int*, int, long int);
extern int  display_readchar(long int); /* Timeout is milliseconds */

/* Information about this display module */
typedef struct
{
  /* Flags */
  int status_line;
  int can_split;
  int variable_font;
  int colours;
  int boldface;
  int italic;
  int fixed_space;
  int sound_effects;
  int timed_input;
  int mouse;

  int lines, columns;
  int width, height;
  int font_width, font_height;

  int pictures;
  int fore, back;

  unsigned int fore_true, back_true;
} ZDisplay;
extern ZDisplay* display_get_info(void);

/* Display attribute functions */

extern void display_set_title(const char* title);
extern void display_update   (void);

/* Version 1-5 display */
extern void display_beep        (void);

extern void display_terminating (unsigned char* table);
extern int  display_get_mouse_x (void);
extern int  display_get_mouse_y (void);

/* Pixmap display */
extern int   display_init_pixmap    (int width, int height);
extern void  display_plot_rect      (int x, int y, 
				     int width, int height);
extern void  display_scroll_region   (int x, int y, 
				      int width, int height,
				      int xoff, int yoff);
extern void  display_pixmap_cols     (int fg, int bg);
extern int   display_get_pix_colour  (int x, int y);
extern void  display_plot_gtext      (const int*, int len, 
				      int style, int x, int y);
extern void  display_plot_image      (BlorbImage*, int x, int y);
extern float display_measure_text    (const int*, int len, int style);
extern float display_get_font_width  (int style);
extern float display_get_font_height (int style);
extern float display_get_font_ascent (int style);
extern float display_get_font_descent(int style);
extern void  display_wait_for_more   (void);

extern void  display_read_mouse      (void);
extern int   display_get_pix_mouse_b (void);
extern int   display_get_pix_mouse_x (void);
extern int   display_get_pix_mouse_y (void);

extern void  display_set_input_pos   (int style, int x, int y, int width);
extern void  display_set_mouse_win   (int x, int y, int width, int height);

extern void  display_flush			 (void);

#endif
