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
 * Parse options
 */

#include <stdio.h>
#include <stdlib.h>

#include "zmachine.h"
#include "options.h"

#if OPT_TYPE==0

#include <argp.h>

const char* argp_program_version     = "Zoom " VERSION;
const char* argp_program_bug_address = "bugs@logicalshift.co.uk";
static char doc[]      = "Zoom - A Z-Machine";
static char args_doc[] = "[story-file] [save-file]";

static struct argp_option options[] = {
  { "warnings", 'w', 0, 0, "Display interpreter warnings" },
  { "fatal", 'W', 0, 0, "Warnings are fatal" },
  { "debugmode", 'D', 0, 0, "Enable source-level debugger (requires gameinfo.dbg)" },
#ifdef TRACKING
  { "trackobjs", 'O', 0, 0, "Track object movement" },
  { "trackattrs", 'A', 0, 0, "Track attribute testing/setting" },
  { "trackprops", 'P', 0, 0, "Track property reading/writing" },
#endif
  { 0 }
};

static error_t parse_opt(int key, char* arg, struct argp_state* state)
{
  arguments* args = state->input;
  
  switch (key)
    {
    case 'w':
      args->warning_level = 1;
      break;
    case 'W':
      args->warning_level = 2;
      break;

    case 'O':
      args->track_objs = 1;
      break;
    case 'A':
      args->track_attr = 1;
      break;
    case 'P':
      args->track_props = 1;
      break;

    case 'D':
      args->debug_mode = 1;
      break;
 
    case ARGP_KEY_ARG:
      if (state->arg_num >= 2)
	argp_usage(state);

      args->arg[state->arg_num] = arg;
      break;

    case ARGP_KEY_END:
      break;
      
    default:
      return ARGP_ERR_UNKNOWN;
    }

  return 0;
}

static struct argp argp = { options, parse_opt, args_doc, doc };

void get_options(int argc, char** argv, arguments* args)
{
  args->arg[0] = NULL;
  args->arg[1] = NULL;
  args->warning_level = 0;

  args->graphical = 0;
  
  args->track_objs  = 0;
  args->track_attr  = 0;
  args->track_props = 0;

  args->debug_mode  = 0;
   
  argp_parse(&argp, argc, argv, 0, 0, args);

  args->story_file = args->arg[0];
  args->save_file  = args->arg[1];
}

#else
# if OPT_TYPE==1

# include <unistd.h>
/* # include <getopt.h> */

void get_options(int argc, char** argv, arguments* args)
{
  int opt;

  args->warning_level = 0;
  args->graphical = 0;
  args->debug_mode = 0;

  while ((opt=getopt(argc, argv, "?hVWwgD")) != -1)
    {
      switch (opt)
	{
	case '?': /* ? */
	case 'h': /* h */
	  printf_info("Usage: %s [OPTION...] [story-file] [save-file]\n", argv[0]);
	  printf_info("  Where option is one of:\n");
	  printf_info("    -? or -h   display this text\n");
	  printf_info("    -V         display version information\n");
	  printf_info("    -w         display warnings\n");
	  printf_info("    -W         make all warnings fatal (strict standards compliance)\n");
	  printf_info("    -D         enable symbolic debug mode (requires gameinfo.dbg)\n");
	  printf_info("Zoom is copyright (C) Andrew Hunter, 2000\n");
	  printf_info_done();
	  display_exit(0);
	  break;

	case 'V': /* V */
	  printf("Zoom version " VERSION "\n");
	  display_exit(0);
	  break;

	case 'D':
	  args->debug_mode = 1;
	  break;

	case 'W': /* W */
	  args->warning_level = 2;
	  break;

	case 'w': /* w */
	  args->warning_level = 1;
	  break;
	}
    }

  if (optind >= argc || (optind-argc)>2)
    {
      zmachine_fatal("Usage: %s [OPTION...] story-file [save-file]\n",
	     argv[0]);
   }
  
  args->track_objs  = 0;
  args->track_attr  = 0;
  args->track_props = 0;

  args->story_file = argv[optind];

  if ((optind-argc) == 2)
    args->save_file = argv[optind+1];
  else
    args->save_file = NULL;
}

# else

void get_options(int argc, char** argv, arguments* args)
{
  args->warning_level = 0;
  args->graphical = 0;
  args->debug_mode = 0;
  
  args->track_objs  = 0;
  args->track_attr  = 0;
  args->track_props = 0;
  
  if (argc == 1)
    {
      args->story_file = NULL;
      args->save_file  = NULL;      
    }
  else if (argc == 2)
    {
      args->story_file = argv[1];
      args->save_file  = NULL;
    }
  else if (argc == 3)
    {
      args->story_file = argv[1];
      args->save_file  = argv[2];      
    }
  else
    {
      zmachine_fatal("Usage: %s story-file [save-file]\n", argv[0]);
      display_exit(1);
    }
}

# endif
#endif
