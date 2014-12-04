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
 * When using format.c, these display functions do not need to use
 * architechture-specific functions
 */

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "zmachine.h"
#include "display.h"
#include "format.h"

#include "v6display.h"

static int is_v6 = 0;

#if defined(V6ASSERT) && defined(SUPPORT_VERSION_6)
# define NOTV6 if (is_v6) { zmachine_fatal("Non-v6 function called when v6 display is active"); }
#else
# define NOTV6
#endif

/* Misc functions */

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

/* Output functions */

void display_is_v6(void)
{
  is_v6 = 1;
}

void display_clear(void)
{
  int x, y, z;

  NOTV6;

  displayed_text = 0;

  /* Clear the main text window */
  text_win[0].force_fixed = 0;
  text_win[0].overlay     = 0;
  text_win[0].no_more     = 0;
  text_win[0].no_scroll   = 0;
  text_win[0].fore        = DEFAULT_FORE;
  text_win[0].back        = DEFAULT_BACK;
  text_win[0].style       = 0;
  text_win[0].xpos        = 0;
  text_win[0].ypos        = 16384;
  text_win[0].winsx       = 0;
  text_win[0].winsy       = 0;
  text_win[0].winlx       = win_x;
  text_win[0].winly       = win_y;
  text_win[0].winback     = DEFAULT_BACK;

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

      text_win[0].winback     = DEFAULT_BACK;
      text_win[x].fore        = DEFAULT_FORE;
      text_win[x].back        = DEFAULT_BACK;
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
	  text_win[x].cline[y].fg   = malloc(sizeof(int)*size_x);
	  text_win[x].cline[y].bg   = malloc(sizeof(int)*size_x);
	  text_win[x].cline[y].font = malloc(sizeof(char)*size_x);
	  
	  for (z=0; z<size_x; z++)
	    {
	      text_win[x].cline[y].cell[z] = ' ';
	      text_win[x].cline[y].fg[z]   = DEFAULT_BACK;
	      text_win[x].cline[y].bg[z]   = -DEFAULT_BACK-1;
	      text_win[x].cline[y].font[z] = style_font[4];
	    }
	}
      
      max_x = size_x;
      max_y = size_y;
    }

  cur_win = 0;
  display_erase_window();
}

void display_erase_window(void)
{
  NOTV6;

  displayed_text = 0;
  
  if (CURWIN.overlay)
    {
      int x,y;

      /* Blank an overlay window */
      CURWIN.winback = CURWIN.back;

      for (y=0; y<(CURWIN.winly/xfont_y); y++)
	{
	  for (x=0; x<max_x; x++)
	    {
	      CURWIN.cline[y].cell[x] = ' ';
	      CURWIN.cline[y].fg[x]   = CURWIN.back;
	      CURWIN.cline[y].bg[x]   = -CURWIN.back-1;
	      CURWIN.cline[y].font[x] = style_font[4];
	    }
	}
    }
  else
    {
      /* Blank a proportional text window */
      struct text* text;
      struct text* nexttext;
      struct line* line;
      struct line* nextline;
      int x, y, z;

      display_set_scroll_region(0);
      display_set_scroll_range(0, 0);
      display_set_scroll_position(0);
      
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
		  text_win[z].cline[y].fg[x]   = DEFAULT_BACK;
		  text_win[z].cline[y].bg[x]   = -DEFAULT_BACK-1;
		  text_win[z].cline[y].font[x] = style_font[4];
		}
	    }
	}
    }

  /* Redraw the main window */
  display_update_region(0,0, win_x, win_y);
}

void display_prints(const int* str)
{
#ifdef SUPPORT_VERSION_6
  if (is_v6)
    {
      v6_prints(str);
      return;
    }
#endif

  NOTV6;

#ifdef DEBUG
  {
    int x;

    printf_debug("Display: >");
    for (x=0; str[x] != 0; x++)
      printf_debug("%c", str[x]);
    printf_debug("<\n");
  }
#endif

  if (CURWIN.overlay)
    {
      int x;
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
		  display_update_region(sx*xfont_x,
					CURWIN.ypos*xfont_y,
					win_x,
					CURWIN.ypos*xfont_y+xfont_y);
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
		  display_update_region(sx*xfont_x,
					CURWIN.ypos*xfont_y,
					CURWIN.xpos*xfont_x,
					CURWIN.ypos*xfont_y+xfont_y);

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

      display_update_region(sx*xfont_x,
			    CURWIN.ypos*xfont_y,
			    CURWIN.xpos*xfont_x,
			    CURWIN.ypos*xfont_y+xfont_y);
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
      text->word   = NULL;
      text->spoken = 0;
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

void display_printc(int ch)
{
  int str[2];
  
  str[0] = ch;
  str[1] = 0;
  display_prints(str);
}

void display_prints_c(const char* str)
{
  int* txt;
  int x, len;

  len = strlen(str);

  txt = malloc((len+1)*sizeof(int)+sizeof(int));
  for (x=0; x<=len; x++)
    {
      txt[x] = str[x];
    }
  txt[len] = 0;
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

void display_erase_line  (int val)
{
  NOTV6;

  if (CURWIN.overlay)
    {
      int x;
      
      if (val == 1)
	val = size_x;
      else
	val += CURWIN.xpos;

      for (x=CURWIN.xpos; x<val; x++)
	{
	  CURWIN.cline[CURWIN.ypos].cell[x] = ' ';
	  CURWIN.cline[CURWIN.ypos].fg[x]   = CURWIN.back;
	  CURWIN.cline[CURWIN.ypos].bg[x]   = -CURWIN.back-1;
	  CURWIN.cline[CURWIN.ypos].font[x] = style_font[4];
	}
    }
}

/* Debug functions */

static int old_win;
static int old_fore, old_back;
static int old_style;

void display_sanitise(void)
{
  if (is_v6)
    {
      v6_reset_windows();
      return;
    }

  old_win = cur_win;

  display_set_window(0);

  old_fore = CURWIN.fore;
  old_back = CURWIN.back;
  old_style = CURWIN.style;

  display_set_style(0);
  display_set_colour(4, 7);
}

void display_desanitise(void)
{
  display_set_colour(old_fore, old_back);
  display_set_style(old_style);
  display_set_window(old_win);
}

/* Style functions */

int  display_set_font    (int font)
{
  NOTV6;

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

int  display_set_style   (int style)
{
  int old_style;

#ifdef SUPPORT_VERSION_6
  if (is_v6)
    {
      return v6_set_style(style);
    }
#endif
  NOTV6;

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

void display_set_colour  (int fore, int back)
{
#ifdef SUPPORT_VERSION_6
  /* Required by the error/warning/finalisation routines */
  if (is_v6)
    {
      v6_set_colours(fore, back);
      return;
    }
#endif
  NOTV6;

  if (fore == -1)
    fore = DEFAULT_FORE;
  if (back == -1)
    back = DEFAULT_BACK;
  if (fore == -2)
    fore = CURWIN.fore;
  if (back == -2)
    back = CURWIN.back;

  CURWIN.fore = fore;
  CURWIN.back = back;
}

/* V5 window management functions */

void display_split       (int lines, int window)
{
  int y;

  NOTV6;

  if (lines > max_y)
    lines = max_y;

  for (y=text_win[window].winly/xfont_y; 
       y<(text_win[window].winsy/xfont_y)+lines;
       y++)
    {
      int x;
      for (x=0; x<max_x; x++)
	{
	  if (text_win[window].cline[y].bg[x] < 0)
	    text_win[window].cline[y].bg[x] = - text_win[window].back-1;
	}
    }
  
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
	  CURWIN.lasttext->next   = NULL;
	  CURWIN.lasttext->spacer = 1;
	  CURWIN.lasttext->space  = CURWIN.winsy -
	    (CURWIN.lastline->baseline + CURWIN.lastline->descent);
	  CURWIN.lasttext->len    = 0;
	  CURWIN.lasttext->text   = NULL;
	  CURWIN.lasttext->font   = style_font[(CURSTYLE>>1)&15];
	  CURWIN.lasttext->word   = NULL;
	  CURWIN.lasttext->spoken = 0;

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

  if (CURWIN.line != NULL)
    {
      display_set_scroll_region(CURWIN.winly-CURWIN.winsy);
      display_set_scroll_range (CURWIN.line->baseline - CURWIN.line->ascent - 
				CURWIN.winsy,
				CURWIN.winly - CURWIN.winsy);
    }
  else
    {
      display_set_scroll_region  (CURWIN.winly-CURWIN.winsy);
      display_set_scroll_range   (0, 0);
      display_set_scroll_position(0);
    }
}

void display_join        (int window1, int window2)
{
  NOTV6;

  if (text_win[window1].winsy != text_win[window2].winly)
    return; /* Windows can't be joined */
  text_win[window1].winsy = text_win[window2].winsy;
  text_win[window2].winly = text_win[window2].winsy;

  text_win[window1].topline = text_win[window2].topline = NULL;
}

void display_set_window  (int window)
{
  NOTV6;

  text_win[window].fore  = CURWIN.fore;
  text_win[window].back  = CURWIN.back;
  text_win[window].style = CURWIN.style;
  cur_win = window;
}

int  display_get_window  (void)
{
  NOTV6;

  return cur_win;
}

void display_set_cursor  (int x, int y)
{
  NOTV6;

  if (CURWIN.overlay)
    {
      if (CURWIN.xpos >= size_x)
	CURWIN.xpos = size_x-1;
      if (CURWIN.ypos >= size_y)
	CURWIN.ypos = size_y-1;
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

int  display_get_cur_x   (void)
{
  NOTV6;
  return CURWIN.xpos;
}

int  display_get_cur_y   (void)
{
  NOTV6;
  return CURWIN.ypos;
}

void display_force_fixed (int window, int val)
{
  NOTV6;
  CURWIN.force_fixed = val;
}

void display_has_restarted(void) 
{
  /* Notification function, mainly used by ZoomCocoa. We do nothing here */
}

void display_flush(void)
{
  /* Do nothing at the moment: placeholder function */
}
