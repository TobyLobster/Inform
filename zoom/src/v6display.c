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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zmachine.h"
#include "display.h"
#include "format.h"
#include "v6display.h"

typedef struct v6window v6window;

static int active_win = 0;

static int erf_n, erf_d;

static int mouse_win;

struct v6window
{
  float curx, cury;

  int xpos, ypos;
  int width, height;

  int lmargin, rmargin;
  int fore, back;

  int style;

  float line_height;

  float text_amount;
  int no_scroll;
  int force_fixed;
  int no_more;

  int wrapping;

  int want_more;
};

static v6window win[8];

static int (*nl_func)(const int * remaining,
		      int rem_len) = NULL;

#define ACTWIN win[active_win]

void v6_startup      (void)
{
#ifdef DEBUG
  printf_debug("V6: startup\n");
#endif

  if (!display_init_pixmap(-1, -1))
    {
      zmachine_fatal("Display driver does not support pixmap display: unable to initialise v6 display");
      return;
    }
  display_is_v6();

  machine.dinfo = display_get_info();

  v6_reset();

  machine.memory[ZH_width] = machine.dinfo->width>>8;
  machine.memory[ZH_width+1] = machine.dinfo->width;
  machine.memory[ZH_height] = machine.dinfo->height>>8;
  machine.memory[ZH_height+1] = machine.dinfo->height;
  /* Note that these are backwards in v6 :-) */
  machine.memory[ZH_fontwidth] = machine.dinfo->font_height;
  machine.memory[ZH_fontheight] = machine.dinfo->font_width;
}

void v6_reset        (void)
{
  int x;

#ifdef DEBUG
  printf_debug("V6: reset\n");
#endif

  v6_reset_windows();

  for (x=0; x<8; x++)
    {
      win[x].fore = DEFAULT_FORE;
      win[x].back = DEFAULT_BACK;
    }

  v6_set_window(0);
  v6_erase_window();

  erf_n = 1; erf_d = 1;

  if (machine.blorb != NULL && machine.blorb->reso.offset != -1)
    {
      if (machine.dinfo->width*machine.blorb->reso.py >
	  machine.dinfo->height*machine.blorb->reso.px)
	{
	  erf_n = machine.dinfo->height;
	  erf_d = machine.blorb->reso.py;
	}
      else
	{
	  erf_n = machine.dinfo->width;
	  erf_d = machine.blorb->reso.px;
	}
    }
}

void v6_scale_image(BlorbImage* img, int* img_n, int* img_d)
{
  *img_n = erf_n*img->std_n;
  *img_d = erf_d;

  if ((*img_n * img->max_d) > (img->max_n * *img_d))
    {
      *img_n = img->max_n;
      *img_d = img->max_d;
    }
  else if ((*img_n * img->min_d) < (img->min_n * *img_d))
    {
      *img_n = img->min_n;
      *img_d = img->min_d;
    }
}

void v6_reset_windows(void)
{
  int x;
#ifdef DEBUG
  printf_debug("V6: reset windows\n");
#endif

  for (x=0; x<8; x++)
    {
      win[x].curx        = win[x].cury = 0;
      win[x].xpos        = win[x].ypos = 0;
      win[x].width       = machine.dinfo->width;
      win[x].height      = machine.dinfo->height;
      win[x].style       = 0;
      win[x].line_height = display_get_font_height(0);
      win[x].force_fixed = 0;
      win[x].text_amount = 0;
      win[x].no_scroll   = 0;
      win[x].no_more     = 0;
      win[x].want_more   = 0;
      win[x].wrapping    = 1;
    }
}

static void scroll_to_height(int height, int change_baseline)
{
  int oldheight, bg;

  bg = ACTWIN.back;
    
  oldheight = ACTWIN.line_height;
  if (height > oldheight)
    {
      ACTWIN.line_height = height;
    }
  
  /* Scroll the line to fit in a bigger font, if necessary */
  if ((ACTWIN.cury+ACTWIN.line_height) > (ACTWIN.ypos+ACTWIN.height) &&
      !ACTWIN.no_scroll)
    {
      int scrollby;
      
      scrollby = (ACTWIN.cury+ACTWIN.line_height)-(ACTWIN.ypos+ACTWIN.height);
#ifdef DEBUG
      printf_debug("V6: Scrolling by %i\n", scrollby);
#endif
      
      display_scroll_region(ACTWIN.xpos, ACTWIN.ypos+scrollby,
			    ACTWIN.width, ACTWIN.height,
			    0, -scrollby);
      if (bg >= 0)
	{
	  display_pixmap_cols(bg, 0);
	  display_plot_rect(ACTWIN.xpos+ACTWIN.lmargin,
			    ACTWIN.ypos+ACTWIN.height-scrollby,
			    ACTWIN.width-ACTWIN.lmargin-ACTWIN.rmargin,
			    scrollby);
	}
      
      ACTWIN.cury -= scrollby;
      
#ifdef DEBUG
      printf_debug("V6: Text amount is now %g (more paging %s)\n", 
		   ACTWIN.text_amount, ACTWIN.no_more?"OFF":"ON");
#endif
    }

  if (!change_baseline)
    return;
  
  /* 
   * Need to scroll any existing text on this line down, so
   * baselines match
   */
  if (height > oldheight && !ACTWIN.no_scroll && oldheight > 0)
    {
      int scrollby;
      
      scrollby = height-oldheight;
      
      display_scroll_region(ACTWIN.xpos,  ACTWIN.cury,
			    ACTWIN.width, oldheight,
			    0,  scrollby);

      if (bg >= 0)
	{
	  display_pixmap_cols(bg, 0);
	  display_plot_rect(ACTWIN.xpos+ACTWIN.lmargin, ACTWIN.cury,
			    ACTWIN.width-ACTWIN.lmargin-ACTWIN.rmargin,
			    scrollby);
	}
    }
}

void v6_prints(const int* text)
{
  int height;
  int start_pos, text_pos, last_word, this_word;
  float width;

  int fg, bg;
  int len;

#ifdef DEBUG
  char t[8192];

  for (len=0; text[len] !=0; len++)
    t[len] = text[len];
  t[len] = 0;

  printf_debug("V6: Printing text to window %i (style %x, colours %i, %i, position %g, %g): >%s<\n", active_win, 
	       ACTWIN.style, ACTWIN.fore, ACTWIN.back, ACTWIN.curx, ACTWIN.cury, t);
#endif

  for (len=0; text[len] != 0; len++);

  fg = ACTWIN.fore;
  bg = ACTWIN.back;

  start_pos = text_pos = last_word = this_word = 0;
  width = 0;

  while (text[text_pos] != 0)
    {
      /* On to the next newline */
      start_pos = text_pos;
      width = 0;
      last_word = this_word = text_pos;

      while (ACTWIN.curx + width <= ACTWIN.xpos + ACTWIN.width - ACTWIN.rmargin &&
	     text[text_pos] != 10 && text[text_pos] != 0)
	{
	  if (text[text_pos] == ' ' || 
	      text[text_pos] == '-' ||
	      ACTWIN.wrapping == 0)
	    {
	      /* Possible break point */
	      width  = display_measure_text(text + start_pos,
					    text_pos - start_pos + 1,
					    ACTWIN.style);

	      last_word = this_word;
	      this_word = text_pos+1;
	    }
	  text_pos++;
	}

      if (text[text_pos] == 0 || text[text_pos] == 10)
	width  = display_measure_text(text + start_pos,
				      text_pos - start_pos,
				      ACTWIN.style);

      /* Back up a word, if necessary */
      if (ACTWIN.curx + width >= ACTWIN.xpos + ACTWIN.width - ACTWIN.rmargin &&
	  (ACTWIN.curx != ACTWIN.xpos + ACTWIN.lmargin || last_word != start_pos))
	{
	  text_pos = last_word;
	  this_word = last_word;

	  width  = display_measure_text(text + start_pos,
					text_pos - start_pos,
					ACTWIN.style);
	}

      /* Work out the new height of this line... */
      if (text_pos != start_pos ||
	  (text_pos == start_pos && text[text_pos] == 10))
	height = display_get_font_height(ACTWIN.style);
      else
	height = ACTWIN.line_height;

      scroll_to_height(height, 1);

      /* Plot the text */
      display_pixmap_cols(fg, bg);

      display_plot_gtext(text + start_pos, text_pos - start_pos,
			 ACTWIN.style,
			 (ACTWIN.curx+0.5), 
			 0.5+ACTWIN.cury+ACTWIN.line_height-display_get_font_descent(ACTWIN.style));

#ifdef DEBUG
      { int x;
      printf_debug("V6: printed line >");
      for (x=start_pos; x<text_pos; x++)
	printf_debug("%c", text[x]);
      printf_debug("<\n");
      }
#endif

      /* Stop plotting if wrapping is off */
      if (ACTWIN.wrapping == 0)
	{
	  ACTWIN.curx += width;
	  return;
	}

      /* Newline, if necessary */
      if (text[text_pos] != 0)
	{
	  int more;

#ifdef DEBUG
	  printf_debug("V6: new line\n");
#endif

	  ACTWIN.text_amount += ACTWIN.line_height;
	  ACTWIN.cury += ACTWIN.line_height;
	  ACTWIN.line_height = 0;
	  ACTWIN.curx = ACTWIN.xpos + ACTWIN.lmargin;

	  if (ACTWIN.text_amount + ACTWIN.line_height > ACTWIN.height - 
	      (ACTWIN.line_height+display_get_font_height(ACTWIN.style)))
	    {
	      if (!ACTWIN.no_more)
		ACTWIN.want_more = 1;
	    }

	  more = -1;
	  if (nl_func != NULL)
	    {
	      more = (nl_func)(text + text_pos + (text[text_pos]==10?1:0),
			       len - text_pos - (text[text_pos]==10?1:0));
	    }

	  if (more == 1 && !ACTWIN.no_more)
	    {
	      display_wait_for_more();
	      ACTWIN.text_amount = ACTWIN.line_height*2;
	    }
	  else if (more == -1 && ACTWIN.want_more)
	    {
	      ACTWIN.text_amount = ACTWIN.line_height*2;
	      display_wait_for_more();
	    }
	  ACTWIN.want_more = 0;
	  
	  scroll_to_height(display_get_font_height(ACTWIN.style), 0);

	  if (more == 2)
	    return;
	}
      else
	{
	  ACTWIN.curx += width;
	}

      if (text[text_pos] == 10 || text[text_pos] == 32)
	text_pos++;
    }
}

void v6_prints_c(const char* text)
{
#ifdef DEBUG
  printf_debug("YAARRRK\n");
#endif
}

void v6_set_caret(void)
{
  display_set_input_pos(ACTWIN.style, ACTWIN.curx, ACTWIN.cury,
			(ACTWIN.xpos+ACTWIN.width-ACTWIN.rmargin)-ACTWIN.curx);
  if (ACTWIN.style&1)
    display_pixmap_cols(ACTWIN.back, ACTWIN.fore);
  else
    display_pixmap_cols(ACTWIN.fore, ACTWIN.back);

  if (mouse_win >= 0)
    {
      display_set_mouse_win(win[mouse_win].xpos, win[mouse_win].ypos,
			    win[mouse_win].width, win[mouse_win].height);
    }
  else
    {
      display_set_mouse_win(-1, -1, -1, -1);
    }

  ACTWIN.text_amount = 0;
}

void v6_erase_window(void)
{
#ifdef DEBUG
  printf_debug("V6: erase window #%i\n", active_win);
#endif

  if (ACTWIN.style&1)
    display_pixmap_cols(ACTWIN.fore, ACTWIN.back);
  else
    display_pixmap_cols(ACTWIN.back, ACTWIN.fore);

  display_plot_rect(ACTWIN.xpos, ACTWIN.ypos,
		    ACTWIN.width, ACTWIN.height);

  ACTWIN.cury = ACTWIN.ypos;
  ACTWIN.curx = ACTWIN.xpos + ACTWIN.lmargin;
  ACTWIN.line_height = ACTWIN.text_amount = display_get_font_height(ACTWIN.style);
  ACTWIN.text_amount *= 2;
}

void v6_erase_line(int val)
{
#ifdef DEBUG
  printf_debug("V6: erase line : %i %g\n", val, ACTWIN.curx);
#endif

  if (ACTWIN.line_height == 0)
    {
      scroll_to_height(display_get_font_height(ACTWIN.style), 1);
      ACTWIN.line_height = display_get_font_height(ACTWIN.style);
    }

  if (ACTWIN.style&1)
    display_pixmap_cols(ACTWIN.fore, 0);
  else
    display_pixmap_cols(ACTWIN.back, 0);
  if (val == 1)
    display_plot_rect(ACTWIN.curx, ACTWIN.cury,
		      ACTWIN.width-ACTWIN.rmargin-(ACTWIN.curx-ACTWIN.xpos),
		      ACTWIN.line_height);
  else
    {
      if (ACTWIN.curx + val > ACTWIN.xpos + ACTWIN.width - ACTWIN.rmargin)
	{
	  val = ACTWIN.width - ACTWIN.rmargin - ACTWIN.curx;
	}

      display_plot_rect(ACTWIN.curx, ACTWIN.cury,
			val, ACTWIN.line_height);
    }
}

void v6_set_colours(int fg, int bg)
{
#ifdef DEBUG
  printf_debug("V6: set colours: %i, %i (window %i)\n", fg, bg, active_win);
#endif

  if (fg == -2)
    fg = ACTWIN.fore;
  if (bg == -2)
    bg = ACTWIN.back;
  if (fg == -1)
    fg = DEFAULT_FORE;
  if (bg == -1)
    bg = DEFAULT_BACK;

  if (bg == -3)
    bg = display_get_pix_colour(ACTWIN.curx, ACTWIN.cury);
  if (fg == -3)
    fg = display_get_pix_colour(ACTWIN.curx, ACTWIN.cury);

  ACTWIN.fore = fg;
  ACTWIN.back = bg;
}

int v6_get_fg_colour(void)
{
  return ACTWIN.fore;
}

int v6_get_bg_colour(void)
{
  return ACTWIN.back;
}

int v6_set_style(int style)
{
  int oldstyle;

  oldstyle = ACTWIN.style;
  
  if (style == 0)
    ACTWIN.style = 0;
  else
    {
      if (style > 0)
	ACTWIN.style |= style;
      else
	ACTWIN.style &= ~(-style);
    }

#ifdef DEBUG
  printf_debug("V6: set style (window %i), new style %x\n", active_win,
	       ACTWIN.style);
#endif

  return oldstyle;
}

int  v6_get_window(void)
{
  return active_win;
}

void v6_set_window(int window)
{
  if (window < 0 || window >= 8)
    {
      zmachine_fatal("Attempt to use nonexistent window %i", window);
    }

#ifdef DEBUG
  printf_debug("V6: window set to %i\n", window);
#endif
  active_win = window;
}

void v6_define_window(int window,
		      int x, int y,
		      int lmargin, int rmargin,
		      int width, int height)
{
#ifdef DEBUG
  printf_debug("V6: defining window %i - at (%i, %i), size %ix%i, margins %i, %i\n", window,
	       x, y, width, height, lmargin, rmargin);
#endif

  x--; y--;

  win[window].xpos = x;
  win[window].ypos = y;
  win[window].lmargin = lmargin;
  win[window].rmargin = rmargin;
  win[window].width = width;
  win[window].height = height;

  if (win[window].curx < win[window].xpos + win[window].lmargin)
    win[window].curx = win[window].xpos + win[window].lmargin;

  if (win[window].cury < win[window].ypos)
    {
      win[window].cury = win[window].ypos;
    }

  if (win[window].cury+win[window].line_height > win[window].ypos + win[window].height)
    {
      win[window].line_height = display_get_font_height(win[window].style);
      win[window].cury = win[window].ypos + win[window].height - win[window].line_height;
      
      if (!ACTWIN.no_scroll)
	scroll_to_height(display_get_font_height(ACTWIN.style), 0);
    }

  win[window].text_amount = win[window].line_height*2;
}

void v6_set_scroll(int flag)
{
  ACTWIN.no_scroll = !flag;
}

void v6_set_more(int window, int flag)
{
  win[window].no_more = !flag;
}

void v6_set_wrap(int window, int flag)
{
  win[window].wrapping = flag;
}

void v6_set_cursor(int x, int y)
{
  int ly;

#ifdef DEBUG
  printf_debug("V6: moving cursor to %i, %i\n", x, y);
#endif

  ly = ACTWIN.cury;

  x--; y--;
  ACTWIN.curx = ACTWIN.xpos + x;
  ACTWIN.cury = ACTWIN.ypos + y;

  if (ly != ACTWIN.cury)
    ACTWIN.line_height = display_get_font_height(ACTWIN.style);

  ACTWIN.text_amount = 0;
}

int  v6_get_cursor_x(void)
{
  return ACTWIN.curx-ACTWIN.xpos+1;
}

int  v6_get_cursor_y(void)
{
  return ACTWIN.cury-ACTWIN.ypos+1;
}

void v6_set_newline_function(int (*func)(const int * remaining,
					 int rem_len))
{
  nl_func = func;
}

void v6_scroll_window(int window, int amount)
{
#ifdef DEBUG
  printf_debug("Scrolling window %i by %i\n", window, amount);
#endif

  if (amount > 0)
    {
      display_scroll_region(win[window].xpos, win[window].ypos+amount,
			    win[window].width, win[window].height-amount,
			    0, -amount);

      if (win[window].back >= 0)
	{
	  display_pixmap_cols(win[window].back, 0);
	  display_plot_rect(win[window].xpos, 
			    win[window].ypos+win[window].height-amount,
			    win[window].width, amount);
	}
   }
  else
    {
      display_scroll_region(win[window].xpos, win[window].ypos,
			    win[window].width, win[window].height+amount,
			    0, -amount);

      if (win[window].back >= 0)
	{
	  display_pixmap_cols(win[window].back, 0);
	  display_plot_rect(win[window].xpos, win[window].ypos,
			    win[window].width, -amount);
	}
    }
}

int v6_split_point(int* text,
		   int  text_len,
		   int  width,
		   int* width_out)
{
  float cwidth;
  int text_pos;
  int this_word, last_word;

  this_word = last_word = text_pos = 0;
  cwidth = 0;

  while (cwidth < width &&
	 text_pos < text_len)
    {
      if (text[text_pos] == ' ' ||
	  text[text_pos] == '-')
	{
	  cwidth = display_measure_text(text,
					text_pos,
					ACTWIN.style);
	  
	  last_word = this_word;
	  this_word = text_pos + 1;
	}
      text_pos++;
    }

  cwidth = display_measure_text(text,
				text_pos,
				ACTWIN.style);
  if (width_out != NULL)
    *width_out = cwidth;

  if (cwidth >= width)
    return last_word;

  return text_len;
}

int v6_measure_text(int* text,
		    int len)
{
  return display_measure_text(text,
			      len,
			      ACTWIN.style);
}

void v6_set_mouse_win(int win)
{
  mouse_win = win;
}
