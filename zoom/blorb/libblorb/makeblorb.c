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
 * Routines for creating a blorb file
 */

#include <stdio.h>
#include <stdlib.h>

#include "libblorb/blorb.h"
#include "blorbint.h"

blorb blorb_create_file(char* file)
{
  blorb newfile;

  newfile = malloc(sizeof(struct blorb));

  newfile->creating = 1;
  newfile->fh       = fopen(file, "w");

  if (!newfile->fh)
    {
      free(newfile);
      return NULL;
    }

  newfile->n_sfx       = 0;
  newfile->sfx_block   = NULL;
  newfile->sfx         = NULL;

  newfile->n_picts     = 0;
  newfile->pict_block  = NULL;
  newfile->pict        = NULL;

  newfile->zcode       = NULL;
  newfile->release_num = 0;
  
  return newfile;
}

void blorb_add_pict(blorb bl, char* file, int num)
{
  
}
