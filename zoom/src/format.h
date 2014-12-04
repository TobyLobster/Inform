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
 * General display formatting
 */

#ifndef __FORMAT_H
#define __FORMAT_H

#include "../config.h"
#include "rc.h"

# if WINDOW_SYSTEM == 3
#  undef FORMAT_ASSUME_BAD_MEASUREMENTS
# else
/*
 * Define this to make the formatting routine measure whole strings,
 * rather than assume that individual word measurements are
 * sufficient. Some systems (*cough*t1lib*cough*) don't measure spaces
 * at the end of words correctly. Defining this will correct any
 * errors that might result from this, at the expense of reduced
 * performance (which is only really an issue under Mac OS X, which
 * provides inadequate facilities for measuring the length of text)
 */
#  define FORMAT_ASSUME_BAD_MEASUREMENTS
# endif

#include "xfont.h"

/* Fonts */
extern xfont** font;
extern int     n_fonts;
extern int     style_font[16];

/* Z-Machine window layout */
struct word
{
  int           start;
  int           len;
  XFONT_MEASURE width;
  int           newline;
};

struct text
{
  int fg, bg;
  int font;

  int spacer;
  int space;
  int spoken;
  
  int len;
  int* text;
  
  struct text* next;

  int          nwords;
  struct word* word;
};

struct line
{
  struct text* start;
  int          n_chars;
  int          offset;
  XFONT_MEASURE baseline;
  XFONT_MEASURE ascent;
  XFONT_MEASURE descent;
  XFONT_MEASURE height;

  struct line* next;
};

struct cellline
{
  int* cell;
  int* fg;
  int* bg;
  unsigned char* font;
};

struct window
{
  int xpos, ypos;

  XFONT_MEASURE winsx, winsy;
  XFONT_MEASURE winlx, winly;

  int overlay;
  int force_fixed;
  int no_more;
  int no_scroll;

  int fore, back;
  int style;

  int winback;

  struct text* text;
  struct text* lasttext;
  
  struct line* line;
  struct line* topline;
  struct line* lastline;

  struct cellline* cline;
};

/* Window data structures themselves */
extern int cur_win;
extern struct window text_win[3];

#define CURWIN text_win[cur_win]
#define CURSTYLE (text_win[cur_win].style|(text_win[cur_win].force_fixed<<3))

/* Window parameters */
#define DEFAULTX 80
#define DEFAULTY 30
extern int size_x, size_y;
extern int max_x, max_y;

extern XFONT_MEASURE xfont_x;
extern XFONT_MEASURE xfont_y;
extern XFONT_MEASURE win_x;
extern XFONT_MEASURE win_y;
extern XFONT_MEASURE total_x;
extern XFONT_MEASURE total_y;
extern XFONT_MEASURE start_y;

extern int scroll_overlays;

#define DEFAULT_FORE rc_get_foreground()
#define DEFAULT_BACK rc_get_background()
//#define FIRST_ZCOLOUR 3

extern int more_on;
extern int displayed_text;

/* Speech */
extern char*         nextspeech;
extern char*         lastspeech;

/* The caret */
extern int  caret_x, caret_y, caret_height;
extern int  input_x, input_y, input_width;
extern int  caret_on;
extern int  caret_shown;
extern int  caret_flashing;
extern int  insert;

/* Input and history buffers */

extern char* force_text;
extern int*  text_buf;
extern int   buf_offset;
extern int   max_buflen;
extern int   read_key;

typedef struct history_item
{
  int* string;
  struct history_item* next;
  struct history_item* last;
} history_item;
extern history_item* last_string;
extern history_item* history_pos;

/* Functions */

extern void format_last_text(int more);

/* External functions */
extern void display_update_region      (XFONT_MEASURE left,
					XFONT_MEASURE top,
					XFONT_MEASURE right,
					XFONT_MEASURE bottom);
extern void display_set_scroll_range   (XFONT_MEASURE top,
					XFONT_MEASURE bottom);
extern void display_set_scroll_region  (XFONT_MEASURE size);
extern void display_set_scroll_position(XFONT_MEASURE pos);

#endif
