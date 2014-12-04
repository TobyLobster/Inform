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

#ifndef __RC_H
#define __RC_H

#include "hash.h"

typedef struct
{
  int r, g, b;
} rc_colour;

typedef struct
{
  char* name;
  int   attributes[8];
  int   n_attr;
  int   num;
} rc_font;

typedef struct
{
  int interpreter;
  int revision;

  char* name;

  rc_font* fonts;
  int      n_fonts;

  rc_colour* colours;
  int        n_colours;
  char*      gamedir;
  char*      savedir;
  char*      sounds;
  char*      graphics;

  int xsize, ysize;
  
  int fg_col, bg_col;

  int antialias;
} rc_game;

extern void       rc_load           (void);
extern void       rc_merge          (char* filename);
extern void       rc_set_game       (char* serial, int revision, int checksum);
extern rc_colour* rc_get_colours    (int* n_cols);
extern rc_font*   rc_get_fonts      (int* n_fonts);
extern char*      rc_get_name       (void);
extern char*      rc_get_game_name  (char* serial, int revision);
extern int        rc_get_interpreter(void);
extern int        rc_get_antialias  (void);
extern int        rc_get_revision   (void);
extern char*      rc_get_gamedir    (void);
extern char*      rc_get_savedir    (void);
extern int        rc_get_xsize      (void);
extern int        rc_get_ysize      (void);
extern char*      rc_get_graphics   (void);
extern char*      rc_get_sounds     (void);
extern int        rc_get_foreground (void);
extern int        rc_get_background (void);

extern hash       rc_hash;
extern rc_game*   rc_defgame;
extern int        rc_merging;

#endif
