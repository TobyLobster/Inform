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
 * Internal data structures used by libblorb
 */

#ifndef __BLORBINT_H
#define __BLORBINT_H

#include <stdio.h>

#include "libblorb/blorb.h"

struct blorb
{
  int   creating;
  FILE* fh;

  int         n_sfx;      /* Number of sound effects in this file */
  int*        sfx_block;  /* The file offset of the beginning of each sfx */
  blorb_sfx*  sfx;        /* The data for each sfx */

  int         n_picts;    /* Number of pictures in this file */
  int*        pict_block; /* The file offset of the beginning of each pict */
  blorb_pict* pict;       /* The data for each picture */

  char*       zcode;

  int         release_num;
};

#endif
