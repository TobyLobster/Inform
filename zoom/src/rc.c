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
 * Deal with the .zoomrc file
 */

#include "../config.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zmachine.h"
#include "rc.h"
#include "rcp.h"
#include "hash.h"

extern FILE* yyin;
extern int   rc_parse(void);
extern int   _rc_line;

hash            rc_hash    = NULL;
static rc_game* game       = NULL;
rc_game*        rc_defgame = NULL;

#ifdef DATADIR
# define ZOOMRC DATADIR "/zoomrc"
# define GAMEDIR DATADIR "/games"
#else
# define ZOOMRC "zoomrc"
# define GAMEDIR NULL
#endif

void rc_error(char* erm)
{
  zmachine_info("Error while parsing .zoomrc (line %i): %s",
		_rc_line, erm);
}

void rc_load(void)
{
  char* home;
  char* filename;
  int domerge = 1;

  if (rc_hash == NULL)
    rc_hash = hash_create();

  rc_merging = 0;

#if WINDOW_SYSTEM != 2
  home = getenv("HOME");
  if (home==NULL)
    {
      filename = "zoomrc";
    }
  else
    {
      filename = malloc(strlen(home)+9);
      strcpy(filename, home);
      strcat(filename, "/.zoomrc");
    }

  yyin = fopen(filename, "r");
  
  if (yyin==NULL)
    {
      domerge = 0;

      yyin = fopen(ZOOMRC, "r");
      if (yyin == NULL)
	zmachine_fatal("Unable to open resource file '%s', or the systems default file at " ZOOMRC, filename);
    }
#else
  yyin = fopen("zoomrc", "r");
  if (yyin == NULL)
    zmachine_fatal("Unable to open resource file 'zoomrc'. Make sure that it is in the current directory");
#endif

  _rc_line = 1;
  if (rc_parse() != 0)
    {
      zmachine_fatal("Unable to recover from errors found in '.zoomrc'");
    }
  fclose(yyin);

#if WINDOW_SYSTEM == 1
  if (domerge)
    {
      rc_merge(ZOOMRC);
    }
#endif
}

void rc_merge(char* filename)
{
  if (rc_hash == NULL)
    rc_hash = hash_create();

  rc_merging = 1;
  yyin = fopen(filename, "r");
  if (yyin == NULL)
    {
      zmachine_warning("Unable to open resource file '%s'", filename);
      return;
    }
  _rc_line = 1;
  if (rc_parse() == 1)
    {
      zmachine_info("Zoomrc file '%s' has errors", filename);
    }
  fclose(yyin);
}

void rc_set_game(char* serial, int revision, int checksum)
{
  char hash[40];

  sprintf(hash, "%i.%.6s.%04x", revision, serial, (unsigned)checksum);
  game = hash_get(rc_hash, (unsigned char*)hash, (int)strlen(hash));

  if (game == NULL)
    {
      sprintf(hash, "%i.%.6s", revision, serial);
      game = hash_get(rc_hash, (unsigned char*)hash, (int)strlen(hash));
    }
  if (game == NULL)
    game = hash_get(rc_hash, (unsigned char*)"default", 7);
  if (game == NULL)
    zmachine_fatal("No .zoomrc entry for your game, and no default entry either");
  rc_defgame = hash_get(rc_hash, (unsigned char*)"default", 7);
  if (rc_defgame == NULL)
    zmachine_fatal("No default entry in .zoomrc");
}

char* rc_get_game_name(char* serial, int revision)
{
  char hash[20];
  rc_game* game;

  sprintf(hash, "%i.%.6s", revision, serial);
  game = hash_get(rc_hash, (unsigned char*)hash, (int)strlen(hash));
  if (game == NULL)
    return NULL;
  return game->name;
}

char* rc_get_name(void)
{
  if (game == NULL)
    zmachine_fatal("Programmer is a spoon");

  return game->name;
}

rc_font* rc_get_fonts(int* n_fonts)
{
  rc_font* deffonts;
  int x, y;
  
  if (game == NULL)
    zmachine_fatal("Programmer is a spoon");

  if (game->fonts == NULL)
    {
      *n_fonts = rc_defgame->n_fonts;
      return rc_defgame->fonts;
    }

  deffonts = rc_defgame->fonts;
  for (x=0; x<rc_defgame->n_fonts; x++)
    {
      int found = 0;

      for (y=0; y<game->n_fonts; y++)
	{
	  if (game->fonts[y].num == rc_defgame->fonts[x].num)
	    found = 1;
	}

      if (!found)
	{
	  game->n_fonts++;
	  game->fonts = realloc(game->fonts,
				sizeof(rc_font)*game->n_fonts);
	  game->fonts[game->n_fonts-1] = rc_defgame->fonts[x];
	}
    }
  
  *n_fonts = game->n_fonts;
  return game->fonts;
}

rc_colour* rc_get_colours(int* n_cols)
{
  if (game == NULL)
    zmachine_fatal("Programmer is a spoon");

  if (game->colours == NULL)
    {
      *n_cols = rc_defgame->n_colours;
      return rc_defgame->colours;
    }
  
  *n_cols = game->n_colours;
  return game->colours;  
}

int rc_get_antialias(void)
{
  if (game->antialias == -1)
    return rc_defgame->antialias==-1?1:rc_defgame->antialias;
  return game->antialias;
}

int rc_get_interpreter(void)
{
  if (game->interpreter == -1)
    return rc_defgame->interpreter;
  return game->interpreter;
}

int rc_get_revision(void)
{
  if (game->revision == -1)
    return rc_defgame->revision;
  return game->revision;
}

char* rc_get_gamedir(void)
{
  if (game->gamedir == NULL)
    {
      if (rc_defgame->gamedir == NULL)
	return GAMEDIR;
      return rc_defgame->gamedir;
    }
  return game->gamedir;
}

char* rc_get_savedir(void)
{
  if (game->savedir == NULL)
    {
      if (rc_defgame->savedir == NULL)
	{
#if WINDOW_SYSTEM != 2
	  static char* dir = NULL;

	  if (dir == NULL && machine.story_file != NULL)
	    {
	      ssize_t x;

	      for (x=strlen(machine.story_file)-1;
		   x>0 && machine.story_file[x] != '/'; 
		   x--);

	      if (x != 0)
		{
		  dir = malloc(x+2);
		  strncpy(dir, machine.story_file, x+1);
		  dir[x+1] = 0;
		}
	    }

	  if (dir != NULL)
	    return dir;

	  return "./";
#else
	  return NULL;
#endif
	}
      return rc_defgame->savedir;
    }
  return game->savedir;
}

char* rc_get_graphics(void)
{
  if (game->graphics == NULL)
    return rc_defgame->graphics;
  return game->graphics;
}

char* rc_get_sounds(void)
{
  if (game->sounds == NULL)
    return rc_defgame->sounds;
  return game->sounds;
}

int rc_get_xsize(void)
{
  if (game->xsize == -1)
    {
      if (rc_defgame->xsize == -1)
	return 80;
      return rc_defgame->xsize;
    }
  return game->xsize;
}

int rc_get_ysize(void)
{
  if (game->ysize == -1)
    {
      if (rc_defgame->ysize == -1)
	return 30;
      return rc_defgame->ysize;
    }
  return game->ysize;
}

int rc_get_foreground (void) {
	if (game->fg_col == -1) return 0;
	return game->fg_col;
}

int rc_get_background (void) {
	if (game->bg_col == -1) return 7;
	return game->bg_col;
}
