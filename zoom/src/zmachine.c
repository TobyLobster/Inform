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
 * General ZMachine utility functions
 */

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>

#include "zmachine.h"
#include "file.h"
#include "zscii.h"
#include "display.h"
#include "rc.h"
#include "stream.h"
#include "blorb.h"
#include "v6display.h"

#if WINDOW_SYSTEM == 2
# include <windows.h>
#elif WINDOW_SYSTEM == 3
# include <Carbon/Carbon.h>

# include "carbondisplay.h"
#endif

void zmachine_load_file(ZFile* file, ZMachine* machine) {
    ZFrame* frame;

    // machine->story_length must be set already
    machine->story_offset = 0;
    machine->file = file;

    if (machine->file == NULL) {
        zmachine_fatal("Unable to open story file");
    }

    machine->blorb_tokens = NULL;
    machine->blorb = NULL;
    if (blorb_is_blorbfile(machine->file))
    {
        machine->blorb_file   = machine->file;
        machine->blorb        = blorb_loadfile(machine->file);
        machine->blorb_tokens = machine->blorb->file;

        machine->story_offset = machine->blorb->zcode_offset;
        machine->story_length = machine->blorb->zcode_len;

        rc_set_game("xxxxxx", 65535, 65535);

        if (machine->blorb->zcode_offset < 0)
        {
            zmachine_fatal("This blorb file does not contain an executable Z-Code section");
        }

        machine->memory = read_block(machine->file,
                                     machine->story_offset,
                                     machine->story_offset+machine->story_length);
    }
    else
    {
        machine->memory = read_block(machine->file, 0, machine->story_length);
    }
    if (machine->memory == NULL)
        zmachine_fatal("Unable to read story file");
    /* close_file(machine->file); */

#ifdef GLOBAL_PC
    machine->zpc = -1;
#endif

    if (machine->memory[0] < 3)
        zmachine_fatal("The game you are trying to load is a version 1 or 2 game: Zoom does not support version 1 or 2 games. You can obtain patches for all known version 1/2 games from http://www.ifarchive.org that will turn them into version 3 or better games");

    machine->stack.stack_size    = 2048;
    machine->stack.stack_total   = 2048;
    machine->stack.stack         = malloc(sizeof(ZWord)*2048);
    machine->stack.stack_top     = machine->stack.stack;

    /*
     * Topmost frame is a 'fake' frame to make quetzal work properly
     */
    frame = machine->stack.current_frame = malloc(sizeof(ZFrame));

    frame->ret          = 0;
    frame->flags        = 0;
    frame->storevar     = 0;
    frame->discard      = 0;
    frame->frame_size   = 0;
    frame->last_frame   = NULL;
    frame->frame_num    = 0;
    frame->nlocals      = 0;
    frame->v4read       = NULL;
    frame->v5read       = NULL;
	frame->break_on_return = 0;

    machine->header = machine->memory;

    if (machine->header[0] > 8)
        zmachine_fatal("Not a ZCode file");

    if (machine->memory[0] >= 5)
        zscii_install_alphabet();

    machine->dynamic_ceiling     = (ZUWord)GetWord(machine->header, ZH_static);
    machine->buffering           = 1;

    machine->globals             = machine->memory +
        GetWord(machine->header, ZH_globals);
    /*machine->objects             = machine->memory +
        GetWord(machine->header, ZH_objs); */
    machine->dict                = machine->memory +
        GetWord(machine->header, ZH_dict);

    machine->cached_dictionaries = hash_create();

    machine->routine_offset = 8*GetWord(machine->header, ZH_routines);
    machine->string_offset = 8*GetWord(machine->header,
                                       ZH_staticstrings);

    machine->heb = NULL;
    machine->heblen = 0;
    if (machine->header[0] >= 5)
    {
        if (GetWord(machine->header, ZH_extntable) > 32 &&
            GetWord(machine->header, ZH_extntable) < machine->story_length)
        {
            machine->heb    = machine->memory + GetWord(machine->header,
                                                        ZH_extntable);
            machine->heblen = GetWord(machine->heb, ZHEB_len);

            if (machine->heblen > 32)
            {
                zmachine_warning("Dodgy-looking header extension table (%i bytes long?), ignoring", machine->heblen);
                machine->heb    = NULL;
                machine->heblen = 0;
            }
            else
                stream_update_unicode_table();
        }
        else
        {
            zmachine_warning("Dodgy-looking header extension table, ignoring");
            machine->heb = NULL;
            machine->heblen = 0;
        }
    }

    /* Parse the abbreviations table */
    if (GetWord(machine->header, ZH_abbrevs) != 0)
    {
        ZByte* abbrev;
        int*  word;
        int x, len;

        abbrev = machine->memory + GetWord(machine->header, ZH_abbrevs);

        for (x=0; x<96*2; x+=2)
        {
            int y;
	  
            machine->abbrev_addr[x>>1] = ((abbrev[x]<<9)|(abbrev[x+1]<<1));
		
	    if (abbrev[x] == 0 && abbrev[x+1] == 0) {
	      word = malloc(sizeof(int));
	      word[0] = 0;
	    } else {
              word = zscii_to_unicode((ZByte*)machine->memory +
                                      ((abbrev[x]<<9)|(abbrev[x+1]<<1)), &len);
	    }
	  
            for (y=0; word[y] != 0; y++);
            machine->abbrev[x>>1] = malloc(sizeof(int)*(y+1));

            for (y=0; word[y] != 0; y++)
                machine->abbrev[x>>1][y] = word[y];
            machine->abbrev[x>>1][y] = 0;
        }
    }

    machine->screen_on = 1;
    machine->transcript_on = 0;
    machine->transcript_file = NULL;
    machine->script_on = 0;
    machine->script_file = NULL;
    machine->memory_on = 0;
	
	machine->autosave_pc = 0;
	
#ifdef REMOTE_BREAKPOINT
	machine->force_breakpoint = 0;
#endif
}

void zmachine_load_story(const char* filename, ZMachine* machine)
{
  ZDWord size;

  machine->story_file = filename;

#if WINDOW_SYSTEM == 3
  if (filename == NULL)
    {
      FSRef* ref;

      ref = carbon_get_zcode_file();

      if (ref == NULL)
	zmachine_fatal("No story file");

      machine->story_length = size = get_file_size_fsref(ref);
      machine->story_offset = 0;
      if (size < 0)
	zmachine_fatal("Unable to open story file");
      if (size < 64)
	zmachine_fatal("Story file is way too small (%i bytes)", size);
      
      machine->file = open_file_fsref(ref);
      if (machine->file == NULL)
	zmachine_fatal("Unable to open story file");      
    }
  else
#endif
    {
      machine->story_length = size = get_file_size(filename);
      machine->story_offset = 0;
      if (size < 0)
	zmachine_fatal("Unable to open story file");
      if (size < 64)
	zmachine_fatal("Story file is way too small (%i bytes)", size);
      
      machine->file = open_file(filename);
      if (machine->file == NULL)
	zmachine_fatal("Unable to open story file");
    }

  zmachine_load_file(machine->file, machine);
}

#if WINDOW_SYSTEM==1 || WINDOW_SYSTEM==2 || WINDOW_SYSTEM==3
void zmachine_fatal(const char* format, ...)
{
  va_list  ap;
  char     string[256];

  va_start(ap, format);
  vsnprintf(string, 256, format, ap);
  string[255] = 0;
  va_end(ap);

#if WINDOW_SYSTEM != 3
  if (machine.display_active)
    {
      machine.display_active = 0;

      display_sanitise();

      display_set_style(0);
      display_set_style(2);
      display_set_colour(7, 0);
      display_prints_c("\n\n");
      display_set_colour(3, 1);
      display_printf("INTERPRETER PANIC: %s", string);
#ifdef GLOBAL_PC
      display_printf(" (PC = #%x)", machine.zpc);
#endif
      display_set_colour(7, 0);
      display_set_style(0);
      display_prints_c("\n\n[Press any key to exit]\n");
      display_readchar(0);

      display_exit(1);
    }
  else
#endif
    {
#if WINDOW_SYSTEM == 2
      char erm[512];

# ifdef GLOBAL_PC
      sprintf(erm, "INTERPRETER PANIC - %s (PC = #%x)", string, machine.zpc);
# else
      sprintf(erm, "INTERPRETER PANIC - %s", string);
# endif
      MessageBox(NULL, erm, "Zoom " VERSION " - fatal error",
		 MB_OK|MB_ICONSTOP|MB_TASKMODAL);
      display_exit(1);
#elif WINDOW_SYSTEM == 3
      Str255 erm;
      Str255 title;
      SInt16 item;

      title[0] = strlen("Zoom " VERSION " - fatal error");
      strcpy(title+1, "Zoom " VERSION " - fatal error");
      sprintf(erm + 1, "(PC = #%x) %s", machine.zpc, string);
      erm[0] = strlen(erm+1);
      if (window_available == 0)
	{
	  AlertStdAlertParamRec par;

	  par.movable = false;
	  par.helpButton = false;
	  par.filterProc = nil;
	  par.defaultText = "\004Quit";
	  par.cancelText = nil;
	  par.otherText = nil;
	  par.defaultButton = kAlertStdAlertOKButton;
	  par.cancelButton = 0;
	  par.position = 0;

	  StandardAlert(kAlertStopAlert, title, erm, &par, &item);
  
	  display_exit(1);
	}
      else
	{
	  AlertStdCFStringAlertParamRec par;
	  OSStatus res;

	  par.version       = kStdCFStringAlertVersionOne;
	  par.movable       = false;
	  par.helpButton    = false;
	  par.defaultText   = CFSTR("Quit");
	  par.cancelText    = nil;
	  par.otherText     = nil;
	  par.defaultButton = kAlertStdAlertOKButton;
	  par.cancelButton  = 0;
	  par.position      = kWindowDefaultPosition;
	  par.flags         = 0;
	  
	  res = CreateStandardSheet(kAlertStopAlert, 
				    CFStringCreateWithPascalString(NULL, title, kCFStringEncodingMacRoman),
				    CFStringCreateWithPascalString(NULL, erm, kCFStringEncodingMacRoman),
				    &par,
				    GetWindowEventTarget(zoomWindow),
				    &fataldlog);
	  if (res == noErr)
	    ShowSheetWindow(GetDialogWindow(fataldlog), zoomWindow);
	  else
	    {
	      StandardAlert(kAlertStopAlert, title, erm, NULL, &item);
	      display_exit(1);
	    }
	}
#else
      fprintf(stderr, "\nINTERPRETER PANIC - %s", string);
#ifdef GLOBAL_PC
      fprintf(stderr, " (PC = #%x)\n\n", machine.zpc);
#endif
      display_exit(1);
#endif
    }
}

void zmachine_warning(const char* format, ...)
{
	va_list  ap;
	char     string[256];
	
	if (machine.warning_level == 0)
		return;
	
	va_start(ap, format);
	vsprintf(string, format, ap);
	va_end(ap);
	
	if (machine.warning_level == 2)
		zmachine_fatal("WARNING - %s", string);
	
	if (machine.display_active)
    {
		display_printf("[ WARNING - %s", string);
#ifdef GLOBAL_PC
		display_printf(" (PC = #%x)", machine.zpc);
#endif
		display_prints_c(" ]\n");
    }
	else
    {
#if WINDOW_SYSTEM == 2
		char erm[512];
		
# ifdef GLOBAL_PC
		sprintf(erm, "%s (PC = #%x)", string, machine.zpc);
# else
		sprintf(erm, "%s", string);
# endif
		MessageBox(NULL, erm, "Zoom " VERSION " - warning",
				   MB_OK|MB_ICONWARNING|MB_TASKMODAL);
#elif WINDOW_SYSTEM == 3
		Str255 erm;
		Str255 title;
		DialogItemIndex item;
		AlertStdAlertParamRec par;
		
		ResetAlertStage();
		
		par.movable = false;
		par.helpButton = false;
		par.filterProc = nil;
		par.defaultText = "\010Continue";
		par.cancelText = nil;
		par.otherText = nil;
		par.defaultButton = kAlertStdAlertOKButton;
		par.cancelButton = 0;
		par.position = 0;
		
		title[0] = strlen("Zoom " VERSION " - warning");
		strcpy(title+1, "Zoom " VERSION " - warning");
		sprintf(erm + 1, "(PC = #%x) %s", machine.zpc, string);
		erm[0] = strlen(erm+1);
		
		StandardAlert(kAlertCautionAlert, title, erm, &par, &item);
#else
		fprintf(stderr, "[ WARNING - %s", string);
# ifdef GLOBAL_PC
		fprintf(stderr, " (PC = #%x)", machine.zpc);
# endif
		fprintf(stderr, " ]\n");
#endif
    }
#ifdef DEBUG
	fprintf(stderr, "\nWARNING - %s", string);
#ifdef GLOBAL_PC
	fprintf(stderr, " (PC = #%x)", machine.zpc);
#endif
	fprintf(stderr, "\n\n");
#endif
}
#endif

void zmachine_info(const char* format, ...)
{
  va_list  ap;
  char     string[256];

  va_start(ap, format);
  vsprintf(string, format, ap);
  va_end(ap);

#if WINDOW_SYSTEM != 3
  if (machine.display_active)
    {
      machine.display_active = 0;

      display_sanitise();

      display_set_style(0);
      display_set_style(2);
      display_set_colour(7, 0);
      display_prints_c("\n\n");
      display_set_colour(3, 1);
      display_printf("[ NOTE: %s", string);
#ifdef GLOBAL_PC
      display_printf(" (PC = #%x) ]", machine.zpc);
#endif
      display_set_colour(7, 0);
      display_set_style(0);
      display_prints_c("\n");
    }
  else
#endif
    {
#if WINDOW_SYSTEM == 2
      char erm[512];

# ifdef GLOBAL_PC
      sprintf(erm, "INTERPRETER NOTE - %s (PC = #%x)", string, machine.zpc);
# else
      sprintf(erm, "INTERPRETER NOTE - %s", string);
# endif
      MessageBox(NULL, erm, "Zoom " VERSION " - fatal error",
		 MB_OK|MB_ICONSTOP|MB_TASKMODAL);
#elif WINDOW_SYSTEM == 3
      Str255 erm;
      Str255 title;
      SInt16 item;

      title[0] = strlen("Zoom " VERSION " - note");
      strcpy(title+1, "Zoom " VERSION " - note");
      sprintf(erm + 1, "(PC = #%x) %s", machine.zpc, string);
      erm[0] = strlen(erm+1);
      if (window_available == 0)
	{
	  AlertStdAlertParamRec par;

	  par.movable = false;
	  par.helpButton = false;
	  par.filterProc = nil;
	  par.defaultText = "\010Continue";
	  par.cancelText = nil;
	  par.otherText = nil;
	  par.defaultButton = kAlertStdAlertOKButton;
	  par.cancelButton = 0;
	  par.position = 0;

	  StandardAlert(kAlertStopAlert, title, erm, &par, &item);
	}
      else
	{
	  AlertStdCFStringAlertParamRec par;
	  OSStatus res;

	  par.version       = kStdCFStringAlertVersionOne;
	  par.movable       = false;
	  par.helpButton    = false;
	  par.defaultText   = CFSTR("OK");
	  par.cancelText    = nil;
	  par.otherText     = nil;
	  par.defaultButton = kAlertStdAlertOKButton;
	  par.cancelButton  = 0;
	  par.position      = kWindowDefaultPosition;
	  par.flags         = 0;
	  
	  res = CreateStandardSheet(kAlertStopAlert, 
				    CFStringCreateWithPascalString(NULL, title, kCFStringEncodingMacRoman),
				    CFStringCreateWithPascalString(NULL, erm, kCFStringEncodingMacRoman),
				    &par,
				    GetWindowEventTarget(zoomWindow),
				    &fataldlog);
	  if (res == noErr)
	    ShowSheetWindow(GetDialogWindow(fataldlog), zoomWindow);
	  else
	    {
	      StandardAlert(kAlertStopAlert, title, erm, NULL, &item);
	    }
	}
#else
      fprintf(stderr, "[ %s", string);
#ifdef GLOBAL_PC
      fprintf(stderr, " (PC = #%x) ]\n", machine.zpc);
#endif
#endif
    }
}

#define Flag(p, f, v) machine.memory[p] = \
    (v)?machine.memory[p]|(1<<(f)): \
    machine.memory[p]&~(1<<(f))

#define FlagE(p, f, v) machine.heb[p] = \
    (v)?machine.heb[p]|(1<<(f)): \
    machine.heb[p]&~(1<<(f))

void zmachine_setup_header(void)
{
  machine.dinfo = display_get_info();

  if (machine.memory[0]<5 || (Word(ZH_flags2)&8) == 0)
    {
      if (machine.graphical)
	zmachine_warning("Graphics turned off");
      machine.graphical = 0;
    }
  
  switch (machine.memory[0])
    {
    case 6:
      zscii_install_alphabet();

      Flag(1, 0, machine.dinfo->colours);
      machine.memory[ZH_width] = machine.dinfo->width>>8;
      machine.memory[ZH_width+1] = machine.dinfo->width;
      machine.memory[ZH_height] = machine.dinfo->height>>8;
      machine.memory[ZH_height+1] = machine.dinfo->height;
      /* Note that these are backwards in v6 :-) */
      machine.memory[ZH_fontwidth] = machine.dinfo->font_height;
      machine.memory[ZH_fontheight] = machine.dinfo->font_width;

      Flag(1, 2, machine.dinfo->boldface);
      Flag(1, 3, machine.dinfo->italic);
      Flag(1, 4, machine.dinfo->fixed_space);
      Flag(1, 4, machine.dinfo->timed_input);
      Flag(1, 5, 0);
      Flag(1, 5, machine.dinfo->pictures);

      machine.memory[ZH_intnumber] = 1;
      machine.memory[ZH_intvers] = 1;
      machine.memory[ZH_lines] = machine.dinfo->lines;
      machine.memory[ZH_columns] = machine.dinfo->columns;

      machine.memory[ZH_intnumber] = rc_get_interpreter();
      machine.memory[ZH_intvers] = rc_get_revision();

      if (machine.blorb == NULL)
	Flag(ZH_flags2+1, 3, 0);

#ifdef SPEC_11
      if (machine.heblen >= 10)
	{
	  FlagE(ZHEB_flags3+1, 2, 1);
	}

      if (machine.heblen >= 4)
	{
	  FlagE(ZHEB_flags3+1, 0, 0);
	  FlagE(ZHEB_flags3+1, 1, 0);

	  machine.heb[ZHEB_flags3] = 0;
	  machine.heb[ZHEB_flags3] &= ~ 0x7;
	}

      if (machine.heblen >= 5)
	{
	  machine.heb[ZHEB_truefore] = machine.dinfo->fore_true>>8;
	  machine.heb[ZHEB_truefore] = machine.dinfo->fore_true;
	}

      if (machine.heblen >= 6)
	{
	  machine.heb[ZHEB_trueback] = machine.dinfo->back_true>>8;
	  machine.heb[ZHEB_trueback] = machine.dinfo->back_true;
	}
#endif
      break;
      
    case 8:
    case 7:
    case 5:
      zscii_install_alphabet();

      Flag(1, 0, machine.dinfo->colours);
      machine.memory[ZH_deffore]    = machine.dinfo->fore+2;
      machine.memory[ZH_defback]    = machine.dinfo->back+2;

      if (machine.memory[0] != 6)
	{
	  if (!machine.graphical)
	    {
	      machine.memory[ZH_width]      = machine.dinfo->columns>>8;
	      machine.memory[ZH_width+1]    = machine.dinfo->columns;
	      machine.memory[ZH_height]     = machine.dinfo->lines>>8;
	      machine.memory[ZH_height+1]   = machine.dinfo->lines;
	      machine.memory[ZH_fontwidth]  = 1;
	      machine.memory[ZH_fontheight] = 1;
	      
	      Flag(ZH_flags2+1, 3, 0);
	    }
	  else
	    {
	      machine.memory[ZH_width]      = machine.dinfo->width>>8;
	      machine.memory[ZH_width+1]    = machine.dinfo->width;
	      machine.memory[ZH_height]     = machine.dinfo->height>>8;
	      machine.memory[ZH_height+1]   = machine.dinfo->height;
	      machine.memory[ZH_fontwidth]  = machine.dinfo->font_width;
	      machine.memory[ZH_fontheight] = machine.dinfo->font_height;
	    }
	}

      if (Word(ZH_flags2)&(1<<5))
	Flag(ZH_flags2+1, 5, machine.dinfo->mouse);
      if (Word(ZH_flags2)&(1<<6))
	Flag(ZH_flags2+1, 6, machine.dinfo->colours);
      if (Word(ZH_flags2)&(1<<7))
	Flag(ZH_flags2+1, 7, machine.dinfo->sound_effects);

#ifdef SPEC_11
      if (machine.heblen >= 4)
	{
	  FlagE(ZHEB_flags3+1, 0, 0);
	  FlagE(ZHEB_flags3+1, 1, 0);

	  machine.heb[ZHEB_flags3] = 0;
	  machine.heb[ZHEB_flags3] &= ~ 0x7;
	}

      if (machine.heblen >= 5)
	{
	  machine.heb[ZHEB_truefore] = machine.dinfo->fore_true>>8;
	  machine.heb[ZHEB_truefore] = machine.dinfo->fore_true;
	}

      if (machine.heblen >= 6)
	{
	  machine.heb[ZHEB_trueback] = machine.dinfo->back_true>>8;
	  machine.heb[ZHEB_trueback] = machine.dinfo->back_true;
	}
#endif

    case 4:
      Flag(1, 2, machine.dinfo->boldface);
      Flag(1, 3, machine.dinfo->italic);
      Flag(1, 4, machine.dinfo->fixed_space);
      Flag(1, 7, machine.dinfo->timed_input);

      machine.memory[ZH_lines]     = machine.dinfo->lines;
      machine.memory[ZH_columns]   = machine.dinfo->columns;

      machine.memory[ZH_intnumber] = rc_get_interpreter();
      machine.memory[ZH_intvers]   = rc_get_revision();
      break;

    case 3:
      Flag(1, 4, !machine.dinfo->status_line);
      Flag(1, 5, machine.dinfo->can_split);
      Flag(1, 6, machine.dinfo->variable_font);
      break;
    }

  /*
   * Spec 1.0 doesn't let us use graphical mode for v5 games, so if
   * it's on, we're not conformant. (This is daft because the checks
   * already made mean that no game malfunctions with this mode on)
   */
#ifdef SPEC_10
# ifdef SAFE
  if (!machine.graphical)
    {
# endif
      machine.memory[0x32] = 1;
# ifdef SPEC_11
      machine.memory[0x33] = 1;
# else
      machine.memory[0x33] = 0;
# endif
# ifdef SAFE
    }
  else
    {
      zmachine_warning("Graphics mode on - not indicating conformance to specification v1.0");
    }
# endif
#endif
}

void zmachine_resize_display(ZDisplay* dis)
{
  machine.dinfo = dis;

  if (machine.memory == NULL)
    return;
  
  switch (machine.memory[0])
    {
    case 6:
      Flag(1, 0, machine.dinfo->colours);
      machine.memory[ZH_width] = machine.dinfo->width>>8;
      machine.memory[ZH_width+1] = machine.dinfo->width;
      machine.memory[ZH_height] = machine.dinfo->height>>8;
      machine.memory[ZH_height+1] = machine.dinfo->height;
      /* Note that these are backwards in v6 :-) */
      machine.memory[ZH_fontwidth] = machine.dinfo->font_height;
      machine.memory[ZH_fontheight] = machine.dinfo->font_width;

      machine.memory[ZH_lines] = machine.dinfo->lines;
      machine.memory[ZH_columns] = machine.dinfo->columns;
      break;
      
    case 8:
    case 7:
    case 5:
      if (!machine.graphical)
	{
	  machine.memory[ZH_width]      = machine.dinfo->columns>>8;
	  machine.memory[ZH_width+1]    = machine.dinfo->columns;
	  machine.memory[ZH_height]     = machine.dinfo->lines>>8;
	  machine.memory[ZH_height+1]   = machine.dinfo->lines;
	  machine.memory[ZH_fontwidth]  = 1;
	  machine.memory[ZH_fontheight] = 1;

	  Flag(ZH_flags2+1, 3, 0);
	}
      else
	{
	  machine.memory[ZH_width]      = machine.dinfo->width>>8;
	  machine.memory[ZH_width+1]    = machine.dinfo->width;
	  machine.memory[ZH_height]     = machine.dinfo->height>>8;
	  machine.memory[ZH_height+1]   = machine.dinfo->height;
	  machine.memory[ZH_fontwidth]  = machine.dinfo->font_width;
	  machine.memory[ZH_fontheight] = machine.dinfo->font_height;
	}
    case 4:
      machine.memory[ZH_lines]     = machine.dinfo->lines;
      machine.memory[ZH_columns]   = machine.dinfo->columns;
      break;
    }
}

void zmachine_mark_statusbar(void)
{
  if (machine.memory[0] == 6)
    {
      Flag(ZH_flags2+1, 2, 1);
    }
}

char* zmachine_get_serial(void)
{
  static char serial[7];
  ZByte* addr;
  int x;

  addr = Address(ZH_serial);

  for (x=0; x<6; x++)
    {
      if (addr[x] >= '0' && addr[x] <= '9')
	{
	  serial[x] = addr[x];
	}
      else
	{
	  serial[x] = 'A' + addr[x] % 26;
	}
    }

  serial[6] = 0;

  return serial;
}

void zmachine_dump_stack(ZStack* stack) {
  int x;
  ZWord* sp;
  ZFrame* frame;
  
  /* This implements a request by Graham to dump the stack for debugging purposes */
  display_printf("== Zoom debug: beginning stack dump\n");
  
  display_printf("Stack total size: %i words\n", stack->stack_total);
  display_printf("Current stack usage: %i words\n", stack->stack_total-stack->stack_size);
  display_printf("\nValues pushed to stack: (top) ");

  sp = stack->stack_top;
  for (x=stack->stack_size; x<stack->stack_total; x++) {
    display_printf("0x%04x ", (ZUWord)*(--sp));
  }
  display_printf("(bottom)\n\nStack frames:\n");
  
  for (frame=stack->current_frame; frame != NULL; frame=frame->last_frame) {
    display_printf("  Return address: 0x%08x. Frame stack size: %i. Number of locals: %i.\n",
		   frame->ret, frame->frame_size, frame->nlocals);
  }
  
  display_printf("== Dump finished\n");
}

#ifdef DEBUG
ZWord debug_print_var(ZWord val, int var)
{
  printf_debug("Read variable #%x (value %i)\n", var, val);
  return val;
}
#endif
