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
 * Display for MacOS X (Carbon)
 *
 * (Things are a bit odd in here, mainly because lots of this is a fairly
 * direct port from the Windows version)
 */

#include "../config.h"

#if WINDOW_SYSTEM == 3

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#include <Carbon/Carbon.h>

#include "zmachine.h"
#include "display.h"
#include "format.h"
#include "zoomres.h"
#include "rc.h"
#include "hash.h"
#include "xfont.h"
#include "blorb.h"
#include "image.h"
#include "carbondisplay.h"
#include "v6display.h"

#define DEBUG

#ifdef DEBUG
#define dassert(x) if (!(x)) { window_available = 0; zmachine_fatal("Assertion failed: " # x " (line %i)", __LINE__); }
#else
#define dassert(x)
#endif

static int process_events(long int timeout,
			  int* buf,
			  int  buflen);

/* Colour information */
RGBColor maccolour[17] = {
  { 0xdd00, 0xdd00, 0xdd00 },
  { 0xaa00, 0xaa00, 0xaa00 },
  { 0xff00, 0xff00, 0xff00 },

  { 0x0080, 0x9900, 0xee00 },
  { 0x00bb, 0xdd00, 0xff00 },
  { 0x0020, 0x4400, 0x8800 },

  { 0x0000, 0x0000, 0x0000 },
  { 0xff00, 0x0000, 0x0000 },
  { 0x0000, 0xff00, 0x0000 },
  { 0xff00, 0xff00, 0x0000 },
  { 0x0000, 0x0000, 0xff00 },
  { 0xff00, 0x0000, 0xff00 },
  { 0x0000, 0xff00, 0xff00 },
  { 0xff00, 0xff00, 0xcc00 },
  
  { 0xbb00, 0xbb00, 0xbb00 },
  { 0x8800, 0x8800, 0x8800 },
  { 0x4400, 0x4400, 0x4400 }
};

/* Windows, flags */
WindowRef     zoomWindow;
ControlRef    zoomScroll;

DialogRef  fataldlog = nil;
DialogRef  quitdlog  = nil;
DialogRef  carbon_questdlog = nil;
int        carbon_q_res = 0;
int        window_available = 0;
int        quitflag = 0;
static int updating = 0;

static int updatecount = 0;

static int scrollpos = 0;

char carbon_title[256];

#undef  INSETBORDER        /* Define to use the border style used on Unix */
#ifdef  INSETBORDER
#define BORDERWIDTH 8
#else
#define BORDERWIDTH 2
#endif

/* Pixmap display */
static GWorldPtr pixmap = NULL;

static int pix_w, pix_h;
static int pix_fore;
static int pix_back;

static int pix_cstyle = 0;
static int pix_cx = 0;
static int pix_cy = 0;
static int pix_cw = 0;

static int mousew_x, mousew_y, mousew_w, mousew_h = -1;

/* Preferences */
carbon_preferences carbon_prefs = { 0, 0, 0, 0 };

/* Speech */
static SpeechChannel speechchan;

/* Font information */
int            mac_openflag = 0;

static char*   fontlist[] =
{
  "'Arial' 10",
  "'Arial' 10 b",
  "'Arial' 10 i",
  "'Courier New' 10 f",
  "font3",
  "'Arial' 10 ib",
  "'Courier New' 10 fb",
  "'Courier New' 10 fi",
  "'Courier New' 10 fib"
};

/* Window parameters */

#define DEFAULT_FORE 0
#define DEFAULT_BACK 7
#define FIRST_ZCOLOUR 6

/* The caret */
#define FLASH_DELAY (kEventDurationSecond*3)/5

EventLoopTimerRef caret_timer;

/* Input and history buffers */

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

static void draw_input_text(void);
static void rejig_fonts(void);

/***                           ----// 888 \\----                           ***/

/* Lifted from the carbon developer docs */
OSStatus RegisterMyHelpBook(void)
{
  CFBundleRef myAppsBundle;
  CFURLRef myBundleURL;
  FSRef myBundleRef;
  OSStatus err;
  
  /* set up a known state */
  myAppsBundle = NULL;
  myBundleURL = NULL;
  
  /* Get our application's main bundle from Core Foundation */
  myAppsBundle = CFBundleGetMainBundle();
  if (myAppsBundle == NULL) 
    { 
      err = fnfErr;
      goto bail;
    }
  
  /* retrieve the URL to our bundle */
  myBundleURL = CFBundleCopyBundleURL(myAppsBundle);
  if (myBundleURL == nil) 
    { 
      err = fnfErr;
      goto bail;
    }
  
  /* convert the URL to a FSRef */
  if ( ! CFURLGetFSRef(myBundleURL, &myBundleRef))
    {
      err = fnfErr;
      goto bail;
    }
  
  /* register our application's help book */
  err = AHRegisterHelpBook(&myBundleRef);
  if (err != noErr) 
    goto bail;
  
  /* done */
  CFRelease(myBundleURL);
  return noErr;
  
 bail:
  if (myBundleURL != NULL) 
    CFRelease(myBundleURL);
  return err;
}

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
/* Colour functions */

RGBColor* carbon_get_colour(int colour)
{
  if (colour < 16)
    {
      /* Standard z-colour */
      return &maccolour[colour+FIRST_ZCOLOUR];
    }
  else
    {
      static RGBColor col;

      colour -= 16;

      /* Really, we should scale and not just shift... This doesn't give us 
       * good whites...
       */
      col.red   = (colour&0x001f)<<11;
      col.green = (colour&0x03e0)<<6;
      col.blue  = (colour&0x7c00)<<1;

      return &col;
    }
}

/***                           ----// 888 \\----                           ***/

/* Manipulation functions */
Boolean display_force_input(char* text)
{
  static char* buf = NULL;

  if (text_buf == NULL)
    return false;

  buf = realloc(buf, strlen(text)+1);
  
  strcpy(buf, text);
  force_text = buf;

  QuitEventLoop(GetMainEventLoop()); /* Give it a poke */

  return true;
}

/***                           ----// 888 \\----                           ***/

/* Support functions */

static void redraw_input_text(void);
static void draw_window(int win, Rect* rct);
static void draw_borders(void);

/* Required by format.c */
void display_update_region(XFONT_MEASURE left,
			   XFONT_MEASURE top,
			   XFONT_MEASURE right,
			   XFONT_MEASURE bottom)
{
  Rect rct;

  updatecount++;

  if (updatecount == 20)
    {
      rct.top = 0;
      rct.left = 0;
      rct.right = total_x;
      rct.bottom = total_y;
      InvalWindowRect(zoomWindow, &rct);
    }
  else
    {
      return;
    }

  rct.top    = top;
  rct.left   = left;
  rct.right  = right;
  rct.bottom = bottom;
  InvalWindowRect(zoomWindow, &rct);
}

void display_set_scroll_range(XFONT_MEASURE top,
			      XFONT_MEASURE bottom)
{
  SetControl32BitMinimum(zoomScroll,
			  top);
  SetControl32BitMaximum(zoomScroll,
			 bottom - GetControlViewSize(zoomScroll));
}

void display_set_scroll_region(XFONT_MEASURE size)
{
  SetControlViewSize(zoomScroll, size);
}

void display_set_scroll_position(XFONT_MEASURE pos)
{
  SetControl32BitValue(zoomScroll, pos);
}

/* Reformat the text in a window that has been resized */
static void resize_window()
{
  int x,y,z;
  int ofont_x, ofont_y;
  int owin;
  int lastx, lasty;
  Rect rct;

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

  GetWindowBounds(zoomWindow, kWindowContentRgn, &rct);
  
  if ((rct.bottom-rct.top) <= CURWIN.winsy)
    rct.bottom = rct.top + CURWIN.winsy + xfont_y;

  lastx = total_x;
  lasty = total_y;

  total_x = rct.right - rct.left;
  total_y = rct.bottom - rct.top;
  
  if (lastx == total_x &&
      lasty == total_y)
    return;

  MoveControl(zoomScroll, total_x - 15, 0);
  SizeControl(zoomScroll, 16, total_y-14);

  size_x = (total_x-BORDERWIDTH*2-15)/xfont_x;
  size_y = (total_y-BORDERWIDTH*2)/xfont_y;

  win_x = total_x-BORDERWIDTH*2-15;
  win_y = total_y-BORDERWIDTH*2;

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
	      CURWIN.cline[y].fg   = malloc(sizeof(int)*max_x);
	      CURWIN.cline[y].bg   = malloc(sizeof(int)*max_x);
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
					     sizeof(int)*size_x);
	      CURWIN.cline[y].bg   = realloc(CURWIN.cline[y].bg,
					     sizeof(int)*size_x);
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

  redraw_input_text();
  
  zmachine_resize_display(display_get_info());
  
  cur_win = owin;
}

/* Configure the size of a window */
static void size_window(void)
{
  Rect bounds;
  Boolean isvalid;

  bounds.left =
    CFPreferencesGetAppIntegerValue(CFSTR("winLeft"),
				    kCFPreferencesCurrentApplication,
				    &isvalid);
  if (isvalid)
    bounds.right =
      CFPreferencesGetAppIntegerValue(CFSTR("winRight"),
				      kCFPreferencesCurrentApplication,
				      &isvalid);
  if (isvalid)
    bounds.top =
      CFPreferencesGetAppIntegerValue(CFSTR("winTop"),
				      kCFPreferencesCurrentApplication,
				      &isvalid);
  if (isvalid)
    bounds.bottom =
      CFPreferencesGetAppIntegerValue(CFSTR("winBottom"),
				      kCFPreferencesCurrentApplication,
				      &isvalid);

  if (!isvalid)
    {
      win_x = xfont_x*size_x;
      win_y = xfont_y*size_y;
      total_x = win_x + BORDERWIDTH*2 + 15;
      total_y = win_y + BORDERWIDTH*2;
      
      MoveControl(zoomScroll, total_x - 15, 0);
      SizeControl(zoomScroll, 15, total_y - 14);

      bounds.left = bounds.top = 100;

      GetWindowBounds(zoomWindow, kWindowContentRgn, &bounds);
      bounds.right = bounds.left + total_x;
      bounds.bottom = bounds.top + total_y;
      SetWindowBounds(zoomWindow, kWindowContentRgn, &bounds);
    }
  else
    {
      SetWindowBounds(zoomWindow, kWindowContentRgn, &bounds);

      total_x = bounds.right - bounds.left;
      total_y = bounds.bottom - bounds.top;
      win_x = total_x - BORDERWIDTH*2 - 15;
      win_y = total_y - BORDERWIDTH*2;
            
      MoveControl(zoomScroll, total_x - 15, 0);
      SizeControl(zoomScroll, 15, total_y - 14);
    }

  total_y = 0; resize_window();
}

/* Draw the caret */
static void draw_caret()
{
  CGrafPtr thePort;
  Rect portRect;

  thePort = GetQDGlobalsThePort();
  GetPortBounds(thePort, &portRect); 

  if ((caret_on^caret_shown)) /* If the caret needs redrawing... */
    {
      /* 
       * I'd quite like to implement a coloured caret as in the 
       * Windows & X versions, but RGBForeColor doesn't seem to
       * work well with PenMode(srcXor). Well, s/well/at all/.
       */
      PenNormal();
      PenMode(srcXor);
      PenSize(2,1);
      MoveTo(portRect.left+caret_x+BORDERWIDTH, portRect.top+caret_y+BORDERWIDTH);
      Line(0, caret_height);

      PenNormal();

      caret_shown = !caret_shown;
    }
}

/* Redraw the caret */
static void redraw_caret(void)
{
  CGrafPtr oldport = nil;

  if (!updating)
    {
      Rect clip;

      GetPort(&oldport);

      SetPortWindowPort(zoomWindow);
      
      clip.left = BORDERWIDTH;
      clip.right = clip.left+win_x;
      clip.top = BORDERWIDTH;
      clip.bottom = clip.top+win_y;
      ClipRect(&clip);
    }

  draw_caret();

  if (!updating)
    {
      Rect clip;

      clip.left = 0;
      clip.right = total_x;
      clip.top = 0;
      clip.bottom = total_y;
      ClipRect(&clip);

      SetPort(oldport);
    }
}

/* Force the caret to be hidden */
static void hide_caret(void)
{
  caret_on = 0;
  redraw_caret();
}

/* Force the caret to be shown */
static void show_caret(void)
{
  caret_on = 1;
  redraw_caret();
}

/* Flash the caret */
static void flash_caret(void)
{
  caret_on = !caret_on;
  redraw_caret();
}

static pascal void caret_flasher(EventLoopTimerRef iTimer,
				 void*             data)
{
  if (caret_flashing)
    {
      flash_caret();
    }
}

/* Draw the current input buffer */
static void draw_input_text(void)
{
  int w;
  int on;
  int fg, bg;
  int style;

  fg = CURWIN.fore;
  bg = CURWIN.back;
  
  style = CURWIN.style;

  if (style&1)
    {
      fg = CURWIN.back;
      bg = CURWIN.fore;
    }

  on = caret_on;
  hide_caret();

  if (pixmap != NULL)
    {
      int xp, yp;

      xp = win_x/2-pix_w/2;
      yp = win_y/2-pix_h/2;

      style = pix_cstyle;

      input_x = caret_x = pix_cx;
      input_y = caret_y = pix_cy;
      input_y += xfont_get_ascent(font[style_font[(pix_cstyle>>1)&15]]);
      input_width = pix_cw;
      caret_height = xfont_get_height(font[style_font[(pix_cstyle>>1)&15]])-1;

      input_x += xp; input_y += yp;
      caret_x += xp; caret_y += yp;

      fg = pix_fore;
      bg = pix_back;
    }
  else
    {
      if (CURWIN.overlay)
	{
	  input_x = caret_x = xfont_x*CURWIN.xpos;
	  input_y = caret_y = xfont_y*CURWIN.ypos;
	  input_y += xfont_get_ascent(font[style_font[(style>>1)&15]]);
	  caret_height = xfont_y;
	}
      else
	{
	  if (CURWIN.lastline != NULL)
	    {
	      input_x = caret_x = CURWIN.xpos;
	      input_y = caret_y = CURWIN.lastline->baseline-scrollpos;
	      caret_y -= CURWIN.lastline->ascent;
	      caret_height = CURWIN.lastline->ascent+CURWIN.lastline->descent-1;
	    }
	  else
	    {
	      input_x = input_y = caret_x = caret_y = 0;
	      caret_height = xfont_y-1;
	    }
	}

      input_width = win_x - input_x;
    }

  if (text_buf != NULL)
    {
      Rect rct;

      CGrafPtr thePort;
      Rect portRect;
      
      thePort = GetQDGlobalsThePort();
      GetPortBounds(thePort, &portRect); 

      dassert(style < 32);
      dassert(style >= 0);
      dassert(style_font[(style>>1)&15] <= n_fonts &&
	      style_font[(style>>1)&15] >= 0);
      w = xfont_get_text_width(font[style_font[(style>>1)&15]],
			       text_buf,
			       istrlen(text_buf));

      PenNormal();
      rct.left   = portRect.left + input_x + BORDERWIDTH;
      rct.right  = portRect.left + input_x + input_width + BORDERWIDTH;
      rct.top    = portRect.top + caret_y + BORDERWIDTH;
      rct.bottom = rct.top + xfont_get_height(font[style_font[(style>>1)&15]]);
      RGBForeColor(carbon_get_colour(bg));
      PaintRect(&rct);

      caret_x += xfont_get_text_width(font[style_font[(style>>1)&15]],
				      text_buf,
				      buf_offset);

      xfont_set_colours(fg, bg);
      xfont_plot_string(font[style_font[(style>>1)&15]],
			input_x+BORDERWIDTH, -input_y-BORDERWIDTH,
			text_buf,
			istrlen(text_buf));
    }

  if (on)
    show_caret();
}

/* Redraw the input text */
static void redraw_input_text(void)
{
  Rect clip;

  SetPortWindowPort(zoomWindow);

#ifdef USE_QUARTZ
  carbon_set_context();
#endif

  clip.left = BORDERWIDTH;
  clip.right = clip.left+win_x;
  clip.top = BORDERWIDTH;
  clip.bottom = clip.right+win_y;
  ClipRect(&clip);

  draw_input_text();

  clip.left = 0;
  clip.right = total_x;
  clip.top = 0;
  clip.bottom = total_y;
  ClipRect(&clip);

  CGContextSynchronize(carbon_quartz_context);
}

/* Set/unset 'fullscreen' */
static void set_fullscreen(int is_fullscreen)
{
  static int setting = 0;
  static int used_fs = 0;

  static Rect oldBounds;

  if (is_fullscreen == -1)
    {
      if (setting)
	is_fullscreen = 0;
      else
	is_fullscreen = 1;
    }

  if (setting == is_fullscreen)
    {
      return;
    }

  setting = is_fullscreen;

  if (is_fullscreen)
    {
      Rect newBounds;
      CGrafPtr oldport = nil;
      GDHandle dev;

      HideMenuBar();

      GetWindowBounds(zoomWindow, kWindowContentRgn, &oldBounds);

      GetPort(&oldport);
      SetPortWindowPort(zoomWindow);
      dev = GetGDevice();
      newBounds = (*dev)->gdRect;
      SetPort(oldport);

      carbon_set_scale_factor((double)(newBounds.right-newBounds.left) / 
			      (double)(oldBounds.right-oldBounds.left));
      carbon_display_rejig();

      SetWindowBounds(zoomWindow, kWindowContentRgn, &newBounds);

      ChangeWindowAttributes(zoomWindow, 0, kWindowResizableAttribute);

      if (!used_fs)
	{
	  carbon_display_message("Fullscreen mode started",
				 "To exit fullscreen mode, use Command-F");
	}
    }
  else
    {
      ShowMenuBar();
      carbon_set_scale_factor(1.0);
      SetWindowBounds(zoomWindow, kWindowContentRgn, &oldBounds);
      carbon_display_rejig();

      ChangeWindowAttributes(zoomWindow, kWindowResizableAttribute, 0);

      used_fs = 1;
      
    }
}

/* Redraw (part of?) the window */
void redraw_window(Rect* rct)
{
  RgnHandle oldclip = nil;

  if (!updating)
    {
      SetPortWindowPort(zoomWindow);

      oldclip = NewRgn();
      GetClip(oldclip);

      ClipRect(rct);
     } 
 
#ifdef USE_QUARTZ
  carbon_set_context();
#endif

  draw_window(0, rct);
  draw_window(1, rct);
  draw_window(2, rct);
  caret_shown = 0;
  draw_input_text();
  draw_borders();

  if (!updating)
    {
      SetClip(oldclip);
      DisposeRgn(oldclip);
    }

  if (more_on)
    {
      int more[] = { '[', 'M', 'o', 'r', 'e', ']' };
      XFONT_MEASURE w, h;
      XFONT_MEASURE hgt;

      h   = xfont_get_descent(font[style_font[1]]);
      hgt = xfont_get_height(font[style_font[1]]);
      w   = xfont_get_text_width(font[style_font[1]], more, 6);

      if (carbon_prefs.use_quartz)
	{
	  CGRect morebg;

	  CGContextSetAlpha(carbon_quartz_context, 0.80);

	  morebg = CGRectMake(total_x-w-17-1.5,
			      0,
			      w+1.5, hgt+1.5);

	  CGContextSetRGBFillColor(carbon_quartz_context, 
				   (float)maccolour[3].red/65536.0,
				   (float)maccolour[3].green/65536.0,
				   (float)maccolour[3].blue/65536.0,
				   1.0);
	  CGContextFillRect(carbon_quartz_context, morebg);

	  CGContextSetRGBStrokeColor(carbon_quartz_context, 
				     (float)maccolour[4].red/65536.0,
				     (float)maccolour[4].green/65536.0,
				     (float)maccolour[4].blue/65536.0,
				     1.0);
	  CGContextSetLineWidth(carbon_quartz_context, 1.0);
	  CGContextBeginPath(carbon_quartz_context);
	  CGContextMoveToPoint(carbon_quartz_context, total_x-w-17-1.5, 0.5);
	  CGContextAddLineToPoint(carbon_quartz_context, total_x-w-17-1.5, hgt+1.5);
	  CGContextAddLineToPoint(carbon_quartz_context, total_x-17-1.5, hgt+1.5);
	  CGContextStrokePath(carbon_quartz_context);

	  CGContextSetRGBStrokeColor(carbon_quartz_context, 
				     (float)maccolour[5].red/65536.0,
				     (float)maccolour[5].green/65536.0,
				     (float)maccolour[5].blue/65536.0,
				     1.0);
	  CGContextSetLineWidth(carbon_quartz_context, 1.5);
	  CGContextBeginPath(carbon_quartz_context);
	  CGContextMoveToPoint(carbon_quartz_context, total_x-w-17-1.5, 0.5);
	  CGContextAddLineToPoint(carbon_quartz_context, total_x-17-0.5, 0.5);
	  CGContextAddLineToPoint(carbon_quartz_context, total_x-17-0.5, hgt+1.5);
	  CGContextStrokePath(carbon_quartz_context);
	}
      else
	{
	  Rect frct;

	  frct.left   = total_x-w-17-2;
	  frct.right  = total_x-17;
	  frct.top    = total_y-hgt-2;
	  frct.bottom = total_y;
	  RGBForeColor(&maccolour[3]);
	  PaintRect(&frct);

	  PenNormal();
	  PenSize(1,1);

	  RGBForeColor(&maccolour[4]);
	  MoveTo(total_x-w-17-3, total_y-1);
	  Line(0, -(hgt+2));
	  Line(w+2, 0);
	  RGBForeColor(&maccolour[5]);
	  Line(0, hgt+2);
	  Line(-(w+2), 0);
	}

      xfont_set_colours(0, 6);
      xfont_plot_string(font[style_font[1]], total_x-w-17-1, -(total_y-h-1), more, 6);

      if (carbon_prefs.use_quartz)
	{
	  CGContextSetAlpha(carbon_quartz_context, 1.0);
	}
    }

  CGContextSynchronize(carbon_quartz_context);
}

/***                           ----// 888 \\----                           ***/

/* Event handlers */

static pascal OSStatus zoom_evt_handler(EventHandlerCallRef myHandlerChain,
					EventRef event, 
					void* data)
{
  UInt32    cla;
  UInt32    wha;
  HICommand cmd;

  cla = GetEventClass(event);
  wha = GetEventKind(event);

  switch (cla)
    {
    case kEventClassCommand:
      switch (wha)
	{
	case kEventCommandProcess:
	  GetEventParameter(event, kEventParamDirectObject,
			    typeHICommand, NULL, sizeof(HICommand),
			    NULL, &cmd);
	  switch (cmd.commandID)
	    {
	    case 'REST':
	      if (!display_force_input("restore"))
		{
		  carbon_display_message("Unable to force restore",
					 "Unable to force a restore at this point (the game is probably not waiting for the right kind of input)");
		}
	      break;

	    case 'SAVE':
	      if (!display_force_input("save"))
		{
		  carbon_display_message("Unable to force save",
					 "Unable to force a save at this point (the game is probably not waiting for the right kind of input)");
		}
	      break;

	    case 'FULL':
	      set_fullscreen(-1);
	      break;

	    case kHICommandPreferences:
	      carbon_show_prefs();
	      break;

	    case kHICommandQuit:
	      if (window_available)
		{
		  AlertStdCFStringAlertParamRec par;
		  OSStatus res;
	
		  par.version       = kStdCFStringAlertVersionOne;
		  par.movable       = false;
		  par.helpButton    = false;
		  par.defaultText   = CFSTR("Quit Zoom");
		  par.cancelText    = CFSTR("Continue playing");
		  par.otherText     = nil;
		  par.defaultButton = kAlertStdAlertCancelButton;
		  par.cancelButton  = kAlertStdAlertOKButton;
		  par.position      = kWindowDefaultPosition;
		  par.flags         = 0;
		  
		  res = CreateStandardSheet(kAlertCautionAlert,
					    CFSTR("Are you sure you want to quit Zoom?"),
					    CFSTR("Any changes since your last save will be lost"),
					    &par,
					    GetWindowEventTarget(zoomWindow),
					    &quitdlog);
		  ShowSheetWindow(GetDialogWindow(quitdlog), zoomWindow);
		}
	      else
		{
		  quitflag = 1;
		}
	      break;
	      
	    default:
	      return eventNotHandledErr;
	    }
	  return noErr;

	default:
	  return eventNotHandledErr;
	}
      break;

    case kEventClassMouse:
      switch (wha)
	{
	case kEventMouseDown:
	  {
	    short part;
	    WindowPtr ourwindow;
	    HIPoint   argh;
	    Point     point;

	    /* 
	     * Yay, more great docs. Apple's docs specify that the type here
	     * should be 'QDPoint', which doesn't exist, of course.
	     * And HIPoint is almost totally useless for any real work,
	     * so the first thing we have to do is convert it to a Point.
	     * None of this is in the docs, either.
	     */
	    GetEventParameter(event, kEventParamMouseLocation,
			      typeHIPoint, NULL, sizeof(HIPoint),
			      NULL, &argh);
	    point.h = argh.x;
	    point.v = argh.y;
	    part = FindWindow(point, &ourwindow);

	    switch (part)
	      {
	      case inMenuBar:
		MenuSelect(point);
		return noErr;
		break;

	      default:
		return eventNotHandledErr;
	      }
	  }
	  break;
	}

    case kEventClassAppleEvent:
      {
	EventRecord er;
	OSStatus erm;

	ConvertEventRefToEventRecord(event, &er);
	erm = AEProcessAppleEvent( &er );

	return erm;
      }
    }

  return eventNotHandledErr;
}

static inline int isect_rect(Rect* r1, Rect* r2)
{
  return 1;
}

/* Draws a Z-Machine window */
/*
 * *ahem* The zoom screen model (versions 1-5) is as follows:
 *
 * There are 3 windows - one main text window and two overlay windows.
 * One of the overlay windows is used as the 'split' window in version
 * 4+, and the other is used as the status bar in version 3 (all three
 * windows may be used if a v3 game splits the screen).
 *
 * Overlay windows are an array of cells that cover the window. As each
 * cell has a fixed size (or *should* do, there's not a lot stopping the
 * user from selecting a non-proportional font), there may be some space
 * left at the edges - this is filled in in the colours of the neighbouring
 * cells. The text window is a full formatted text window. We do things in
 * a slightly complicated manner here: while this does make bits of the
 * code pretty much unreadable, it has the advantage of allowing us to
 * resize and reformat the window dynamically (yay).
 *
 * Each overlay window has a 'solid' section and a 'transparent' section.
 * The 'solid' section is that defined by the split, the rest is transparent.
 * The difference between the sections comes when the background colour of
 * a cell is set to -colour-1. In the 'solid' section, this cell will be
 * plotted in that colour. In the 'transparent' section, this cell will not
 * be plotted. All other cells are plotted in both sections.
 *
 * The text window should be drawn first, followed by the overlay windows.
 */
static void draw_window(int   win,
			Rect* rct)
{
  struct line* line;
  int x;
  XFONT_MEASURE width;
  int offset;
  XFONT_MEASURE lasty;
  struct text* text;

  CGrafPtr thePort;
  Rect portRect;
  Rect frct;

  thePort = GetQDGlobalsThePort();
  GetPortBounds(thePort, &portRect);

  updatecount = 0;

  dassert(rct != NULL);

  if (pixmap != NULL)
    {
      Rect src, dst, r;
      PixMapHandle winPix, pixPix;

      static const RGBColor black = { 0,0,0 };
      static const RGBColor white = { 0xffff, 0xffff, 0xffff };
      int xp, yp;

      if (win != 0)
	return;

      xp = win_x/2-pix_w/2;
      yp = win_y/2-pix_h/2;

      src.left   = 0;
      src.top    = 0;
      src.right  = pix_w;
      src.bottom = pix_h;

      dst.left   = BORDERWIDTH+xp;
      dst.top    = BORDERWIDTH+yp;
      dst.right  = dst.left + pix_w;
      dst.bottom = dst.top + pix_h;

      RGBForeColor(&white);
      r.left = 0;
      r.top  = 0;
      r.right = total_x - 15;
      r.bottom = yp+BORDERWIDTH;
      PaintRect(&r);
      
      r.right = xp + BORDERWIDTH;
      r.bottom = total_y;
      PaintRect(&r);

      r.right = total_x-15;
      r.bottom = total_y;

      r.left = total_x-15-BORDERWIDTH-xp;
      r.top  = 0;
      PaintRect(&r);

      r.left = 0;
      r.top  = total_y-BORDERWIDTH-yp;
      PaintRect(&r);

      RGBForeColor(&black);
      RGBBackColor(&white);

      winPix = GetPortPixMap(thePort);
      pixPix = GetGWorldPixMap(pixmap);

      if (!LockPixels(winPix))
	zmachine_fatal("Unable to lock window");
      if (!LockPixels(pixPix))
	zmachine_fatal("Unable to lock pixmap");
      CopyBits((BitMap*)*pixPix, (BitMap*)*winPix, &src, &dst,
	       srcCopy, NULL);
      UnlockPixels(pixPix);
      UnlockPixels(winPix);

      return;
    }

  if (text_win[win].overlay)
    {
      /* Window is an overlay window (status bars, etc) */
      int x,y;

      x = y = 0;

      for (y=(text_win[win].winsy/xfont_y); y<size_y; y++)
	{
	  int bg = 0;

	  for (x=0; x<size_x; x++)
	    {
	      if (text_win[win].cline[y].cell[x] != ' ' ||
		  text_win[win].cline[y].bg[x] >= 0     ||
		  y*xfont_y<text_win[win].winly)
		{
		  int len;
		  int fn, fg;
		  
		  len = 1;
		  fg = text_win[win].cline[y].fg[x];
		  bg = text_win[win].cline[y].bg[x];
		  fn = text_win[win].cline[y].font[x];
		  
		  /* We want to plot as much as possible in one go */
		  while (x+len < size_x &&
			 text_win[win].cline[y].font[x+len] == fn &&
			 text_win[win].cline[y].fg[x+len]   == fg &&
			 text_win[win].cline[y].bg[x+len]   == bg &&
			 (bg >= 0 ||
			  text_win[win].cline[y].cell[x+len] != ' ' ||
			  y*xfont_y<text_win[win].winly))
		    len++;

		  dassert(x + len <= size_x);
		  dassert(fg >= 0);
		  
		  if (bg < 0)
		    bg = -(bg+1);

		  if (carbon_prefs.use_quartz)
		    {
		      CGRect bgr;
		      RGBColor bg_col;

		      bg_col = *carbon_get_colour(bg);
		      
		      bgr = CGRectMake(portRect.left+BORDERWIDTH+(float)x*xfont_x,
				       (portRect.bottom-portRect.top)-
				       ((float)y*xfont_y+
					xfont_y+
					BORDERWIDTH),
				       xfont_x*len,
				       xfont_y);
		      CGContextSetRGBFillColor(carbon_quartz_context, 
					       (float)bg_col.red/65536.0,
					       (float)bg_col.green/65536.0,
					       (float)bg_col.blue/65536.0,
					       1.0);
		      CGContextFillRect(carbon_quartz_context, bgr);
		    }
		  else
		    {
		      frct.top    = portRect.top + (y*xfont_y + BORDERWIDTH);
		      frct.bottom = frct.top + xfont_y;
		      frct.left   = portRect.left + BORDERWIDTH +
			x*xfont_x;
		      frct.right  = frct.left + xfont_x*len;
		      RGBForeColor(carbon_get_colour(bg));
		      PaintRect(&frct);
		    }

		  xfont_set_colours(fg, bg);
		  xfont_plot_string(font[text_win[win].cline[y].font[x]],
				    BORDERWIDTH + (float)x*xfont_x,
				    -(y*xfont_y +
				      xfont_get_ascent(font[text_win[win].cline[y].font[x]]))
				    - BORDERWIDTH,
				    &text_win[win].cline[y].cell[x],
				    len);

		  x += len-1;
		}
	    }
	  
	  /* May need to fill in to the end of the line */
	  if (xfont_x*size_x < win_x &&
	      y*xfont_y<text_win[win].winly)
	    {
	      Rect frct;

	      frct.top    = portRect.top + y*xfont_y+BORDERWIDTH;
	      frct.left   = portRect.left + xfont_x*size_x+BORDERWIDTH;
	      frct.bottom = frct.top + xfont_y;
	      frct.right  = portRect.left + win_x+BORDERWIDTH;
	      RGBForeColor(carbon_get_colour(bg));
	      PaintRect(&frct);
	    }
	}
    }
  else
    {
      RgnHandle oldregion;
      RgnHandle newregion;

      /* Set up the clip region */
      oldregion = NewRgn();
      newregion = NewRgn();
      GetClip(oldregion);

      frct.left   = portRect.left + BORDERWIDTH;
      frct.right  = portRect.left + win_x + BORDERWIDTH;
      frct.top    = portRect.top + text_win[win].winsy + BORDERWIDTH;
      frct.bottom = portRect.top + text_win[win].winly + BORDERWIDTH;
      RectRgn(newregion, &frct);

      SectRgn(oldregion, newregion, newregion);
      
      SetClip(newregion);

      line = text_win[win].line;

      /* Free any lines that scrolled off ages ago */
      if (line != NULL)
	{
	  while (line->baseline < -32768)
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
	}

      /* Skip to the first visible line */
      if (line != NULL)
	{
	  while (line != NULL && line->baseline + line->descent - scrollpos < text_win[win].winsy)
	    line = line->next;
	}

      /* Fill in to the start of the lines */
      if (line != NULL)
	{
	  frct.top    = portRect.top+text_win[win].winsy + BORDERWIDTH;
	  frct.bottom = portRect.top+line->baseline-line->ascent + BORDERWIDTH - scrollpos;
	  frct.left   = portRect.left + BORDERWIDTH;
	  frct.right  = frct.left + win_x;
	  if (frct.top < frct.bottom)
	    {
	      RGBForeColor(carbon_get_colour(text_win[win].winback));
	      PaintRect(&frct);
	    }

	  lasty = frct.bottom;
	}
      else
	lasty = portRect.top + text_win[win].winsy + BORDERWIDTH;

      /* Iterate through the lines and plot what's necessary */
      while (line != NULL &&
	     line->baseline - line->ascent - scrollpos < text_win[win].winly)
	{
	  text   = line->start;
	  width     = 0;
	  offset    = line->offset;

	  /*
	   * Each line may span several text objects. We have to plot
	   * each one in turn.
	   */
	  for (x=0; x<line->n_chars;)
	    {
	      XFONT_MEASURE w;
	      int toprint;

	      /* 
	       * Work out the amount of text to plot from the current 
	       * text object 
	       */
	      toprint = line->n_chars-x;
	      if (toprint > (text->len - offset))
		toprint = text->len - offset;
	      
	      if (toprint > 0)
		{
		  /* Plot the text */
		  if (text->text[toprint+offset-1] == 10)
		    {
		      toprint--;
		      x++;
		    }

		  dassert(offset+toprint <= text->len);
		  w = xfont_get_text_width(font[text->font],
					   text->text + offset,
					   toprint);

		  if (carbon_prefs.use_quartz)
		    {
		      CGRect bgr;
		      RGBColor bg_col;

		      bg_col = *carbon_get_colour(text->bg);
		      
		      bgr = CGRectMake(portRect.left+width+BORDERWIDTH,
				       (portRect.bottom-portRect.top)-
				       (line->baseline+line->descent+
					BORDERWIDTH-scrollpos),
				       w,
				       line->ascent+line->descent);
		      CGContextSetRGBFillColor(carbon_quartz_context, 
					       (float)bg_col.red/65536.0,
					       (float)bg_col.green/65536.0,
					       (float)bg_col.blue/65536.0,
					       1.0);
		      CGContextFillRect(carbon_quartz_context, bgr);
		    }
		  else
		    {
		      frct.top    = portRect.top + line->baseline - line->ascent 
			+ BORDERWIDTH - scrollpos;
		      frct.bottom = frct.top + line->ascent + line->descent;
		      frct.left   = portRect.left + width + BORDERWIDTH;
		      frct.right  = frct.left + w;
		      RGBForeColor(carbon_get_colour(text->bg));
		      PaintRect(&frct);
		    }

		  xfont_set_colours(text->fg,
				    text->bg);
		  xfont_plot_string(font[text->font],
				    width + BORDERWIDTH,
				    -line->baseline - BORDERWIDTH + scrollpos,
				    text->text + offset,
				    toprint);

		  x      += toprint;
		  offset += toprint;
		  width  += w;
		}
	      else
		{
		  /* At the end of this object - move onto the next */
		  offset = 0;
		  text = text->next;
		}
	    }

	  /* Fill in to the end of the line */
	  frct.top    = portRect.top+line->baseline - line->ascent + BORDERWIDTH -
	    scrollpos;
	  frct.bottom = frct.top + line->ascent + line->descent;
	  frct.left   = portRect.left + width + BORDERWIDTH;
	  frct.right  = portRect.left + win_x + BORDERWIDTH;
	  RGBForeColor(carbon_get_colour(text_win[win].winback));
	  PaintRect(&frct);

	  lasty = frct.bottom;

	  /* Move on */
	  line = line->next;
	}

      /* Fill in to the bottom of the window */
      frct.top    = lasty;
      frct.bottom = win_y + BORDERWIDTH;
      frct.left = BORDERWIDTH;
      frct.right = BORDERWIDTH+win_x;
      if (frct.top < frct.bottom)
	{
	  RGBForeColor(carbon_get_colour(text_win[win].winback));
	  PaintRect(&frct);
	}

      /* Reset the clip region */
      SetClip(oldregion);

      DisposeRgn(newregion);
      DisposeRgn(oldregion);
    }
}

static void draw_borders()
{
  Rect rct;

  CGrafPtr thePort;
  Rect portRect;

  thePort = GetQDGlobalsThePort();
  GetPortBounds(thePort, &portRect); 

  PenNormal();
  RGBForeColor(&maccolour[2]);

#ifdef INSETBORDER
  /* Gray border */
  RGBForeColor(&maccolour[0]);

  /* Top */
  rct.left   = portRect.left;
  rct.right  = portRect.left+win_x+BORDERWIDTH*2;
  rct.top    = portRect.top;
  rct.bottom = rct.top+BORDERWIDTH-2;
  PaintRect(&rct);

  /* Bottom */
  rct.bottom = portRect.bottom;
  rct.top    = rct.bottom-BORDERWIDTH+2;
  PaintRect(&rct);

  /* Left */
  rct.left   = portRect.left;
  rct.right  = rct.left+BORDERWIDTH-2;
  rct.top    = portRect.top;
  rct.bottom = portRect.bottom;
  PaintRect(&rct);
  
  /* Right */
  rct.left  = portRect.left+win_x+BORDERWIDTH+2;
  rct.right = rct.left+BORDERWIDTH-2;
  PaintRect(&rct);

  /* Inset border */

  /* Top */
  rct.left   = portRect.left+BORDERWIDTH-2;
  rct.right  = rct.left+win_x+4;
  rct.top    = portRect.top+BORDERWIDTH-2;
  rct.bottom = rct.top+2;
  RGBForeColor(&maccolour[1]);
  PaintRect(&rct);

  /* Bottom */
  rct.top    = portRect.bottom-BORDERWIDTH;
  rct.bottom = rct.top+2;
  RGBForeColor(&maccolour[2]);
  PaintRect(&rct);

  /* Left */
  rct.left   = portRect.left+BORDERWIDTH-2;
  rct.right  = rct.left+2;
  rct.top    = portRect.top+BORDERWIDTH-2;
  rct.bottom = rct.top+win_y+4;
  RGBForeColor(&maccolour[1]);
  PaintRect(&rct);
  
  /* Right */
  rct.left  = portRect.left+win_x+BORDERWIDTH;
  rct.right = rct.left+2;
  RGBForeColor(&maccolour[2]);
  PaintRect(&rct);

#else

  RGBForeColor(&maccolour[2]);

  /* Top */
  rct.left   = portRect.left;
  rct.right  = portRect.left+win_x+BORDERWIDTH*2;
  rct.top    = portRect.top;
  rct.bottom = rct.top+BORDERWIDTH;
  PaintRect(&rct);

  /* Bottom */
  rct.bottom = portRect.bottom;
  rct.top    = rct.bottom-BORDERWIDTH;
  PaintRect(&rct);

  /* Left */
  rct.left   = portRect.left;
  rct.right  = rct.left+BORDERWIDTH;
  rct.top    = portRect.top;
  rct.bottom = portRect.bottom;
  PaintRect(&rct);
  
  /* Right */
  rct.left  = portRect.left+win_x+BORDERWIDTH;
  rct.right = rct.left+BORDERWIDTH;
  PaintRect(&rct);
#endif
}

static void update_scroll(void)
{
  Rect rct;
  int newpos;
  
  newpos = GetControl32BitValue(zoomScroll);
  
  if (newpos != scrollpos)
    {
      scrollpos = newpos;

      rct.top    = text_win[0].winsy+BORDERWIDTH;
      rct.bottom = text_win[0].winly+BORDERWIDTH;
      rct.left   = BORDERWIDTH;
      rct.right  = BORDERWIDTH+win_x;

      updating = 1;
      redraw_window(&rct);
      updating = 0;
    }
}

static pascal void zoom_scroll_handler(ControlRef control,
				       ControlPartCode partcode)
{
  if (partcode)
    {
      int newpos;

      newpos = scrollpos;

      switch (partcode)
	{
	case kControlUpButtonPart:
	  newpos -= xfont_y;
	  break;
	case kControlDownButtonPart:
	  newpos += xfont_y;
	  break;

	case kControlPageUpPart:
	  newpos -= text_win[0].winly - text_win[0].winsy - xfont_y;
	  break;
	case kControlPageDownPart:
	  newpos += text_win[0].winly - text_win[0].winsy - xfont_y;
	  break;
	}

      if (newpos != scrollpos)
	{
	  if (text_win[0].line != NULL &&
	      newpos < text_win[0].line->baseline - text_win[0].line->ascent)
	    newpos = text_win[0].line->baseline - text_win[0].line->ascent;
	  if (newpos > 0)
	    newpos = 0;
	  
	  SetControl32BitValue(zoomScroll, newpos);
	}
    }
  update_scroll(); /* There's only one event, so we do this...  */
}

static pascal OSStatus zoom_wnd_handler(EventHandlerCallRef myHandlerChain,
					EventRef event, 
					void* data)
{
  UInt32    cla;
  UInt32    wha;

  int x;

  cla = GetEventClass(event);
  wha = GetEventKind(event);

  switch (cla)
    {
    case kEventClassWindow:
      switch (wha)
	{
	case kEventWindowDrawContent:
	  /* Draw the window */
	  {
	    Rect rct;

	    rct.top = rct.left = 0;
	    rct.bottom = total_y;
	    rct.right  = total_x;

	    updating = 1;
	    redraw_window(&rct);
	    updating = 0;
	  }
	  break;

	case kEventWindowResizeCompleted:
	  /* Force a complete window update */
	  scroll_overlays = 0;
	  resize_window();
	  scroll_overlays = 1;
	  display_update();
	  break;

	case kEventWindowBoundsChanged:
	  {
	    Rect rct;
	    int old_x, old_y;

	    old_x = total_x;
	    old_y = total_y;

	    /* Resize the text in the window */
	    scroll_overlays = 0;
	    resize_window();
	    scroll_overlays = 1;

	    rct.top = rct.left = 0;
	    rct.bottom = total_y;
	    rct.right  = total_x;
	    
	    /* Redraw the window */
	    if (total_x != old_x || total_y != old_y)
	      {
		display_update();
	      }
	  }
	  break;

	case kEventWindowFocusRelinquish:
	case kEventWindowDeactivated:
	  if (!more_on)
	    show_caret();
	  else
	    hide_caret();
	  caret_flashing = 0;
	  return eventNotHandledErr;
	  break;

	case kEventWindowFocusAcquired:
	case kEventWindowActivated:
	  if (!more_on)
	    caret_flashing = 1;
	  return eventNotHandledErr;
	}
      break;

    case kEventClassCommand:
      switch (wha)
	{
	case kEventProcessCommand:
	  {
	    HICommand cmd;

	    GetEventParameter(event, kEventParamDirectObject,
			      typeHICommand, NULL, sizeof(HICommand),
			      NULL, &cmd);

	    switch (cmd.commandID)
	      {
	      case kHICommandOK:
		if (carbon_questdlog != nil)
		  {
		    QuitAppModalLoopForWindow(carbon_message_win);
		    carbon_questdlog = nil;
		    carbon_q_res = 1;
		    return noErr;
		  }
		else if (fataldlog != nil)
		  {
		    fataldlog = nil;
		    display_exit(1);
		    return noErr;
		  }
		else if (quitdlog != nil)
		  {
		    quitdlog = nil;
		    display_exit(0);
		    return noErr;
		  }

		return eventNotHandledErr;
		break;

	      case kHICommandCancel:
		if (carbon_questdlog != nil)
		  {
		    QuitAppModalLoopForWindow(GetDialogWindow(carbon_questdlog));
		    carbon_questdlog = nil;
		    carbon_q_res = 0;
		    return noErr;
		  }
		else if (fataldlog != nil)
		  {
		    fataldlog = nil;
		    return noErr;
		  }
		else if (quitdlog != nil)
		  {
		    quitdlog = nil;
		    return noErr;
		  }
		break;

	      case 'abou':
		carbon_display_about();
		break;
		
	      default:
		return eventNotHandledErr;
	      }
	  }
	  break;
	}
      break;

    case kEventClassMouse:
      switch (wha)
	{
	case kEventMouseDown:
	  {
	    short part;
	    WindowPtr ourwindow;
	    HIPoint   argh;
	    Point     point;

	    GetEventParameter(event, kEventParamMouseLocation,
			      typeHIPoint, NULL, sizeof(HIPoint),
			      NULL, &argh);
	    point.h = argh.x;
	    point.v = argh.y;
	    part = FindWindow(point, &ourwindow);

	    switch (part)
	      {
	      case inContent:
		return eventNotHandledErr;

	      case inGoAway:
		if (TrackGoAway(ourwindow, point))
		  {
		    AlertStdCFStringAlertParamRec par;
		    OSStatus res;

		    par.version       = kStdCFStringAlertVersionOne;
		    par.movable       = false;
		    par.helpButton    = false;
		    par.defaultText   = CFSTR("Quit Zoom");
		    par.cancelText    = CFSTR("Continue playing");
		    par.otherText     = nil;
		    par.defaultButton = kAlertStdAlertCancelButton;
		    par.cancelButton  = kAlertStdAlertOKButton;
		    par.position      = kWindowDefaultPosition;
		    par.flags         = 0;

		    res = CreateStandardSheet(kAlertCautionAlert,
					      CFSTR("Are you sure you want to quit Zoom?"),
					      CFSTR("Any changes since your last save will be lost"),
					      &par,
					      GetWindowEventTarget(zoomWindow),
					      &quitdlog);
		    ShowSheetWindow(GetDialogWindow(quitdlog), zoomWindow);
		  }
		break;

	      case inProxyIcon:
		{
		  OSStatus status = TrackWindowProxyDrag(zoomWindow, 
							 point);
		  
		  if (status == errUserWantsToDragWindow)
		    return eventNotHandledErr;
		}
		break;

	      default:
		return eventNotHandledErr;
	      }
	  }
	  break;
	  
	case kEventMouseUp:
	  {
	    short part;
	    WindowPtr ourwindow;
	    HIPoint   argh;
	    Point     point;
	    Rect      bound;
	    UInt32    count;
	    int key;

	    GetEventParameter(event, kEventParamClickCount,
			      typeUInt32, NULL, sizeof(UInt32),
			      NULL, &count);
	    key = 254;
	    if (count == 2)
	      key = 253;
 
	    GetEventParameter(event, kEventParamMouseLocation,
			      typeHIPoint, NULL, sizeof(HIPoint),
			      NULL, &argh);
	    point.h = argh.x;
	    point.v = argh.y;
	    part = FindWindow(point, &ourwindow);
	    
	    if (part == inContent && 
		(terminating[key] || text_buf == NULL))
	      {
		int xp, yp;

		GetWindowBounds(ourwindow, kWindowContentRgn, &bound);

		click_x = (argh.x - BORDERWIDTH - bound.left);
		click_y = (argh.y - BORDERWIDTH - bound.top);

		xp = click_x - (win_x/2-pix_w/2);
		yp = click_y - (win_y/2-pix_h/2);

		if (pixmap == NULL ||
		    mousew_h == -1 ||
		    (xp > mousew_x          && yp > mousew_y &&
		     xp < mousew_x+mousew_w && yp < mousew_y+mousew_h))
		  {
		    read_key = key;
		    return noErr;
		  }
	      }

	    return eventNotHandledErr;
	  }
	  break;
	}
      break;

    case kEventClassTextInput:
      switch (wha)
	{
	case kEventTextInputUnicodeForKeyEvent:
	  {
	    UniChar* text;
	    UInt32   size;
	    int      nchars;
	    UInt32   mod;

	    EventRef* keyRef;

	    if (scrollpos != 0)
	      {
		SetControl32BitValue(zoomScroll, 0);
		update_scroll();
	      }

	    /* Read the text */
	    GetEventParameter(event, kEventParamTextInputSendText,
			      typeUnicodeText, NULL, 0, &size, NULL);
	    if (size == 0)
	      return eventNotHandledErr;
	    text = malloc(size);
	    GetEventParameter(event, kEventParamTextInputSendText,
			      typeUnicodeText, NULL, size, NULL, text);
	    nchars = size>>1;

	    /* Read the character codes */
	    GetEventParameter(event, kEventParamTextInputSendKeyboardEvent,
			      typeEventRef, NULL, 0, &size, NULL);

	    if (size > 0)
	      {
		keyRef = malloc(size);
		GetEventParameter(event, kEventParamTextInputSendKeyboardEvent,
				  typeEventRef, NULL, size, NULL, keyRef);

		GetEventParameter(keyRef[0], kEventParamKeyModifiers,
				  typeUInt32, NULL, sizeof(UInt32), NULL, &mod);
	      }
	    else
	      { 
		keyRef = NULL;
	      }

	    /* 
	     * We handle the even differently depending on whether or not
	     * we are reading into a text buffer
	     */
	    if (text_buf == NULL)
	      {
		/* Waiting for a single keypress */
		if (nchars != 1)
		  {
		    zmachine_warning("Multiple Unicode characters received - only returning one to the game");
		  }
		
		if ((mod&(cmdKey|optionKey|controlKey|rightOptionKey|rightControlKey)) == 0)
		  {
		    switch (text[0])
		      {
		      case kUpArrowCharCode:
			read_key = 129;
			break;
		      case kDownArrowCharCode:
			read_key = 130;
			break;
		      case kLeftArrowCharCode:
			read_key = 131;
			break;
		      case kRightArrowCharCode:
			read_key = 132;
			break;
			
		      case kReturnCharCode:
			read_key = 13;
			break;
			
		      case kDeleteCharCode:
		      case kBackspaceCharCode:
			read_key = 8;
			break;
			
		      case kFunctionKeyCharCode:
			/* FIXME: how do we deal with this? */
			break;
			
		      default:
			if (text[0] >= 32)
			  read_key = text[0];
			break;
		      }
		  }
		else if ((mod&cmdKey) != 0)
		  {
		    if (text[0] > '0' && text[0] <= '9')
		      read_key = text[0] - '0' + 132; 
		    if (text[0] == '0')
		      read_key = 142;
		  }
	      }
	    else
	      {
		/* We're dealing with an input buffer */
		if ((mod&(cmdKey|optionKey|controlKey|rightOptionKey|rightControlKey)) == 0)
		  {
		    switch (text[0])
		      {
		      case kUpArrowCharCode:
			if (history_pos == NULL)
			  history_pos = last_string;
			else
			  if (history_pos->next != NULL)
			    history_pos = history_pos->next;
			if (history_pos != NULL)
			  {
			    if (istrlen(history_pos->string) < max_buflen)
			      istrcpy(text_buf, history_pos->string);
			    
			    buf_offset = istrlen(text_buf);
			  }
			redraw_input_text();
			break;
		      case kDownArrowCharCode:
			if (history_pos != NULL)
			  {
			    history_pos = history_pos->last;
			    if (history_pos != NULL)
			      {
				if (istrlen(history_pos->string) < max_buflen)
				  istrcpy(text_buf, history_pos->string);
				buf_offset = istrlen(text_buf);
			      }
			    else
			      {
				text_buf[0] = 0;
				buf_offset = 0;
			      }
			  }
			
			redraw_input_text();
			break;
			
		      case kLeftArrowCharCode:
			if (buf_offset > 0)
			  buf_offset--;
			redraw_input_text();
			break;
		      case kRightArrowCharCode:
			if (buf_offset < istrlen(text_buf))
			  buf_offset++;
			redraw_input_text();
			break;
			
		      case kDeleteCharCode:
		      case kBackspaceCharCode:
			if (buf_offset > 0)
			  {
			    int  x;
			    
			    for (x=buf_offset-1; text_buf[x] != 0; x++)
			      {
				text_buf[x] = text_buf[x+1];
			      }
			    buf_offset--;
			    
			    redraw_input_text();
			  }
			break;
			
		      case kReturnCharCode:
			{
			  history_item* newhist;
			  
			  newhist = malloc(sizeof(history_item));
			  newhist->last = NULL;
			  newhist->next = last_string;
			  if (last_string)
			    last_string->last = newhist;
			  newhist->string = malloc(sizeof(int)*(istrlen(text_buf)+1));
			  istrcpy(newhist->string, text_buf);
			  last_string = newhist;
			}
		    
			display_prints(text_buf);
			display_prints_c("\n");
			text_buf = NULL;
			read_key = 10;
			break;
			
		      case kFunctionKeyCharCode:
			/* FIXME... */
			break;
			
		      default:
			for (x=0; x<nchars; x++)
			  {
			    if (text_buf[buf_offset] == 0 &&
				buf_offset < max_buflen)
			      { 
				text_buf[buf_offset++] = text[x];
				text_buf[buf_offset] = 0;
			      }
			    else
			      {
				if ((insert && buf_offset < max_buflen-1) ||
				    !insert)
				  {
				    if (insert)
				      {
					int x;
					
					for (x=istrlen(text_buf); x>=buf_offset; x--)
					  {
					    text_buf[x+1] = text_buf[x];
					  }
				      }
				    
				    text_buf[buf_offset] = text[x];
				    buf_offset++;
				  }
			      }
			  }
			break;
		      }
			
		    redraw_input_text();
		  }
		else if ((mod&cmdKey) != 0)
		  {
		    if (text[0] > '0' && text[0] <= '9')
		      read_key = text[0] - '0' + 132; 
		    if (text[0] == '0')
		      read_key = 142;

		    if (read_key != -1 && terminating[read_key] == 0)
		      read_key = -1;

		    if (read_key != -1)
		      {
			text_buf = NULL;
		      }
		  }
	      }

	    free(text);
	    if (keyRef != NULL)
	      free(keyRef);
	  }
	  break;
	}
      break;
    }

  return noErr;
}

/* Support functions */

static void rejig_fonts(void)
{
  int x;
  rc_font* fonts;

#ifdef USE_QUARTZ
  carbon_set_quartz(carbon_prefs.use_quartz);
#endif

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
	style_font[x] = n_fonts;

      font = realloc(font, sizeof(xfont*)*(n_fonts+1));
      font[n_fonts] = xfont_load_font("'Courier' 16 bi");
      for (x=0; x<n_fonts; x++)
	{
	  font[x] = xfont_load_font(fonts[x].name);

	  for (y=0; y<fonts[x].n_attr; y++)
	    style_font[fonts[x].attributes[y]] = x;
	}
      
      for (x=8; x<16; x++)
	if (style_font[x] == n_fonts)
	  style_font[x] = style_font[8];
    }
}

/* Display implementation */

/***                           ----// 888 \\----                           ***/

void printf_debug(char* format, ...)
{
}

void printf_info (char* format, ...)
{
}

void printf_info_done(void)
{
}

void printf_error(char* format, ...)
{
}

void printf_error_done(void)
{
}

/***                           ----// 888 \\----                           ***/

void display_exit(int code)
{
  CFNumberRef cfnum;
  Rect rct;

  /* Save the window bounds */
  if (window_available)
    {
      int n;

      set_fullscreen(0);

      GetWindowBounds(zoomWindow, kWindowContentRgn, &rct);

      n = rct.left; cfnum = CFNumberCreate(NULL, kCFNumberIntType, &n);
      CFPreferencesSetAppValue(CFSTR("winLeft"),
			       cfnum,
			       kCFPreferencesCurrentApplication);
      CFRelease(cfnum);

      n = rct.right; cfnum = CFNumberCreate(NULL, kCFNumberIntType, &n);
      CFPreferencesSetAppValue(CFSTR("winRight"),
			       cfnum,
			       kCFPreferencesCurrentApplication);
      CFRelease(cfnum);

      n = rct.top; cfnum = CFNumberCreate(NULL, kCFNumberIntType, &n);
      CFPreferencesSetAppValue(CFSTR("winTop"),
			       cfnum,
			       kCFPreferencesCurrentApplication);
      CFRelease(cfnum);

      n = rct.bottom; cfnum = CFNumberCreate(NULL, kCFNumberIntType, &n);
      CFPreferencesSetAppValue(CFSTR("winBottom"),
			       cfnum,
			       kCFPreferencesCurrentApplication);
      CFRelease(cfnum);

      CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
    }

  exit(code);
}

static pascal OSErr drag_track(short message, 
			       WindowPtr pWindow, 
			       void *handlerRefCon, 
			       DragReference drag)
{
  UInt16 nitems;
  UInt16 nflavs;
  DragItemRef item;
  OSErr erm;

  int x;

  /* We only accept one item, which must have an HFS flavour... */
  erm = CountDragItems(drag, &nitems);
  if (erm != noErr || nitems != 1)
    return noErr;

  erm = GetDragItemReferenceNumber(drag, 1, &item);
  if (erm != noErr)
    return noErr;

  erm = CountDragItemFlavors(drag, item, &nflavs);
  if (erm != noErr)
    return noErr;

  for (x=0; x<nflavs; x++)
    {
      FlavorType t;

      GetFlavorType(drag, item, x+1, &t);

      if (t == kDragFlavorTypeHFS)
	{
	  HFSFlavor hfs;
	  Size sz;
	  FSRef ref;
	  
	  enum carbon_file_type type;
	  Rect r;
	  RgnHandle rgn;

	  /* Highlight the window if we can load this type of file */
	  sz = sizeof(HFSFlavor);
	  erm = GetFlavorData(drag, item, kDragFlavorTypeHFS,
			      &hfs, &sz,
			      NULL);
	  if (erm != noErr)
	    {
	      return noErr;
	    }

	  erm = FSpMakeFSRef(&hfs.fileSpec,
			     &ref);
	  if (erm != noErr)
	    {
	      return noErr;
	    }

	  type = carbon_type_fsref(&ref);
	  if (type != TYPE_IFZS && type != TYPE_IFRS)
	    return noErr;

	  switch (message)
	    {
	    case kDragTrackingInWindow:
	      GetWindowBounds(pWindow, kWindowContentRgn, &r);
	      r.bottom -= r.top;
	      r.top    -= r.top;
	      r.right  -= r.left;
	      r.left   -= r.left;
	      
	      if (pWindow == zoomWindow)
		r.right -= 15;
	      
	      rgn = NewRgn();
	      RectRgn(rgn, &r);
	      ShowDragHilite(drag, rgn, true);
	      DisposeRgn(rgn);
	      break;

	    case kDragTrackingLeaveWindow:
	      HideDragHilite(drag);	      
	      break;
	    }
	}
    }

  return noErr;
}

static pascal OSErr drag_receive(WindowRef win, void* data, DragRef drag)
{
  UInt16 nitems;
  UInt16 nflavs;
  DragItemRef item;
  OSErr erm;

  int x;
  WindowRef lastmsg;

  lastmsg = carbon_message_win;

  erm = CountDragItems(drag, &nitems);
  if (erm != noErr || nitems != 1)
    return dragNotAcceptedErr;

  erm = GetDragItemReferenceNumber(drag, 1, &item);
  if (erm != noErr)
    return dragNotAcceptedErr;

  erm = CountDragItemFlavors(drag, item, &nflavs);
  if (erm != noErr)
    return dragNotAcceptedErr;

  for (x=0; x<nflavs; x++)
    {
      FlavorType t;

      GetFlavorType(drag, item, x+1, &t);

      if (t == kDragFlavorTypeHFS)
	{
	  HFSFlavor hfs;
	  Size sz;
	  FSRef ref;
	  char path[512];
	  ZFile* f;

	  sz = sizeof(HFSFlavor);
	  erm = GetFlavorData(drag, item, kDragFlavorTypeHFS,
			      &hfs, &sz,
			      NULL);
	  if (erm != noErr)
	    {
	      return dragNotAcceptedErr;
	    }

	  erm = FSpMakeFSRef(&hfs.fileSpec,
			     &ref);
	  if (erm != noErr)
	    {
	      return dragNotAcceptedErr;
	    }

	  if (FSRefMakePath(&ref, path, 512) != noErr)
	    {
	      return dragNotAcceptedErr;
	    }

	  if (carbon_type_fsref(&ref) == TYPE_IFZS)
	    {
	      display_force_restore(&ref);
	      if (!display_force_input("restore"))
		{
		  return dragNotAcceptedErr;
		}
	      return noErr;
	    }

	  f = open_file(path);
	  if (f == NULL || !blorb_is_blorbfile(f))
	    {
	      return dragNotAcceptedErr;
	    }

	  close_file(f);

	  carbon_message_win = win;
	  if (machine.blorb == NULL ||
	      carbon_ask_question("Resources already loaded", "This game already has a resource file associated with it: are you sure you wish to replace it with a new one?",
				  "Replace", "Cancel", 1))
	    {
	      carbon_prefs_set_resources(path);
	    }

	  carbon_message_win = lastmsg;
	  return noErr;
	}
    }

  return dragNotAcceptedErr;
}

void carbon_merge_rc(void)
     /* Merge in the default zoomrc */
{
  CFBundleRef ourbundle;
  CFURLRef    zoomrc;
  CFStringRef path = nil;
  
  /* It doesn't... Get the location of the default zoomrc... */
  ourbundle = CFBundleGetMainBundle();
  zoomrc = CFBundleCopyResourceURL(ourbundle, CFSTR("zoomrc"), NULL,
				   NULL);
  if (zoomrc != nil)
    path = CFURLCopyFileSystemPath(zoomrc, kCFURLPOSIXPathStyle);
  
  if (zoomrc != nil && path != nil)
    {
      char name[512];
      
      CFStringGetCString(path, name, 511, kCFStringEncodingUTF8);
      
      rc_merge(name);
    }
}
  

void display_initialise(void)
{
  EventLoopRef    mainLoop;
  EventTargetRef  target;

  rc_colour* colours;
  int n_cols;
  int x;

  if (RegisterMyHelpBook() != noErr)
    {
      carbon_display_message("Unable to register help book",
			     "Help might not be available");
    }

  NewSpeechChannel(NULL, &speechchan);

  target = GetEventDispatcherTarget();

  /* Initialise font structures */
  rejig_fonts();

  /* Set up the colour structures */
  colours = rc_get_colours(&n_cols);
  
  if (colours != NULL)
    {
      for (x=FIRST_ZCOLOUR; x<FIRST_ZCOLOUR+11; x++)
	{
	  if ((x-FIRST_ZCOLOUR)<n_cols)
	    {
	      maccolour[x].red   = colours[x-FIRST_ZCOLOUR].r<<8;
	      maccolour[x].green = colours[x-FIRST_ZCOLOUR].g<<8;
	      maccolour[x].blue  = colours[x-FIRST_ZCOLOUR].b<<8;
	    }
	}
    }

  /* Resize the window */
  max_x = size_x = rc_get_xsize();
  max_y = size_y = rc_get_ysize();

  xfont_x = xfont_get_width(font[style_font[4]]);
  xfont_y = xfont_get_height(font[style_font[4]]);

  /* Setup the display */
  display_clear();
  size_window();

  /* Install a timer to flash the caret */
  mainLoop = GetMainEventLoop();
  InstallEventLoopTimer(mainLoop,
			FLASH_DELAY,
			FLASH_DELAY,
			NewEventLoopTimerUPP(caret_flasher),
			NULL,
			&caret_timer);

  /* Install a drag handler */
  InstallReceiveHandler(NewDragReceiveHandlerUPP(drag_receive),
			NULL,
			NULL);
  InstallTrackingHandler(NewDragTrackingHandlerUPP(drag_track),
			 NULL,
			 NULL);

  /* Yay, we can now show the window */
  ShowWindow(zoomWindow);
  EnableMenuCommand(NULL,kAEShowPreferences);
  
  window_available = 1;
}

void display_reinitialise(void)
{
  rejig_fonts();

  display_clear();
  resize_window();
}

void carbon_display_rejig(void)
{
  struct text* txt;

  txt = text_win[0].text;
  while (txt != NULL)
    {
      free(txt->word);
      txt->nwords = -1;
      txt->word   = NULL;

      txt = txt->next;
    }

  rejig_fonts();
  total_x = total_y = 0;
  scroll_overlays = 0;
  resize_window();
  scroll_overlays = 1;
  display_update();
}

void display_finalise(void)
{
  int x;

  /* Deallocate fonts */
  for (x=0; x<9; x++)
    xfont_release_font(font[x]);
}

/***                           ----// 888 \\----                           ***/

int display_readline(int* buf, int buflen, long int timeout)
{
  int result;

  if (pixmap != NULL)
    v6_set_caret();

  displayed_text = 0;
  result = process_events(timeout, buf, buflen);

  return result;
}

int display_readchar(long int timeout)
{
  if (pixmap != NULL)
    v6_set_caret();

  displayed_text = 0;
  return process_events(timeout, NULL, 0);
}

/***                           ----// 888 \\----                           ***/

void display_set_title(const char* title)
{
  static char tit[256];
  FSRef  fileref;
  FSSpec filespec;

  /* 
   * Don't really need to say we're called 'Zoom'. That's what's the menu 
   * bar is for
   */
  strcpy(tit+1, title);
  tit[0] = strlen(tit+1);
  SetWTitle(zoomWindow, tit);

  strcpy(carbon_title, title);

  fileref = get_file_fsref(machine.file);
  FSGetCatalogInfo(&fileref, kFSCatInfoNone, NULL,
		   NULL, &filespec, NULL);
  SetWindowProxyFSSpec(zoomWindow, &filespec);
}

void display_update(void)
{
  Rect rct;

  rct.top    = 0;
  rct.left   = 0;
  rct.right  = total_x;
  rct.bottom = total_y;
  InvalWindowRect(zoomWindow, &rct);
}

/***                           ----// 888 \\----                           ***/

void display_beep        (void)
{
}

void display_terminating (unsigned char* table)
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

int  display_get_mouse_x (void)
{
  return click_x/xfont_x;
}

int  display_get_mouse_y (void)
{
  return click_y/xfont_y;
}

void display_window_define       (int window,
					 int x, int y,
					 int lmargin, int rmargin,
					 int width, int height)
{
}

void display_window_scroll       (int window, int pixels)
{
}

void display_set_newline_function(int (*func)(const int * remaining,
						     int rem_len))
{
}

void display_reset_windows       (void)
{
}

ZDisplay* display_get_info(void)
{
  static ZDisplay dis;
  RGBColor col;

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
  
  dis.lines         = size_y;
  dis.columns       = size_x;
  dis.width         = size_x;
  dis.height        = size_y;
  dis.font_width    = 1;
  dis.font_height   = 1;
  dis.pictures      = 1;
  dis.fore          = DEFAULT_FORE;
  dis.back          = DEFAULT_BACK;

  col               = maccolour[FIRST_ZCOLOUR+DEFAULT_FORE];
  dis.fore_true     = (col.red>>11)|((col.green>>11)<<5)|((col.blue>>11)<<10);
  col               = maccolour[FIRST_ZCOLOUR+DEFAULT_BACK];
  dis.back_true     = (col.red>>11)|((col.green>>11)<<5)|((col.blue>>11)<<10);

  if (pixmap != NULL)
    {
      dis.width = pix_w;
      dis.height = pix_h;

      dis.font_width = xfont_get_width(font[style_font[4]])+0.5;
      dis.font_height = xfont_get_height(font[style_font[4]])+0.5;
    }

  return &dis;
}

extern int zoom_main(int, char**);

int main(int argc, char** argv)
{
  IBNibRef nib;
  Rect rct;
  EventTypeSpec   appevts[] = 
    { 
      { kEventClassCommand,    kEventCommandProcess },
      { kEventClassMouse,      kEventMouseDown },
      { kEventClassAppleEvent, kEventAppleEvent }
    };
  EventTypeSpec   wndevts[] = 
    { 
      { kEventClassWindow,     kEventWindowDrawContent },
      { kEventClassWindow,     kEventWindowResizeCompleted },
      { kEventClassWindow,     kEventWindowBoundsChanged, },
      { kEventClassWindow,     kEventWindowFocusAcquired },
      { kEventClassWindow,     kEventWindowFocusRelinquish },
      { kEventClassWindow,     kEventWindowActivated },
      { kEventClassWindow,     kEventWindowDeactivated },
      { kEventClassMouse,      kEventMouseDown },
      { kEventClassMouse,      kEventMouseUp },
      { kEventClassCommand,    kEventProcessCommand },
      { kEventClassTextInput,  kEventTextInputUnicodeForKeyEvent }
    };

  EventTargetRef target;
  EventRef       event;

  /* Create the default .zoomrc, if necessary */
  {
    char*       home;
    char*       filename;

    FILE* f;

    /* Get the location of ~/.zoomrc */
    home = getenv("HOME");
    if (home == NULL)
      {
	carbon_display_message("Unable to locate home directory", "(Zoom probably won't start)");
	filename = "zoomrc";
      }
    else
      {
	filename = malloc(strlen(home)+9);
	strcpy(filename, home);
	strcat(filename, "/.zoomrc");
      }

    /* See if it exists... */
    f = fopen(filename, "r");
    if (f == NULL)
      {
	CFBundleRef ourbundle;
	CFURLRef    zoomrc;
	CFStringRef path = nil;

	/* It doesn't... Get the location of the default zoomrc... */
	ourbundle = CFBundleGetMainBundle();
	zoomrc = CFBundleCopyResourceURL(ourbundle, CFSTR("zoomrc"), NULL,
					 NULL);
	if (zoomrc != nil)
	  path = CFURLCopyFileSystemPath(zoomrc, kCFURLPOSIXPathStyle);

	if (zoomrc == nil || path == nil)
	  {
	    carbon_display_message("Unable to locate default .zoomrc", "Zoom probably won't start. You may be able to try creating .zoomrc by hand");
	  }
	else
	  {
	    char name[512];
	    FILE* o;

	    CFStringGetCString(path, name, 511, kCFStringEncodingUTF8);

	    /* Create the new one and copy the contents of the default one there */
	    f = fopen(name, "r");
	    o = fopen(filename, "w");

	    if (f == NULL)
	      carbon_display_message("Unable to open default .zoomrc", "Zoom probably won't start. You may be able to try creating .zoomrc by hand");
	    if (o == NULL)
	      carbon_display_message("Unable to open user .zoomrc", "Zoom probably won't start. You may be able to try creating .zoomrc by hand");

	    if (f != NULL && o != NULL)
	      while (!feof(f))
		{
		  char buf[128];
		  int len;

		  len = fread(buf, 1, 128, f);
		  fwrite(buf, 1, len, o);
		}

	    if (f != NULL)
	      fclose(f);
	    if (o != NULL)
	      fclose(o);
	  }

	CFRelease(zoomrc);
	CFRelease(path);
      }
    else
      fclose(f);
  }

  /* Read the preferences */
  {
    Boolean isvalid;

    carbon_prefs.use_speech = 
      CFPreferencesGetAppIntegerValue(CFSTR("useSpeech"),
				      kCFPreferencesCurrentApplication,
				      &isvalid);
    if (!isvalid)
      {
	carbon_prefs.use_speech = 0;
      }

    carbon_prefs.show_warnings = 
      CFPreferencesGetAppIntegerValue(CFSTR("showWarnings"),
				      kCFPreferencesCurrentApplication,
				      &isvalid);
    if (!isvalid)
      carbon_prefs.show_warnings = 0;

    carbon_prefs.fatal_warnings = 
      CFPreferencesGetAppIntegerValue(CFSTR("fatalWarnings"),
				      kCFPreferencesCurrentApplication,
				      &isvalid);
    if (!isvalid)
      carbon_prefs.fatal_warnings = 0;

    carbon_prefs.use_quartz = 
      CFPreferencesGetAppIntegerValue(CFSTR("useQuartz"),
				      kCFPreferencesCurrentApplication,
				      &isvalid);
    if (!isvalid)
      carbon_prefs.use_quartz = 0;
  }

  /* Set the menu bar */
  CreateNibReference(CFSTR("zoom"), &nib);
  SetMenuBarFromNib(nib, CFSTR("MenuBar"));
  DisposeNibReference(nib);

  /* Create the window */
  rct.top = 100;
  rct.left = 100;
  rct.bottom = rct.top + 480;
  rct.right = rct.left + 640;
  CreateNewWindow(kDocumentWindowClass,
		  kWindowStandardDocumentAttributes|
		  kWindowCollapseBoxAttribute|
		  kWindowLiveResizeAttribute|
		  kWindowStandardHandlerAttribute,
		  &rct,
		  &zoomWindow);

  SetWindowModified(zoomWindow, true);
  SetWindowModified(zoomWindow, false);

  /* Create the scrollback scrollbar */
  rct.top    = 0;
  rct.left   = 640-15;
  rct.bottom = 480;
  rct.right  = 640;
  CreateScrollBarControl(zoomWindow, &rct, 0,0,0,0, true, 
			 NewControlActionUPP(zoom_scroll_handler), 
			 &zoomScroll);

  /* Apple Event handlers */
  AEInstallEventHandler(kCoreEventClass, kAEOpenApplication, 
			NewAEEventHandlerUPP(ae_open_handler), 0,
			false);
  AEInstallEventHandler(kCoreEventClass, kAEReopenApplication, 
			NewAEEventHandlerUPP(ae_reopen_handler), 0,
			false);
  AEInstallEventHandler(kCoreEventClass, kAEQuitApplication, 
			NewAEEventHandlerUPP(ae_quit_handler), 0,
			false);
  AEInstallEventHandler(kCoreEventClass, kAEPrintDocuments, 
			NewAEEventHandlerUPP(ae_print_handler), 0,
			false);
  AEInstallEventHandler(kCoreEventClass, kAEOpenDocuments, 
			NewAEEventHandlerUPP(ae_opendocs_handler), 0,
			false);

  /* Setup event handlers */
  InstallApplicationEventHandler(NewEventHandlerUPP(zoom_evt_handler),
				 3, appevts, 0, NULL);
  InstallWindowEventHandler(zoomWindow,
			    NewEventHandlerUPP(zoom_wnd_handler),
			    11, wndevts, 0, NULL);

  /* Wait for the open event to arrive */

  /* 
   * (I originally didn't bother to do this. However, it turns out that if
   * you try to, for example, open a dialog box before this event and then
   * carry on, things break in subtle and irritating ways)
   */
  target = GetEventDispatcherTarget();

  while (!quitflag && !mac_openflag)
    {
      if (ReceiveNextEvent(0, NULL, kEventDurationForever, true, &event) == noErr)
	{
	  SendEventToEventTarget(event, target);
	  ReleaseEvent(event);
	}
    }

  xfont_initialise();

  zoom_main(argc, argv);

  return 0;
}

static void process_menu_command(long menres)
{
  HiliteMenu(0);
}

static pascal void timeout_time(EventLoopTimerRef iTimer,
				void*             data)
{
  read_key = 0;
  QuitEventLoop(GetMainEventLoop()); /* Give it a poke */
}

static int process_events(long int timeout,
			  int* buf,
			  int  buflen)
{
  EventRef event;
  EventTargetRef target;
  EventLoopTimerRef ourtime = nil;

  target = GetEventDispatcherTarget();

  if (nextspeech != NULL)
    {
      if (lastspeech != NULL)
	free(lastspeech);
      
      lastspeech = nextspeech;
      nextspeech = NULL;

      if (carbon_prefs.use_speech)
	SpeakBuffer(speechchan, lastspeech, strlen(lastspeech), 0);
    }

  if (forceopenfs != NULL)
    {
      free(forceopenfs);
      forceopenfs = NULL;
    }

  if (timeout > 0)
    {
      static EventLoopTimerUPP timer = NULL;

      if (timer == NULL)
	timer = NewEventLoopTimerUPP(timeout_time);

      InstallEventLoopTimer(GetMainEventLoop(),
			    kEventDurationMillisecond*timeout,
			    0,
			    timer,
			    NULL,
			    &ourtime);
    }
			  
  if (!more_on)
    {
      show_caret();
      caret_flashing = 1;
    }
  else
    {
      hide_caret();
      caret_flashing = 0;
    }
  display_update();

  if (buf != NULL)
    {
      text_buf    = buf;
      max_buflen  = buflen;
      buf_offset  = istrlen(buf);
      history_pos = NULL;
      read_key    = -1;
    }
  else
    {
      text_buf   = NULL;
      buf_offset = 0;
      read_key   = -1;
    }

  while (!quitflag && read_key == -1)
    {
      if (ReceiveNextEvent(0, NULL, kEventDurationForever, true, &event) == noErr)
	{
	  SendEventToEventTarget(event, target);
	  ReleaseEvent(event);
	}

      if (force_text != NULL && buf != NULL)
	{
	  int x,len;

	  len = strlen(force_text);

	  for (x=0; x<len; x++)
	    {
	      buf[x] = force_text[x];
	    }
	  buf[len] = '\0';
	  read_key = 10;
	  force_text = NULL;

	  display_prints(buf);
	  display_prints_c("\n");
	  text_buf = NULL;
	}
    }

  if (ourtime != nil)
    {
      RemoveEventLoopTimer(ourtime);
    }

  text_buf = NULL;
  force_text = NULL;

  caret_flashing = 0;
  hide_caret();

  if (read_key != -1)
    return read_key;

  display_exit(0);
  
  return 0;
}

/***                           ----// 888 \\----                           ***/

/*
 * Pixmap display
 */
int display_init_pixmap(int width, int height)
{
  QDErr erm;
  Rect  bounds;

  if (pixmap != NULL)
    {
      zmachine_fatal("Can't initialise a pixmap twice in succession");
      return 0;
    }

  if (width < 0)
    {
      width = win_x; height = win_y;
    }

  pix_w = width; pix_h = height;

  bounds.left   = 0;
  bounds.top    = 0;
  bounds.right  = width;
  bounds.bottom = height;
 
  erm = NewGWorld(&pixmap, 0, &bounds, NULL, NULL, 0);

  if (erm != noErr)
    return 0; /* Drat it */

  win_x = width; win_y = height;
  total_x = win_x + BORDERWIDTH*2+15;
  total_y = win_y + BORDERWIDTH*2;

  GetWindowBounds(zoomWindow, kWindowContentRgn, &bounds);
  bounds.right = bounds.left + total_x;
  bounds.bottom = bounds.top + total_y;
  SetWindowBounds(zoomWindow, kWindowContentRgn, &bounds);

  resize_window();

  return 1;
}

void display_plot_rect(int x, int y, int width, int height)
{
  Rect r;
  int xp, yp;

  xp = win_x/2-pix_w/2;
  yp = win_y/2-pix_h/2;

  if (!LockPixels(GetGWorldPixMap(pixmap)))
    zmachine_fatal("Unable to lock pixmap");
  SetGWorld(pixmap, nil);
  
  r.left   = x;
  r.top    = y;
  r.right  = x+width;
  r.bottom = y+height;

  RGBForeColor(carbon_get_colour(pix_fore));
  PaintRect(&r);
  
  UnlockPixels(GetGWorldPixMap(pixmap));

  display_update_region(xp+r.left, yp+r.top,
			xp+r.right, yp+r.bottom);
}

void display_scroll_region(int x, int y, int width, int height, int xoff, int yoff)
{
  Rect src, dst;

  PixMapHandle pixPix;

  static const RGBColor black = { 0,0,0 };
  static const RGBColor white = { 0xffff, 0xffff, 0xffff };

  if (!LockPixels(GetGWorldPixMap(pixmap)))
    zmachine_fatal("Unable to lock pixmap");
  SetGWorld(pixmap, nil);
  pixPix = GetGWorldPixMap(pixmap);

  RGBForeColor(&black);
  RGBBackColor(&white);

  src.left = x;
  src.top = y;
  src.right = x+width;
  src.bottom = y+height;

  dst = src;
  dst.left += xoff; dst.right += xoff;
  dst.top  += yoff; dst.bottom += yoff;

  CopyBits((BitMap*)*pixPix, (BitMap*)*pixPix, &src, &dst, srcCopy, NULL);

  UnlockPixels(GetGWorldPixMap(pixmap));
}

void display_pixmap_cols(int fg, int bg)
{
  pix_fore = fg; pix_back = bg;
}

int display_get_pix_colour(int x, int y)
{
  RGBColor col;
 
  CGrafPtr oldport;
  GDHandle olddev;

  int res;

  if (!LockPixels(GetGWorldPixMap(pixmap)))
    zmachine_fatal("Unable to lock pixmap");
  GetGWorld(&oldport, &olddev);
  SetGWorld(pixmap, nil);
  
  GetCPixel(x, y, &col);

  SetGWorld(oldport, olddev);

  res = (col.red>>11)|((col.green>>11)<<5)|((col.blue>>11)<<10);

  return res + 16;
}

void display_plot_gtext(const int* text, int len,
			int style, int x, int y)
{
  int ft;
  int fg, bg;

  float width, height;
  int xp, yp;
  
  xp = win_x/2-pix_w/2;
  yp = win_y/2-pix_h/2;

  if (len == 0)
    return;

  if (x<0 || y<0)
    return;

  fg = pix_fore; bg = pix_back;
  if ((style&1))
    { fg = pix_back; bg = pix_fore; }
  if (fg < 0)
    fg = 7;

  ft = style_font[(style>>1)&15];

  if (!LockPixels(GetGWorldPixMap(pixmap)))
    zmachine_fatal("Unable to lock pixmap");
  SetGWorld(pixmap, nil);

#ifdef USE_QUARTZ
  carbon_set_context();
#endif

  width = xfont_get_text_width(font[ft],
			       text, len);
  height = xfont_get_height(font[ft])+0.5;
  if (bg >= 0)
    {
      if (carbon_prefs.use_quartz)
	{
	  CGRect bgr;
	  RGBColor bg_col;
	  
	  bg_col = *carbon_get_colour(bg);
	  bgr = CGRectMake(x,
			   pix_h - y - xfont_get_descent(font[ft]),
			   width,
			   height);
	  CGContextSetRGBFillColor(carbon_quartz_context, 
				   (float)bg_col.red/65536.0,
				   (float)bg_col.green/65536.0,
				   (float)bg_col.blue/65536.0,
				   1.0);
	  CGContextFillRect(carbon_quartz_context, bgr);
	}
      else
	{
	  Rect frct;

	  frct.left = x;
	  frct.right = x+width;
	  frct.top = y - xfont_get_ascent(font[ft]);
	  frct.bottom = frct.top + height;
	  RGBForeColor(carbon_get_colour(bg));
	  PaintRect(&frct);
	}
    }

  xfont_set_colours(fg, bg);
  xfont_plot_string(font[ft], x, -y,
		    text, len);
  
  UnlockPixels(GetGWorldPixMap(pixmap));

  display_update_region(xp+x, yp+y - xfont_get_ascent(font[ft]),
			xp+x+width, yp+y + xfont_get_descent(font[ft]));
}

float display_measure_text(const int* text, int len, int style)
{
  int ft;

  ft = style_font[(style>>1)&15];

  return xfont_get_text_width(font[ft], text, len);
}

float display_get_font_width(int style)
{
  int ft;

  ft = style_font[(style>>1)&15];

  return xfont_get_width(font[ft]);
}

float display_get_font_height(int style)
{
  int ft;

  ft = style_font[(style>>1)&15];

  return xfont_get_height(font[ft]);
}

float display_get_font_ascent(int style)
{
  int ft;

  ft = style_font[(style>>1)&15];

  return xfont_get_ascent(font[ft]);
}

float display_get_font_descent(int style)
{
  int ft;

  ft = style_font[(style>>1)&15];

  return xfont_get_descent(font[ft]);
}

void display_plot_image(BlorbImage* img, int x, int y)
{
  int sc_n, sc_d;

  if (pixmap == NULL)
    zmachine_fatal("Programmer is a spoon: tried to use pixmap display functions when none were available");

  if (img == NULL)
    return;

  v6_scale_image(img, &sc_n, &sc_d);

  if (img->loaded != NULL)
    {
      int xp, yp;
      
      xp = win_x/2-pix_w/2;
      yp = win_y/2-pix_h/2;

      if (!LockPixels(GetGWorldPixMap(pixmap)))
	zmachine_fatal("Unable to lock pixmap");
      SetGWorld(pixmap, nil);
      image_draw_carbon(img->loaded, pixmap, x, y, sc_n, sc_d);

      UnlockPixels(GetGWorldPixMap(pixmap));

      display_update_region(xp+x, yp+y,
			    xp+x+image_width(img->loaded), yp+y+image_height(img->loaded));
    }
}

void display_wait_for_more(void)
{
  more_on = 1;
  display_readchar(0);
  more_on = 0;
}

void display_read_mouse(void)
{
  Point loc;
  Rect      bound;

  GetMouse(&loc);
  
  GetWindowBounds(zoomWindow, kWindowContentRgn, &bound);
  
  click_x = (loc.h - BORDERWIDTH - bound.left);
  click_y = (loc.v - BORDERWIDTH - bound.top);
}

int display_get_pix_mouse_x(void)
{
  return click_x - (win_x/2-pix_w/2);  
}

int display_get_pix_mouse_y(void)
{
  return click_y - (win_y/2-pix_h/2);
}

int display_get_pix_mouse_b(void)
{
  return Button()?1:0;
}

void display_set_input_pos(int style, int x, int y, int width)
{
  pix_cstyle = style;
  pix_cx = x; pix_cy = y;
  pix_cw = width;
}

void display_set_mouse_win(int x, int y, int w, int h)
{
  mousew_x = x;
  mousew_y = y;
  mousew_w = w;
  mousew_h = h;
}

#endif
