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

#ifndef __BLORB_H
#define __BLORB_H

#include "ztypes.h"
#include "file.h"

#include "image.h"

typedef struct IffChunk IffChunk;
typedef struct IffForm  IffForm;
typedef struct IffFile  IffFile;

typedef struct BlorbIndex      BlorbIndex;
typedef struct BlorbImage      BlorbImage;
typedef struct BlorbSound      BlorbSound;
typedef struct BlorbResolution BlorbResolution;
typedef struct BlorbID         BlorbID;
typedef struct BlorbFile       BlorbFile;

/* General IFF-reading routines */
struct IffChunk
{
  char   id[4];
  ZDWord offset;
  ZDWord length;
};

struct IffForm
{
  ZDWord len;
  char   id[4];
};

struct IffFile
{
  IffForm*  form;
  int       nchunks;
  IffChunk* chunk;
};

IffChunk* iff_decode_next_chunk(ZFile*    file,
				const IffChunk* lastchunk /* Can be NULL */,
				const IffForm*  form);
IffForm*  iff_decode_form      (ZFile*    file);
IffFile*  iff_decode_file      (ZFile*    file);

/* Blorb-specific routines */
struct BlorbIndex
{
  int offset;
  int length;

  int         npictures;
  BlorbImage* picture;
  int         nsounds;
  BlorbSound* sound;
};

struct BlorbImage
{
  int file_offset;
  int file_len;
  int number;
  
  int width;
  int height;

  /* Scaling info - _n = numerator, _d = denominator */
  int std_n, std_d;
  int min_n, min_d;
  int max_n, max_d;

  image_data* loaded;
  int in_use;
  int usage_count;

  int is_adaptive;
};

struct BlorbSound
{
  enum
    {
      TYPE_AIFF,
      TYPE_MOD,
      TYPE_SONG,
      
      TYPE_UNKNOWN
    }
  type;
  int file_offset;
  int file_len;
  int number;
};

struct BlorbResolution
{
  int offset, length;

  int px, py;
  int minx, miny;
  int maxx, maxy;
};

struct BlorbID
{
  ZUWord release;
  ZByte  serial[6];
  ZUWord checksum;
};

struct BlorbFile
{
  BlorbIndex index;

  ZFile* source;

  int      zcode_offset, zcode_len;
  int      release_number;
  BlorbID* game_id;
  
  BlorbResolution reso;

  IffFile* file;

  IffChunk* APal;

  int release;

  char* copyright;
  char* author;
};

int         blorb_is_blorbfile(ZFile* file);
BlorbFile*  blorb_loadfile    (ZFile* file);
void        blorb_closefile   (BlorbFile* file);
BlorbImage* blorb_findimage   (BlorbFile* blorb, int num);
BlorbSound* blorb_findsound   (BlorbFile* blorb, int num);

#endif
