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
 * Routines for dealing with blorb
 */

#ifndef __BLORB_H
#define __BLORB_H

#include <stdio.h>

typedef struct blorb* blorb;

typedef struct blorb_sfx
{
  enum
  {
    BLORB_AIFF,
    BLORB_MOD,
    BLORB_SONG
  } type;

  int data_loaded;
  void* data;
} *blorb_sfx;

typedef struct blorb_pict
{
  enum
  {
    BLORB_PNG
  } type;

  int xsize, ysize;

  int data_loaded;
  void* data;
} *blorb_pict;

/*
 * Blorb file operations
 */
extern blorb blorb_open_file  (char* file);
extern void  blorb_close_file (blorb);

/*
 * Functions to get information about the resources in the file
 */
extern int   blorb_n_picts   (blorb);
extern int   blorb_n_sfxs    (blorb);
extern int   blorb_has_code  (blorb);
extern int   blorb_get_pict_x(blorb, int);
extern int   blorb_get_pict_y(blorb, int);

/*
 * Functions to read the contents of resources
 */
extern char*       blorb_get_zcode(blorb);
extern blorb_sfx*  blorb_get_sfx  (blorb, int);
extern blorb_pict* blorb_get_pict (blorb, int);

/*
 * Functions to free memory used by a loaded resource
 */
extern void  blorb_free_pict(blorb, int);
extern void  blorb_free_sfx (blorb, int);

#endif
