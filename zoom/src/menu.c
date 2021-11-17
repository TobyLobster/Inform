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
 * Some functions to do with menus
 */

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <sys/types.h>
#include <dirent.h>
#ifdef HAVE_UNISTD_H
# include <unistd.h>
#endif
#include <string.h>

#include "zmachine.h"
#include "menu.h"
#include "display.h"
#include "rc.h"
#include "file.h"

#if WINDOW_SYSTEM != 2

static void center(char* text, int columns)
{
  display_set_cursor((int)((columns>>1)-(strlen(text)>>1)), display_get_cur_y());
  display_prints_c(text);
}

struct game_struct {
  char* filename;
  char* storyname;
};

static int game_compare(const void* a, const void* b)
{
  const struct game_struct *ga, *gb;

  ga = a; gb = b;

  return strcmp(ga->storyname, gb->storyname);
}

char* menu_get_story(void)
{
  char*     dirname;
  DIR*      gamedir;
  ZDisplay* di;
  int       n_games = 0;
  int       x;
  struct game_struct* game = NULL;
  struct dirent* dent;
  int       selection, start, end, height;
  char      format[10];
  int       read;
  
  di = display_get_info();

  display_set_window(0);
  display_split(di->height, 1);
  display_set_window(1);
  display_set_colour(7, 4);
  display_erase_window();

  rc_set_game("xxxxxx", 65535, 65535);

  dirname = rc_get_gamedir();
  gamedir = opendir(dirname);

  if (gamedir == NULL)
    zmachine_fatal("Unable to find game directory '%s'", dirname);

  chdir(dirname);
  
  /* Read the files in this directory, and work out their names */
  while ((dent=readdir(gamedir)))
    {
      size_t len;

      len = strlen(dent->d_name);
      
      if (len > 2)
	{
	  if (dent->d_name[len-2] == 'z' && dent->d_name[len-3]=='.')
	    {
	      ZFile* file;

	      file = open_file(dent->d_name);
	      
	      if (file)
		{
		  size_t x,len;
		  ZByte* header;

		  header = read_block(file, 0, 64);
		  
		  game =
		    realloc(game, sizeof(struct game_struct)*(n_games+1));
		  game[n_games].filename =
		    malloc(sizeof(char)*(strlen(dent->d_name)+1));
		  strcpy(game[n_games].filename, dent->d_name);
		  
		  game[n_games].storyname =
		    rc_get_game_name((char*)(header + ZH_serial),
				     GetWord(header, ZH_release));

		  if (game[n_games].storyname == NULL)
		    {
		      len = strlen(game[n_games].filename);
		      
		      game[n_games].storyname = malloc(len+1);
		      for (x=0; x<len-3; x++)
			{
			  game[n_games].storyname[x] =
			    game[n_games].filename[x];
			}
		      game[n_games].storyname[x] = 0;
		    }

		  free(header);
		  
		  n_games++;

		  close_file(file);
		}
	    }
	}
    }

  closedir(gamedir);

  qsort(game, n_games, sizeof(struct game_struct), game_compare);

  selection = 0;
  height = (di->lines-6)&~1;
  sprintf(format, " %%.%is ", di->columns-6);

  if (n_games < 1)
    zmachine_fatal("No game file available in %s", dirname);
  
  do
    {
      start = selection - (height>>1);
      end = selection + (height>>1);

      display_erase_window();
      display_set_cursor(0,1);
      display_set_font(3);
      center("Zoom " VERSION " Menu of games", di->columns);
      display_set_cursor(0,di->lines-2);
      center("Use the UP and DOWN arrow keys to select a game", di->columns);
      display_set_cursor(0,di->lines-1);
      center("Press RETURN to load the selected game", di->columns);
    
      if (start < 0)
	{
	  end -= start;
	  start = 0;
	}
      if (end > n_games)
	{
	  end = n_games;
	  start = end - height;
	  if (start < 0)
	    start = 0;
	}
      
      for (x=0; x<(end-start); x++)
	{
	  display_set_cursor(2, 3+x);
	  display_set_cursor(2, 3+x);
	  display_printf(format, game[x+start].storyname);
	}
      display_set_cursor(2, 3+(selection-start));
      display_set_colour(0, 3);
      display_printf(format, game[selection].storyname);
      display_set_colour(7, 4);
  
      read = display_readchar(0);

      switch (read)
	{
	case 'Q':
	case 'q':
	  display_exit(1);
	  
	case 129:
	  selection--;
	  if (selection<0)
	    selection = 0;
	  break;
	  
	case 130:
	  selection++;
	  if (selection>=n_games)
	    selection = n_games-1;
	  break;
	}
    }
  while (read != 13 && read != 10);
  
  return game[selection].filename;
}

#else

#include <windows.h>
#include <commdlg.h>
#include "windisplay.h"

char* menu_get_story(void)
{
  OPENFILENAME fn;
  static char filter[] = "Z-Code files (*.z[34578])\0*.z3;*.z4;*.z5;*.z7;*.z8\0All files (*.*)\0*.*\0\0";
  static char fname[256];

  if (rc_get_gamedir() == NULL)
    zmachine_fatal("No default game directory set");

  strcpy(fname, "");
  fn.lStructSize       = sizeof(fn);
  fn.hwndOwner         = mainwin;
  fn.hInstance         = NULL;
  fn.lpstrFilter       = filter;
  fn.lpstrCustomFilter = NULL;
  fn.nFilterIndex      = 1;
  fn.lpstrFile         = fname;
  fn.nMaxFile          = 256;
  fn.lpstrFileTitle    = NULL;
  fn.lpstrInitialDir   = rc_get_gamedir();
  fn.lpstrTitle        = NULL;
  fn.nFileOffset       = 0;
  fn.nFileExtension    = 0;
  fn.Flags             = OFN_HIDEREADONLY|OFN_FILEMUSTEXIST;
  fn.lpstrDefExt       = "qut";

  if (GetOpenFileName(&fn))
    {
      return fname;
    }
  else
    {
      zmachine_fatal("Unable to open story file");
    }
  
  return NULL;
}

#endif
