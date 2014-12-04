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
 * Display for MacOS (Carbon)
 */

#undef  USE_ATS    /* A bit experimental */
#define USE_QUARTZ /* 
		    * Just as experimental, really, and about as
		    * slow... Don't define this and USE_ATS. If
		    * USE_QUARTZ is defined, Quartz is used for font
		    * rendering instead of quickdraw. Quartz produces
		    * **much** better font quality, at the cost of
		    * low speed (Apple, in their wisdom, don't provide
		    * any decent functions for measuring text widths
		    * with Quartz, so we hack it. CGContextSetFont()
		    * is a load of crap, too... Sigh)
		    */

#ifdef USE_QUARTZ
# undef USE_ATS
#endif

#ifndef __CARBONDISPLAY_H
#define __CARBONDISPLAY_H

#define SIGNATURE 'YZZY'

enum carbon_file_type
  {
    TYPE_ZCOD,
    TYPE_IFZS,
    TYPE_IFRS,
    TYPE_BINA,
    TYPE_BORING
  };

extern WindowRef zoomWindow;
extern WindowRef carbon_message_win;
extern RGBColor  maccolour[17];
extern int       window_available;
extern DialogRef fataldlog;
extern FSRef*    lastopenfs;
extern FSRef*    forceopenfs;
extern int       quitflag;
extern int       mac_openflag;
extern char      carbon_title[];

extern DialogRef carbon_questdlog;
extern int       carbon_q_res;

#ifdef USE_QUARTZ
extern CGContextRef carbon_quartz_context;
#endif

extern FSRef* carbon_get_zcode_file(void);

extern ZFile* open_file_fsref(FSRef* ref);
extern ZFile* open_file_write_fsref(FSRef* ref);
extern ZDWord get_file_size_fsref(FSRef* file);
extern FSRef  get_file_fsref(ZFile* file);

extern Boolean display_force_input  (char* text);
extern void    display_force_restore(FSRef* ref);

extern OSErr ae_opendocs_handler(const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);
extern OSErr ae_open_handler    (const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);
extern OSErr ae_print_handler   (const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);
extern OSErr ae_quit_handler    (const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);
extern OSErr ae_reopen_handler  (const AppleEvent* evt,
				 AppleEvent* reply,
				 SInt32      handlerRefIcon);

extern void carbon_display_message(char* title, char* message);
extern void carbon_display_rejig  (void);

extern RGBColor* carbon_get_colour(int colour);

extern void carbon_show_prefs(void);
extern void carbon_set_context(void);
extern void carbon_set_quartz(int q);

extern void carbon_prefs_set_resources(char* path);

extern int  carbon_ask_question       (char* title, char* message,
				       char* OK, char* cancel, int def);
extern void carbon_display_about      (void);

extern void carbon_merge_rc           (void);

extern void carbon_set_scale_factor   (double factor);

extern enum carbon_file_type carbon_type_fsref(FSRef* file);

/* image_ routines have their own naming convention, which we preserve */
extern void image_draw_carbon(image_data* img, 
			      CGrafPtr port, 
			      int x, int y,
			      int n, int d);

/* Font information */
typedef struct carbon_font
{
  char* face_name;
  int   isfont3;
  int   size;
  int   isbold;
  int   isitalic;
  int   isunderlined;
} carbon_font;

/* Preferences */
typedef struct {
  int use_speech;
  int use_quartz;
  int show_warnings;
  int fatal_warnings;
} carbon_preferences;

extern carbon_preferences carbon_prefs;

extern carbon_font* carbon_parse_font(char* name);

/* Preferences dialog signatures */
#define CARBON_TABS      'tabs' /* Both the tabs control and the panes */
#define CARBON_DISPWARNS 'Warn' /* Display warnings option */
#define CARBON_FATWARNS  'FWar' /* Warnings are fatal option */
#define CARBON_SPEAK     'Spek' /* Speak game text option */
#define CARBON_RENDER    'Rend' /* Rendering style */
#define CARBON_ANTI      'Anti' /* Anti-aliasing */
#define CARBON_SERIAL    'Seri' /* Serial # */
#define CARBON_RELEASE   'Rele' /* Release # */
#define CARBON_TITLE     'Titl' /* Game title */
#define CARBON_INTERPLOC 'ILoc' /* Intepreter version global/local */
#define CARBON_INTERP    'Terp' /* Intepreter version */
#define CARBON_REVLOC    'RLoc' /* Interpreter revision global/local */
#define CARBON_REVISION  'Revi' /* Interpreter revision */
#define CARBON_FONTLOC   'Fapp' /* Fonts global/local */
#define CARBON_FONTLIST  'Flis' /* Font list */
#define CARBON_COLLOC    'Capp' /* Colours global/local */
#define CARBON_COLLIST   'Clis' /* Colour list */
#define CARBON_RESFILE   'ReFN' /* Resource filename */
#define CARBON_RESFONT   'ResF' /* Restore fonts to defaults */
#define CARBON_RESCOLS   'ResC' /* Restore colours to defaults */

/* Preferences dialog identifiers */
#define CARBON_TABSID      128
#define CARBON_DISPWARNSID 600
#define CARBON_FATWARNSID  601
#define CARBON_SPEAKID     602
#define CARBON_RENDERID    603
#define CARBON_ANTIID      604
#define CARBON_SERIALID    700
#define CARBON_RELEASEID   701
#define CARBON_TITLEID     702
#define CARBON_INTERPLOCID 703
#define CARBON_INTERPID    704
#define CARBON_REVLOCID    705
#define CARBON_REVISIONID  706
#define CARBON_FONTLOCID   800
#define CARBON_FONTLISTID  801
#define CARBON_RESFONTID   802
#define CARBON_COLLOCID    900
#define CARBON_COLLISTID   901
#define CARBON_RESCOLSID   902
#define CARBON_RESFILEID   1000

#endif
