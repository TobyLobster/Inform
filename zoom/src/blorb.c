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
 * Blorb file reading
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "zmachine.h"
#include "file.h"
#include "blorb.h"

#include "image.h"

#define MAX_IMAGES 32

static inline int cmp_token(const char* data, const char* token)
{
  if (*((ZDWord*)data) == *((ZDWord*)token))
    return 1;
  else
    return 0;
}

int blorb_is_blorbfile(ZFile* file)
{
  IffForm* frm;

  frm = iff_decode_form(file);

  if (frm == NULL)
    return 0;

  if (!cmp_token(frm->id, "IFRS"))
    {
      free(frm);
      return 0;
    }

  free(frm);
  return 1;
}

BlorbFile* blorb_loadfile(ZFile* file)
{
  IffFile* iff;
  BlorbFile* res;

  int            x;
  ZDWord         index_len;
  unsigned char* data;

  if (!blorb_is_blorbfile(file))
    {
      zmachine_fatal("Programmer is a spoon: blorbfile is not a blorbfile");
      return NULL;
    }

  iff = iff_decode_file(file);
  if (iff == NULL)
    {
      zmachine_warning("Bad blorb file (no tokens)");
      return NULL;
    }

  res = malloc(sizeof(BlorbFile));
  res->file = iff;

  res->zcode_offset    = -1;
  res->release_number  = -1;
  res->game_id         = NULL;
  res->source          = file;

  res->index.offset    = -1;
  res->index.npictures = 0;
  res->index.picture   = NULL;
  res->index.nsounds   = 0;
  res->index.sound     = NULL;

  res->copyright       = NULL;
  res->author          = NULL;
  res->APal            = NULL;

  res->reso.offset     = -1;
  res->reso.length     = -1;
  
  res->release = -1;

  /* Decode and allocate space for each of the chunks in the file */
  for (x=0; x<iff->nchunks; x++)
    {
      if (cmp_token(iff->chunk[x].id, "RIdx"))
	{
	  /* Index chunk */
	  res->index.offset = iff->chunk[x].offset;
	  res->index.length = iff->chunk[x].length;

	  if (x != 0)
	    zmachine_warning("Blorb: Technically, the index chunk should be the very first chunk in a file. Zoom doesn't care, though");
	}
      else if (cmp_token(iff->chunk[x].id, "JPEG"))
	{
	  /* JPEG image chunk */
	  zmachine_warning("Due to patent restrictions, Zoom does not support JPEG images");
	}
      else if (cmp_token(iff->chunk[x].id, "PNG "))
	{
	  /* PNG image chunk */
	  res->index.npictures++;
	  res->index.picture = realloc(res->index.picture,
				       sizeof(BlorbImage)*res->index.npictures);
	  res->index.picture[res->index.npictures-1].file_offset =
	    iff->chunk[x].offset;
	  res->index.picture[res->index.npictures-1].file_len =
	    iff->chunk[x].length;
	  res->index.picture[res->index.npictures-1].number = -1;
	  res->index.picture[res->index.npictures-1].width = -1;
	  res->index.picture[res->index.npictures-1].height = -1;
	  res->index.picture[res->index.npictures-1].std_n = 1;
	  res->index.picture[res->index.npictures-1].std_d = 1;
	  res->index.picture[res->index.npictures-1].min_n = 0;
	  res->index.picture[res->index.npictures-1].min_d = 1;
	  res->index.picture[res->index.npictures-1].max_n = 1;
	  res->index.picture[res->index.npictures-1].max_d = 0;

	  res->index.picture[res->index.npictures-1].loaded      = NULL;
	  res->index.picture[res->index.npictures-1].in_use      = 0;
	  res->index.picture[res->index.npictures-1].usage_count = 0;

	  res->index.picture[res->index.npictures-1].is_adaptive = 0;
	}
      else if (cmp_token(iff->chunk[x].id, "Rect") &&
	       iff->chunk[x].length == 8)
	{
	  /* 
	   * Hum, nonstandard, 'fake' image. Some blorb files seem to have 
	   * this piece of evilness, so we support it...
	   */
	  data = read_block(file, iff->chunk[x].offset, 
			    iff->chunk[x].offset + iff->chunk[x].length);

	  res->index.npictures++;
	  res->index.picture = realloc(res->index.picture,
				       sizeof(BlorbImage)*res->index.npictures);
	  res->index.picture[res->index.npictures-1].file_offset =
	    iff->chunk[x].offset;
	  res->index.picture[res->index.npictures-1].file_len =
	    -1;
	  res->index.picture[res->index.npictures-1].number = -1;
	  res->index.picture[res->index.npictures-1].width  =
	    (data[0]<<24)|(data[1]<<16)|(data[2]<<8)|data[3];
	  res->index.picture[res->index.npictures-1].height =
	    (data[4]<<24)|(data[5]<<16)|(data[6]<<8)|data[7];
	  res->index.picture[res->index.npictures-1].std_n  = 1;
	  res->index.picture[res->index.npictures-1].std_d  = 1;
	  res->index.picture[res->index.npictures-1].min_n  = 0;
	  res->index.picture[res->index.npictures-1].min_d  = 1;
	  res->index.picture[res->index.npictures-1].max_n  = 1;
	  res->index.picture[res->index.npictures-1].max_d  = 0;

	  res->index.picture[res->index.npictures-1].loaded      = NULL;
	  res->index.picture[res->index.npictures-1].in_use      = 0;
	  res->index.picture[res->index.npictures-1].usage_count = 0;

	  res->index.picture[res->index.npictures-1].is_adaptive = 0;

	  free(data);
	}
      else if (cmp_token(iff->chunk[x].id, "FORM"))
	{
	  /* FORM chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "MOD "))
	{
	  /* MOD chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "SONG"))
	{
	  /* SONG chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "Plte"))
	{
	  /* Palette chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "APal"))
	{
	  /* Adaptive palette chunk */
	  res->APal = iff->chunk + x;
	}
     else if (cmp_token(iff->chunk[x].id, "Reso"))
	{
	  /* Resolution chunk */
	  res->reso.offset = iff->chunk[x].offset;
	  res->reso.length = iff->chunk[x].length;
	}
      else if (cmp_token(iff->chunk[x].id, "Loop"))
	{
	  /* Loop chunk */
	}
      else if (cmp_token(iff->chunk[x].id, "RelN"))
	{
	  /* Release number chunk */
	  data = read_block(file,
			    iff->chunk[x].offset, 
			    iff->chunk[x].offset+2);
	  res->release = (data[0]<<8)|data[1];
	  free(data);
	}
      else if (cmp_token(iff->chunk[x].id, "IFhd"))
	{
	  /* Game ID chunk */
	  if (iff->chunk[x].length == 13)
	    {
	      data = read_block(file,
				iff->chunk[x].offset,
				iff->chunk[x].offset+64);
	      res->game_id = malloc(sizeof(BlorbID));
	      res->game_id->release = (data[0]<<8)|data[1];
	      res->game_id->checksum = (data[8]<<8)|data[9];
	      memcpy(res->game_id->serial,
		     data + 2,
		     6);
	      free(data);
	    }
	  else
	    {
	      zmachine_warning("Blorb: IFhd chunk is apparently not a Z-Code IFhd");
	    }
	}
      else if (cmp_token(iff->chunk[x].id, "(c) "))
	{
	  /* Copyright chunk */
	  res->copyright = read_block(file, 
				      iff->chunk[x].offset,
				      iff->chunk[x].offset+iff->chunk[x].length);
	}
      else if (cmp_token(iff->chunk[x].id, "AUTH"))
	{
	  /* Author chunk */
	  res->author = read_block(file, 
				   iff->chunk[x].offset,
				   iff->chunk[x].offset+iff->chunk[x].length);
	}
      else if (cmp_token(iff->chunk[x].id, "ANNO"))
	{
	  /* Annotation */
	}
      else if (cmp_token(iff->chunk[x].id, "ZCOD"))
	{
	  /* Executable chunk */
	  res->zcode_offset = iff->chunk[x].offset;
	  res->zcode_len    = iff->chunk[x].length;
	}
      else
	{
	  zmachine_warning("Unknown Blorb chunk type @%x: '%.4s'",
			   iff->chunk[x].offset-8,
			   iff->chunk[x].id);
	}
    }
  
  if (res->index.offset < 0)
    {
      zmachine_fatal("Blorb: Bad file (no index chunk)");
      free(res);
      return NULL;
    }

  /* Read the index */
  data = read_block(file, res->index.offset, res->index.offset+4);
  index_len = (data[0]<<24)|(data[1]<<16)|(data[2]<<8)|data[3];
  free(data);

  if (index_len*12 + 4 != res->index.length)
    {
      zmachine_fatal("Blorb: index length indicator (%i) doesn't match length of index chunk (%i)", index_len, (res->index.length-4)/12);
      free(res);
      return NULL;
    }

  for (x=0; x<index_len; x++)
    {
      int number;
      int offset;
      
      data = read_block(file, res->index.offset + 4 + x*12,
			res->index.offset + 4 + x*12 + 12);
	  
      number = (data[4]<<24)|(data[5]<<16)|(data[6]<<8)|data[7];
      offset = (data[8]<<24)|(data[9]<<16)|(data[10]<<8)|data[11];

      if (cmp_token(data, "Pict"))
	{
	  int y;
	  int picnum;

	  /* Find the picture being referred to */
	  picnum = -1;
	  for (y=0; y<res->index.npictures; y++)
	    {
	      if (res->index.picture[y].file_offset == offset+8)
		{
		  picnum = y;
		  break;
		}
	    }
	  
	  if (picnum >= 0)
	    {
	      res->index.picture[y].number = number;
	    }
	  else
	    {
	      /* 
	       * Not found? Check to see if someone's defined a new resource 
	       * type without telling me 
	       */
	      for (y=0; y<iff->nchunks; y++)
		{
		  if (iff->chunk[y].offset == offset+8)
		    {
		      zmachine_warning("Blorb: picture #%i refers to non-picture resource type '%.4s'", number, iff->chunk[y].id);
		      picnum = y;
		      break;
		    }
		}
	      if (picnum < 0)
		zmachine_warning("Blorb: picture #%i refers to no resource", number);
	    }
	}
      else if (cmp_token(data, "Snd "))
	{
	  int y;

	  /* Check that this does indeed point to a chunk within the file */
	  for (y=0; y<iff->nchunks; y++)
	    {
	      if (iff->chunk[y].offset == offset+8)
		break;
	    }

	  if (y>=iff->nchunks)
	    {
	      zmachine_warning("Blorb: sound #%i does not refer to a resource");
	    }
	  else
	    {
	      BlorbSound snd;

	      snd.type = TYPE_UNKNOWN;
	      snd.file_offset = iff->chunk[y].offset;
	      snd.file_len    = iff->chunk[y].length;
	      snd.number      = number;

	      if (cmp_token(iff->chunk[y].id, "FORM"))
		{
		  snd.type = TYPE_AIFF;
		}
	      else if (cmp_token(iff->chunk[y].id, "MOD "))
		{
		  snd.type = TYPE_MOD;
		}
	      else if (cmp_token(iff->chunk[y].id, "SONG"))
		{
		  snd.type = TYPE_SONG;
		}

	      res->index.nsounds++;
	      res->index.sound = realloc(res->index.sound,
					 sizeof(BlorbSound)*res->index.nsounds);
	      res->index.sound[res->index.nsounds-1] = snd;
	    }
	}
      else if (cmp_token(data, "Exec"))
	{
	  if (number != 0)
	    zmachine_warning("Blorb: There should not be more than one code resource in a file");
	  else if (offset+8 != res->zcode_offset)
	    zmachine_warning("Blorb: Code index does not match code chunk");
	}
      else
	{
	  zmachine_warning("Blorb: Unknown index type: %.4s", data);
	}

      free(data);
    }

  /* Read the resolution chunk */
  if (res->reso.offset != -1)
    {
      int num,x;

      data = read_block(file, res->reso.offset, res->reso.offset + res->reso.length);

      res->reso.px   = (data[0]<<24)|(data[1]<<16)|(data[2]<<8)|data[3];
      res->reso.py   = (data[4]<<24)|(data[5]<<16)|(data[6]<<8)|data[7];
      res->reso.minx = (data[8]<<24)|(data[9]<<16)|(data[10]<<8)|data[11];
      res->reso.miny = (data[12]<<24)|(data[13]<<16)|(data[14]<<8)|data[15];
      res->reso.maxx = (data[16]<<24)|(data[17]<<16)|(data[18]<<8)|data[19];
      res->reso.maxy = (data[20]<<24)|(data[21]<<16)|(data[22]<<8)|data[23];

      num = (res->reso.length-24)/28;
      for (x=0; x<num; x++)
	{
	  unsigned char* rec;
	  int num;
	  int y;

	  rec = data + 24 + 28*x;
	  
	  num = (data[0]<<24)|(data[1]<<16)|(data[2]<<8)|data[3];
	  
	  for (y=0; y<res->index.npictures; y++)
	    {
	      if (res->index.picture[y].number == num)
		{
		  res->index.picture[y].std_n =
		    (data[4]<<24)|(data[5]<<16)|(data[6]<<8)|data[7];
		  res->index.picture[y].std_d =
		    (data[8]<<24)|(data[9]<<16)|(data[10]<<8)|data[11];
		  res->index.picture[y].min_n =
		    (data[12]<<24)|(data[13]<<16)|(data[14]<<8)|data[15];
		  res->index.picture[y].min_d =
		    (data[16]<<24)|(data[17]<<16)|(data[18]<<8)|data[19];
		  res->index.picture[y].max_n =
		    (data[20]<<24)|(data[21]<<16)|(data[22]<<8)|data[23];
		  res->index.picture[y].max_d =
		    (data[24]<<24)|(data[25]<<16)|(data[26]<<8)|data[27];
		  
		  break;
		}
	    }
	}

      free(data);
    }

  /* Read the adaptive palette chunk */
  if (res->APal != NULL)
    {
      data = read_block(file, res->APal->offset, res->APal->offset + res->APal->length);

      for (x=0; x<res->APal->length; x+=4)
	{
	  int num, y;

	  num = (data[x]<<24)|(data[x+1]<<16)|(data[x+2]<<8)|data[x+3];

	  for (y=0; y<res->index.npictures; y++)
	    {
	      if (res->index.picture[y].number == num)
		{
		  res->index.picture[y].is_adaptive = 1;
		  break;
		}
	    }
	}

      free(data);
    }

  return res;
}

static int         nloaded = 0;
static BlorbImage* image_queue[MAX_IMAGES];
static BlorbImage* last_img = NULL; /* Last non-adaptive image */

BlorbImage* blorb_findimage(BlorbFile* blb, int number)
{
  int x;
  BlorbImage* res;

  if (blb == NULL)
    return NULL;
  
  res = NULL;
  for (x=0; x<blb->index.npictures; x++)
    {
      if (blb->index.picture[x].number == number)
	{
	  res = blb->index.picture + x;
	}
    }

  if (res == NULL)
    return NULL;

  if (res->file_len == -1)
    return res; /* Fake image */

  if (last_img != NULL && last_img->loaded == NULL)
    {
      last_img->loaded = image_load(blb->source,
				    last_img->file_offset,
				    last_img->file_len,
				    NULL);
    }

  if (res->loaded == NULL)
    {
      image_data* plte = NULL;

      if (res->is_adaptive && last_img != NULL && last_img->loaded != NULL)
	plte = last_img->loaded;

      res->loaded = image_load(blb->source, res->file_offset, res->file_len,
			       plte);
      res->usage_count++;

      if (res->loaded == NULL)
	return res;
      res->width  = image_width(res->loaded);
      res->height = image_height(res->loaded);
    }

  if (!res->is_adaptive)
    {
      if (last_img != NULL)
	{
	  if (image_cmp_palette(last_img->loaded, res->loaded) == 0)
	    {
	      int x;

	      /* Unload any adaptive images that are currently loaded */
	      for (x=0; x<blb->index.npictures; x++)
		{
		  if (blb->index.picture[x].loaded != NULL &&
		      blb->index.picture[x].is_adaptive)
		    {
		      image_unload(blb->index.picture[x].loaded);

		      blb->index.picture[x].loaded = NULL;
		    }
		}
	    }

	  /* Last non-adaptive image is no longer in use... */
	  last_img->usage_count--;
	  if (last_img->usage_count <= 0)
	    image_unload(last_img->loaded);
	}
      /* Store this as the new non-adaptive image */
      last_img = res;
      last_img->usage_count++;
    }

  /* Delete any old entry for this image in the queue */
  for (x=0; x<nloaded; x++)
    {
      if (image_queue[x] == res)
	{
	  nloaded--;
	  memmove(image_queue + x,
		  image_queue + x + 1,
		  sizeof(BlorbImage*)*(nloaded-x));
	  break;
	}
    }

  /* Free any images that have dropped off the end of the queue */
  if (nloaded >= MAX_IMAGES)
    {
      nloaded--;
      image_queue[nloaded]->usage_count--;
      if (image_queue[nloaded]->usage_count <= 0)
	image_unload(image_queue[nloaded]->loaded);
      image_queue[nloaded]->loaded = NULL;
    }

  memmove(image_queue+1, image_queue,
	  sizeof(BlorbImage*)*nloaded);
  nloaded++;
  image_queue[0] = res;

  return res;
}

BlorbSound* blorb_findsound(BlorbFile* blorb, int num)
{
  int x;

  for (x=0; x<blorb->index.nsounds; x++)
    {
      if (blorb->index.sound[x].number == num)
	return &blorb->index.sound[x];
    }

  return NULL;
}

void blorb_closefile(BlorbFile* blorb)
{
  if (blorb->game_id != NULL)
    free(blorb->game_id);

  if (blorb->index.picture != NULL)
    {
      int x;

      for (x=0; x<blorb->index.npictures; x++)
	{
	  if (blorb->index.picture[x].loaded != NULL)
	    image_unload(blorb->index.picture[x].loaded);
	}

      free(blorb->index.picture);
    }

  if (blorb->index.sound != NULL)
    free(blorb->index.sound);

  if (blorb->copyright != NULL)
    free(blorb->copyright);
  if (blorb->author != NULL)
    free(blorb->author);

  free(blorb);
}
