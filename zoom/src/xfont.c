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
 * Font handling for X-Windows
 */

#include "../config.h"

#if WINDOW_SYSTEM == 1

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zmachine.h"
#include "xdisplay.h"
#include "xfont.h"
#include "font3.h"
#include "format.h"
#include "rc.h"

#ifdef HAVE_XFT
# include <X11/Xft/Xft.h>
#endif

#ifdef HAVE_T1LIB
# include <t1lib.h>
# include <t1libx.h>
#endif

/* Definition of an xfont */

struct xfont
{
  enum
  {
    XFONT_X,
#ifdef HAVE_T1LIB
    XFONT_T1LIB,
#endif
#ifdef HAVE_XFT
    XFONT_XFT,
#endif
    XFONT_FONT3
  } type;
  union
  {
    XFontStruct* X;
#ifdef HAVE_T1LIB
    struct {
      int id;
      double size;
      BBox bounds;
    } t1;
#endif
#ifdef HAVE_XFT
    XftFont* Xft;
#endif
  } data;
};

static int fore, back;

/***                           ----// 888 \\----                           ***/

/*
 * Function to plot a font 3 definition
 */

static void plot_font_3(Drawable draw, GC gc, int chr, int xpos, int ypos)
{
  static XPoint poly[32];
  int x;
    
  if (chr > 127 || chr < 32)
    return;
  chr-=32;

  if (font_3.chr[chr].num_coords < 0)
    {
      zmachine_warning("Attempt to plot unspecified character %i",
		       chr+32);
      return;
    }
  
  for (x=0; x<font_3.chr[chr].num_coords; x++)
    {
      poly[x].x = font_3.chr[chr].coords[x<<1];
      poly[x].y = font_3.chr[chr].coords[(x<<1)+1];

      poly[x].x *= (int)(xfont_x); poly[x].x /= 8; poly[x].x += xpos;
      poly[x].y *= (int)(xfont_y); poly[x].y /= 8; poly[x].y += ypos;
    }

  XFillPolygon(x_display,
	       draw, gc,
	       poly, font_3.chr[chr].num_coords,
	       Complex, CoordModeOrigin);
}

/***                           ----// 888 \\----                           ***/

void xfont_initialise(void)
{
#ifdef HAVE_T1LIB
  /* Whoops, this can be called twice if the menu is activated */
  static int t1_initialised = 0;
#endif

#ifdef HAVE_T1LIB
  if (!t1_initialised) {
    t1_initialised = 1;

    if (T1_InitLib(T1_AA_CACHING) == NULL)
      zmachine_fatal("Unable to initialise t1lib");
    T1_SetX11Params(x_display, DefaultVisual(x_display, x_screen),
  		    DefaultDepth(x_display, x_screen),
		    DefaultColormap(x_display, x_screen));
    T1_AASetBitsPerPixel(DefaultDepth(x_display, x_screen));
    T1_AASetLevel(T1_AA_LOW);
    T1_AASetSmartMode(T1_YES);
  }
#endif
}

void xfont_shutdown(void)
{ }

xfont* xfont_load_font(char* font)
{
  xfont* f;

  f = malloc(sizeof(xfont));

  if (strcmp(font, "font3") == 0)
    {
      f->type = XFONT_FONT3;
      return f;
    }

  if (font[0] == '/')
    {
#if !defined(HAVE_T1LIB)
      zmachine_fatal("Font files are not supported in this version");
#else
      char* name = NULL;
      char* size = NULL;
      int x;

      f->type = XFONT_T1LIB;
      
      for (x=0; x<strlen(font); x++)
	{
	  if (font[x] == ' ')
	    {
	      name = font;
	      size = font + x + 1;
	      font[x] = 0;
	    }
	  if (font[x] == '\\' && font[x+1] != 0)
	    x++;
	}
      if (name == NULL)
	name = font;
      if (size == NULL)
	size = "14";

      f->data.t1.id = T1_AddFont(name);
      f->data.t1.size = strtod(size, NULL);
      if (f->data.t1.id >= 0 &&
	  f->data.t1.size > 0)
	{
	  T1_LoadFont(f->data.t1.id);
	  f->data.t1.bounds = T1_GetFontBBox(f->data.t1.id);
	}
      else
	{
	  f->type = XFONT_X;
	  zmachine_warning("Unable to load font %s (error %i) - reverting to 8x13", font, f->data.t1.id);
	  f->data.X = XLoadQueryFont(x_display, "8x13");
	  if (f->data.X == NULL)
	    zmachine_fatal("Unable to load font %s or fall back to 8x13", font);
	}

#endif
    }
  else
    {
#ifdef HAVE_XFT
      f->type = XFONT_XFT;
      if (xft_drawable != NULL &&
	  rc_get_antialias())
	{
#if XFT_MAJOR >= 2
	  f->data.Xft = XftFontOpenXlfd(x_display, x_screen, font);		  
#else
	  XftPattern* pat, *match;
	  XftResult   res;

	  pat = XftXlfdParse(font, False, False);

	  if (!pat) {
	    f->data.Xft = NULL;
	  } else {
	    // FcPatternPrint(pat);

	    XftPatternAddBool(pat, XFT_ANTIALIAS, rc_get_antialias()?True:False);

	    res = XftResultNoMatch; /* Bug in Xft... */
	    match = XftFontMatch(x_display, x_screen, pat, &res);
	    if (match && res != XftResultNoMatch)
	      {
		f->data.Xft = XftFontOpenPattern(x_display, match);
	      }
	    else
	      {
		f->data.Xft = NULL;
	      }
	    XftPatternDestroy(pat);
	  }
#endif
	}
      else
	{
	  f->data.Xft = NULL;
	}
      if (f->data.Xft != NULL)
	return f;

      zmachine_warning("XFT: Unable to load font '%s', trying standard X font", font);
#endif
      f->type = XFONT_X;
      f->data.X = XLoadQueryFont(x_display, font);
      if (f->data.X == NULL)
	{
	  zmachine_warning("Unable to load font %s - reverting to 8x13", font);
	  f->data.X = XLoadQueryFont(x_display, "8x13");
	  if (f->data.X == NULL)
	    zmachine_fatal("Unable to load font %s or fall back to 8x13", font);
	}
    }

  return f;
}

void xfont_release_font(xfont* f)
{
  switch (f->type)
    {
    case XFONT_X:
      XFreeFont(x_display, f->data.X);
      break;
#ifdef HAVE_XFT
    case XFONT_XFT:
      XftFontClose(x_display, f->data.Xft);
      break;
#endif
#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      T1_DeleteSize(f->data.t1.id, f->data.t1.size);
      break;
#endif
    case XFONT_FONT3:
      break;
    }

  free(f);
}

void xfont_set_colours(int foreground,
		       int background)
{
  fore = foreground;
  back = background;
}

XFONT_MEASURE xfont_get_width(xfont* f)
{
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      return f->data.Xft->max_advance_width;
      break;
#endif
#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      {
	BBox bounds;

	bounds = f->data.t1.bounds;

	return (XFONT_MEASURE)(bounds.urx)*f->data.t1.size / 
	  (XFONT_MEASURE)1000;
      }
      break;
#endif
    case XFONT_X:
      return f->data.X->max_bounds.width;
    case XFONT_FONT3:
      return (int) xfont_x;
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

XFONT_MEASURE xfont_get_height(xfont* f)
{
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      return xfont_get_ascent(f)+xfont_get_descent(f);
#endif
#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      return xfont_get_ascent(f)+xfont_get_descent(f);
#endif
    case XFONT_X:
      return f->data.X->ascent + f->data.X->descent;
    case XFONT_FONT3:
      return (int)(xfont_y);
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

XFONT_MEASURE xfont_get_ascent(xfont* f)
{
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      return f->data.Xft->ascent;
#endif
#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      {
	BBox bounds;

	bounds = f->data.t1.bounds;

	return (int)(((XFONT_MEASURE)(bounds.ury*f->data.t1.size)/
		      (XFONT_MEASURE)1000.0) + 1.0);
      }
#endif
    case XFONT_X:
      return f->data.X->ascent;
    case XFONT_FONT3:
      return (int)(xfont_y);
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

XFONT_MEASURE xfont_get_descent(xfont* f)
{
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      return f->data.Xft->descent;
#endif
#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      {
	BBox bounds;

	bounds = f->data.t1.bounds;

	return (int) (((XFONT_MEASURE)(-bounds.lly*f->data.t1.size)/
		       (XFONT_MEASURE)1000.0) + 1.0);
      }
#endif
    case XFONT_X:
      return f->data.X->descent;
    case XFONT_FONT3:
      return 0;
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

XFONT_MEASURE xfont_get_text_width(xfont* f, const int* text, int len)
{
  static XChar2b* xtxt = NULL;
  int x;

  if (len <= 0)
    return 0;

  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      {
	XGlyphInfo ext;
	static XftChar16* xfttxt;

	xfttxt = realloc(xfttxt, (len+1)*sizeof(XftChar16));
	for (x=0; x<len; x++)
	  {
	    xfttxt[x] = text[x];
	  }

	XftTextExtents16(x_display, f->data.Xft, xfttxt, len, &ext);

	return ext.xOff;
      }
#endif
#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      {
	BBox bounds;
	static char* t1txt = NULL;

	t1txt = realloc(t1txt, (len+1)*sizeof(char));
	for (x=0; x<len; x++)
	  {
	    t1txt[x] = text[x];
	    if (text[x] > 255)
	      t1txt[x] = '?';
	  }
	t1txt[len] = 0;

	if (len == 0)
	  return 0;

	if (t1txt[x-1] == 32)
	  {
	    len++;
	  }

	bounds = T1_GetStringBBox(f->data.t1.id, t1txt, len, 0, T1_KERNING);

	return (XFONT_MEASURE)((bounds.urx)*f->data.t1.size)/
	  (XFONT_MEASURE)1000.0;
      }
#endif
    case XFONT_X:
      xtxt = realloc(xtxt, (len+1)*sizeof(int));
      for (x=0; x<len; x++)
	{
	  xtxt[x].byte2 = text[x]&255;
	  xtxt[x].byte1 = (text[x]>>8)&255;
	}

      return XTextWidth16(f->data.X, xtxt, len);
    case XFONT_FONT3:
      return len*((int)xfont_x);
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

void xfont_plot_string(xfont* f,
		       Drawable draw,
		       GC gc,
		       int x, int y,
		       const int* text, int len)
{
  static XChar2b* xtxt = NULL;
  int i;
  
  if (len <= 0)
    return;
  
  switch (f->type)
    {
#ifdef HAVE_XFT
    case XFONT_XFT:
      {
	static XftChar16* xfttxt;

	xfttxt = realloc(xfttxt, (len+1)*sizeof(XftChar16));
	for (i=0; i<len; i++)
	  {
	    xfttxt[i] = text[i];
	  }

	XftDrawString16(xft_drawable, xdisplay_get_xft_colour(fore), 
			f->data.Xft, x, y, xfttxt, len);
      }
      break;
#endif

#ifdef HAVE_T1LIB
    case XFONT_T1LIB:
      {
	static char* t1txt = NULL;
	int i;

	t1txt = realloc(t1txt, (len+1)*sizeof(char));
	for (i=0; i<len; i++)
	  {
	    t1txt[i] = text[i];
	    if (text[i] > 255)
	      t1txt[i] = '?';
	  }
	t1txt[i] = 0;

	XSetForeground(x_display, gc, xdisplay_get_pixel_value(fore));
	if (back > -1)
	  XSetBackground(x_display, gc, xdisplay_get_pixel_value(back));
	if (rc_get_antialias() && back > -1)
	  {
	    /*
	     * NOTE: can't antialias with transparent backgrounds...
	     */
	    T1_AASetStringX(draw, gc, T1_OPAQUE, 
			    x, y + (f->data.t1.bounds.llx*f->data.t1.size)/1000, 
			    f->data.t1.id,
			    t1txt, len, 0, T1_KERNING,
			    f->data.t1.size, NULL);
	  }
	else
	  {
	    T1_SetStringX(draw, gc, T1_TRANSPARENT, 
			  x, y + (f->data.t1.bounds.llx*f->data.t1.size)/1000, 
			  f->data.t1.id,
			  t1txt, len, 0, T1_KERNING,
			  f->data.t1.size, NULL);
	  }
      }
      break;
#endif

    case XFONT_X:
      xtxt = realloc(xtxt, (len+1)*sizeof(int));
      for (i=0; i<len; i++)
	{
	  xtxt[i].byte2 = text[i]&255;
	  xtxt[i].byte1 = (text[i]>>8)&255;
	}

      XSetForeground(x_display, gc, xdisplay_get_pixel_value(fore));
      XSetFont(x_display, gc, f->data.X->fid);
      XDrawString16(x_display, draw, gc, x, y, xtxt, len);
      break;
      
    case XFONT_FONT3:
      XSetForeground(x_display, gc, xdisplay_get_pixel_value(fore));
      {
	int pos;

	for (pos=0; pos<len; pos++)
	  {
	    plot_font_3(draw, gc, text[pos], x, y-(int)(xfont_y));
	    x+=(int)xfont_x;
	  }
      }
      break;
    }
}

#endif
