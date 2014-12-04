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
 * Fonts for Win32
 */

#include "../config.h"

#if WINDOW_SYSTEM == 2

#include <stdlib.h>
#include <string.h>

#include <windows.h>

#include "zmachine.h"
#include "font3.h"
#include "windisplay.h"
#include "xfont.h"

struct xfont
{
  enum
  {
    WINFONT_INTERNAL,
    WINFONT_FONT3
  } type;
  union
  {
    struct
    {
      HFONT handle;
      LOGFONT defn;
    } win;
  } data;
};

static int fore;
static int back;

/***                           ----// 888 \\----                           ***/

/*
 * Function to plot a font 3 definition
 */

static int bitmap_x = 0;
static int bitmap_y = 0;
static int created_bitmaps = 0;
static HBITMAP f3mask[96];
static HDC     compat_dc = NULL;

static void create_font3_bitmaps(HDC dc)
{
  int x;
  HBRUSH black, white;
  RECT rct;
  POINT point[32];
  int i;
  HDC bdc;
  HGDIOBJ origbit, origbrush;
  
  bitmap_x = xfont_x;
  bitmap_y = xfont_y;

  if (created_bitmaps)
    {
      for (x=0; x<96; x++)
	{
	  DeleteObject(f3mask[x]);
	}
    }

  black = CreateSolidBrush(RGB(0,0,0));
  white = CreateSolidBrush(RGB(255,255,255));

  rct.top = rct.left = 0;
  rct.right   = xfont_x;
  rct.bottom = xfont_y;

  bdc = CreateCompatibleDC(NULL);
  for (x=0; x<96; x++)
    {      
      f3mask[x] = CreateBitmap(xfont_x, xfont_y, 1, 1, NULL);
      
      origbit = SelectObject(bdc, f3mask[x]);

      FillRect(bdc, &rct, white);
      origbrush = SelectObject(bdc, black);

      for (i=0; i<font_3.chr[x].num_coords; i++)
	{
	  point[i].x = font_3.chr[x].coords[i<<1];
	  point[i].y = font_3.chr[x].coords[(i<<1)+1];
	  
	  point[i].x *= xfont_x; point[i].x /= 8;
	  point[i].y *= xfont_y; point[i].y /= 8;
	}
      
      BeginPath(bdc);
      Polygon(bdc, point, font_3.chr[x].num_coords);
      EndPath(bdc);
      FillPath(bdc);

      SelectObject(bdc, origbit);
      SelectObject(bdc, origbrush);
    }

  DeleteObject(black);
  DeleteObject(white);

  DeleteDC(bdc);
  
  created_bitmaps = 1;
}

static void plot_font_3(HDC dc, int chr, int xpos, int ypos)
{
  HGDIOBJ origbit;
  
  if (chr > 127 || chr < 32)
    chr = 32;
  chr-=32;

  if (!created_bitmaps || xfont_x != bitmap_x || xfont_y != bitmap_y)
    {
      create_font3_bitmaps(dc);
    }

  if (font_3.chr[chr].num_coords < 0)
    {
      zmachine_warning("Attempt to plot unspecified character %i",
		       chr+32);
      return;
    }

  if (compat_dc == NULL)
    compat_dc = CreateCompatibleDC(dc);

  origbit = SelectObject(compat_dc, f3mask[chr]);
  BitBlt(dc, xpos, ypos, xfont_x, xfont_y, compat_dc, 0, 0, SRCCOPY);
  SelectObject(compat_dc, origbit);
}

/***                           ----// 888 \\----                           ***/

void xfont_initialise(void)
{
}

void xfont_shutdown(void)
{
}

#define DEFAULT_FONT "'Fixed' 9"

static int recur = 0;
/*
 * Internal format for windows font names
 *
 * "face name" width properties
 *
 * Where properties can be one or more of:
 *   b - bold
 *   i - italic
 *   u - underline
 *   f - fixed
 */
xfont* xfont_load_font(char* font)
{
  char   fontcopy[256];
  char*  face_name;
  char*  face_width;
  char*  face_props;
  xfont* xf;

  LOGFONT defn;
  HFONT   hfont;
  int x;

  if (strcmp(font, "font3") == 0)
    {
      xf = malloc(sizeof(struct xfont));

      xf->type = WINFONT_FONT3;
      return xf;
    }
  
  if (recur > 2)
    {
      zmachine_fatal("Unable to load font, and unable to load default font " DEFAULT_FONT);
    }

  recur++;

  if (strlen(font) > 256)
    {
      zmachine_warning("Invalid font name (too long)");
      
      xf = xfont_load_font(DEFAULT_FONT);
      recur--;
      return xf;
    }

  /* Get the face name */
  strcpy(fontcopy, font);
  x = 0;
  while (fontcopy[x++] != '\'')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (font name must be in single quotes)", font);

	  xf = xfont_load_font(DEFAULT_FONT);
	  recur--;
	  return xf;
	}
    }

  face_name = &fontcopy[x];

  x--;
  while (fontcopy[++x] != '\'')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (missing \')", font);

	  xf = xfont_load_font(DEFAULT_FONT);
	  recur--;
	  return xf;
	}
    }
  fontcopy[x] = 0;

  /* Get the font width */
  while (fontcopy[++x] == ' ')
    {
      if (fontcopy[x] == 0)
	{
	  zmachine_warning("Invalid font name: %s (no font size specified)", font);

	  xf = xfont_load_font(DEFAULT_FONT);
	  recur--;
	  return xf;
	}
    }

  face_width = &fontcopy[x];

  while (fontcopy[x] >= '0' &&
	 fontcopy[x] <= '9')
    x++;

  if (fontcopy[x] != ' ' &&
      fontcopy[x] != 0)
    {
      zmachine_warning("Invalid font name: %s (invalid size)", font);

      xf = xfont_load_font(DEFAULT_FONT);
      recur--;
      return xf;
    }

  if (fontcopy[x] != 0)
    {
      fontcopy[x] = 0;
      face_props  = &fontcopy[x+1];
    }
  else
    face_props = NULL;

  defn.lfHeight         = -MulDiv(atoi(face_width),
				  GetDeviceCaps(mainwindc, LOGPIXELSY),
				  72);
  defn.lfWidth          = 0;
  defn.lfEscapement     = defn.lfOrientation = 0;
  defn.lfWeight         = 0;
  defn.lfItalic         = 0;
  defn.lfUnderline      = 0;
  defn.lfStrikeOut      = 0;
  defn.lfCharSet        = ANSI_CHARSET;
  defn.lfOutPrecision   = OUT_DEFAULT_PRECIS;
  defn.lfClipPrecision  = CLIP_DEFAULT_PRECIS;
  defn.lfQuality        = DEFAULT_QUALITY;
  defn.lfPitchAndFamily = DEFAULT_PITCH|FF_DONTCARE;
  strcpy(defn.lfFaceName, face_name);

  if (face_props != NULL)
    {
      for (x=0; face_props[x] != 0; x++)
	{
	  switch (face_props[x])
	    {
	    case 'f':
	    case 'F':
	      defn.lfPitchAndFamily = FIXED_PITCH|FF_DONTCARE;
	      break;

	    case 'b':
	      defn.lfWeight = FW_BOLD;
	      break;

	    case 'B':
	      defn.lfWeight = FW_EXTRABOLD;
	      break;

	    case 'i':
	    case 'I':
	      defn.lfItalic = TRUE;
	      break;

	    case 'u':
	    case 'U':
	      defn.lfUnderline = TRUE;
	      break;
	    }
	}
    }

  hfont = CreateFontIndirect(&defn);

  if (hfont == NULL)
    {
      zmachine_warning("Couldn't load font %s", font);
      xf = xfont_load_font(DEFAULT_FONT);
    }
  else
    {
      xf = malloc(sizeof(struct xfont));
      xf->type = WINFONT_INTERNAL;
      xf->data.win.handle = hfont;
      xf->data.win.defn   = defn;
    }
  
  recur--;
  return xf;
}

void xfont_release_font(xfont* font)
{
  switch (font->type)
    {
    case WINFONT_INTERNAL:
      DeleteObject(font->data.win.handle);
      break;
      
    default:
      break;
    }
  free(font);
}

void xfont_set_colours(int foreground,
		       int background)
{
  fore = foreground%14;
  back = background%14;
}

int xfont_get_width(xfont* font)
{
  switch (font->type)
    {
    case WINFONT_INTERNAL:
      {
	HGDIOBJ ob;
	TEXTMETRIC metric;

	ob = SelectObject(mainwindc,
			  font->data.win.handle);	
	GetTextMetrics(mainwindc, &metric);
	SelectObject(mainwindc, ob);

	return metric.tmAveCharWidth;
      }
      
    case WINFONT_FONT3:
      return xfont_x;
    }

  zmachine_fatal("Programmer is a spoon");
  return -1;
}

int xfont_get_height(xfont* font)
{
  switch (font->type)
    {
    case WINFONT_INTERNAL:
      {
	TEXTMETRIC metric;
	HGDIOBJ ob;
	
	ob = SelectObject(mainwindc,
			  font->data.win.handle);
	GetTextMetrics(mainwindc, &metric);
	SelectObject(mainwindc, ob);

	return metric.tmHeight;
      }

    case WINFONT_FONT3:
      return xfont_y;
    }
  
  zmachine_fatal("Programmer is a spoon");
  return -1;
}

int xfont_get_ascent(xfont* font)
{
  switch (font->type)
    {
    case WINFONT_INTERNAL:
      {
	TEXTMETRIC metric;
	HGDIOBJ ob;
	
	ob = SelectObject(mainwindc,
			  font->data.win.handle);
	GetTextMetrics(mainwindc, &metric);
	SelectObject(mainwindc, ob);

	return metric.tmAscent;
      }

    case WINFONT_FONT3:
      return xfont_y;
    }
  
  zmachine_fatal("Programmer is a spoon");
  return -1;
}

int xfont_get_descent(xfont* font)
{
  switch (font->type)
    {
    case WINFONT_INTERNAL:
      {
	TEXTMETRIC metric;
	HGDIOBJ ob;
	
	ob = SelectObject(mainwindc,
			  font->data.win.handle);
	GetTextMetrics(mainwindc, &metric);
	SelectObject(mainwindc, ob);

	return metric.tmDescent;
      }

    case WINFONT_FONT3:
      return 0;
    }
  
  zmachine_fatal("Programmer is a spoon");
  return -1;
}

int xfont_get_text_width(xfont*     font,
			 const int* string,
			 int        len)
{
  switch (font->type)
    {
    case WINFONT_INTERNAL:
      {
	WCHAR* wide_str;
	int    x;
	SIZE   size;
	HGDIOBJ ob;
	
	ob = SelectObject(mainwindc,
			  font->data.win.handle);

	wide_str = malloc(sizeof(WCHAR)*(len+1));

	for (x=0; x<len; x++)
	  wide_str[x] = string[x];
	wide_str[len] = 0;
	
	GetTextExtentPoint32W(mainwindc,
			      wide_str,
			      len,
			      &size);

	free(wide_str);

	SelectObject(mainwindc, ob);
	
	return size.cx;
      }

    case WINFONT_FONT3:
      return xfont_x * len;
    }
  
  zmachine_fatal("Programmer is a spoon");
  return -1;  
}

void xfont_plot_string(xfont*     font,
		       HDC        dc,
		       int        xpos,
		       int        ypos,
		       const int* string,
		       int        len)
{
  switch (font->type)
    {
    case WINFONT_INTERNAL:
      {
	WCHAR* wide_str;
	int    x;
	SIZE   size;
	RECT   rct;
	HGDIOBJ ob;
	
	ob = SelectObject(dc,
			  font->data.win.handle);

	wide_str = malloc(sizeof(WCHAR)*(len+1));

	for (x=0; x<len; x++)
	  wide_str[x] = string[x];
	wide_str[len] = 0;
	
	GetTextExtentPoint32W(dc,
			      wide_str,
			      len,
			      &size);
	SetTextAlign(dc, TA_TOP|TA_LEFT);
	SetTextColor(dc, wincolour[fore]);
	SetBkColor(dc, wincolour[back]);

	rct.left   = xpos;
	rct.top    = ypos;
	rct.right  = xpos+size.cx;
	rct.bottom = ypos+xfont_get_height(font);

	/*
	DrawTextW(dc,
		  wide_str,
		  len,
		  &rct,
		  DT_SINGLELINE);
	*/
	ExtTextOutW(dc,
		    xpos, ypos,
		    ETO_OPAQUE, &rct,
		    wide_str, len,
		    NULL);

	free(wide_str);
	SelectObject(mainwindc, ob);
      }
      break;

    case WINFONT_FONT3:
      SetTextColor(dc, wincolour[fore]);
      SetBkColor(dc, wincolour[back]);
      {
	int pos;

	for (pos=0; pos<len; pos++)
	  {
	    plot_font_3(dc, string[pos], xpos, ypos);
	    xpos+=xfont_x;
	  }	
      }
      break;

    default:
      zmachine_fatal("Programmer is a spoon");
    }
}

void xfont_choose_new_font(xfont* font,
			   int    fixed_pitch)
{
  CHOOSEFONT dlg;
  LOGFONT    defn;
  
  if (font->type != WINFONT_INTERNAL)
    {
      MessageBox(0, "Sorry, can only reassign Windows fonts", "Zoom",
		 MB_OK|MB_ICONSTOP);
      return;
    }

  defn = font->data.win.defn;
    
  dlg.lStructSize = sizeof(dlg);
  dlg.hwndOwner = mainwin;
  dlg.lpLogFont = &defn;
  dlg.Flags = CF_SCREENFONTS|CF_EFFECTS|CF_INITTOLOGFONTSTRUCT;

  if (fixed_pitch)
    dlg.Flags |= CF_FIXEDPITCHONLY;

  if (ChooseFont(&dlg))
    {
      HFONT fnt;

      fnt = CreateFontIndirect(&defn);

      if (fnt == NULL)
	{
	  MessageBox(0, "Unable to load font", "Error", MB_ICONSTOP);
	  return;
	}

      DeleteObject(font->data.win.handle);
      font->data.win.handle = fnt;
      font->data.win.defn   = defn;
    }
}

#endif
