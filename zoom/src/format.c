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

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#include "zmachine.h"
#include "display.h"
#include "zoomres.h"
#include "rc.h"
#include "hash.h"
#include "xfont.h"
#include "format.h"

/* Fonts */
xfont** font = NULL;
int     n_fonts = 0;
int     style_font[16] = { 0, 1, 2, 5, 3, 6, 7, 8,
			   4, 4, 4, 4, 4, 4, 4, 4 };;
/* Speech */
char*         nextspeech = NULL;
char*         lastspeech = NULL;

/* Window data structures themselves */
int cur_win;
struct window text_win[3] = 
  { { 0,0, 0,0,0,0, 0,0,0,0, 0,7,0, 7, NULL, NULL, NULL, NULL, NULL, NULL }, 
    { 0,0, 0,0,0,0, 0,0,0,0, 0,7,0, 7, NULL, NULL, NULL, NULL, NULL, NULL }, 
    { 0,0, 0,0,0,0, 0,0,0,0, 0,7,0, 7, NULL, NULL, NULL, NULL, NULL, NULL } };

#define CURWIN text_win[cur_win]
#define CURSTYLE (text_win[cur_win].style|(text_win[cur_win].force_fixed<<3))

/* Window parameters */
#define DEFAULTX 80
#define DEFAULTY 30
int size_x, size_y;
int max_x, max_y;

XFONT_MEASURE xfont_x = 0;
XFONT_MEASURE xfont_y = 0;
XFONT_MEASURE win_x   = 0;
XFONT_MEASURE win_y   = 0;
XFONT_MEASURE total_x = 0;
XFONT_MEASURE total_y = 0;
XFONT_MEASURE start_y;

int scroll_overlays = 1;

#define FIRST_ZCOLOUR 3

int more_on = 0;
int displayed_text = 0;

/* The caret */
int  caret_x, caret_y, caret_height;
int  input_x, input_y, input_width;
int  caret_on = 0;
int  caret_shown = 0;
int  caret_flashing = 0;
int  insert = 1;

/* Input and history buffers */

char* force_text = NULL;
int*  text_buf   = NULL;
int   buf_offset = 0;
int   max_buflen = 0;
int   read_key   = -1;

history_item* last_string = NULL;
history_item* history_pos = NULL;

static void new_line(int more,
		     int fnum)
{
  struct line* line;

  /*
   * If (while MORE is being displayed) the window is resized, everything
   * will be reformatted, and the current state of play will be invalid.
   * So, we set/unset this variable on entry and exit to detect
   * recursive entries into this function. A similar mechanism is used in
   * format_last_line()
   */
  static int reformatting;

  reformatting = 0;

  if (CURWIN.lastline == NULL)
    {
      CURWIN.lastline = CURWIN.line = malloc(sizeof(struct line));

      CURWIN.line->start    = NULL;
      CURWIN.line->n_chars  = 0;
      CURWIN.line->offset   = 0;
      CURWIN.line->baseline =
	CURWIN.ypos + xfont_get_ascent(font[fnum]);
      CURWIN.line->ascent   = xfont_get_ascent(font[fnum]);
      CURWIN.line->descent  = xfont_get_descent(font[fnum]);
      CURWIN.line->height   = xfont_get_height(font[fnum]);
      CURWIN.line->next     = NULL;

      displayed_text = CURWIN.lastline->ascent + CURWIN.lastline->descent;
      
      reformatting = 1;
      return;
    }

  if (more != 0)
    {
      int distext;

      distext = CURWIN.lastline->ascent + CURWIN.lastline->descent;
      if (displayed_text+distext >= (CURWIN.winly - CURWIN.winsy))
	{
	  more_on = 1;
	  display_readchar(0);
	  more_on = 0;
	  if (reformatting)
	    return;
	}
      displayed_text += distext;
    }

  display_update_region(0,
			CURWIN.lastline->baseline - CURWIN.lastline->ascent,
			win_x,
			CURWIN.lastline->baseline + CURWIN.lastline->descent);
  
  line = malloc(sizeof(struct line));

  line->start     = NULL;
  line->n_chars   = 0;
  line->baseline  = CURWIN.lastline->baseline+CURWIN.lastline->descent;
  line->baseline += xfont_get_ascent(font[fnum]);
  line->ascent    = xfont_get_ascent(font[fnum]);
  line->descent   = xfont_get_descent(font[fnum]);
  line->height    = xfont_get_height(font[fnum]);
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
      if (scroll_overlays)
	{
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
	}
      
      for (x=0; x<max_x; x++)
	{
	  text_win[2].cline[size_y-1].cell[x] = ' ';
	  text_win[2].cline[size_y-1].font[x] = style_font[4];
	  text_win[2].cline[size_y-1].fg[x]   = DEFAULT_BACK;
	  text_win[2].cline[size_y-1].bg[x]   = -DEFAULT_BACK-1;
	}

      display_update();
    }

  reformatting = 1;
}

void format_last_text(int more)
{
  int x;
  struct text* text;
  int word_start, word_len, total_len, text_start;
  XFONT_MEASURE xpos;
  xfont* fn;
  struct line* line;

  static int reformatting = 0;

  reformatting = 0;

  text = CURWIN.lasttext;

  fn = font[text->font];

  if (CURWIN.lastline == NULL)
    {
      new_line(more, text->font);
      if (reformatting)
	return;
    }

  if (text->spacer)
    {
      line = CURWIN.lastline;
      
      new_line(more, text->font);
      if (reformatting)
	return;

      CURWIN.lastline->descent = 0;
      CURWIN.lastline->baseline =
	line->baseline+line->descent+text->space;
      CURWIN.lastline->ascent = text->space;

      new_line(more, text->font);
      if (reformatting)
	return;
    }
  else
    {
      word_start = 0;
      word_len   = 0;
      total_len  = 0;
      xpos       = CURWIN.xpos;
      text_start = xpos;
      line       = CURWIN.lastline;

      if (text->spoken == 0)
	{
	  int len,x;

	  if (nextspeech == NULL)
	    len = 0;
	  else
	    len = strlen(nextspeech);

	  nextspeech = realloc(nextspeech, len+text->len+1);

	  for (x=0; x<text->len; x++)
	    {
	      nextspeech[len+x] = text->text[x];
	      switch (nextspeech[len+x])
		{
		case '\n':
		  nextspeech[len+x] = '.';
		  len++;
		  nextspeech = realloc(nextspeech, len+text->len+1);
		  nextspeech[len+x] = ' ';
		  break;
		case '>':
		  nextspeech[len+x] = ' ';
		  break;
		}
	    }
	  nextspeech[len+x] = '\0';
	  text->spoken = 1;
	}
      
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
      
      if (text->word == NULL)
	{
	  /*
	   * Measure and format the text. We measure each word individually,
	   * see if it will fit on the current line, and create a newline
	   * if not.
	   */
	  text->nwords = 0;
	  text->word = malloc(sizeof(struct word));

	  for (x=0; x<text->len;)
	    {
	      if (text->text[x] == ' '  ||
		  text->text[x] == '-'  ||
		  text->text[x] == '\n' ||
		  x == (text->len-1))
		{
		  XFONT_MEASURE w;
		  int nl;
		  
		  /* Skip any following spaces */
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
		  
		  /* We've got a word - measure it */
		  w = xfont_get_text_width(fn,
					   text->text + word_start,
					   word_len);

		  /* Store the details */
		  text->word = realloc(text->word,
				       sizeof(struct word)*(text->nwords+1));
		  text->word[text->nwords].start   = word_start;
		  text->word[text->nwords].len     = word_len;
		  text->word[text->nwords].width   = w;
		  text->word[text->nwords].newline = nl;
		  text->nwords++;
		  
		  /* Move swiftly along */
		  word_start += word_len;
		  total_len  += word_len;
		  word_len    = 0;
		  
		  if (nl)
		    {
		      x++;
		      total_len++;
		      word_start++;
		    }
		}
	      else
		{
		  x++;
		  word_len++;
		}
	    }
	}

      /* Actually format the text */
      for (x=0; x<text->nwords; x++)
	{
	  int s;

	  s = line->start==text?line->offset:0;
	  if (line->start == NULL)
	    s = text->word[x].start;
	  if (text->text[s] == '\n')
	    s++;

#ifdef FORMAT_ASSUME_BAD_MEASUREMENTS
	  xpos = text_start + xfont_get_text_width(fn,
						   text->text+s,
						   text->word[x].start+
						   text->word[x].len - s);
#else
	  xpos += text->word[x].width;
#endif
	  
	  if (xpos > CURWIN.winlx)
	    {
	      /* This word goes on the next line */
	      new_line(more, text->font);
	      if (reformatting)
		return;

	      xpos = CURWIN.xpos + text->word[x].width;
	      text_start = CURWIN.xpos;
	      line = CURWIN.lastline;
	    }

	  if (line->start == NULL)
	    {
	      line->offset = text->word[x].start;
	      line->start  = text;
	    }
	  line->n_chars += text->word[x].len;
	  
	  if (text->word[x].newline)
	    {
	      new_line(more, text->font);
	      if (reformatting)
		return;
	      
	      text_start = xpos = CURWIN.xpos;
	      line = CURWIN.lastline;
	    }
	}

      CURWIN.xpos = xpos;
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
      display_set_scroll_region(CURWIN.winly-CURWIN.winsy);
      display_set_scroll_range(0,0);
    }
  
  display_update_region(0,
			CURWIN.lastline->baseline - CURWIN.lastline->ascent,
			win_x,
			CURWIN.lastline->baseline + CURWIN.lastline->descent);

  reformatting = 1;
}
