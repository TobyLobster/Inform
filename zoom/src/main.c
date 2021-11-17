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
 * Time to get this show on the road
 */

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#ifdef HAVE_SYS_TIME_H
# include <sys/time.h>
#endif
#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif

#include "zmachine.h"
#include "file.h"
#include "options.h"
#include "interp.h"
#include "rc.h"
#include "stream.h"
#include "menu.h"
#include "random.h"
#include "debug.h"

#include "display.h"
#include "v6display.h"

#if WINDOW_SYSTEM == 3
#include <Carbon/Carbon.h>
#include "carbondisplay.h"
#endif

ZMachine machine;
extern char save_fname[256];
extern char script_fname[256];

int zoom_main(int argc, char** argv)
{
  arguments args;
#ifdef HAVE_GETTIMEOFDAY
  struct timeval tv;
#endif

  machine.display_active = 0;
  
  /* Seed RNG */
#ifdef HAVE_GETTIMEOFDAY
  gettimeofday(&tv, NULL);
  random_seed((ZDWord)(tv.tv_sec^tv.tv_usec));
#else
  random_seed((unsigned int)time(NULL));
#endif

#if WINDOW_SYSTEM != 3
  get_options(argc, argv, &args);
#else
  args.story_file = NULL;
  args.save_file = NULL;
  args.warning_level = 0;
  if (carbon_prefs.show_warnings)
    {
      args.warning_level = 1;
      if (carbon_prefs.fatal_warnings)
	args.warning_level = 2;
    }
  args.track_attr = args.track_objs = args.track_props = args.graphical = 0;
#endif
  machine.warning_level = args.warning_level;

#ifdef TRACKING
  machine.track_objects = args.track_objs;
  machine.track_attributes = args.track_attr;
  machine.track_properties = args.track_props;
#endif

  rc_load();
#if WINDOW_SYSTEM == 3
  carbon_merge_rc();
#endif

#if WINDOW_SYSTEM != 3  
  if (args.story_file == NULL)
    {
      rc_set_game("xxxxxx", 65535, 65535);
      display_initialise();
      args.story_file = menu_get_story();
      zmachine_load_story(args.story_file, &machine);
      rc_set_game(zmachine_get_serial(), Word(ZH_release), Word(ZH_checksum));
      display_reinitialise();
    }
  else
    {
      zmachine_load_story(args.story_file, &machine);
      rc_set_game(zmachine_get_serial(), Word(ZH_release), Word(ZH_checksum));
      display_initialise();
    }
#else
  {
    static char path[256];

    zmachine_load_story(NULL, &machine);
    FSRefMakePath(lastopenfs, path, 256);
    args.story_file = path;
    rc_set_game(zmachine_get_serial(), Word(ZH_release), Word(ZH_checksum));
    display_initialise();
  }
#endif

  {
    char  title[256];
    char* name;
    long x, len, slashpos;

    len = strlen(args.story_file);

    machine.story_file = args.story_file;

    slashpos = -1;
    name = malloc(len+1);
    for (x=0; x<len; x++)
      {
#if WINDOW_SYSTEM != 2
	if (args.story_file[x] == '/')
	  slashpos = x;
#else
	if (args.story_file[x] == '\\')
	  slashpos = x;
#endif
      }

    for (x=slashpos+1;
	 args.story_file[x] != 0 && args.story_file[x] != '.';
	 x++)
      {
	name[x-slashpos-1] = args.story_file[x];
      }
    name[x-slashpos-1] = 0;

    if (rc_get_graphics() != NULL)
      {
	ZFile* res;

	res = open_file(rc_get_graphics());
	
	if (res != NULL && blorb_is_blorbfile(res))
	  {
	    machine.blorb_file = res;
	    machine.blorb = blorb_loadfile(machine.blorb_file);
	  }
	else
	  {
	    zmachine_warning("Resource file is not a blorb file (ignored)");
	    close_file(res);
	  }
      }

    if (machine.blorb == NULL)
      {
	char* file;

	/*
	 * Try to load a suitable blorb file...
	 */
	file = malloc(strlen(args.story_file)+6);
	strcpy(file, args.story_file);

	for (x=strlen(file)-1; x>=0 && file[x] != '.'; x--);
	if (x < 0)
	  x = strlen(file);
	
	file[x] = 0;
	strcat(file, ".blb");

	if (get_file_size(file) > 64)
	  {
	    ZFile* bf;

	    bf = open_file(file);

	    if (bf != NULL && blorb_is_blorbfile(bf))
	      {
		BlorbFile* blb;

		blb = blorb_loadfile(bf);

		if (blb->game_id == NULL)
		  zmachine_warning("Game appears to have resources, but there is no ID chunk: assuming that the resources are correct");

		/* We only auto-load for files that actually match versions */
		if (blb->game_id != NULL &&
		    ((ZUWord)Word(ZH_release) != blb->game_id->release ||
		     (ZUWord)Word(ZH_checksum) != blb->game_id->checksum ||
		     memcmp(Address(ZH_serial), blb->game_id->serial, 6) != 0))
		  {
		    blorb_closefile(blb);
		    close_file(bf);

		    zmachine_warning("Game appears to have resources, but their ID does not match the game: these resources will not be loaded. Set the resources explicitly to override this behaviour");
		  }
		else
		  {
		    machine.blorb = blb;
		    machine.blorb_file = bf;
		  }
	      }
	  }

	free(file);
      }

    sprintf(title, rc_get_name(),
	    name,
	    Word(ZH_release),
	    zmachine_get_serial(),
	    (unsigned)Word(ZH_checksum));
    display_set_title(title);

    sprintf(save_fname, "%s.qut", name);
    sprintf(script_fname, "%s.txt", name);
  }
  
#ifdef DEBUG
  {
    int x;

    display_prints_c("\nFont 3: ");
    display_set_style(16);
    for (x=32; x<128; x++)
      display_printf("%c", x);
    display_set_style(0);
  }
#endif
  
  display_set_style(2);
#ifdef CUTE_STARTUP
  display_prints_c("\n\nMaze\n");
  display_set_style(0);
  display_prints_c("You are in a maze of twisty little software licences, all different.\nA warranty lurks in a corner.\n\n>read warranty\n");
  display_prints_c("WELCOME, adventurer, to ");
#endif
  display_set_style(6);
  display_prints_c("Zoom " VERSION);
  display_set_style(-4);
  display_prints_c(" Copyright (c) Andrew Hunter, 2000-2004\n");
  display_set_style(0);
  
  display_prints_c("This program is free software; you can redistribute and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.\n\n");
  display_prints_c("This program is distributed in the hope that it will be useful, but ");
  display_set_style(2);
  display_prints_c("WITHOUT ANY WARRANTY");
  display_set_style(0);
  display_prints_c("; without even the implied warranty of ");
  display_set_style(2);
  display_prints_c("MERCHANTABILITY");
  display_set_style(0);
  display_prints_c(" or ");
  display_set_style(2);
  display_prints_c("FITNESS FOR A PARTICULAR PURPOSE");
  display_set_style(0);
  display_prints_c(". See the GNU Lesser General Public Licence for more details.\n\n");
  display_prints_c("You should have received a copy of the GNU Lesser General Public License along with this program. If not, write to the Free Software Foundation, 675 Mass Ave, Cambridge, MA 02139, USA.\n");
  display_prints_c("\nThe Zoom homepage can be located at ");
  display_set_style(4);
  display_prints_c("http://www.logicalshift.co.uk/unix/zoom/");
  display_set_style(0);
  display_prints_c(" - check this page for any updates\n\n\n");
  display_set_colour(0, 6);
  display_prints_c("[ Press any key to begin ]");
  display_set_colour(0, 7);
  display_readchar(0);
  display_set_colour(rc_get_foreground(), rc_get_background());
  display_clear();

  machine.graphical = args.graphical;
  
  machine.display_active = 1;

  if (machine.header[0] >= 5)
    {
      display_set_cursor(0,0);
      
      if (args.debug_mode == 1)
	{
	  char* filename;
	  char* pathname;
	  long x;
	  debug_symbol* start;
	  
	  filename = malloc(strlen(args.story_file) + strlen("gameinfo.dbg") + 1);
	  pathname = malloc(strlen(args.story_file) + 1);
	  strcpy(filename, args.story_file);
	  strcpy(pathname, args.story_file);
	  
	  for (x=strlen(filename)-1; x > 0 && filename[x-1] != '/'; x--);
	  
	  strcpy(filename + x, "gameinfo.dbg");
	  pathname[x] = 0;
	  
	  debug_load_symbols(filename, pathname);
	  
	  start = hash_get(debug_syms.symbol, (unsigned char*)"main", 4);
	  if (start == NULL ||
	      start->type != dbg_routine)
	    {
	      debug_set_breakpoint(GetWord(machine.header, ZH_initpc), 0, 0);
	    }
	  else
	    {
	      debug_routine* routine;
	      
	      routine = debug_syms.routine + start->data.routine;
	      debug_set_breakpoint(routine->start+1, 0, 0);
	    }

	  for (x=0; x<debug_syms.nroutines; x++)
	    {
	      debug_set_breakpoint(debug_syms.routine[x].start+1,
				   0, 1);
	    }
	}
    }

  switch (machine.header[0])
    {
#ifdef SUPPORT_VERSION_3
    case 3:
      display_split(1, 1);

      display_set_colour(rc_get_foreground(), rc_get_background()); display_set_font(0);
      display_set_window(0);
      zmachine_run(3, args.save_file);
      break;
#endif
#ifdef SUPPORT_VERSION_4
    case 4:
      zmachine_run(4, args.save_file);
      break;
#endif
#ifdef SUPPORT_VERSION_5
    case 5:
      zmachine_run(5, args.save_file);
      break;
    case 7:
      zmachine_run(7, args.save_file);
      break;
    case 8:
      zmachine_run(8, args.save_file);
      break;
#endif
#ifdef SUPPORT_VERSION_6
    case 6:
      v6_startup();
      v6_set_cursor(1,1);
      zmachine_run(6, args.save_file);
      break;
#endif

    default:
      zmachine_fatal("Unsupported ZMachine version %i", machine.header[0]);
      break;
    }

  stream_flush_buffer();
  display_prints_c("\n");
  display_set_colour(7, 1);
  display_prints_c("[ Press any key to exit ]");
  display_set_colour(7, 0);
  display_readchar(0);

  display_exit(0);
  
  return 0;
}

