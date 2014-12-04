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
 * The preferences dialog box
 */

#include "../config.h"

#if WINDOW_SYSTEM == 3

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#include <Carbon/Carbon.h>

#include "zmachine.h"
#include "file.h"
#include "display.h"
#include "zoomres.h"
#include "rc.h"
#include "hash.h"
#include "xfont.h"
#include "format.h"
#include "carbondisplay.h"

WindowRef carbon_prefdlog    = nil;
static rc_font*  font_copy   = NULL;
static int       font_nfonts = 0;
static MenuRef   fontmenu    = nil;
static rc_game*  ourgame     = NULL;

static char*     colour_name[11] = 
  {
    "Black",
    "Red",
    "Green",
    "Yellow",
    "Blue",
    "Magenta",
    "Cyan",
    "White",
    "Light grey",
    "Medium grey",
    "Dark grey"
  };
static RGBColor colour_copy[14];

static void pref_select_tab(ControlRef tab)
{
  ControlRef pane;
  ControlRef selpane;
  ControlID  cid;
  UInt16     i;

  SInt16 index;

  index = GetControlValue(tab);

  cid.signature = CARBON_TABS;

  selpane = nil;

  for (i = 400; i <= 404; i++)
    {
      cid.id = i;
      GetControlByID(GetControlOwner(tab), &cid, &pane);

      if (i-399 == index)
	{
	  selpane = pane;
	}
      else
	{
	  SetControlVisibility(pane, false, false);
	  DisableControl(pane);
	}
    }

  if (selpane != nil)
    {
      EnableControl(selpane);
      SetControlVisibility(selpane, true, true);
    }

  Draw1Control(tab);
}

/* Write a configuration block */
static void pref_write_block(FILE*    f,
			     rc_game* game,
			     char*    section,
			     char*    serial)
{
  int x;

  for (x=0; game->name[x] != '\0'; x++)
    {
      if (game->name[x] == '\"')
	game->name[x] = '\'';
      if (game->name[x] < 32 || game->name[x] >= 127)
	game->name[x] = '.';
    }

  fprintf(f, "%s \"%s\" %s\n{\n", 
	  section, game->name, (serial!=NULL?serial:""));
  if (game->interpreter != -1)
    fprintf(f, "  interpreter %i\n", game->interpreter);
  if (game->revision != -1)
    fprintf(f, "  revision %c\n", game->revision);

  if (game->fonts != NULL)
    {
      for (x=0; x<game->n_fonts; x++)
	{
	  char str[256];

	  str[0] = '\0';
	  
	  if (game->fonts[x].attributes[0]&1)
	    strcat(str, "bold");
	  if (game->fonts[x].attributes[0]&2)
	    {
	      if (str[0] != '\0')
		strcat(str, "-italic");
	      else
		strcat(str, "italic");
	    }
	  if (game->fonts[x].attributes[0]&4)
	    {
	      if (str[0] != '\0')
		strcat(str, "-fixed");
	      else
		strcat(str, "fixed");
	    }
	  if (game->fonts[x].attributes[0]&8)
	    {
	      if (str[0] != '\0')
		strcat(str, "-symbolic");
	      else
		strcat(str, "symbolic");
	    }
	  
	  if (str[0] == '\0')
	    strcat(str, "roman");

	  fprintf(f, "  font %i \"%s\" %s\n", x, game->fonts[x].name, str);
	}
    }

  if (game->colours != NULL)
    {
      fprintf(f, "  colours ");

      for (x=0; x<game->n_colours; x++)
	{
	  fprintf(f, "(%i,%i,%i)",
		  game->colours[x].r,
		  game->colours[x].g,
		  game->colours[x].b);
	  
	  if (x < game->n_colours-1)
	    fprintf(f, ", ");
	}
      fprintf(f, "\n");
    }

  if (game->xsize > 0)
    {
      fprintf(f, "  size %i,%i\n", game->xsize, game->ysize);
    }

  if (game->graphics != NULL)
    {
      fprintf(f, "  resources \"%s\"\n", game->graphics);
    }

  if (game->antialias != -1)
    {
      fprintf(f, "  antialias %s\n", game->antialias?"yes":"no");
    }
  fprintf(f, "}\n\n");
}

/* Iterator for the games in the hash */
static int pref_write_game(char* key,
			   int   keylen,
			   void* data,
			   void* arg)
{
  char name[256];

  if (data == NULL)
    return 0;

  strncpy(name, key, keylen);
  name[keylen] = '\0';

  if (strcmp(name, "default") != 0)
    {
      pref_write_block(arg, data, "game", name);
    }
  
  return 0;
}

/* Write the resource file */
static void pref_write(void)
{
  char* home;
  char* filename;
  FILE* out;

  home = getenv("HOME");
  if (home == NULL)
    {
      carbon_display_message("Can't find home directory", "Dammit");
      return;
    }
  else
    {
      filename = malloc(strlen(home)+9);
      strcpy(filename, home);
      strcat(filename, "/.zoomrc");
    }
  
  out = fopen(filename, "w");
  fprintf(out, 
	  "#\n"
	  "# Zoom configuration file, automatically generated\n"
	  "#\n\n");

  pref_write_block(out, rc_defgame, "default", NULL);
  hash_iterate(rc_hash, pref_write_game, out);

  fclose(out);

  free(filename);
}

/* Update the stored copy of the preferences */
static void pref_store(void)
{
  ControlID  cid;
  ControlRef cntl;

  char str[512];
  Size outsize;

  int  islocal;
  int  x;

  /* Get the general preferences */
  cid.signature = CARBON_DISPWARNS;
  cid.id        = CARBON_DISPWARNSID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  carbon_prefs.show_warnings = 
    GetControlValue(cntl)==kControlCheckBoxCheckedValue;

  cid.signature = CARBON_FATWARNS;
  cid.id        = CARBON_FATWARNSID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  carbon_prefs.fatal_warnings =
    GetControlValue(cntl)==kControlCheckBoxCheckedValue;

  cid.signature = CARBON_SPEAK;
  cid.id        = CARBON_SPEAKID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  carbon_prefs.use_speech = 
    GetControlValue(cntl)==kControlCheckBoxCheckedValue;

  cid.signature = CARBON_RENDER;
  cid.id        = CARBON_RENDERID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  carbon_prefs.use_quartz = 
    GetControlValue(cntl)==2;

  if (carbon_prefs.show_warnings)
    {
      machine.warning_level = 1;
      if (carbon_prefs.fatal_warnings)
	machine.warning_level = 2;
    }

  cid.signature = CARBON_ANTI;
  cid.id        = CARBON_ANTIID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  ourgame->antialias = -1;
  rc_defgame->antialias =
    GetControlValue(cntl)==kControlCheckBoxCheckedValue?1:0;

  if (carbon_quartz_context != nil)
    {
      CGContextSetShouldAntialias(carbon_quartz_context,
				  rc_defgame->antialias);
    }

  /* Get the game title */
  cid.signature = CARBON_TITLE;
  cid.id        = CARBON_TITLEID;  
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  GetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		 256, str, &outsize);
  str[outsize] = '\0';
  ourgame->name = realloc(ourgame->name, strlen(str)+1);
  strcpy(ourgame->name, str);
  display_set_title(str);

  /* Get the interpreter ID */
  cid.signature = CARBON_INTERPLOC;
  cid.id        = CARBON_INTERPLOCID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  islocal = GetControlValue(cntl)==kControlCheckBoxCheckedValue;
  
  cid.signature = CARBON_INTERP;
  cid.id        = CARBON_INTERPID;

  GetControlByID(carbon_prefdlog, &cid, &cntl);
  GetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		 256, str, &outsize);
  str[outsize] = '\0';

  if (islocal)
    {
      ourgame->interpreter = atoi(str);
    }
  else
    {
      ourgame->interpreter = -1;
      rc_defgame->interpreter = atoi(str);
    }

  /* Get the interpreter revision */
  cid.signature = CARBON_REVLOC;
  cid.id        = CARBON_REVLOCID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  islocal = GetControlValue(cntl)==kControlCheckBoxCheckedValue;
  
  cid.signature = CARBON_REVISION;
  cid.id        = CARBON_REVISIONID;

  GetControlByID(carbon_prefdlog, &cid, &cntl);
  GetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		 256, str, &outsize);
  str[outsize] = '\0';

  if (outsize != 1)
    {
      carbon_display_message("Bad interpreter revision", "The interpreter revision should be a single upper case letter");
    }
  else
    {
      if (islocal)
	{
	  ourgame->revision = str[0];
	}
      else
	{
	  ourgame->revision = -1;
	  rc_defgame->revision = str[0];
	}
    }

  /* Get the fonts */
  cid.signature = CARBON_FONTLOC;
  cid.id        = CARBON_FONTLOCID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  islocal = GetControlValue(cntl)==kControlCheckBoxCheckedValue;

  if (!islocal && ourgame->fonts != NULL)
    {
      for (x=0; x<ourgame->n_fonts; x++)
	{
	  free(ourgame->fonts[x].name);
	}

      free(ourgame->fonts);
      ourgame->fonts = NULL;
      ourgame->n_fonts = -1;
    }

  if (islocal)
    {
      if (ourgame->fonts != NULL)
	{
	  for (x=0; x<ourgame->n_fonts; x++)
	    {
	      free(ourgame->fonts[x].name);
	    }
	}

      ourgame->n_fonts = font_nfonts;
      ourgame->fonts = realloc(ourgame->fonts, sizeof(rc_font)*font_nfonts);
      memcpy(ourgame->fonts, font_copy, sizeof(rc_font)*font_nfonts);

      for (x=0; x<ourgame->n_fonts; x++)
	{
	  ourgame->fonts[x].name = malloc(strlen(font_copy[x].name)+1);
	  strcpy(ourgame->fonts[x].name, font_copy[x].name);
	}
    }
  else
    {
      if (rc_defgame->fonts != NULL)
	{
	  for (x=0; x<rc_defgame->n_fonts; x++)
	    {
	      free(rc_defgame->fonts[x].name);
	    }
	}

      rc_defgame->n_fonts = font_nfonts;
      rc_defgame->fonts = realloc(rc_defgame->fonts, sizeof(rc_font)*font_nfonts);
      memcpy(rc_defgame->fonts, font_copy, sizeof(rc_font)*font_nfonts);

      for (x=0; x<rc_defgame->n_fonts; x++)
	{
	  rc_defgame->fonts[x].name = malloc(strlen(font_copy[x].name)+1);
	  strcpy(rc_defgame->fonts[x].name, font_copy[x].name);
	}
    }

  /*
  free(font_copy);
  font_copy = NULL;
  */

  /* ...and the colours */
  cid.signature = CARBON_COLLOC;
  cid.id        = CARBON_COLLOCID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  
  islocal = GetControlValue(cntl)==kControlCheckBoxCheckedValue;
  
  if (!islocal)
    {
      if (ourgame->colours != NULL)
	free(ourgame->colours);

      ourgame->colours = NULL;
      ourgame->n_colours = -1;

      rc_defgame->colours   = realloc(rc_defgame->colours, sizeof(rc_colour)*11);
      rc_defgame->n_colours = 11;

      for (x=0; x<11; x++)
	{
	  rc_defgame->colours[x].r = colour_copy[x].red  >>8;
	  rc_defgame->colours[x].g = colour_copy[x].green>>8;
	  rc_defgame->colours[x].b = colour_copy[x].blue >>8;
	}
    }
  else
    {
      ourgame->colours   = realloc(ourgame->colours, sizeof(rc_colour)*11);
      ourgame->n_colours = 11;

      for (x=0; x<11; x++)
	{
	  ourgame->colours[x].r = colour_copy[x].red  >>8;
	  ourgame->colours[x].g = colour_copy[x].green>>8;
	  ourgame->colours[x].b = colour_copy[x].blue >>8;
	}
     }

  for (x=0; x<11; x++)
    {
      maccolour[x+6] = colour_copy[x];
    }

  /* Reset the display */
  rc_set_game(zmachine_get_serial(), Word(ZH_release), Word(ZH_checksum));
  
  /* Rewrite the preferences file */
  pref_write();

  /* Resource location is handled slightly differently */
  cid.signature = CARBON_RESFILE;
  cid.id        = CARBON_RESFILEID;

  GetControlByID(carbon_prefdlog, &cid, &cntl);
  GetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		 512, str, &outsize);
  str[outsize] = '\0';

  if (strcmp(str, "") == 0)
    {
      if (ourgame->graphics != NULL)
	free(ourgame->graphics);
      ourgame->graphics = NULL;
    }
  else
    {
      if (strcmp(ourgame->graphics, str) != 0)
	{
	  WindowRef lastmsg;

	  lastmsg = carbon_message_win;
	  carbon_message_win = carbon_prefdlog;
	  carbon_prefs_set_resources(str);
	  carbon_message_win = lastmsg;
	}
    }

  /* Store the app preferences */
  {
    CFNumberRef cfnum;

    cfnum = CFNumberCreate(NULL, kCFNumberIntType, &carbon_prefs.use_speech);
    CFPreferencesSetAppValue(CFSTR("useSpeech"),
			     cfnum,
			     kCFPreferencesCurrentApplication);
    CFRelease(cfnum);

    cfnum = CFNumberCreate(NULL, kCFNumberIntType, &carbon_prefs.show_warnings);
    CFPreferencesSetAppValue(CFSTR("showWarnings"),
			     cfnum,
			     kCFPreferencesCurrentApplication);
    CFRelease(cfnum);

    cfnum = CFNumberCreate(NULL, kCFNumberIntType, &carbon_prefs.fatal_warnings);
    CFPreferencesSetAppValue(CFSTR("fatalWarnings"),
			     cfnum,
			     kCFPreferencesCurrentApplication);
    CFRelease(cfnum);

    cfnum = CFNumberCreate(NULL, kCFNumberIntType, &carbon_prefs.use_quartz);
    CFPreferencesSetAppValue(CFSTR("useQuartz"),
			     cfnum,
			     kCFPreferencesCurrentApplication);
    CFRelease(cfnum);

    CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication);
  }

  carbon_display_rejig();
  zmachine_mark_statusbar();
  display_update();
}

/* Deal with events to the window */
static pascal OSStatus pref_wnd_evt(EventHandlerCallRef handler,
				    EventRef event,
				    void*    data)
{
  UInt32    cla;
  UInt32    wha;

  cla = GetEventClass(event);
  wha = GetEventKind(event);

  switch (cla)
    {
    case kEventClassWindow:
      switch (wha)
	{
	case kEventWindowBoundsChanged:
	  {
	    const UInt32 toSize[54] =
	      { 
		CARBON_FONTLIST, CARBON_FONTLISTID, 3,
	        CARBON_COLLIST, CARBON_COLLISTID, 3,
		CARBON_TABS, CARBON_TABSID, 3,
		CARBON_TABS, 400, 3,
		CARBON_TABS, 401, 3,
		CARBON_TABS, 402, 3,
		CARBON_TABS, 403, 3,
		CARBON_TABS, 404, 3,
	        'bar ', 200, 1,
	        'bar ', 201, 1,
	        'bar ', 202, 1,
	        'bar ', 203, 1,
		CARBON_TITLE, CARBON_TITLEID, 1,
		CARBON_INTERP, CARBON_INTERPID, 1,
		CARBON_REVISION, CARBON_REVISIONID, 1,
		'TogB', 799, 3,
		CARBON_RESFILE, CARBON_RESFILEID, 1,
		'FilB', 1099, 1
	      };

	    const UInt32 toMove[4] =
	      {
		CARBON_RESFONT, CARBON_RESFONTID,
		CARBON_RESCOLS, CARBON_RESCOLSID
	      };
	    int x;
	    Rect origSize;
	    Rect newSize;

	    GetEventParameter(event, kEventParamPreviousBounds,
			      typeQDRectangle, NULL, sizeof(Rect),
			      NULL, &origSize);
	    GetEventParameter(event, kEventParamCurrentBounds,
			      typeQDRectangle, NULL, sizeof(Rect),
			      NULL, &newSize);

	    /* Resize those as need resizing */
	    for (x=0; x<54; x+=3)
	      {
		ControlRef cntl;
		ControlID  id;
		Rect cbounds;

		int oldw, oldh;
		int diffw, diffh;

		id.signature = toSize[x];
		id.id        = toSize[x+1];

		GetControlByID(carbon_prefdlog, &id, &cntl);
		
		GetControlBounds(cntl, &cbounds);

		/* Old height of this control */
		oldw = cbounds.right - cbounds.left;
		oldh = cbounds.bottom - cbounds.top;

		/* Difference in the width/height of the window */
		diffw = (newSize.right - newSize.left) - 
		  (origSize.right - origSize.left);
		diffh = (newSize.bottom - newSize.top) - 
		  (origSize.bottom - origSize.top);

		/* Don't resize width/height if the control doesn't want it */
		if ((toSize[x+2]&1) == 0)
		  diffw = 0;
		if ((toSize[x+2]&2) == 0)
		  diffh = 0;

		if (diffw !=0 || diffh != 0)
		  {
		    SizeControl(cntl, 
				oldw + diffw, oldh + diffh);
		  }
	      }

	    /* Move those that need moving */
	    for (x=0; x<4; x+=2)
	      {
		ControlRef cntl;
		ControlID  id;
		Rect cbounds;

		int diffw, diffh;

		id.signature = toMove[x];
		id.id        = toMove[x+1];

		GetControlByID(carbon_prefdlog, &id, &cntl);
		
		GetControlBounds(cntl, &cbounds);

		/* Difference in the width/height of the window */
		diffw = (newSize.right - newSize.left) - 
		  (origSize.right - origSize.left);

		/* Don't resize width/height if the control doesn't want it */
		diffh = 0;

		if (diffw !=0)
		  {
		    MoveControl(cntl, 
				cbounds.left + diffw, cbounds.top);
		  }
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
	      case inGoAway:
		if (TrackGoAway(ourwindow, point))
		  {
		    ControlID  cid;
		    ControlRef cntl;
		    
		    int cfonts, ccols;

		    /* 
		     * Check if the font settings have been changed from
		     * local to global
		     */
		    cfonts = 0;

		    cid.signature = CARBON_FONTLOC;
		    cid.id        = CARBON_FONTLOCID;
		    GetControlByID(carbon_prefdlog, &cid, &cntl);

		    if (ourgame->fonts != NULL &&
			GetControlValue(cntl) == kControlCheckBoxUncheckedValue)
		      {
			cfonts = 1;
		      }

		    /*
		     * Check if the colour settings have been changed from
		     * local to global
		     */
		    ccols = 0;

		    cid.signature = CARBON_COLLOC;
		    cid.id        = CARBON_COLLOCID;
		    GetControlByID(carbon_prefdlog, &cid, &cntl);

		    if (ourgame->colours != NULL &&
			GetControlValue(cntl) == kControlCheckBoxUncheckedValue)
		      {
			ccols = 1;
		      }

		    /*
		     * Get confirmation if necessary
		     */
		    if (cfonts || ccols)
		      {
			AlertStdCFStringAlertParamRec par;
			DialogRef confdlog;

			par.version       = kStdCFStringAlertVersionOne;
			par.movable       = false;
			par.helpButton    = false;
			par.defaultText   = CFSTR("Keep changes");
			par.cancelText    = CFSTR("Cancel");
			par.otherText     = CFSTR("Discard changes");
			par.defaultButton = kAlertStdAlertOKButton;
			par.cancelButton  = kAlertStdAlertCancelButton;
			par.position      = kWindowDefaultPosition;
			par.flags         = 0;

			CreateStandardSheet(kAlertCautionAlert,
					    CFSTR("Are you sure you want the changes to apply globally?"),
					    CFSTR("You have changed the font and/or colour settings from applying only to the current game to applying to all games - if you choose to keep these changes, they will apply to all games, not just the current one"),
					    &par,
					    GetWindowEventTarget(carbon_prefdlog),
					    &confdlog);
			ShowSheetWindow(GetDialogWindow(confdlog), carbon_prefdlog);
		      }
		    else
		      {
			int x;
			int str1[] = { 'M' };
			int str2[] = { 'i' };
			XFONT_MEASURE base_width;
			XFONT_MEASURE base_height;

			pref_store();

			DisposeWindow(carbon_prefdlog);
			carbon_prefdlog = nil;

			base_width =
			  xfont_get_width(font[style_font[4]]);
			base_height =
			  xfont_get_height(font[style_font[4]]);

			/* Check our stats */
			for (x=4; x<7; x++)
			  {
			    if (xfont_get_text_width(font[style_font[x]], str1, 1) !=
				xfont_get_text_width(font[style_font[x]], str2, 1))
			      {
				carbon_display_message("One of the 'fixed-pitch' fonts does not appear to be fixed pitch",
						       "One of the fonts you have selected as a 'fixed-pitch' font (the fixed-* family of fonts) appears to have some characters that vary in width. Zoom can cope with this, but many games rely on truly fixed-pitch fonts (such as Courier or Monaco) to display correctly");
				break;
			      }

			    if (xfont_get_width(font[style_font[x]]) !=
				base_width)
			      {
				carbon_display_message("One of the fixed-pitch fonts you have selected is of a different width to the others",
						       "Many games require that all the fixed-pitch fonts be the same shape: one of the ones you have selected has a different width to the others.");
				break;
			      }

			    if (xfont_get_height(font[style_font[x]]) !=
				base_height)
			      {
				carbon_display_message("One of the fixed-pitch fonts you have selected is of a different height to the others",
						       "Many games require that all the fixed-pitch fonts be the same shape: one of the ones you have selected has a different height to the others.");
				break;
			      }
			  }
		      }
		  }
		return noErr;
		
	      default:
		return eventNotHandledErr;
	      }
	  }
	  break;
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
	      case CARBON_RESFONT:
		{
		  ControlID cid;
		  ControlRef cntl;
		  
		  DataBrowserItemID items[40];
		  
		  rc_font* fonts;
		  int      n_fonts;
		  
		  int x;

		  fonts = rc_defgame->fonts;
		  n_fonts = rc_defgame->n_fonts;

		  /* Redo the fonts with the defaults... */
		  cid.signature = CARBON_FONTLIST;
		  cid.id        = CARBON_FONTLISTID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);
		  
		  for (x=0; x<font_nfonts; x++)
		    {
		      free(font_copy[x].name);
		    }

		  font_copy = realloc(font_copy, sizeof(rc_font)*n_fonts);
		  memcpy(font_copy, fonts, sizeof(rc_font)*n_fonts);
		  font_nfonts = n_fonts;

		  for (x=0; x < n_fonts; x++)
		    {
		      font_copy[x].name = malloc(strlen(fonts[x].name)+1);
		      strcpy(font_copy[x].name, fonts[x].name);
		      items[x] = x+1;
		    }
		  RemoveDataBrowserItems(cntl, kDataBrowserNoItem, n_fonts, items, 0);
		  AddDataBrowserItems(cntl, kDataBrowserNoItem, n_fonts, items, kDataBrowserItemNoProperty);

		  /* Mark as using the global fonts... */
		  cid.signature = CARBON_FONTLOC;
		  cid.id = CARBON_FONTLOCID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);
		  SetControlValue(cntl, kControlCheckBoxUncheckedValue);

		  /* Deactivate the control */
		  cid.signature = CARBON_RESFONT;
		  cid.id = CARBON_RESFONTID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);
		  DeactivateControl(cntl);

		  /* Update */
		  pref_store();
		}
		break;

	      case CARBON_FONTLOC:
		{
		  WindowRef lastmsg;
		  ControlID cid;
		  ControlRef cntl;
		  int islocal;

		  lastmsg = carbon_message_win;
		  carbon_message_win = carbon_prefdlog;

		  cid.signature = CARBON_FONTLOC;
		  cid.id = CARBON_FONTLOCID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);

		  islocal = GetControlValue(cntl)==kControlCheckBoxCheckedValue;

		  if (!islocal)
		    {
		      if (!carbon_ask_question("Make these fonts global?",
					       "You are changing the font settings from applying only to this game to applying to all games: this will make these fonts the default for all games. If you want to revert to the current global settings, use the 'Use global fonts' button",
					  "Use these fonts", "Cancel", 2))
			{
			  islocal = 1;
			  SetControlValue(cntl, kControlCheckBoxCheckedValue);
			}
		    }

		  cid.signature = CARBON_RESFONT;
		  cid.id = CARBON_RESFONTID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);

		  if (islocal)
		    {
		      ActivateControl(cntl);
		    }
		  else
		    {
		      DeactivateControl(cntl);
		    }
		      
		  carbon_message_win = lastmsg;

		  /* Update... */
		  pref_store();
		}
		break;

	      case CARBON_RESCOLS:
		{
		  ControlID cid;
		  ControlRef cntl;
		  
		  DataBrowserItemID items[40];

		  int x;

		  cid.signature = CARBON_COLLIST;
		  cid.id        = CARBON_COLLISTID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);

		  /* Redo the colours with the defaults */
		  for (x=0; x<rc_defgame->n_colours; x++)
		    {
		      maccolour[x+6].red =
			colour_copy[x].red =
			rc_defgame->colours[x].r<<8;
		      maccolour[x+6].green =
			colour_copy[x].green =
			rc_defgame->colours[x].g<<8;
		      maccolour[x+6].blue =
			colour_copy[x].blue =
			rc_defgame->colours[x].b<<8;
		    }

		  /* Update the display */		  
		  for (x=0; x < 11; x++)
		    {
		      items[x] = x+1;
		    }
		  UpdateDataBrowserItems(cntl, kDataBrowserNoItem, 11, items, 0, 'Samp');

		  /* Mark as using the global colours */	  
		  cid.signature = CARBON_COLLOC;
		  cid.id = CARBON_COLLOCID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);
		  SetControlValue(cntl, kControlCheckBoxUncheckedValue);

		  /* Deactivate the control */
		  cid.signature = CARBON_RESCOLS;
		  cid.id = CARBON_RESCOLSID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);
		  DeactivateControl(cntl);

		  /* Store */
		  pref_store();
		}
		break;
		
	      case CARBON_COLLOC:
		{
		  WindowRef lastmsg;
		  ControlID cid;
		  ControlRef cntl;
		  int islocal;

		  lastmsg = carbon_message_win;
		  carbon_message_win = carbon_prefdlog;

		  cid.signature = CARBON_COLLOC;
		  cid.id = CARBON_COLLOCID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);

		  islocal = GetControlValue(cntl)==kControlCheckBoxCheckedValue;

		  if (!islocal)
		    {
		      if (!carbon_ask_question("Make these colours global?",
					       "You are changing the colour settings from applying only to this game to applying to all games: this will make these colours the default for all games. If you want to revert to the current global settings, use the 'Use global colours' button",
					  "Use these colours", "Cancel", 2))
			{
			  islocal = 1;
			  SetControlValue(cntl, kControlCheckBoxCheckedValue);
			}
		    }

		  cid.signature = CARBON_RESCOLS;
		  cid.id = CARBON_RESCOLSID;
		  GetControlByID(carbon_prefdlog, &cid, &cntl);

		  if (islocal)
		    {
		      ActivateControl(cntl);
		    }
		  else
		    {
		      DeactivateControl(cntl);
		    }
		      
		  carbon_message_win = lastmsg;

		  /* Update... */
		  pref_store();
		}		
		break;

	      case CARBON_RENDER:
	      case CARBON_ANTI:
		pref_store(); /* Update... */
		break;
		
	      case kHICommandOK:
		if (carbon_questdlog != nil)
		  {
		    QuitAppModalLoopForWindow(GetDialogWindow(carbon_questdlog));
		    carbon_questdlog = nil;
		    carbon_q_res = 1;
		    return noErr;
		  }
		else
		  {
		    pref_store();
		    
		    DisposeWindow(carbon_prefdlog);
		    carbon_prefdlog = nil;
		  }
		break;
		
	      case kHICommandCancel:
	      case kHICommandOther:
		if (carbon_questdlog != nil)
		  {
		    QuitAppModalLoopForWindow(GetDialogWindow(carbon_questdlog));
		    carbon_questdlog = nil;
		    carbon_q_res = 0;
		    return noErr;
		  }
		else
		  {
		    DisposeWindow(carbon_prefdlog);
		    carbon_prefdlog = nil;
		  }
		break;
	      }
	  }
	  break;
	}
      break;
    }

  return eventNotHandledErr;
}

static pascal OSStatus pref_tab_evt(EventHandlerCallRef handler,
				    EventRef event,
				    void*    data)
{
  OSStatus result = eventNotHandledErr;

  ControlRef control;
  ControlID  cid;

  GetEventParameter(event, kEventParamDirectObject, typeControlRef, NULL,
		    sizeof(ControlRef), NULL, &control);
  GetControlID(control, &cid);

  if (cid.id == CARBON_TABSID)
    {
      pref_select_tab(control);
    }

  return result;
}

/* Sets up the font menu to show font examples */
static void style_font_menu(void)
{
  char family[257];
  int x;
  int nitems;
  
  nitems = CountMenuItems(fontmenu);
  for (x=2; x<=nitems; x++)
    {
      GetMenuItemText(fontmenu, x, family);
      family[family[0]+1] = '\0';
      SetMenuItemFontID(fontmenu, x, FMGetFontFamilyFromName(family));
    }
}

/* Data event handler for the colour list view */
static pascal OSStatus colour_data_cb(ControlRef browser,
				      DataBrowserItemID item,
				      DataBrowserPropertyID property,
				      DataBrowserItemDataRef itemref,
				      Boolean setvalue)
{
  switch (property)
    {
    case 'Desc':
      SetDataBrowserItemDataText(itemref,
				 CFStringCreateWithCString(NULL, colour_name[item-1], kCFStringEncodingMacRoman));
      break;
    }

  return noErr;
}

/* Function to draw the preview of a colour */
static pascal void colour_draw_cb(ControlRef            browser,
				  DataBrowserItemID     item,
				  DataBrowserPropertyID prop,
				  DataBrowserItemState  state,
				  const Rect*           rct,
				  SInt16                gdDepth,
				  Boolean               colorDevice)
{
  Rect prct;

  prct = *rct;
  RGBForeColor(&colour_copy[item-1]);
  prct.left   += 2;
  prct.right  -= 2;
  prct.top    += 2;
  prct.bottom -= 2;
  PaintRect(&prct);
}

/* No custom tracking wanted... */
static pascal Boolean colour_track_cb(ControlRef browser,
				      DataBrowserItemID item,
				      DataBrowserPropertyID prop,
				      const Rect* theRect,
				      Point startPt,
				      EventModifiers modifiers)
{
  return 1;
}

/* Test to see if the click was in the colour's clickable area */
static pascal Boolean colour_hit_cb(ControlRef browser,
				    DataBrowserItemID item,
				    DataBrowserPropertyID prop,
				    const Rect* theRect,
				    const Rect* mouseRect)
{
  Rect r;
  Boolean res;

  r = *theRect;
  r.top += 2;
  r.bottom -= 2;
  r.left += 2;
  r.right -= 2;

  if (mouseRect->left == mouseRect->right)
    {
      res = (mouseRect->top > r.top && mouseRect->top < r.bottom) &&
	(mouseRect->left > r.left && mouseRect->left < r.right);
    }
  else
    {
      res = SectRect(mouseRect, &r, NULL);
    }

  return res;
}

/* Notification handler for the colour list view */
static pascal void colour_data_notify(ControlRef browser,
				      DataBrowserItemID item,
				      DataBrowserItemNotification msg)
{
  Point pt;
  RGBColor res;
  DataBrowserItemID id[1];

  switch (msg)
    {
    case kDataBrowserItemDoubleClicked:
      GetGlobalMouse(&pt);
      pt.v -= 10;
      pt.h -= 10;

      if (GetColor(pt, "\016Choose colour", &colour_copy[item-1], &res))
	colour_copy[item-1] = res;

      id[0] = item;
      UpdateDataBrowserItems(browser, kDataBrowserNoItem, 1, id, 0, 'Samp');

      pref_store();
      break;
    }
       
}

/* Comparason handler for the font list view */
static pascal Boolean font_compare_cb(ControlRef browser,
				      DataBrowserItemID item1,
				      DataBrowserItemID item2,
				      DataBrowserPropertyID property)
{
  carbon_font* fnt1, *fnt2;

  switch (property)
    {
    case 'Styl':
      if (font_copy[item1-1].attributes[0] <
	  font_copy[item2-1].attributes[0])
	return true;
      else
	return false;

    case 'Size':
      fnt1 = carbon_parse_font(font_copy[item1-1].name);
      fnt2 = carbon_parse_font(font_copy[item2-1].name);

      if (fnt1->size < fnt2->size)
	return true;
      else
	return false;
      break;
    }

  return false;
}

/* Data event handler for the font list view */
static pascal OSStatus font_data_cb(ControlRef browser,
				    DataBrowserItemID item,
				    DataBrowserPropertyID property,
				    DataBrowserItemDataRef itemref,
				    Boolean setvalue)
{
  carbon_font* fnt;
  char str[256];
  int x;

  if (item <= 0)
    return noErr;

  fnt = carbon_parse_font(font_copy[item-1].name);

  switch (property)
    {
    case kDataBrowserItemIsSelectableProperty:
      SetDataBrowserItemDataBooleanValue(itemref, true);
      break;

    case 'Styl':
      str[0] = '\0';

      if (font_copy[item-1].attributes[0]&8)
	{
	  if (str[0] != '\0')
	    strcat(str, "-symbolic");
	  else
	    strcat(str, "symbolic");
	}
      if (font_copy[item-1].attributes[0]&4)
	{
	  if (str[0] != '\0')
	    strcat(str, "-fixed");
	  else
	    strcat(str, "fixed");
	}
      if (font_copy[item-1].attributes[0]&1)
	{
	  if (str[0] != '\0')
	    strcat(str, "-bold");
	  else
	    strcat(str, "bold");
	}
      if (font_copy[item-1].attributes[0]&2)
	{
	  if (str[0] != '\0')
	    strcat(str, "-italic");
	  else
	    strcat(str, "italic");
	}

      if (str[0] == '\0')
	strcat(str, "roman");

      SetDataBrowserItemDataText(itemref,
				 CFStringCreateWithCString(NULL, str, kCFStringEncodingMacRoman));
      break;

    case 'Size':
      if (!setvalue)
	{
	  sprintf(str, "%i", fnt->size);
	  SetDataBrowserItemDataText(itemref,
				     CFStringCreateWithCString(NULL, str, kCFStringEncodingMacRoman));
	}
      else
	{
	  CFStringRef cfstr;
	  char buf[64];
	  int sz;

	  GetDataBrowserItemDataText(itemref,
				     &cfstr);
	  CFStringGetCString(cfstr, buf, 64, kCFStringEncodingMacRoman);
	  sz = atoi(buf);
	  if (sz > 0 && sz < 200)
	    fnt->size = sz;
	  CFRelease(cfstr);
	}
      break;

    case 'Bold':
      if (!setvalue)
	{
	  SetDataBrowserItemDataButtonValue(itemref,
					    fnt->isbold?kControlCheckBoxCheckedValue:kControlCheckBoxUncheckedValue);
	}
      else
	{
	  ThemeButtonValue val;

	  GetDataBrowserItemDataButtonValue(itemref, &val);
	  fnt->isbold = val == kControlCheckBoxCheckedValue;
	}
      break;

    case 'Ital':
      if (!setvalue)
	{
	  SetDataBrowserItemDataButtonValue(itemref,
					    fnt->isitalic?kControlCheckBoxCheckedValue:kControlCheckBoxUncheckedValue);
	}
      else
	{
	  ThemeButtonValue val;

	  GetDataBrowserItemDataButtonValue(itemref, &val);
	  fnt->isitalic = val == kControlCheckBoxCheckedValue;
	}
      break;

    case 'Undl':
      if (!setvalue)
	{
	  SetDataBrowserItemDataButtonValue(itemref,
					    fnt->isunderlined?kControlCheckBoxCheckedValue:kControlCheckBoxUncheckedValue);
	}
      else
	{
	  ThemeButtonValue val;

	  GetDataBrowserItemDataButtonValue(itemref, &val);
	  fnt->isunderlined = val == kControlCheckBoxCheckedValue;
	}
      break;

    case 'Desc':
      if (!setvalue)
	{
	  char family[257];
	  int nitems, ouritem;

	  nitems = CountMenuItems(fontmenu);
	  ouritem = 1;
	  if (fnt->isfont3)
	    {
	      ouritem = 1;
	    }
	  else
	    {
	      for (x=2; x<=nitems; x++)
		{
		  GetMenuItemText(fontmenu, x, family);
		  family[family[0]+1] = '\0';
		  if (strcmp(family+1, fnt->face_name) == 0)
		    {
		      ouritem = x;
		    }
		}
	    }

	  SetDataBrowserItemDataMenuRef(itemref, fontmenu);
	  SetDataBrowserItemDataValue(itemref, ouritem);
	}
      else
	{
	  SInt32 ouritem;
	  OSStatus stat;
	  char hum[257];

	  stat = GetDataBrowserItemDataValue(itemref, &ouritem);
	  if (ouritem > 0)
	    {
	      if (ouritem == 1)
		fnt->isfont3 = 1;
	      else
		{
		  fnt->isfont3 = 0;
		  
		  GetMenuItemText(fontmenu, ouritem, hum);
		  
		  hum[hum[0]+1] = '\0';
		  strcpy(fnt->face_name, hum+1);
		}
	    }
	}
      break;

    case kDataBrowserItemIsEditableProperty:
      SetDataBrowserItemDataBooleanValue(itemref, true);
      break;
    }

  if (setvalue)
    {
      char str[256];
      DataBrowserItemID id[1];
      
      id[0] = item;
      
      if (fnt->isfont3)
	strcpy(str, "font3");
      else
	sprintf(str, "'%s' %i %c%c%c", 
		fnt->face_name,
		fnt->size,
		fnt->isbold?'b':' ',
		fnt->isitalic?'i':' ',
		fnt->isunderlined?'u':' ');
      font_copy[item-1].name = realloc(font_copy[item-1].name,
				       strlen(str)+1);
      strcpy(font_copy[item-1].name, str);

      UpdateDataBrowserItems(browser, kDataBrowserNoItem, 1, id, 0, 'Samp');

      pref_store();
    }

  return noErr;
}

/* Function to draw the preview of a font */
static pascal void font_draw_cb(ControlRef            browser,
				DataBrowserItemID     item,
				DataBrowserPropertyID prop,
				DataBrowserItemState  state,
				const Rect*           rct,
				SInt16                gdDepth,
				Boolean               colorDevice)
{
  char   name[256];
  carbon_font* fnt;
  xfont* xfnt;
  int string[] = 
    { 'T', 'h', 'e', ' ', 'Q', 'u', 'i', 'c', 'k', ' ', 
      'B', 'r', 'o', 'w', 'n', ' ', 'F', 'o', 'x', ' ', 
      'J', 'u', 'm', 'p', 'e', 'd', ' ', 'O', 'v', 'e', 'r', ' ', 
      't', 'h', 'e', ' ', 'L', 'a', 'z', 'y', ' ', 'D', 'o', 'g' };
  int offset;

  RgnHandle oldclip;
  RgnHandle newclip;

  /* 
   * The docs say we shouldn't alter the clip region, but we need to clip 
   * the example, sooo... we, er, bend the rules a bit 
   */
  oldclip = NewRgn();
  newclip = NewRgn();
  RectRgn(newclip, rct);
  GetClip(oldclip);

  SectRgn(oldclip, newclip, newclip);

  SetClip(newclip);

#ifdef USE_QUARTZ
  carbon_set_quartz(0);
#endif

  /* Create a 14-point version of this font */
  fnt = carbon_parse_font(font_copy[item-1].name);
  if (fnt->isfont3)
    strcpy(name, "font3");
  else
    sprintf(name, "'%s' 14 %c%c%c", 
	    fnt->face_name,
	    fnt->isbold?'b':' ',
	    fnt->isitalic?'i':' ',
	    fnt->isunderlined?'u':' ');

  /* Load it, display it, release it */
  xfnt = xfont_load_font(name);
  xfont_set_colours(0, 7);

  offset = (rct->bottom - rct->top)/2 + xfont_get_ascent(xfnt)/2;

  xfont_plot_string(xfnt,
		    rct->left,
		    -rct->top - offset,
		    string,
		    44);
  xfont_release_font(xfnt);

  /* Reset the clipping region */
  SetClip(oldclip);
  DisposeRgn(oldclip);

#ifdef USE_QUARTZ
  carbon_set_quartz(carbon_prefs.use_quartz);
#endif
}

void carbon_prefs_set_resources(char* path)
{
  BlorbFile* file;
  ZFile*     rfile;

  char       str[128];

  rc_game*   game;

  int        hadblorb;

  hadblorb = machine.blorb != NULL;

  /* Read the file... See if it looks good... */
  rfile = open_file(path);
  if (rfile != NULL)
    file = blorb_loadfile(rfile);
  
  /* Read failure? */
  if (rfile == NULL || file == NULL)
    {
      char* msg;

      if (rfile == NULL)
	msg = "Unable to read file: access error";
      else
	{
	  close_file(rfile);
	  msg = "Unable to read file: not a Blorb file";
	}
      
      carbon_display_message("Resource file load error", msg);
      
      return;
    }
  
  /* Doesn't belong to this game? */
  if (file->game_id != NULL)
    {
      if ((ZUWord)Word(ZH_release) != file->game_id->release ||
	  (ZUWord)Word(ZH_checksum) != file->game_id->checksum ||
	  memcmp(Address(ZH_serial), file->game_id->serial, 6) != 0)
	{
	  if (!carbon_ask_question("Resource file does not match currently loaded game", "The resource file you are trying to load does not appear to correspond to the game you are running: are you sure you want to use this file?",
				   "Use file", "Cancel", 1))
	    {
	      blorb_closefile(file);
	      close_file(rfile);
	      return;
	    }
	}
    }
  
  if (machine.blorb != NULL)
    {
      blorb_closefile(machine.blorb);
      close_file(machine.blorb_file);
    }
  
  machine.blorb = file;
  machine.blorb_tokens = file->file;
  machine.blorb_file = rfile; 

  /* Store this in the resources... */
  sprintf(str, "%i.%.6s.%04x", Word(ZH_release), zmachine_get_serial(), 
	  (unsigned)Word(ZH_checksum));
  game = hash_get(rc_hash, str, strlen(str));

  if (game == NULL)
    {
      rc_game* nocs;
      char str2[20];

      sprintf(str2, "%i.%.6s", Word(ZH_release), zmachine_get_serial());
      nocs = hash_get(rc_hash, str2, strlen(str2));

      if (nocs == NULL)
	{
	  /* Create a new, blank entry */
	  game = malloc(sizeof(rc_game));
	  game->name = malloc(strlen(carbon_title)+1);
	  strcpy(game->name, carbon_title);
      
	  game->interpreter = -1;
	  game->revision    = -1;
	  game->fonts       = NULL;
	  game->n_fonts     = -1;
	  game->colours     = NULL;
	  game->n_colours   = -1;
	  game->gamedir     = NULL;
	  game->savedir     = NULL;
	  game->sounds      = NULL;
	  game->graphics    = NULL;
	  game->xsize       = -1;
	  game->ysize       = -1;
	  game->antialias   = -1;
	}
      else
	{
	  /* Copy the old-style entry into the new new-style one */
	  game = malloc(sizeof(rc_game));
	  *game = *nocs;

	  /* Delete the old one... */
	  hash_store(rc_hash, str2, strlen(str2), NULL);
	}
      
      hash_store(rc_hash, str, strlen(str), game);
    }

  game->graphics = malloc(strlen(path)+1);
  strcpy(game->graphics, path);

  pref_write();

  if (carbon_prefdlog != nil)
    {
      ControlID  cid;
      ControlRef cntl;
      
      cid.signature = CARBON_RESFILE;
      cid.id        = CARBON_RESFILEID;
      GetControlByID(carbon_prefdlog, &cid, &cntl);

      SetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		     strlen(game->graphics), game->graphics);

    }

  /* Notification... */
  if (!hadblorb)
    {
      char str[512];
      sprintf(str, "The resources for the game '%s' have been remembered in the configuration file: you should not have to do this again", 
	      carbon_title);
      carbon_display_message("Resource location recorded",
			     str);
    }
  else
    {
      carbon_display_message("Resource location recorded",
			     "The resources for this game have been updated with the location of the new file you have supplied");
    }
}

/* Function to set up the contents of the preferences dialog */
static void pref_setup(void)
{
  ControlID  cid;
  ControlRef cntl;

  char str[40];
  int val,x;

  rc_game* game;

  DataBrowserItemID items[40];

  rc_font* fonts;
  int      n_fonts;

  /* Set up the general preferences */
  cid.signature = CARBON_DISPWARNS;
  cid.id        = CARBON_DISPWARNSID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  SetControlValue(cntl, carbon_prefs.show_warnings?
		  kControlCheckBoxCheckedValue:kControlCheckBoxUncheckedValue);

  cid.signature = CARBON_FATWARNS;
  cid.id        = CARBON_FATWARNSID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  SetControlValue(cntl, carbon_prefs.fatal_warnings?
		  kControlCheckBoxCheckedValue:kControlCheckBoxUncheckedValue);

  cid.signature = CARBON_SPEAK;
  cid.id        = CARBON_SPEAKID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  SetControlValue(cntl, carbon_prefs.use_speech?
		  kControlCheckBoxCheckedValue:kControlCheckBoxUncheckedValue);

  cid.signature = CARBON_RENDER;
  cid.id        = CARBON_RENDERID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  SetControlValue(cntl, carbon_prefs.use_quartz?
		  2:1);

  cid.signature = CARBON_ANTI;
  cid.id        = CARBON_ANTIID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  SetControlValue(cntl, rc_defgame->antialias?
		  kControlCheckBoxCheckedValue:kControlCheckBoxUncheckedValue);

  /* Try to get the game hash entry */
  sprintf(str, "%i.%.6s.%04x", Word(ZH_release), zmachine_get_serial(), 
	  (unsigned)Word(ZH_checksum));
  game = hash_get(rc_hash, str, strlen(str));

  if (game == NULL)
    {
      rc_game* nocs;
      char str2[20];

      sprintf(str2, "%i.%.6s", Word(ZH_release), zmachine_get_serial());
      nocs = hash_get(rc_hash, str2, strlen(str2));

      if (nocs == NULL)
	{
	  /* Create a new, blank entry */
	  game = malloc(sizeof(rc_game));
	  game->name = malloc(strlen(carbon_title)+1);
	  strcpy(game->name, carbon_title);
      
	  game->interpreter = -1;
	  game->revision    = -1;
	  game->fonts       = NULL;
	  game->n_fonts     = -1;
	  game->colours     = NULL;
	  game->n_colours   = -1;
	  game->gamedir     = NULL;
	  game->savedir     = NULL;
	  game->sounds      = NULL;
	  game->graphics    = NULL;
	  game->xsize       = -1;
	  game->ysize       = -1;
	  game->antialias   = -1;
	}
      else
	{
	  /* Copy the old-style entry into the new new-style one */
	  game = malloc(sizeof(rc_game));
	  *game = *nocs;

	  /* Delete the old one... */
	  hash_store(rc_hash, str2, strlen(str2), NULL);
	}

      hash_store(rc_hash, str, strlen(str), game);
    }

  /* Set up the 'serial #' field */
  cid.signature = CARBON_SERIAL;
  cid.id        = CARBON_SERIALID;
  
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  sprintf(str, "%.6s", zmachine_get_serial());
  SetControlData(cntl, kControlEntireControl, kControlStaticTextTextTag,
		 strlen(str), str);

  /* Set up the 'Release #' field */
  cid.signature = CARBON_RELEASE;
  cid.id        = CARBON_RELEASEID;
  
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  sprintf(str, "%i", Word(ZH_release));
  SetControlData(cntl, kControlEntireControl, kControlStaticTextTextTag,
		 strlen(str), str);

  /* Set up the 'Game title' field */
  cid.signature = CARBON_TITLE;
  cid.id        = CARBON_TITLEID;
  
  GetControlByID(carbon_prefdlog, &cid, &cntl);
  SetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		 strlen(game->name), game->name);

  /* Set up the 'Interpreter' field */
  cid.signature = CARBON_INTERPLOC;
  cid.id        = CARBON_INTERPLOCID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  if (game->interpreter == -1)
    {
      val = rc_defgame->interpreter;
      SetControlValue(cntl, kControlCheckBoxUncheckedValue);
    }
  else
    {
      val = game->interpreter;
      SetControlValue(cntl, kControlCheckBoxCheckedValue);
    }

  cid.signature = CARBON_INTERP;
  cid.id        = CARBON_INTERPID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  sprintf(str, "%i", val);
  SetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		 strlen(str), str);

  /* Set up the 'Interpreter revision' field */
  cid.signature = CARBON_REVLOC;
  cid.id        = CARBON_REVLOCID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  if (game->revision == -1)
    {
      val = rc_defgame->revision;
      SetControlValue(cntl, kControlCheckBoxUncheckedValue);
    }
  else
    {
      val = game->revision;
      SetControlValue(cntl, kControlCheckBoxCheckedValue);
    }

  cid.signature = CARBON_REVISION;
  cid.id        = CARBON_REVISIONID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  sprintf(str, "%c", val);
  SetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		 strlen(str), str);

  /* Set up the font list */
  cid.signature = CARBON_FONTLOC;
  cid.id        = CARBON_FONTLOCID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  if (game->fonts != NULL)
    {
      SetControlValue(cntl, kControlCheckBoxCheckedValue);
      fonts = game->fonts;
      n_fonts = game->n_fonts;

      cid.signature = CARBON_RESFONT;
      cid.id        = CARBON_RESFONTID;
      GetControlByID(carbon_prefdlog, &cid, &cntl);
      ActivateControl(cntl);
    }
  else
    {
      SetControlValue(cntl, kControlCheckBoxUncheckedValue);
      fonts = rc_defgame->fonts;
      n_fonts = rc_defgame->n_fonts;

      cid.signature = CARBON_RESFONT;
      cid.id        = CARBON_RESFONTID;
      GetControlByID(carbon_prefdlog, &cid, &cntl);
      DeactivateControl(cntl);
    }

  cid.signature = CARBON_FONTLIST;
  cid.id        = CARBON_FONTLISTID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  for (x=0; x<font_nfonts; x++)
    {
      free(font_copy[x].name);
    }

  font_copy = realloc(font_copy, sizeof(rc_font)*n_fonts);
  memcpy(font_copy, fonts, sizeof(rc_font)*n_fonts);
  font_nfonts = n_fonts;

  for (x=0; x < n_fonts; x++)
    {
      font_copy[x].name = malloc(strlen(fonts[x].name)+1);
      strcpy(font_copy[x].name, fonts[x].name);
      items[x] = x+1;
    }
  AddDataBrowserItems(cntl, kDataBrowserNoItem, n_fonts, items, kDataBrowserItemNoProperty);

  /* Set up the colour list */
  cid.signature = CARBON_COLLIST;
  cid.id        = CARBON_COLLISTID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  for (x=0; x < 11; x++)
    {
      items[x] = x+1;
      colour_copy[x] = maccolour[x+6];
    }
  AddDataBrowserItems(cntl, kDataBrowserNoItem, 11, items, kDataBrowserItemNoProperty);
  
  cid.signature = CARBON_COLLOC;
  cid.id        = CARBON_COLLOCID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);
 
  if (game->colours != NULL)
    {
      SetControlValue(cntl, kControlCheckBoxCheckedValue);

      cid.signature = CARBON_RESCOLS;
      cid.id        = CARBON_RESCOLSID;
      GetControlByID(carbon_prefdlog, &cid, &cntl);
      ActivateControl(cntl);
    }
  else
    {
      SetControlValue(cntl, kControlCheckBoxUncheckedValue);

      cid.signature = CARBON_RESCOLS;
      cid.id        = CARBON_RESCOLSID;
      GetControlByID(carbon_prefdlog, &cid, &cntl);
      DeactivateControl(cntl);
    }

  /* Set up the resource file field */
  cid.signature = CARBON_RESFILE;
  cid.id        = CARBON_RESFILEID;
  GetControlByID(carbon_prefdlog, &cid, &cntl);

  if (game->graphics != NULL)
    {
      SetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		     strlen(game->graphics), game->graphics);
    }
  else
    {
      SetControlData(cntl, kControlEntireControl, kControlEditTextTextTag,
		     strlen(""), "");
    }

  ourgame = game;  
}

void carbon_show_prefs(void)
{
  IBNibRef nib;
  
  if (fontmenu == nil)
    {
      fontmenu = NewMenu(20, "\005Fonts");
      AppendMenuItemText(fontmenu, "\017Built-in font 3");
      CreateStandardFontMenu(fontmenu, 1, 0, kNilOptions, NULL);      
      style_font_menu();
      InsertMenu(fontmenu, -1);
    }

  if (carbon_prefdlog == nil)
    {
      ControlID tab;
      ControlRef tabcontrol;

      ControlID cid;
      ControlRef cntl;

      EventTypeSpec winspec[] = 
	{ 
	  { kEventClassMouse,   kEventMouseDown },
	  { kEventClassCommand, kEventProcessCommand },
	  { kEventClassWindow,  kEventWindowBoundsChanged }
	};
      EventTypeSpec tabspec = { kEventClassControl, kEventControlHit };
      static EventHandlerUPP evhandle = nil;
      static EventHandlerUPP prefhandle = nil;

      DataBrowserCallbacks dbcb;
      DataBrowserCustomCallbacks dbcustom;

      /* Create the window */
      CreateNibReference(CFSTR("zoom"), &nib);
      CreateWindowFromNib(nib, CFSTR("Preferences"), &carbon_prefdlog);
      DisposeNibReference(nib);

      /* Install a handler to deal with adjustments to the window */
      if (prefhandle == nil)
	prefhandle = NewEventHandlerUPP(pref_wnd_evt);

      InstallEventHandler(GetWindowEventTarget(carbon_prefdlog),
			  prefhandle, 3, winspec, 0, NULL);

      /* Install a handler to change the tab panes */
      tab.signature = CARBON_TABS;
      tab.id        = CARBON_TABSID;
      GetControlByID(carbon_prefdlog, &tab, &tabcontrol);

      if (evhandle == nil)
	evhandle = NewEventHandlerUPP(pref_tab_evt);

      InstallEventHandler(GetControlEventTarget(tabcontrol),
			  evhandle, 1, &tabspec, 0, NULL);

      pref_setup();
      pref_select_tab(tabcontrol);

      /* Install handlers for the font list box */
      cid.signature = CARBON_FONTLIST;
      cid.id        = CARBON_FONTLISTID;
      GetControlByID(carbon_prefdlog, &cid, &cntl);

      SetDataBrowserTableViewRowHeight(cntl, 20);
      SetDataBrowserSelectionFlags(cntl, kDataBrowserSelectOnlyOne);
      SetDataBrowserListViewUsePlainBackground(cntl, false);

      dbcb.version = kDataBrowserLatestCallbacks;
      InitDataBrowserCallbacks(&dbcb);

      dbcb.u.v1.itemDataCallback = NewDataBrowserItemDataUPP(font_data_cb);
      dbcb.u.v1.itemCompareCallback = NewDataBrowserItemCompareUPP(font_compare_cb);
      
      SetDataBrowserCallbacks(cntl, &dbcb);
        
      SetDataBrowserSortProperty(cntl, 'Styl');
      SetDataBrowserSortOrder(cntl, kDataBrowserOrderIncreasing);

      dbcustom.version = kDataBrowserLatestCustomCallbacks;
      InitDataBrowserCustomCallbacks(&dbcustom);
      
      dbcustom.u.v1.drawItemCallback = NewDataBrowserDrawItemUPP(font_draw_cb);
      SetDataBrowserCustomCallbacks(cntl, &dbcustom);

      /* Set the editable fields */
      SetDataBrowserPropertyFlags(cntl, 'Desc', kDataBrowserPropertyIsEditable);
      SetDataBrowserPropertyFlags(cntl, 'Size', kDataBrowserPropertyIsEditable);
      SetDataBrowserPropertyFlags(cntl, 'Bold', kDataBrowserPropertyIsEditable);
      SetDataBrowserPropertyFlags(cntl, 'Ital', kDataBrowserPropertyIsEditable);
      SetDataBrowserPropertyFlags(cntl, 'Undl', kDataBrowserPropertyIsEditable);
      
      /* Set up the colour list box */
      cid.signature = CARBON_COLLIST;
      cid.id        = CARBON_COLLISTID;
      GetControlByID(carbon_prefdlog, &cid, &cntl);
      
      SetDataBrowserPropertyFlags(cntl, 'Samp', kDataBrowserPropertyIsEditable);
      
      dbcb.version = kDataBrowserLatestCallbacks;
      InitDataBrowserCallbacks(&dbcb);

      dbcb.u.v1.itemDataCallback = NewDataBrowserItemDataUPP(colour_data_cb);
      dbcb.u.v1.itemNotificationCallback = NewDataBrowserItemNotificationUPP(colour_data_notify);
      
      SetDataBrowserCallbacks(cntl, &dbcb);

      dbcustom.version = kDataBrowserLatestCustomCallbacks;
      InitDataBrowserCustomCallbacks(&dbcustom);
      
      dbcustom.u.v1.drawItemCallback = NewDataBrowserDrawItemUPP(colour_draw_cb);
      dbcustom.u.v1.hitTestCallback = NewDataBrowserHitTestUPP(colour_hit_cb);
      dbcustom.u.v1.trackingCallback = NewDataBrowserTrackingUPP(colour_track_cb);

      SetDataBrowserCustomCallbacks(cntl, &dbcustom);
    }

  ShowWindow(carbon_prefdlog);
  BringToFront(carbon_prefdlog);
}

#endif

