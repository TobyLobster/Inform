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
 * IFF reading
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zmachine.h"
#include "file.h"
#include "blorb.h"

IffForm* iff_decode_form(ZFile* file)
{
  IffForm* res;
  unsigned char* header;

  header = read_block(file, 0, 12);
  if (header == NULL)
    return NULL;

  if (memcmp(header, "FORM", 4) != 0)
    {
      free(header);
      return NULL; /* Not an IFF file */
    }

  res = malloc(sizeof(IffForm));

  res->id[0] = header[8];  res->id[1] = header[9];
  res->id[2] = header[10]; res->id[3] = header[11];
  res->len = (header[4]<<24)|(header[5]<<16)|(header[6]<<8)|header[7];

  free(header);

  return res;
}

IffChunk* iff_decode_next_chunk(ZFile*          file,
				const IffChunk* lastchunk,
				const IffForm*  form)
{
  int       pos;
  IffChunk* res;
  unsigned char*     header;

  if (lastchunk != NULL)
    {
      pos = lastchunk->offset + lastchunk->length;
      if ((pos&1))
	pos++;
    }
  else
    {
      pos = 12;
    }

  if (form != NULL &&
      pos >= form->len)
    {
      return NULL;
    }

  header = read_block(file, pos, pos+8);
  if (header == NULL)
    {
      return NULL;
    }

  res = malloc(sizeof(IffChunk));
  res->id[0] = header[0]; res->id[1] = header[1]; 
  res->id[2] = header[2]; res->id[3] = header[3];
  res->offset = pos + 8;
  res->length = (header[4]<<24)|(header[5]<<16)|(header[6]<<8)|header[7];

  free(header);

  return res;
}

IffFile* iff_decode_file(ZFile* file)
{
  IffFile* res;
  IffChunk* chunk;

  res = malloc(sizeof(IffFile));
  
  res->form    = iff_decode_form(file);
  res->nchunks = 0;
  res->chunk   = NULL;

  chunk = iff_decode_next_chunk(file, NULL, res->form);
  while (chunk != NULL)
    {
      IffChunk* lastchunk;

      res->chunk = realloc(res->chunk, sizeof(IffChunk)*(res->nchunks+1));
      res->chunk[res->nchunks] = *chunk;
      res->nchunks++;

      lastchunk = chunk;
      chunk = iff_decode_next_chunk(file, lastchunk, res->form);
      free(lastchunk);
    }

  return res;
}
