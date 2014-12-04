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
 * Image routines for Carbon
 */

/*
 * Under Carbon, we use the routines provided by QuickTime to load
 * images - this enables us to support a much wider range of image
 * types if necessary, with little extra work. Unfortunately,
 * QuickTime does a truly blecherous job of alpha blender,
 * so we switch to libpng/Quartz if we possibly can.
 *
 * (Feel free to compare to the blecherousness of the X imaging
 * system)
 */

#include "../config.h"

#if WINDOW_SYSTEM==3

# include <stdio.h>
# include <stdlib.h>
# include <string.h>

# include <Carbon/Carbon.h>
# include "zmachine.h"
# include "carbondisplay.h"
# include "image.h"

# if !defined(HAVE_LIBPNG) || !defined(USE_QUARTZ)
#  include <QuickTime/QuickTime.h>

struct image_data
{
  PointerDataRef          dataRef;
  GraphicsImportComponent gi;
  Rect                    bounds;
};

image_data* image_load(ZFile* file, int offset, int len)
{
  image_data* res;
  void* data;

  OSErr erm;

  Handle mimeTypeH;
  Str255 mimeType;

  ComponentInstance dataHandler;

  /*
   * Awkward and slightly inefficient (well, very inefficient) means of
   * getting the data into a handle...
   */
  data = read_block(file, offset, offset+len);
  if (data == NULL)
    return NULL;

  res = malloc(sizeof(image_data));

  res->dataRef = NULL;
  res->gi      = NULL;

  res->dataRef = (PointerDataRef)NewHandle(sizeof(PointerDataRefRecord));
  if (res->dataRef == NULL)
    {
      free(data);
      free(res);
      return NULL;
    }
  (*res->dataRef)->data = data;
  (*res->dataRef)->dataLength = len;

  /* Get an importer... */
  res->gi = 0;
  erm = GetGraphicsImporterForDataRefWithFlags(res->dataRef, PointerDataHandlerSubType, &res->gi, 0);
  if (erm != noErr)
    {
      DisposeHandle((Handle)res->dataRef);
      free(res);
      return NULL;
    }

  /* Measure the image... */
  erm = GraphicsImportGetNaturalBounds(res->gi, &res->bounds);
  if (erm != noErr)
    {
      CloseComponent(res->gi);
      DisposeHandle(res->dataRef);
      free(res);
      return NULL;
    }

  return res;
}

int image_height(image_data* img)
{
  return img->bounds.bottom;
}

int image_width(image_data* img)
{
  return img->bounds.right;
}

void image_draw_carbon(image_data* img, 
		       CGrafPtr port, 
		       int x, int y,
		       int n, int d)
{
  Rect rct;

  rct.left = x;
  rct.top  = y;

  rct.right  = x + (img->bounds.right*n)/d;
  rct.bottom = y + (img->bounds.bottom*n)/d;

  /* Yay documentation. Not. 
   * (This isn't documented in IV-2726, but *IS* elsewhere. I'm
   * guessing Apple is trying to get me to buy a book. Grr.).
   *
   * No idea if this is *supposed* to work or not. The docs
   * are... vague on this point. I think they are implying it is.
   *
   * Sigh, I was hoping QuickTime's alpha blending was less blecherous
   * than it appears to be... I wonder if I can use libpng and
   * Quartz... my own resampling algorithm seems to produce less
   * artifacts.
   */

  GraphicsImportSetGWorld(img->gi, port, nil);
  GraphicsImportSetQuality(img->gi, codecMaxQuality);
  GraphicsImportSetGraphicsMode(img->gi, graphicsModeComposition, NULL);
  GraphicsImportSetBoundsRect(img->gi, &rct);
  GraphicsImportDraw(img->gi);
}

# else /* HAVE_LIBPNG */

#  include <string.h>

typedef struct q_prov_inf
{
  unsigned char* data;
  size_t         pos;
  size_t         len;
} q_prov_inf;

typedef struct quartz_data
{
  q_prov_inf        p_inf;
  CGDataProviderRef provider;

  CGImageRef        image;
} quartz_data;

static size_t quartz_getbytes(void* info, void* buffer, size_t count)
{
  q_prov_inf* i;

  i = info;

  if (i->pos + count > i->len)
    count = i->len - i->pos;
  if (count <= 0)
    return 0;

  memcpy(buffer, i->data + i->pos, count);
  i->pos += count;

  return count;
}

static void quartz_skipbytes(void* info, size_t count)
{
  q_prov_inf* i;

  i = info;

  i->pos += count;

  if (i->pos > i->len)
    i->pos = i->len;
}

static void quartz_rewind(void* info)
{
  q_prov_inf* i;

  i = info;

  i->pos = 0;
}

static void quartz_release(void* info)
{
}

static void quartz_destruct(image_data* img, void* data)
{
}

/* 
 * Usefully, both Quartz and my PNG loader use RGBA as their format.
 */
void image_quartz_prepare(image_data* img)
{
  quartz_data* data;

  data = image_get_data(img);
  
  if (data == NULL)
    {
      static CGDataProviderCallbacks pcb = {
	quartz_getbytes,
	quartz_skipbytes,
	quartz_rewind,
	quartz_release
      };
      static CGColorSpaceRef cspace = NULL;

      if (cspace == NULL) {
          cspace = CGColorSpaceCreateDeviceRGB();
      }

      data = malloc(sizeof(quartz_data));

      pcb.getBytes = quartz_getbytes;
      pcb.skipBytes = quartz_skipbytes;
      pcb.rewind = quartz_rewind;
      pcb.releaseProvider = quartz_release;

      data->p_inf.data = image_rgb(img);
      data->p_inf.pos  = 0;
      data->p_inf.len  = 4*image_width(img)*image_height(img);

      /* FIXME: actually premultiply the alpha... */

      data->provider = CGDataProviderCreate(&data->p_inf, &pcb);
      data->image    = CGImageCreate(image_width(img), image_height(img),
				     8, 32, 4*image_width(img),
				     cspace, kCGImageAlphaLast,
				     data->provider, NULL,
				     1, kCGRenderingIntentDefault);
      
      image_set_data(img, data, quartz_destruct);
    }
}

void image_draw_carbon(image_data* img, 
		       CGrafPtr port, 
		       int x, int y,
		       int n, int d)
{
  quartz_data* data;
  CGRect rect;

  Rect portRect;

  data = image_get_data(img);
  
  if (data == NULL)
    {
      image_quartz_prepare(img);
      data = image_get_data(img);
    }

  SetPort(port);
  carbon_set_context();

  GetPortBounds(port, &portRect);

  rect.origin.x    = x;
  rect.origin.y    = (portRect.bottom-portRect.top)-y;
  rect.size.width  = (image_width(img)*n)/d;
  rect.size.height = (image_height(img)*n)/d;
  rect.origin.y   -= rect.size.height;

  CGContextDrawImage(carbon_quartz_context, rect, data->image);
}

# endif
#endif
