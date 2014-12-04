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

#include "../config.h"

#if WINDOW_SYSTEM == 2

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#include <windows.h>
#include <commctrl.h>

#include "zmachine.h"
#include "display.h"
#include "zoomres.h"
#include "rc.h"
#include "hash.h"

#include "windisplay.h"
#include "xfont.h"

/***                           ----// 888 \\----                           ***/

static int process_events(long int, int*, int);

static char zoomClass[] = "ZoomWindowClass";
static HINSTANCE inst = NULL;

COLORREF wincolour[] =
{
  RGB(0xdd, 0xdd, 0xdd),
  RGB(0xaa, 0xaa, 0xaa),
  RGB(0xff, 0xff, 0xff),
  
  /* ZMachine colours start here */
  RGB(0x00, 0x00, 0x00),
  RGB(0xff, 0x00, 0x00),
  RGB(0x00, 0xff, 0x00),
  RGB(0xff, 0xff, 0x00),
  RGB(0x00, 0x00, 0xff),
  RGB(0xff, 0x00, 0xff),
  RGB(0x00, 0xff, 0xff),
  RGB(0xff, 0xff, 0xcc),

  RGB(0xbb, 0xbb, 0xbb),
  RGB(0x88, 0x88, 0x88),
  RGB(0x44, 0x44, 0x44)
};

#define DEFAULT_FORE 0
#define DEFAULT_BACK 7
#define FIRST_ZCOLOUR 3
#define FLASH_TIME 400

HBRUSH winbrush[14];
HPEN   winpen  [14];
HWND   mainwin;
#ifndef NO_STATUS_BAR
HWND   mainwinstat;
#endif
HDC    mainwindc;
HMENU  mainwinmenu;

HMENU  filemenu, optionmenu, helpmenu, screenmenu, fontmenu;

static xfont** font = NULL;
static int     n_fonts = 9;

static char*   fontlist[] =
{
  "'Helvetica' 10",
  "'Helvetica' 10 b",
  "'Helvetica' 10 i",
  "'Courier' 10",
  "font3",
  "'Helvetica' 10 ib",
  "'Courier' 10 fb",
  "'Courier' 10 fi",
  "'Courier' 10 fib"
};

static int style_font[16] = { 0, 1, 2, 5, 3, 6, 7, 8,
			      4, 4, 4, 4, 4, 4, 4, 4 };

struct text
{
  int fg, bg;
  int font;

  int spacer;
  int space;
  
  int len;
  int* text;
  
  struct text* next;
};

struct line
{
  struct text* start;
  int          n_chars;
  int          offset;
  int          baseline;
  int          ascent;
  int          descent;
  int          height;

  struct line* next;
};

struct cellline
{
  int*           cell;
  unsigned char* fg;
  unsigned char* bg;
  unsigned char* font;
};

struct window
{
  int xpos, ypos;

  int winsx, winsy;
  int winlx, winly;

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

int cur_win;
struct window text_win[3];
static int    nShow;

#define CURWIN text_win[cur_win]
#define CURSTYLE (text_win[cur_win].style|(text_win[cur_win].force_fixed<<8))

#define DEFAULTX 80
#define DEFAULTY 30
static int size_x, size_y;
static int max_x,  max_y;

int xfont_x = 0;
int xfont_y = 0;
static int win_x, win_y;
static int total_x, total_y;
static int start_y;

static int  caret_x, caret_y, caret_height;
static int  input_x, input_y;
static int  caret_on = 0;
static int  caret_shown = 0;
static int  caret_flashing = 0;
static int  insert = 1;
static HPEN caret_pen;
static int  initialised = 0;

static int  timed_out = 0;

static int*  text_buf = NULL;
static int   buf_offset;

static int   more_on = 0;
static int   displayed_text = 0;

typedef struct history_item
{
  int* string;
  struct history_item* next;
  struct history_item* last;
} history_item;
static history_item* last_string = NULL;

static void draw_input_text(HDC dc);
static void update_status_text(void);

static unsigned char terminating[256] =
{
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 
  0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0
};
static int click_x, click_y;

/***                           ----// 888 \\----                           ***/

static inline int istrlen(const int* string)
{
  int x = 0;

  while (string[x] != 0) x++;
  return x;
}

static inline void istrcpy(int* dest, const int* src)
{
  memcpy(dest, src, (istrlen(src)+1)*sizeof(int));
}

/***                           ----// 888 \\----                           ***/

static void size_window(void)
{
  RECT rct, clrct, strct;
  
  xfont_x = xfont_get_width(font[style_font[4]]);
  xfont_y = xfont_get_height(font[style_font[4]]);

  win_x = xfont_x*size_x;
  win_y = xfont_y*size_y;

  GetWindowRect(mainwin, &rct);
  GetClientRect(mainwin, &clrct);
#ifndef NO_STATUS_BAR
  GetWindowRect(mainwinstat, &strct);
#endif
  
  SetWindowPos(mainwin, HWND_TOP,
	       rct.top, rct.left,
	       win_x+8 + ((rct.right-rct.left)-clrct.right),
	       win_y+8 + ((rct.bottom-rct.top)-clrct.bottom)
#ifndef NO_STATUS_BAR
	       +(strct.bottom-strct.top)
#endif
	       , 0);

  total_x = win_x + 8;
  total_y = win_y + 8;
}

static void rejig_fonts(void)
{
  int x, y;
  rc_font* fonts;

  fonts = rc_get_fonts(&n_fonts);
 
  /* Allocate fonts */
  if (fonts == NULL)
    {
      font = realloc(font, sizeof(xfont*)*9);
      for (x=0; x<9; x++)
	{
	  font[x] = xfont_load_font(fontlist[x]);
	}
      n_fonts = 9;
    }
  else
    {
      int y;
      
      for (x=0; x<16; x++)
	style_font[x] = -1;
      
      font = realloc(font, sizeof(xfont*)*n_fonts);
      for (x=0; x<n_fonts; x++)
	{
	  font[x] = xfont_load_font(fonts[x].name);

	  for (y=0; y<fonts[x].n_attr; y++)
	    style_font[fonts[x].attributes[y]] = x;
	}
    }

  for (x=0; x<16; x++)
    {
      if (style_font[x] == -1)
	{
	  if (x == 0)
	    zmachine_fatal("No roman font defined");
	  if (x == 4)
	    zmachine_fatal("No fixed-pitch font defined");
	  if (x == 8)
	    zmachine_fatal("No symbolic font defined");

	  if (x<4)
	    style_font[x] = style_font[0];
	  else if (x<8)
	    style_font[x] = style_font[4];
	  else
	    style_font[x] = style_font[8];
	}
    }

  while (DeleteMenu(fontmenu, 0, MF_BYPOSITION));
  
  for (x=0; x<n_fonts; x++)
    {
      char f[256];

      sprintf(f, "Font %i (", x);

      for (y=0; y<fonts[x].n_attr; y++)
	{
	  int a;
	  a = fonts[x].attributes[y];

	  if (a==0)
	    strcat(f, "roman-");
	  if (a&1)
	    strcat(f, "bold-");
	  if (a&2)
	    strcat(f, "italic-");
	  if (a&4)
	    strcat(f, "fixed-");
	  if (a&8)
	    strcat(f, "symbolic-");

	  f[strlen(f)-1] = 0;

	  if (y+1 < fonts[x].n_attr)
	    strcat(f, ", ");
	}
      strcat(f, ")");
      
      AppendMenu(fontmenu, 0, IDM_FONTS+x, f);
    }
}

void display_initialise(void)
{
  int x;
  int n_cols;
  rc_colour* colours;

  for (x=0; x<3; x++)
    {
      text_win[x].text        = NULL;
      text_win[x].lasttext    = NULL;
      text_win[x].line        = NULL;
      text_win[x].topline     = NULL;
      text_win[x].lastline    = NULL;
      text_win[x].cline       = NULL;
    }
  
  colours = rc_get_colours(&n_cols);
  
  /* Allocate colours */
  if (colours == NULL)
    {
      for (x=3; x<14; x++)
	{
	  winbrush[x] = CreateSolidBrush(wincolour[x]);
	  winpen[x]   = CreatePen(PS_SOLID, 1, wincolour[x]);
	}
    }
  else
    {
      for (x=3; x<14; x++)
	{
	  if ((x-3)<n_cols)
	    {
	      wincolour[x] = RGB(colours[x-3].r,
				 colours[x-3].g,
				 colours[x-3].b);
	      winbrush[x] = CreateSolidBrush(RGB(colours[x-3].r,
						 colours[x-3].g,
						 colours[x-3].b));
	      winpen[x]   = CreatePen(PS_SOLID, 1, RGB(colours[x-3].r,
						       colours[x-3].g,
						       colours[x-3].b));
	    }
	  else
	    {
	      winbrush[x] = CreateSolidBrush(wincolour[x]);
	      winpen[x]   = CreatePen(PS_SOLID, 1, wincolour[x]);
	    }
	}
    }

  rejig_fonts();
  
  max_x = size_x = rc_get_xsize();
  max_y = size_y = rc_get_ysize();
 
  size_window();
 
  display_clear();

  initialised = 1;
  
  ShowWindow(mainwin, nShow);
  UpdateWindow(mainwin);
}

void display_reinitialise(void)
{
  int x;
  int n_cols;
  rc_colour* colours;
  
  /* Deallocate colours */
  for (x=3; x<14; x++)
    {
      DeleteObject(winbrush[x]);
      DeleteObject(winpen[x]);
    }

  /* Deallocate fonts */
  for (x=0; x<5; x++)
    xfont_release_font(font[x]);
  
  colours = rc_get_colours(&n_cols);
  
  /* Allocate colours */
  if (colours == NULL)
    {
      for (x=3; x<14; x++)
	{
	  winbrush[x] = CreateSolidBrush(wincolour[x]);
	  winpen[x]   = CreatePen(PS_SOLID, 1, wincolour[x]);
	}
    }
  else
    {
      for (x=3; x<14; x++)
	{
	  if ((x-3)<n_cols)
	    {
	      wincolour[x] = RGB(colours[x-3].r,
				 colours[x-3].g,
				 colours[x-3].b);
	      winbrush[x] = CreateSolidBrush(RGB(colours[x-3].r,
						 colours[x-3].g,
						 colours[x-3].b));
	      winpen[x]   = CreatePen(PS_SOLID, 1, RGB(colours[x-3].r,
						       colours[x-3].g,
						       colours[x-3].b));
	    }
	  else
	    {
	      winbrush[x] = CreateSolidBrush(wincolour[x]);
	      winpen[x]   = CreatePen(PS_SOLID, 1, wincolour[x]);
	    }
	}
    }

  rejig_fonts();
  
  max_x = size_x = rc_get_xsize();
  max_y = size_y = rc_get_ysize();
 
  size_window();
  display_clear();
}

void display_finalise(void)
{
  int x;
  
  /* Deallocate colours */
  for (x=3; x<14; x++)
    {
      DeleteObject(winbrush[x]);
      DeleteObject(winpen[x]);
    }

  /* Deallocate fonts */
  for (x=0; x<9; x++)
    xfont_release_font(font[x]);
}

/***                           ----// 888 \\----                           ***/

void display_clear(void)
{
  int x, y, z;

  displayed_text = 0;
  
  /* Clear the main text window */
  text_win[0].force_fixed = 0;
  text_win[0].overlay     = 0;
  text_win[0].no_more     = 0;
  text_win[0].no_scroll   = 0;
  text_win[0].fore        = DEFAULT_FORE+FIRST_ZCOLOUR;
  text_win[0].back        = DEFAULT_BACK+FIRST_ZCOLOUR;
  text_win[0].style       = 0;
  text_win[0].xpos        = 0;
  text_win[0].ypos        = win_y;
  text_win[0].winsx       = 0;
  text_win[0].winsy       = 0;
  text_win[0].winlx       = win_x;
  text_win[0].winly       = win_y;
  text_win[0].winback     = DEFAULT_BACK+FIRST_ZCOLOUR;

  start_y = text_win[0].ypos;

  /* Clear the overlay windows */
  for (x=1; x<3; x++)
    {
      text_win[x].force_fixed = 1;
      text_win[x].overlay     = 1;
      text_win[x].no_more     = 1;
      text_win[x].no_scroll   = 1;
      text_win[x].xpos        = 0;
      text_win[x].ypos        = 0;
      text_win[x].winsx       = 0;
      text_win[x].winsy       = 0;
      text_win[x].winlx       = win_x;
      text_win[x].winly       = 0;

      text_win[0].winback     = DEFAULT_BACK+FIRST_ZCOLOUR;
      text_win[x].fore        = DEFAULT_FORE+FIRST_ZCOLOUR;
      text_win[x].back        = DEFAULT_BACK+FIRST_ZCOLOUR;
      text_win[x].style       = 4;

      text_win[x].text        = NULL;
      text_win[x].line        = NULL;

      if (text_win[x].cline != NULL)
	{
	  for (y=0; y<max_y; y++)
	    {
	      free(text_win[x].cline[y].cell);
	      free(text_win[x].cline[y].fg);
	      free(text_win[x].cline[y].bg);
	      free(text_win[x].cline[y].font);
	    }
	  free(text_win[x].cline);
	}
      
      text_win[x].cline       = malloc(sizeof(struct cellline)*size_y);
	  
      for (y=0; y<size_y; y++)
	{
	  text_win[x].cline[y].cell = malloc(sizeof(int)*size_x);
	  text_win[x].cline[y].fg   = malloc(sizeof(char)*size_x);
	  text_win[x].cline[y].bg   = malloc(sizeof(char)*size_x);
	  text_win[x].cline[y].font = malloc(sizeof(char)*size_x);
	  
	  for (z=0; z<size_x; z++)
	    {
	      text_win[x].cline[y].cell[z] = ' ';
	      text_win[x].cline[y].fg[z]   = DEFAULT_BACK+FIRST_ZCOLOUR;
	      text_win[x].cline[y].bg[z]   = 255;
	      text_win[x].cline[y].font[z] = style_font[4];
	    }
	}
      
      max_x = size_x;
      max_y = size_y;
    }

  cur_win = 0;
  display_erase_window();
}

static void new_line(int more)
{
  struct line* line;
  RECT rct;

  if (CURWIN.lastline == NULL)
    {
      CURWIN.lastline = CURWIN.line = malloc(sizeof(struct line));

      CURWIN.line->start    = NULL;
      CURWIN.line->n_chars  = 0;
      CURWIN.line->offset   = 0;
      CURWIN.line->baseline =
	CURWIN.ypos + xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
      CURWIN.line->ascent   = xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
      CURWIN.line->descent  = xfont_get_descent(font[style_font[(CURSTYLE>>1)&15]]);
      CURWIN.line->height   = xfont_get_height(font[style_font[(CURSTYLE>>1)&15]]);
      CURWIN.line->next     = NULL;

      displayed_text = CURWIN.lastline->ascent + CURWIN.lastline->descent;
      
      return;
    }

  if (more != 0)
    {
      int distext;

      distext = CURWIN.lastline->ascent + CURWIN.lastline->descent;
      if (displayed_text+distext >= (CURWIN.winly - CURWIN.winsy))
	{
	  more_on = 1;
	  update_status_text();
	  display_readchar(0);
	  more_on = 0;
	  update_status_text();
	}
      displayed_text += distext;
    }

  rct.top    = CURWIN.lastline->baseline - CURWIN.lastline->ascent+4;
  rct.bottom = CURWIN.lastline->baseline + CURWIN.lastline->descent+4;
  rct.left   = 4;
  rct.right  = win_x+4;
  InvalidateRect(mainwin, &rct, 0);
  
  line = malloc(sizeof(struct line));

  line->start     = NULL;
  line->n_chars   = 0;
  line->baseline  = CURWIN.lastline->baseline+CURWIN.lastline->descent;
  line->baseline += xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
  line->ascent    = xfont_get_ascent(font[style_font[(CURSTYLE>>1)&15]]);
  line->descent   = xfont_get_descent(font[style_font[(CURSTYLE>>1)&15]]);
  line->height    = xfont_get_height(font[style_font[(CURSTYLE>>1)&15]]);
  line->next      = NULL;

  CURWIN.lastline->next = line;
  CURWIN.lastline = line;

  CURWIN.xpos = 0;
  CURWIN.ypos = line->baseline - line->ascent;

  if (line->baseline+line->descent > CURWIN.winly)
    {
      int toscroll;
      struct line* l;
      int x, y;

      toscroll = (line->baseline+line->descent)-CURWIN.winly;
      l = CURWIN.line;

      /* Scroll the lines upwards */
      while (l != NULL)
	{
	  l->baseline -= toscroll;
	  l = l->next;
	}

      /* Scroll the overlays upwards */
      for (y=CURWIN.winsy/xfont_y;
	   y<(size_y-1);
	   y++)
	{
	  for (x=0; x<max_x; x++)
	    {
	      text_win[2].cline[y].cell[x] = text_win[2].cline[y+1].cell[x];
	      text_win[2].cline[y].font[x] = text_win[2].cline[y+1].font[x];
	      text_win[2].cline[y].fg[x]   = text_win[2].cline[y+1].fg[x];
	      text_win[2].cline[y].bg[x]   = text_win[2].cline[y+1].bg[x];
	    }
	}
      
      for (x=0; x<max_x; x++)
	{
	  text_win[2].cline[size_y-1].cell[x] = ' ';
	  text_win[2].cline[size_y-1].font[x] = style_font[4];
	  text_win[2].cline[size_y-1].fg[x]   = DEFAULT_BACK+FIRST_ZCOLOUR;
	  text_win[2].cline[size_y-1].bg[x]   = 255;
	}

      display_update();
    }
}

static void format_last_text(int more)
{
  int x;
  struct text* text;
  int word_start, word_len, total_len, xpos;
  xfont* fn;
  struct line* line;
  RECT rct;
  
  text = CURWIN.lasttext;

  fn = font[text->font];

  if (CURWIN.lastline == NULL)
    {
      new_line(more);
    }

  if (text->spacer)
    {
      line = CURWIN.lastline;
      
      new_line(more);

      CURWIN.lastline->descent = 0;
      CURWIN.lastline->baseline =
	line->baseline+line->descent+text->space;
      CURWIN.lastline->ascent = text->space;

      new_line(more);
    }
  else
    {
      word_start = 0;
      word_len   = 0;
      total_len  = 0;
      xpos       = CURWIN.xpos;
      line       = CURWIN.lastline;
      
      /*
       * Move the other lines to make room if this font is bigger than
       * ones previously used on this line
       */
      if (CURWIN.lastline->ascent < xfont_get_ascent(font[text->font]))
	{
	  int toscroll;
	  struct line* l;
	  
	  toscroll = xfont_get_ascent(font[text->font]) - CURWIN.lastline->ascent;
	  
	  l = CURWIN.line;
	  while (l != CURWIN.lastline)
	    {
	      if (l == NULL)
		zmachine_fatal("Programmer is a spoon");
	      
	      l->baseline -= toscroll;
	      l = l->next;
	    }
	  if (more != 0)
	    displayed_text += toscroll;
	  CURWIN.lastline->ascent = xfont_get_ascent(font[text->font]);
	  display_update();
	}
      
      /*
       * Ditto
       */
      if (CURWIN.lastline->descent < xfont_get_descent(font[text->font]))
	{
	  int toscroll;
	  
	  toscroll = xfont_get_descent(font[text->font]) -
	    CURWIN.lastline->descent;
	  if (CURWIN.lastline->baseline+xfont_get_descent(font[text->font]) 
	      > CURWIN.winly)
	    {
	      struct line* l;
	      
	      l = CURWIN.line;
	      
	      while (l != NULL)
		{
		  l->baseline -= toscroll;
		  l = l->next;
		}
	      
	      display_update();
	    }
	  
	  if (more != 0)
	    displayed_text += toscroll;
	  CURWIN.lastline->descent = xfont_get_descent(font[text->font]);
	}
      
      for (x=0; x<text->len;)
	{
	  if (text->text[x] == ' '  ||
	      text->text[x] == '\n' ||
	      x == (text->len-1))
	    {
	      int w;
	      int nl;

	      nl = 0;
	      do
		{
		  if (text->text[x] == '\n')
		    {
		      nl = 1;
		      break;
		    }
		  x++;
		  word_len++;
		}
	      while (!nl &&
		     (x < text->len &&
		      (text->text[x] == ' ' ||
		       text->text[x] == '\n')));
	      
	      w = xfont_get_text_width(fn,
				       text->text + word_start,
				       word_len);
	      
	      /* We've got a word */
	      xpos += w;
	      
	      if (xpos > CURWIN.winlx)
		{
		  /* Put this word on the next line */
		  new_line(more);
		  
		  xpos = CURWIN.xpos + w;
		  line = CURWIN.lastline;
		}
	      
	      if (line->start == NULL)
		{
		  line->offset = word_start;
		  line->start = text;
		}
	      line->n_chars += word_len;
	      
	      word_start += word_len;
	      total_len  += word_len;
	      word_len    = 0;
	      
	      if (nl)
		{
		  new_line(more);
		  
		  x++;
		  total_len++;
		  word_start++;
		  
		  xpos = CURWIN.xpos;
		  line = CURWIN.lastline;
		}
	    }
	  else
	    {
	      word_len++;
	      x++;
	    }
	}
      
      CURWIN.xpos = xpos;
    }
  
  rct.top    = CURWIN.lastline->baseline - CURWIN.lastline->ascent+4;
  rct.bottom = CURWIN.lastline->baseline + CURWIN.lastline->descent+4;
  rct.left   = 4;
  rct.right  = win_x+4;
  InvalidateRect(mainwin, &rct, 0);
}

void display_prints(const int* str)
{
  if (CURWIN.overlay)
    {
      int x;
      RECT rct;
      int sx;

      if (CURWIN.xpos >= max_x)
	CURWIN.xpos = max_x-1;
      if (CURWIN.xpos < 0)
	CURWIN.xpos = 0;
      if (CURWIN.ypos >= max_y)
	CURWIN.ypos = max_y-1;
      if (CURWIN.ypos < 0)
	CURWIN.ypos = 0;
      
      CURWIN.style |= 8;
      sx = CURWIN.xpos;
      
      /* Is an overlay window */
      for (x=0; str[x] != 0; x++)
	{
	  if (str[x] > 31)
	    {
	      if (CURWIN.xpos >= size_x)
		{
		  rct.top = CURWIN.ypos*xfont_y+4;
		  rct.bottom = CURWIN.ypos*xfont_y+4+xfont_y;
		  rct.left   = sx*xfont_x+4;
		  rct.right  = win_x+4;
		  InvalidateRect(mainwin, &rct, 0);
		  sx = 0;
		  
		  CURWIN.xpos = 0;
		  CURWIN.ypos++;
		}
	      if (CURWIN.ypos >= size_y)
		{
		  CURWIN.ypos = size_y-1;
		}

	      CURWIN.cline[CURWIN.ypos].cell[CURWIN.xpos] = str[x];
	      if (CURWIN.style&1)
		{
		  CURWIN.cline[CURWIN.ypos].fg[CURWIN.xpos]   = CURWIN.back;
		  CURWIN.cline[CURWIN.ypos].bg[CURWIN.xpos]   = CURWIN.fore;
		}
	      else
		{
		  CURWIN.cline[CURWIN.ypos].fg[CURWIN.xpos]   = CURWIN.fore;
		  CURWIN.cline[CURWIN.ypos].bg[CURWIN.xpos]   = CURWIN.back;
		}
	      CURWIN.cline[CURWIN.ypos].font[CURWIN.xpos] = style_font[(CURSTYLE>>1)&15];
	      
	      CURWIN.xpos++;
	    }
	  else
	    {
	      switch (str[x])
		{
		case 10:
		case 13:
		  rct.top = CURWIN.ypos*xfont_y+4;
		  rct.bottom = CURWIN.ypos*xfont_y+4+xfont_y;
		  rct.left   = sx*xfont_x+4;
		  rct.right  = CURWIN.xpos*xfont_x+4;
		  InvalidateRect(mainwin, &rct, 0);

		  sx = 0;
		  CURWIN.xpos = 0;
		  CURWIN.ypos++;
		  
		  if (CURWIN.ypos >= size_y)
		    {
		      CURWIN.ypos = size_y-1;
		    }
		  break;
		}
	    }
	}

      rct.top = CURWIN.ypos*xfont_y+4;
      rct.bottom = CURWIN.ypos*xfont_y+4+xfont_y;
      rct.left   = sx*xfont_x+4;
      rct.right  = CURWIN.xpos*xfont_x+4;
      InvalidateRect(mainwin, &rct, 0);
    }
  else
    {
      struct text* text;

      if (str[0] == 0)
	return;

      text = malloc(sizeof(struct text));

      if (CURWIN.style&1)
	{
	  text->fg   = CURWIN.back;
	  text->bg   = CURWIN.fore;
	}
      else
	{
	  text->fg   = CURWIN.fore;
	  text->bg   = CURWIN.back;
	}
      text->spacer = 0;
      text->font   = style_font[(CURSTYLE>>1)&15];
      text->len    = istrlen(str);
      text->text   = malloc(sizeof(int)*text->len);
      text->next   = NULL;
      memcpy(text->text, str, sizeof(int)*text->len);

      if (CURWIN.lasttext == NULL)
	{
	  CURWIN.text = text;
	  CURWIN.lasttext = text;
	}
      else
	{
	  CURWIN.lasttext->next = text;
	  CURWIN.lasttext = text;
	}

      format_last_text(-1);
    }
}

void display_prints_c(const char* str)
{
  int* txt;
  int x, len;

  txt = malloc((len=strlen(str))*sizeof(int)+sizeof(int));
  for (x=0; x<=len; x++)
    {
      txt[x] = str[x];
    }
  display_prints(txt);
  free(txt);
}

void display_printf(const char* format, ...)
{
  va_list  ap;
  char     string[512];
  int x,len;
  int      istr[512];

  va_start(ap, format);
  vsprintf(string, format, ap);
  va_end(ap);

  len = strlen(string);
  
  for (x=0; x<=len; x++)
    {
      istr[x] = string[x];
    }
  display_prints(istr);
}

/***                           ----// 888 \\----                           ***/

static int debug_console = 0;
static HANDLE console_buffer = INVALID_HANDLE_VALUE;
static int console_exit = 0;

static BOOL CALLBACK ctlHandler(DWORD ct)
{
  switch (ct)
    {
    case CTRL_C_EVENT:
    case CTRL_CLOSE_EVENT:
    case CTRL_BREAK_EVENT:
      return TRUE;

    default:
      return FALSE;
    }
}

static BOOL CALLBACK ctlExitHandler(DWORD ct)
{
  switch (ct)
    {
    case CTRL_C_EVENT:
    case CTRL_CLOSE_EVENT:
    case CTRL_BREAK_EVENT:
      console_exit = 1;
      ExitProcess(0);
      return TRUE;

    default:
      return FALSE;
    }
}

void printf_debug(char* format, ...)
{
  va_list  ap;
  char     string[512];

  va_start(ap, format);
  vsprintf(string, format, ap);
  va_end(ap);

  if (!debug_console)
    {
      if (!AllocConsole())
	{
	  FreeConsole();
	  AllocConsole();
	}

      SetConsoleTitle("Zoom debug information");
      debug_console = 1;
      console_buffer =
	CreateConsoleScreenBuffer(GENERIC_READ|GENERIC_WRITE,
				  FILE_SHARE_READ|FILE_SHARE_WRITE,
				  NULL,
				  CONSOLE_TEXTMODE_BUFFER,
				  NULL);
      SetConsoleCtrlHandler(ctlHandler, TRUE);
      SetConsoleActiveScreenBuffer(console_buffer);
    }

  if (console_buffer != INVALID_HANDLE_VALUE)
    {
      DWORD written;
      
      WriteConsole(console_buffer, string, strlen(string), &written, NULL);
    }
}

void printf_info(char* format, ...)
{
  va_list  ap;
  char     string[512];

  va_start(ap, format);
  vsprintf(string, format, ap);
  va_end(ap);

  if (!debug_console)
    {
      if (!AllocConsole())
	{
	  FreeConsole();
	  AllocConsole();
	}
      
      SetConsoleTitle("Zoom debug information");
      debug_console = 1;
      console_buffer =
	CreateConsoleScreenBuffer(GENERIC_READ|GENERIC_WRITE,
				  FILE_SHARE_READ|FILE_SHARE_WRITE,
				  NULL,
				  CONSOLE_TEXTMODE_BUFFER,
				  NULL);
      SetConsoleCtrlHandler(ctlHandler, TRUE);
      SetConsoleActiveScreenBuffer(console_buffer);
    }

  if (console_buffer != INVALID_HANDLE_VALUE)
    {
      DWORD written;
      
      WriteConsole(console_buffer, string, strlen(string), &written, NULL);
    }
}

void printf_info_done(void)
{
}

void display_exit(int code)
{
  CloseWindow(mainwin);

  if (debug_console)
    {
      printf_debug("\n\n(Close this window to exit)\n");
      SetConsoleCtrlHandler(ctlHandler, FALSE);
      if (SetConsoleCtrlHandler(ctlExitHandler, TRUE))
	{
	  MSG msg;
	  
	  while (!console_exit && GetMessage(&msg, NULL, 0, 0))
	    {
	      TranslateMessage(&msg);
	      DispatchMessage(&msg);
	    }
	}
    }
  
  exit(code);
}

static char* error = NULL;
void printf_error(char* format, ...)
{
  va_list  ap;
  char     string[512];

  va_start(ap, format);
  vsprintf(string, format, ap);
  va_end(ap);

  if (error == NULL)
    {
      error = malloc(strlen(string)+1);
      strcpy(error, string);
    }
  else
    {
      error = realloc(error, strlen(error)+strlen(string)+1);
      strcat(error, string);
    }
}

void printf_error_done(void)
{
  MessageBox(0, error, "Zoom - error", MB_ICONEXCLAMATION|MB_TASKMODAL);
  free(error);
  error = NULL;
}

/***                           ----// 888 \\----                           ***/

int display_readline(int* buf, int buflen, long int timeout)
{
  int result;

  displayed_text = 0;
  result = process_events(timeout, buf, buflen);

  return result;
}

int display_readchar(long int timeout)
{
  displayed_text = 0;
  return process_events(timeout, NULL, 0);
}

/***                           ----// 888 \\----                           ***/

ZDisplay* display_get_info(void)
{
  static ZDisplay dis;

  dis.status_line   = 1;
  dis.can_split     = 1;
  dis.variable_font = 1;
  dis.colours       = 1;
  dis.boldface      = 1;
  dis.italic        = 1;
  dis.fixed_space   = 1;
  dis.sound_effects = 0;
  dis.timed_input   = 1;
  dis.mouse         = 0;

  dis.lines   = size_y;
  dis.columns = size_x;
  dis.width   = size_x;
  dis.height  = size_y;
  dis.font_width  = 1;
  dis.font_height = 1;
  dis.pictures    = 0;
  dis.fore        = DEFAULT_FORE;
  dis.back        = DEFAULT_BACK;

  return &dis;
}

void display_set_title(const char* title)
{
  char* str;

  str = malloc(strlen(title)+strlen("Zoom " VERSION " - ")+1);
  strcpy(str, "Zoom " VERSION " - ");
  strcat(str, title);
  SetWindowText(mainwin, str);
}

void display_update(void)
{
  RECT rct;

  rct.top = rct.left = 4;
  rct.right  = win_x+4;
  rct.bottom = win_y+4;
  InvalidateRect(mainwin, &rct, 0);
}

/***                           ----// 888 \\----                           ***/

void display_set_colour(int fore, int back)
{
  if (fore == -1)
    fore = DEFAULT_FORE;
  if (back == -1)
    back = DEFAULT_BACK;
  if (fore == -2)
    fore = CURWIN.fore - FIRST_ZCOLOUR;
  if (back == -2)
    back = CURWIN.back - FIRST_ZCOLOUR;

  CURWIN.fore = fore + FIRST_ZCOLOUR;
  CURWIN.back = back + FIRST_ZCOLOUR;
}

void display_split(int lines, int window)
{
  text_win[window].winsx = CURWIN.winsx;
  text_win[window].winlx = CURWIN.winsx;
  text_win[window].winsy = CURWIN.winsy;
  text_win[window].winly = CURWIN.winsy + xfont_y*lines;
  text_win[window].xpos  = 0;
  text_win[window].ypos  = 0;

  CURWIN.topline = NULL;
  CURWIN.winsy += xfont_y*lines;
  if (CURWIN.ypos < CURWIN.winsy)
    {
      if (CURWIN.line == NULL)
	start_y = CURWIN.winsy;
      else
	{
	  CURWIN.lasttext->next   = malloc(sizeof(struct text));
	  CURWIN.lasttext         = CURWIN.lasttext->next;
	  CURWIN.lasttext->spacer = 1;
	  CURWIN.lasttext->space  = CURWIN.winsy -
	    (CURWIN.lastline->baseline + CURWIN.lastline->descent);
	  CURWIN.lasttext->len    = 0;
	  CURWIN.lasttext->text   = NULL;
	  CURWIN.lasttext->font   = style_font[CURSTYLE];

	  if (CURWIN.style&1)
	    {
	      CURWIN.lasttext->fg   = CURWIN.back;
	      CURWIN.lasttext->bg   = CURWIN.fore;
	    }
	  else
	    {
	      CURWIN.lasttext->fg   = CURWIN.fore;
	      CURWIN.lasttext->bg   = CURWIN.back;
	    }

	  format_last_text(0);
	}
      CURWIN.ypos = CURWIN.winsy;
    }
}

void display_join(int window1, int window2)
{
  if (text_win[window1].winsy != text_win[window2].winly)
    return; /* Windows can't be joined */
  text_win[window1].winsy = text_win[window2].winsy;
  text_win[window2].winly = text_win[window2].winsy;

  text_win[window1].topline = text_win[window2].topline = NULL;
}

void display_set_cursor(int x, int y)
{
  if (CURWIN.overlay)
    {
      CURWIN.xpos = x;
      CURWIN.ypos = y;
    }
  else
    {
      if (CURWIN.line != NULL)
	zmachine_fatal("Can't move the cursor in a non-overlay window when text has been printed");

      CURWIN.xpos = x*xfont_x;
      CURWIN.ypos = y*xfont_y;
      start_y = CURWIN.ypos;
    }
}

void display_set_gcursor(int x, int y)
{
  display_set_cursor(x,y);
}

void display_set_scroll(int scroll)
{
}

int display_get_gcur_x(void)
{
  return CURWIN.xpos;
}

int display_get_gcur_y(void)
{
  return CURWIN.ypos;
}

int display_get_cur_x(void)
{
  return CURWIN.xpos;
}

int display_get_cur_y(void)
{
  return CURWIN.ypos;
}

int display_set_font(int font)
{
  switch (font)
    {
    case -1:
      display_set_style(-16);
      break;

    default:
      break;
    }

  return 0;
}

int display_set_style(int style)
{
  int old_style;

  old_style = CURWIN.style;
  
  if (style == 0)
    CURWIN.style = 0;
  else
    {
      if (style > 0)
	CURWIN.style |= style;
      else
	CURWIN.style &= ~(-style);
    }

  return old_style;
}

void display_set_window(int window)
{
  text_win[window].fore  = CURWIN.fore;
  text_win[window].back  = CURWIN.back;
  text_win[window].style = CURWIN.style;
  cur_win = window;
}

int display_get_window(void)
{
  return cur_win;
}

void display_set_more(int window,
		      int more)
{
}

void display_erase_window(void)
{
  RECT rct;

  displayed_text = 0;
  
  if (CURWIN.overlay)
    {
      int x,y;
      
      for (y=0; y<(CURWIN.winly/xfont_y); y++)
	{
	  for (x=0; x<max_x; x++)
	    {
	      CURWIN.cline[y].cell[x] = ' ';
	      CURWIN.cline[y].fg[x]   = CURWIN.back;
	      CURWIN.cline[y].bg[x]   = 255;
	      CURWIN.cline[y].font[x] = style_font[4];
	    }
	}
    }
  else
    {
      struct text* text;
      struct text* nexttext;
      struct line* line;
      struct line* nextline;
      int x, y, z;

      text = CURWIN.text;
      while (text != NULL)
	{
	  nexttext = text->next;
	  free(text->text);
	  free(text);
	  text = nexttext;
	}
      CURWIN.text = CURWIN.lasttext = NULL;
      CURWIN.winback = CURWIN.back;

      line = CURWIN.line;
      while (line != NULL)
	{
	  nextline = line->next;
	  free(line);
	  line = nextline;
	}
      CURWIN.line = CURWIN.topline = CURWIN.lastline = NULL;
      
      for (y=(CURWIN.winsy/xfont_y); y<size_y; y++)
	{
	  for (x=0; x<max_x; x++)
	    {
	      for (z=1; z<=2; z++)
		{
		  text_win[z].cline[y].cell[x] = ' ';
		  text_win[z].cline[y].fg[x]   = FIRST_ZCOLOUR+DEFAULT_BACK;
		  text_win[z].cline[y].bg[x]   = 255;
		  text_win[z].cline[y].font[x] = style_font[4];
		}
	    }
	}
    }

  rct.top = 0;
  rct.left = 0;
  rct.right = total_x;
  rct.bottom = total_y;
  InvalidateRect(mainwin, &rct, 0);
}

void display_erase_line(int val)
{
  if (CURWIN.overlay)
    {
      int x;
      RECT rct;
      
      if (val == 1)
	val = size_x;
      else
	val += CURWIN.xpos;

      for (x=CURWIN.xpos; x<val; x++)
	{
	  CURWIN.cline[CURWIN.ypos].cell[x] = ' ';
	  CURWIN.cline[CURWIN.ypos].fg[x]   = CURWIN.back;
	  CURWIN.cline[CURWIN.ypos].bg[x]   = 255;
	  CURWIN.cline[CURWIN.ypos].font[x] = style_font[4];
	}

      rct.top = CURWIN.ypos*xfont_y;
      rct.left = 0;
      rct.right = total_x;
      rct.bottom = CURWIN.ypos*xfont_y+xfont_y+4;
      InvalidateRect(mainwin, &rct, 0);
    }
}

void display_force_fixed(int window,
			 int val)
{
  CURWIN.force_fixed = val;
}

/***                           ----// 888 \\----                           ***/

void display_terminating(unsigned char* table)
{
  int x;

  for (x=0; x<256; x++)
    terminating[x] = 0;

  if (table != NULL)
    {
      for (x=0; table[x] != 0; x++)
	{
	  terminating[table[x]] = 1;

	  if (table[x] == 255)
	    {
	      int y;

	      for (y=129; y<=154; y++)
		terminating[y] = 1;
	      for (y=252; y<255; y++)
		terminating[y] = 1;
	    }
	}
    }
}

int display_get_mouse_x(void)
{
  return click_x;
}

int display_get_mouse_y(void)
{
  return click_y;
}

/***                           ----// 888 \\----                           ***/

void display_beep(void)
{
}

/***                           ----// 888 \\----                           ***/

static inline int isect_rect(RECT* r1, RECT* r2)
{
  RECT tmp;

  if (IntersectRect(&tmp, r1, r2))
    return 1;
  else
    return 0;
}

static void draw_window(int win,
			HDC dc,
			RECT* rct)
{
  RECT drct;

  if (text_win[win].overlay)
    {
      int x, y;

      x = 0; y = 0;

      for (y=(text_win[win].winsy/xfont_y); y<size_y; y++)
	{
	  for (x=0; x<size_x; x++)
	    {
	      if (text_win[win].cline[y].cell[x] != ' ' ||
		  text_win[win].cline[y].bg[x]   != 255  ||
		  y*xfont_y<text_win[win].winly)
		{
		  int len;
		  int fn, fg, bg;

		  len = 1;
		  fg = text_win[win].cline[y].fg[x];
		  bg = text_win[win].cline[y].bg[x];
		  fn = text_win[win].cline[y].font[x];
		  
		  while (text_win[win].cline[y].font[x+len] == fn &&
			 text_win[win].cline[y].fg[x+len]   == fg &&
			 text_win[win].cline[y].bg[x+len]   == bg &&
			 (bg != 255 ||
			  text_win[win].cline[y].cell[x+len] != ' ' ||
			  y*xfont_y<text_win[win].winly))
		    len++;

		  if (bg == 255)
		    bg = fg;

		  drct.left   = x*xfont_x+4;
		  drct.top    = y*xfont_y+4;
		  drct.right  = drct.left+ xfont_x*len;
		  drct.bottom = drct.top + xfont_y;

		  if (isect_rect(rct, &drct))
		    {
		      xfont_set_colours(fg,
					bg);
		      xfont_plot_string(font[text_win[win].cline[y].font[x]],
					dc,
					drct.left,
					drct.top,
					&text_win[win].cline[y].cell[x],
					len);
		    }

		  x+=len-1;
		}
	    }

	  if (xfont_x*size_x < win_x &&
	      y*xfont_y<text_win[win].winly)
	    {
	      RECT frct;

	      frct.top    = y*xfont_y+4;
	      frct.left   = xfont_x*size_x+4;
	      frct.bottom = frct.top + xfont_y;
	      frct.right  = win_x+4;
	      FillRect(dc, &frct,
		       winbrush[text_win[win].cline[y].bg[size_x-1]]);
	    }
	}
    }
  else
    {
      RECT frct;
      
      struct line* line;
      struct text* text;

      struct text* lasttext;
      int lastchars, nchars, x, width, lasty;
      HRGN oldclip, newclip;
      int res;

      line = text_win[win].line;

      oldclip = CreateRectRgn(0,0,0,0);
      newclip = CreateRectRgn(4, text_win[win].winsy+4,
			      win_x+5, text_win[win].winly+5);
      res = GetClipRgn(dc, oldclip);
      if (res == 1)
	{
	  HRGN cl;

	  cl = CreateRectRgn(0,0,0,0);
	  CombineRgn(cl, oldclip, newclip, RGN_AND);
	  DeleteObject(newclip);
	  newclip = cl;
	}

      SelectClipRgn(dc, newclip);

      /* Free any lines that scrolled off ages ago */
      if (line != NULL)
	while (line->baseline < -1024)
	  {
	    struct line* n;

	    n = line->next;
	    if (n == NULL)
	      break;

	    if (text_win[win].topline == line)
	      text_win[win].topline = NULL;

	    if (n->start != line->start)
	      {
		struct text* nt;
		
		if (line->start != text_win[win].text)
		  zmachine_fatal("Programmer is a spoon");
		text_win[win].text = n->start;

		text = line->start;
		while (text != n->start)
		  {
		    if (text == NULL)
		      zmachine_fatal("Programmer is a spoon");
		    nt = text->next;
		    free(text);
		    text = nt;
		  }
	      }
	    
	    free(line);
	    text_win[win].line = n;

	    line = n;
	  }

      line = text_win[win].topline;
      if (line == NULL)
	line = text_win[win].line;
      lastchars = 0;
      lasttext = NULL;

      if (line != NULL)
	{
	  frct.top    = text_win[win].winsy+4;
	  frct.bottom = line->baseline - line->ascent+4;
	  frct.left   = 4;
	  frct.right  = 4+win_x;
	  if (frct.top < frct.bottom)
	    FillRect(dc, &frct, winbrush[text_win[win].winback]);

	  lasty = frct.bottom;
	}
      else
	lasty = text_win[win].winsy;
      
      while (line != NULL)
	{
	  width     = 0;
	  text      = line->start;
	  nchars    = line->offset;

	  if (text == NULL && line->n_chars > 0)
	    zmachine_fatal("Programmer is a spoon");

	  if (line->baseline + line->descent <= text_win[win].winsy)
	    {
	      text_win[win].topline = line->next;
	      line = line->next;
	      continue;
	    }
	  
	  for (x=0; x<line->n_chars;)
	    {
	      int w;
	      int toprint;

	      toprint = line->n_chars-x;
	      if (toprint > (text->len - nchars))
		toprint = text->len - nchars;

	      if (toprint > 0)
		{
		  if (text->text[toprint+nchars-1] == 10)
		    {
		      toprint--;
		      x++;
		    }

		  w = xfont_get_text_width(font[text->font],
					   text->text + nchars,
					   toprint);

		  drct.left   = width+4;
		  drct.top    = line->baseline-line->ascent+4;
		  drct.right  = drct.left+w;
		  drct.bottom = line->baseline+line->descent+4;

		  if (isect_rect(rct, &drct))
		    {
		      frct.top    = line->baseline - line->ascent+4;
		      frct.bottom = line->baseline -
			xfont_get_ascent(font[text->font])+4;
		      frct.left   = width+4;
		      frct.right  = width+w+4;
		      if (frct.top < frct.bottom)
			FillRect(dc, &frct, winbrush[text->bg]);
		      
		      xfont_set_colours(text->fg,
					text->bg);
		      xfont_plot_string(font[text->font],
					dc,
					width+4,
					line->baseline-
					xfont_get_ascent(font[text->font])+4,
					text->text + nchars,
					toprint);

		      frct.top    = line->baseline +
			xfont_get_descent(font[text->font])+4;
		      frct.bottom = line->baseline + line->descent+4;
		      frct.left   = width+4;
		      frct.right  = width+w+4;
		      if (frct.top < frct.bottom)
			FillRect(dc, &frct, winbrush[text->bg]);
		    }

		  x      += toprint;
		  nchars += toprint;
		  width  += w;
		}
	      else
		{
		  nchars = 0;
		  text   = text->next;
		}
	    }
	  
	  frct.top    = line->baseline-line->ascent+4;
	  frct.bottom = line->baseline+line->descent+4;
	  frct.left   = width+4;
	  frct.right  = win_x+4;
	  if (line->baseline+line->descent > text_win[win].winsy)
	    FillRect(dc, &frct, winbrush[text_win[win].winback]);
	      
	  lasty = frct.bottom;
	  
	  line = line->next;
	}

      frct.top    = lasty;
      frct.bottom = win_y+4;
      frct.left   = 4;
      frct.right  = 4+win_x;
      if (frct.top < frct.bottom)
	FillRect(dc, &frct, winbrush[text_win[win].winback]); 

      if (res == 1)
	{
	  SelectClipRgn(dc, oldclip);
	}
      else
	{
	  SelectClipRgn(dc, NULL);
	}
      DeleteObject(oldclip);
      DeleteObject(newclip);
    }
}

static void draw_caret(HDC dc)
{
  if ((caret_on^caret_shown))
    {
      HGDIOBJ lpen;
      HGDIOBJ lbrush;
      
      SetROP2(dc, R2_XORPEN);

      if (!insert && text_buf != NULL)
	{
	  int w;

	  w = xfont_get_text_width(font[style_font[CURSTYLE]],
				   text_buf + buf_offset,
				   1);
	  if (text_buf[buf_offset] == 0)
	    w = 3;

	  lpen   = SelectObject(dc, winpen[CURWIN.back]);
	  lbrush = SelectObject(dc, winbrush[CURWIN.back]);
	  Rectangle(dc,
		    caret_x+4, caret_y+4,
		    caret_x+4+w+1, caret_y+caret_height+5);
	  SelectObject(dc, lbrush);
	  SelectObject(dc, lpen);
	  
	  lpen   = SelectObject(dc, winpen[7]);
	  lbrush = SelectObject(dc, winbrush[7]);
	  Rectangle(dc,
		    caret_x+4, caret_y+4,
		    caret_x+4+w+1, caret_y+caret_height+5);
	  SelectObject(dc, lbrush);
	  SelectObject(dc, lpen);
	}
      else
	{
	  lpen   = SelectObject(dc, winpen[CURWIN.back]);
	  lbrush = SelectObject(dc, winbrush[CURWIN.back]);
	  Rectangle(dc,
		    caret_x+3, caret_y+4,
		    caret_x+5, caret_y+caret_height+5);
	  SelectObject(dc, lbrush);
	  SelectObject(dc, lpen);
	  
	  lpen   = SelectObject(dc, winpen[7]);
	  lbrush = SelectObject(dc, winbrush[7]);
	  Rectangle(dc,
		    caret_x+3, caret_y+4,
		    caret_x+5, caret_y+caret_height+5);
	  SelectObject(dc, lbrush);
	  SelectObject(dc, lpen);
	}
	  
      SetROP2(dc, R2_COPYPEN);
      caret_shown = !caret_shown;
    }
}

static void update_status_text(void)
{
#ifndef NO_STATUS_BAR
  SendMessage(mainwinstat,
	      SB_SETTEXT,
	      1,
	      (LPARAM) (LPSTR) (insert?"INS":"OVR"));
  SendMessage(mainwinstat,
	      SB_SETTEXT,
	      2,
	      (LPARAM) (LPSTR) (more_on?"[ MORE ]":""));
#endif
}

static void redraw_caret(void)
{
  draw_caret(mainwindc);
}

static void show_caret(void)
{
  caret_on = 1;
  redraw_caret();
}

static void hide_caret(void)
{
  caret_on = 0;
  redraw_caret();
}

static void flash_caret(void)
{
  caret_on = !caret_on;
  redraw_caret();
}

static void resize_window()
{
  RECT rct, srct;
  int owin;
  int x,y,z;

  int ofont_x, ofont_y;

  if (xfont_x == 0 || xfont_y == 0)
    return;

  ofont_x = xfont_x; ofont_y = xfont_y;
  xfont_x = xfont_get_width(font[style_font[4]]);
  xfont_y = xfont_get_height(font[style_font[4]]);

  if (xfont_x == 0 || xfont_y == 0)
    zmachine_fatal("Bad font selection");

  if (ofont_y != xfont_y)
    {
      int make_equal;
      
      for (x=1; x<3; x++)
	{
	  if (text_win[x].winly == text_win[0].winsy)
	    make_equal = 1;
	  else
	    make_equal = 0;

	  text_win[x].winsy = (text_win[x].winsy/ofont_y)*xfont_y;
	  text_win[x].winly = (text_win[x].winly/ofont_y)*xfont_y;
	  if (make_equal)
	    text_win[0].winsy = text_win[x].winsy;
	}
    }
    
  owin = cur_win;
  cur_win = 0;

  GetClientRect(mainwin, &rct);
#ifndef NO_STATUS_BAR
  GetWindowRect(mainwinstat, &srct);
#endif
  
  if (rct.bottom <= CURWIN.winsy)
    rct.bottom = CURWIN.winsy + xfont_y;
  
  total_x = rct.right;
#ifndef NO_STATUS_BAR
  total_y = rct.bottom - (srct.bottom - srct.top);
#else
  total_y = rct.bottom;
#endif
  
  size_x = (total_x-8)/xfont_x;
  size_y = (total_y-8)/xfont_y;

  win_x = total_x-8;
  win_y = total_y-8;

  /* Resize and reformat the overlay windows */
  for (x=1; x<=2; x++)
    {
      cur_win = x;
      
      if (size_y > max_y)
	{
	  CURWIN.cline = realloc(CURWIN.cline, sizeof(struct cellline)*size_y);

	  /* Allocate new rows */
	  for (y=max_y; y<size_y; y++)
	    {
	      CURWIN.cline[y].cell = malloc(sizeof(int)*max_x);
	      CURWIN.cline[y].fg   = malloc(sizeof(char)*max_x);
	      CURWIN.cline[y].bg   = malloc(sizeof(char)*max_x);
	      CURWIN.cline[y].font = malloc(sizeof(char)*max_x);

	      for (z=0; z<max_x; z++)
		{
		  CURWIN.cline[y].cell[z] = ' ';
		  CURWIN.cline[y].fg[z]   = CURWIN.cline[max_y-1].fg[z];
		  CURWIN.cline[y].bg[z]   = CURWIN.cline[max_y-1].bg[z];
		  CURWIN.cline[y].font[z] = style_font[4];
		}
	    }
	}
      
      if (size_x > max_x)
	{
	  /* Allocate new columns */
	  for (y=0; y<(max_y>size_y?max_y:size_y); y++)
	    {
	      CURWIN.cline[y].cell = realloc(CURWIN.cline[y].cell,
					     sizeof(int)*size_x);
	      CURWIN.cline[y].fg   = realloc(CURWIN.cline[y].fg,
					     sizeof(char)*size_x);
	      CURWIN.cline[y].bg   = realloc(CURWIN.cline[y].bg,
					     sizeof(char)*size_x);
	      CURWIN.cline[y].font = realloc(CURWIN.cline[y].font,
					     sizeof(char)*size_x);
	      for (z=max_x; z<size_x; z++)
		{
		  CURWIN.cline[y].cell[z] = ' ';
		  CURWIN.cline[y].fg[z]   = CURWIN.cline[y].fg[max_x-1];
		  CURWIN.cline[y].bg[z]   = CURWIN.cline[y].bg[max_x-1];
		  CURWIN.cline[y].font[z] = style_font[4];
		}
	    }
	}
    }

  if (size_x > max_x)
    max_x = size_x;
  if (size_y > max_y)
    max_y = size_y;
  
  /* Resize and reformat the text window */
  cur_win = 0;
  
  CURWIN.winlx = win_x;
  CURWIN.winly = win_y;

  if (CURWIN.line != NULL)
    {
      struct line* line;
      struct line* next;

      CURWIN.topline = NULL;
      
      CURWIN.ypos = CURWIN.line->baseline - CURWIN.line->ascent;
      CURWIN.xpos = 0;

      line = CURWIN.line;
      while (line != NULL)
	{
	  next = line->next;
	  free(line);
	  line = next;
	}

      CURWIN.line = CURWIN.lastline = NULL;

      if (CURWIN.text != NULL)
	{
	  CURWIN.lasttext = CURWIN.text;
	  while (CURWIN.lasttext->next != NULL)
	    {
	      format_last_text(0);
	      CURWIN.lasttext = CURWIN.lasttext->next;
	    }
	  format_last_text(0);
	}
    }
  
  /* Scroll more text onto the screen if we can */
  cur_win = 0;
  if (CURWIN.lastline != NULL)
    {
      if (CURWIN.lastline->baseline+CURWIN.lastline->descent < win_y)
	{
	  /* Scroll everything down */
	  int down;
	  struct line* l;

	  down = win_y -
	    (CURWIN.lastline->baseline+CURWIN.lastline->descent);

	  l = CURWIN.line;
	  while (l != NULL)
	    {
	      l->baseline += down;

	      l = l->next;
	    }
	}

      if (CURWIN.line->baseline-CURWIN.line->ascent > start_y)
	{
	  /* Scroll everything up */
	  int up;
	  struct line* l;

	  up = (CURWIN.line->baseline-CURWIN.line->ascent) - start_y;

	  l = CURWIN.line;
	  while (l != NULL)
	    {
	      l->baseline -= up;

	      l = l->next;
	    }
	}
    }

  draw_input_text(mainwindc);
  
  zmachine_resize_display(display_get_info());
  
  cur_win = owin;
}

static void draw_input_text(HDC dc)
{
  int w;
  int on;
  int fg, bg;

  fg = CURWIN.fore;
  bg = CURWIN.back;

  if (CURWIN.style&1)
    {
      fg = CURWIN.back;
      bg = CURWIN.fore;
    }

  on = caret_on;
  hide_caret();

  if (CURWIN.overlay)
    {
      input_x = caret_x = xfont_x*CURWIN.xpos;
      input_y = caret_y = xfont_y*CURWIN.ypos;
      caret_height = xfont_y;
    }
  else
    {
      if (CURWIN.lastline != NULL)
	{
	  input_x = caret_x = CURWIN.xpos;
	  input_y = caret_y = CURWIN.lastline->baseline-CURWIN.lastline->ascent;
	  caret_height = CURWIN.lastline->ascent+CURWIN.lastline->descent-1;
	}
      else
	{
	  input_x = input_y = caret_x = caret_y = 0;
	  caret_height = xfont_y-1;
	}
    }

  if (text_buf != NULL)
    {
      RECT rct;

      w = xfont_get_text_width(font[style_font[CURSTYLE]],
			       text_buf,
			       istrlen(text_buf));
      
      caret_x += xfont_get_text_width(font[style_font[CURSTYLE]],
				      text_buf,
				      buf_offset);

      rct.left = input_x + w +4;
      rct.right = win_x+4;
      rct.top   = input_y+4;
      rct.bottom = input_y+4+
	xfont_get_height(font[style_font[CURSTYLE]]);
      FillRect(mainwindc,
	       &rct,
	       winbrush[bg]);
      
      xfont_set_colours(fg, bg);
      xfont_plot_string(font[style_font[CURSTYLE]],
			mainwindc,
			input_x+4, input_y+4,
			text_buf,
			istrlen(text_buf));
    }

  if (on)
    show_caret();
}

static BOOL CALLBACK about_dlg(HWND hwnd,
			       UINT message,
			       WPARAM wparam,
			       LPARAM lparam)
{
  switch (message)
    {
    case WM_INITDIALOG:
      return TRUE;

    case WM_COMMAND:
      switch (LOWORD(wparam))
	{
	case IDC_OK:
	  EndDialog(hwnd, 0);
	  break;
	}
      break;
    }

  return FALSE;
}

extern hash rc_hash;

static BOOL CALLBACK game_dlg(HWND hwnd,
			      UINT message,
			      WPARAM wparam,
			      LPARAM lparam)
{
  char hash[20];
  rc_game* game;
  
  switch (message)
    {
    case WM_INITDIALOG:
      sprintf(hash, "%i.%.6s", Word(ZH_release), Address(ZH_serial));
      SendDlgItemMessage(hwnd, IDC_SERIAL, WM_SETTEXT,
			 0, (LPARAM) (LPCTSTR) hash);
      if ((game = hash_get(rc_hash, hash, strlen(hash))) == NULL)
	{
	  SendDlgItemMessage(hwnd, IDC_INBASE, WM_SETTEXT,
			     0, (LPARAM) (LPCTSTR)
			     "This game has no entry in the database");
	  SendDlgItemMessage(hwnd, IDC_OK, WM_SETTEXT,
			     0, (LPARAM) (LPCTSTR) "&Add");
	  SendDlgItemMessage(hwnd, IDC_TITLE, WM_SETTEXT,
			     0, (LPARAM) (LPCTSTR) "Untitled");
	}
      else
	{
	  SendDlgItemMessage(hwnd, IDC_INBASE, WM_SETTEXT,
			     0, (LPARAM) (LPCTSTR) "This game is already in the database");
	  SendDlgItemMessage(hwnd, IDC_OK, WM_SETTEXT,
			     0, (LPARAM) (LPCTSTR) "&Change");
	  SendDlgItemMessage(hwnd, IDC_TITLE, WM_SETTEXT,
			     0, (LPARAM) (LPCTSTR)
			     (game->name!=NULL?game->name:"Untitled"));
	}
      return TRUE;

    case WM_COMMAND:
      switch (LOWORD(wparam))
	{
	case IDC_CANCEL:
	case IDC_OK:
	  EndDialog(hwnd, 0);
	  break;
	}
      break;
    }

  return FALSE;
}

void display_int_apply(void)
{
  resize_window();
  display_update();
}

static LRESULT CALLBACK display_winproc(HWND hwnd,
					UINT message,
					WPARAM wparam,
					LPARAM lparam)
{
  switch (message)
    {
    case WM_PAINT:
      {
	RECT        rct;
	PAINTSTRUCT paint;
	HGDIOBJ     ob;

	BeginPaint(hwnd, &paint);
	
	draw_window(0, paint.hdc, &paint.rcPaint);
	draw_window(1, paint.hdc, &paint.rcPaint);
	draw_window(2, paint.hdc, &paint.rcPaint);

	if (text_buf != NULL)
	  {
	    xfont_set_colours(CURWIN.fore, CURWIN.back);
	    xfont_plot_string(font[style_font[CURSTYLE]],
			      paint.hdc,
			      input_x+4, input_y+4,
			      text_buf,
			      istrlen(text_buf));
	  }
	
	rct.left   = 0;
	rct.right  = 3;
	rct.top    = 0;
	rct.bottom = total_y+1;
	FillRect(paint.hdc, &rct, winbrush[0]);

	rct.left   = win_x+6;
	rct.right  = total_x+1;
	rct.top    = 0;
	rct.bottom = total_y+1;
	FillRect(paint.hdc, &rct, winbrush[0]);

	rct.left   = 0;
	rct.right  = total_x+1;
	rct.top    = 0;
	rct.bottom = 3;
	FillRect(paint.hdc, &rct, winbrush[0]);

	rct.left   = 0;
	rct.right  = total_x+1;
	rct.top    = win_y+6;
	rct.bottom = total_y+1;
	FillRect(paint.hdc, &rct, winbrush[0]);
	
	ob = SelectObject(paint.hdc, winpen[1]);
	MoveToEx(paint.hdc, 3, win_y+5, NULL);
	LineTo(paint.hdc, 3, 3);
	MoveToEx(paint.hdc, win_x+5, 3, NULL);
	LineTo(paint.hdc, 3, 3);
	SelectObject(paint.hdc, ob);

	ob = SelectObject(paint.hdc, winpen[2]);
	MoveToEx(paint.hdc, win_x+5, win_y+5, NULL);
	LineTo(paint.hdc, win_x+5, 3);
	MoveToEx(paint.hdc, win_x+5, win_y+5, NULL);
	LineTo(paint.hdc, 3, win_y+5);
	SelectObject(paint.hdc, ob);

	caret_shown = 0;
	draw_caret(paint.hdc);

	EndPaint(hwnd, &paint);
      }
      break;

    case WM_SIZE:
#ifndef NO_STATUS_BAR
      SendMessage(mainwinstat, WM_SIZE, 0, 0);
#endif
      if (initialised)
	resize_window();
      {
	RECT rct;
#define n_parts 3
	int parts[n_parts] = { 0, 30, 100 };
	int x;

	GetClientRect(mainwin, &rct);

	for (x=0; x<n_parts; x++)
	  parts[x] += rct.right - parts[n_parts-1];

#ifndef NO_STATUS_BAR
	SendMessage(mainwinstat, SB_SETPARTS, n_parts, (LPARAM) (LPINT) parts);
#endif
      }
      update_status_text();
      return DefWindowProc(hwnd, message, wparam, lparam);
      
    case WM_CLOSE:
      DestroyWindow(hwnd);
      break;

    case WM_TIMER:
      switch (wparam)
	{
	case 1:
	  if (caret_flashing)
	    {
	      flash_caret();
	    }
	  break;

	case 2:
	  timed_out = 1;
	  KillTimer(mainwin, 2);
	  break;
	  
	default:
	  zmachine_fatal("Unknown timer event type %i (Programmer is a spoon)", wparam);
	}
      break;

    case WM_COMMAND:
      switch (LOWORD(wparam))
	{
	case IDM_EXIT:
	  PostQuitMessage(0);
	  break;

	case IDM_GAME:
	  DialogBox(inst, MAKEINTRESOURCE(ID_GAME),
		    mainwin, game_dlg);
	  break;

	case IDM_ABOUT:
	  DialogBox(inst, MAKEINTRESOURCE(ID_ABOUT),
		    mainwin, about_dlg);
	  break;

	default:
	  if (LOWORD(wparam) >= IDM_FONTS && LOWORD(wparam) <= IDM_FONTS+50)
	    {
	      int fnum;
	      rc_font* fonts;

	      fonts = rc_get_fonts(&n_fonts);

	      fnum = LOWORD(wparam) - IDM_FONTS;
	      xfont_choose_new_font(font[fnum],
				    fonts[fnum].attributes[0]&4);
	      resize_window();
	      display_update();
	    }
	}
      break;

    case WM_DESTROY:
      PostQuitMessage(0);
      break;

    default:
      return DefWindowProc(hwnd, message, wparam, lparam);
    }
  return 0;
}

extern int zoom_main(int, char**);

int WINAPI WinMain(HINSTANCE hInst, 
		   HINSTANCE hPrev, 
		   LPSTR lpCmd,
		   int show)
{
  char** argv = NULL;
  int argc,x;

  WNDCLASSEX class;

  nShow = show;

#ifdef DEBUG
  debug_printf("Zoom " VERSION " compiled for Windows\n\n");
#endif
  
  /* Parse the command string */
  argv = malloc(sizeof(char*));
  argv[0] = malloc(sizeof(char)*strlen("zoom"));
  strcpy(argv[0], "zoom");
  argc = 1;
  for (x=0; lpCmd[x] != 0;)
    {
      int len;
      
      while (lpCmd[x] == ' ')
	x++;

      if (lpCmd[x] != 0)
	{
	  argv = realloc(argv,
			 sizeof(char*)*(argc+1));
	  argv[argc] = NULL;
	    
	  len = 0;
	  while (lpCmd[x] != ' ' &&
		 lpCmd[x] != 0)
	    {
	      argv[argc] = realloc(argv[argc],
				   sizeof(char)*(len+2));
	      argv[argc][len++] = lpCmd[x];
	      argv[argc][len]   = 0;
	      x++;
	    }

	  argc++;
	}
    }

  InitCommonControls();
  
  /* Allocate the three 'standard' brushes */
  wincolour[0] = GetSysColor(COLOR_3DFACE);
  wincolour[1] = GetSysColor(COLOR_3DSHADOW);
  wincolour[2] = GetSysColor(COLOR_3DHILIGHT);
  
  winbrush[0] = CreateSolidBrush(wincolour[0]);
  winbrush[1] = CreateSolidBrush(wincolour[1]);
  winbrush[2] = CreateSolidBrush(wincolour[2]);
  
  winpen[0] = CreatePen(PS_SOLID, 1, wincolour[0]);
  winpen[1] = CreatePen(PS_SOLID, 2, wincolour[1]);
  winpen[2] = CreatePen(PS_SOLID, 2, wincolour[2]);
  caret_pen = CreatePen(PS_SOLID, 2, RGB(220, 0, 0));
  
  /* Create the main Zoom window */
  inst = hInst;
  
  class.cbSize        = sizeof(WNDCLASSEX);
  class.style         = CS_HREDRAW|CS_VREDRAW|CS_DBLCLKS;
  class.lpfnWndProc   = display_winproc;
  class.cbClsExtra    = class.cbWndExtra = 0;
  class.hInstance     = hInst;
  class.hIcon         = LoadIcon(inst, "logo");
  class.hCursor       = LoadCursor(NULL, IDC_ARROW);
  class.hbrBackground = NULL;
  class.lpszMenuName  = NULL;
  class.lpszClassName = zoomClass;
  class.hIconSm       = LoadIcon(inst, MAKEINTRESOURCE(ID_SMICON));

  if (!RegisterClassEx(&class))
    {
      MessageBox(0, "Failed to register window class", "Error",
		 MB_ICONEXCLAMATION | MB_OK | MB_SYSTEMMODAL);
      return 0;
    }

  /* Create the menus that go with the Zoom window */
  filemenu    = CreatePopupMenu();
  optionmenu  = CreatePopupMenu();
  helpmenu    = CreatePopupMenu();
  screenmenu  = CreatePopupMenu();
  fontmenu    = CreatePopupMenu();
  mainwinmenu = CreateMenu();

  AppendMenu(filemenu, 0, IDM_EXIT, "E&xit");

  AppendMenu(optionmenu, 0, IDM_GAME, "&Game...");
  AppendMenu(optionmenu, MF_POPUP, (UINT) screenmenu, "&Screen");
  AppendMenu(optionmenu, 0, IDM_INTERPRETER, "&Interpreter...");
  AppendMenu(optionmenu, MF_SEPARATOR, 0, NULL);
  AppendMenu(optionmenu, 0, IDM_SAVEOPTS, "&Save options");

  AppendMenu(screenmenu, 0, IDM_COLOURS, "&Colours...");
  AppendMenu(screenmenu, 0, IDM_LAYOUT, "&Layout...");
  AppendMenu(screenmenu, MF_POPUP, (UINT) fontmenu, "&Fonts");

  AppendMenu(helpmenu, 0, IDM_ABOUT, "&About...");

  AppendMenu(mainwinmenu, MF_POPUP, (UINT) filemenu, "&File");
  AppendMenu(mainwinmenu, MF_POPUP, (UINT) optionmenu, "&Options");
  AppendMenu(mainwinmenu, MF_POPUP, (UINT) helpmenu, "&Help");

  /* Actually create the window */
  mainwin = CreateWindowEx(0,
			   zoomClass,
			   "Zoom " VERSION,
			   WS_OVERLAPPEDWINDOW,
			   CW_USEDEFAULT, CW_USEDEFAULT,
			   100, 100,
			   NULL, NULL,
			   inst, NULL);
  mainwindc = GetDC(mainwin);

  SetMenu(mainwin, mainwinmenu);

#ifndef NO_STATUS_BAR
  mainwinstat = CreateStatusWindow(WS_CHILD|WS_VISIBLE,
				   "",
				   mainwin,
				   0x57a75);
  SendMessage(mainwinstat,
	      SB_SETTEXT,
	      0|SBT_NOBORDERS,
	      (LPARAM) (LPSTR) "Zoom " VERSION);
#endif
  
  SetTimer(mainwin, 1, FLASH_TIME, NULL);
  
  zoom_main(argc, argv);
  
  return 0;
}

#define event_return(x) \
   { \
     KillTimer(mainwin, 2); \
     return x; \
     hide_caret(); \
     caret_flashing = 0; \
   }
static int process_events(long int timeout,
			  int* buf,
			  int  buflen)
{
  MSG msg;
  history_item*  history = NULL;

  if (!more_on)
    caret_flashing = 1;
  else
    {
      hide_caret();
      caret_flashing = 0;
    }

  KillTimer(mainwin, 2);
  timed_out = 0;
  if (timeout > 0)
    SetTimer(mainwin, 2, timeout, 0);

  if (buf != NULL)
    {
      text_buf = buf;
      buf_offset = istrlen(buf);
    }
  
  draw_input_text(mainwindc);
  
  while (GetMessage(&msg, NULL, 0, 0))
    {
      if (msg.hwnd == mainwin)
	{
	  switch (msg.message)
	    {
	    case WM_KEYDOWN:
	      if (buf == NULL)
		{
		  switch (msg.wParam)
		    {
		    case VK_BACK:
		    case VK_DELETE:
		      event_return(8);

		    case VK_RETURN:
		      event_return(13);

		    case VK_UP:
		      event_return(129);
		    case VK_DOWN:
		      event_return(130);
		    case VK_LEFT:
		      event_return(131);
		    case VK_RIGHT:
		      event_return(132);

		    case VK_F1:
		      event_return(133);
		    case VK_F2:
		      event_return(134);
		    case VK_F3:
		      event_return(135);
		    case VK_F4:
		      event_return(136);
		    case VK_F5:
		      event_return(137);
		    case VK_F6:
		      event_return(138);
		    case VK_F7:
		      event_return(139);
		    case VK_F8:
		      event_return(140);
		    case VK_F9:
		      event_return(141);
		    case VK_F10:
		      event_return(142);
		    case VK_F11:
		      event_return(143);
		    case VK_F12:
		      event_return(144);

		    case VK_NUMPAD0:
		      event_return(145);
		    case VK_NUMPAD1:
		      event_return(146);
		    case VK_NUMPAD2:
		      event_return(147);
		    case VK_NUMPAD3:
		      event_return(148);
		    case VK_NUMPAD4:
		      event_return(149);
		    case VK_NUMPAD5:
		      event_return(150);
		    case VK_NUMPAD6:
		      event_return(151);
		    case VK_NUMPAD7:
		      event_return(152);
		    case VK_NUMPAD8:
		      event_return(153);
		    case VK_NUMPAD9:
		      event_return(154);
		      
		    default:
		      TranslateMessage(&msg);
		    }
		}
	      else
		{
		  switch (msg.wParam)
		    {
		    case VK_INSERT:
		      {
			int on;

			on = caret_on;
			hide_caret();
			insert = !insert;
			update_status_text();
			if (on)
			  show_caret();
		      }
		      break;
		      
		    case VK_LEFT:
		      if (buf_offset > 0)
			buf_offset--;
		      draw_input_text(mainwindc);
		      break;
		    case VK_RIGHT:
		      if (buf_offset < istrlen(buf))
			buf_offset++;
		      draw_input_text(mainwindc);
		      break;

		    case VK_BACK:
		    case VK_DELETE:
		      if (buf_offset > 0)
			{
			  int  x;
			  
			  for (x=buf_offset-1; buf[x] != 0; x++)
			    {
			      buf[x] = buf[x+1];
			    }
			  buf_offset--;

			  draw_input_text(mainwindc);
			}
		      break;

		    case VK_UP:
		      if (history == NULL)
			history = last_string;
		      else
			if (history->next != NULL)
			  history = history->next;
		      if (history != NULL)
			{
			  if (istrlen(history->string) < buflen)
			    istrcpy(buf, history->string);

			  buf_offset = istrlen(buf);
			}

		      draw_input_text(mainwindc);
		      break;

		    case VK_DOWN:
		      if (history != NULL)
			{
			  history = history->last;
			  if (history != NULL)
			    {
			      if (istrlen(history->string) < buflen)
				istrcpy(buf, history->string);
			      buf_offset = istrlen(buf);
			    }
			  else
			    {
			      buf[0] = 0;
			      buf_offset = 0;
			    }
			}

		      draw_input_text(mainwindc);
		      break;
		      
		    case VK_RETURN:
		      {
			history_item* newhist;
			
			newhist = malloc(sizeof(history_item));
			newhist->last = NULL;
			newhist->next = last_string;
			if (last_string)
			  last_string->last = newhist;
			newhist->string = malloc(sizeof(int)*(istrlen(buf)+1));
			istrcpy(newhist->string, buf);
			last_string = newhist;
		      }
		      
		      text_buf = NULL;
		      display_prints(buf);
		      display_prints_c("\n");
		      event_return(10);

		    case VK_F1:
		      if (terminating[133])
			{
			  event_return(133);
			}
		      break;
		    case VK_F2:
		      if (terminating[134])
			{
			  event_return(134);
			}
		      break;
		    case VK_F3:
		      if (terminating[135])
			{
			  event_return(135);
			}
		      break;
		    case VK_F4:
		      if (terminating[136])
			{
			  event_return(136);
			}
		      break;
		    case VK_F5:
		      if (terminating[137])
			{
			  event_return(137);
			}
		      break;
		    case VK_F6:
		      if (terminating[138])
			{
			  event_return(138);
			}
		      break;
		    case VK_F7:
		      if (terminating[139])
			{
			  event_return(139);
			}
		      break;
		    case VK_F8:
		      if (terminating[140])
			{
			  event_return(140);
			}
		      break;
		    case VK_F9:
		      if (terminating[141])
			{
			  event_return(141);
			}
		      break;
		    case VK_F10:
		      if (terminating[142])
			{
			  event_return(142);
			}
		      break;
		    case VK_F11:
		      if (terminating[143])
			{
			  event_return(143);
			}
		      break;
		    case VK_F12:
		      if (terminating[144])
			{
			  event_return(144);
			}
		      break;
		      
		    default:
		      TranslateMessage(&msg);
		    }
		}
	      break;

	    case WM_LBUTTONDOWN:
	      if (terminating[254] || buf == NULL)
		{
		  click_x = (LOWORD(msg.lParam)-4)/xfont_x;
		  click_y = (HIWORD(msg.lParam)-4)/xfont_y;

		  event_return(254);
		}
	      break;
	      
	    case WM_CHAR:
	      if (buf == NULL)
		{
		  event_return(msg.wParam);
		}
	      else
		{
		  if (buf[buf_offset] == 0 &&
		      buf_offset < buflen)
		    { 
		      buf[buf_offset++] = msg.wParam;
		      buf[buf_offset] = 0;
		    }
		  else
		    {
		      if ((insert && buf_offset < buflen-1) ||
			  !insert)
			{
			  if (insert)
			    {
			      int x;
			      
			      for (x=istrlen(buf); x>=buf_offset; x--)
				{
				  buf[x+1] = buf[x];
				}
			    }

			  buf[buf_offset] = msg.wParam;
			  buf_offset++;
			}
		    }

		  draw_input_text(mainwindc);
		}
	      break;

	    default:
	      DispatchMessage(&msg);
	    }
	}
      else
	DispatchMessage(&msg);

      if (timed_out)
	event_return(0);
    }

  display_exit(0);
}

#endif
