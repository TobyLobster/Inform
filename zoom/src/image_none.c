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
 * Generic image routines, nothing around
 */

#include "../config.h"

#ifndef HAVE_LIBPNG

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "image.h"

image_data* image_load(ZFile* f, int offset, int length, image_data* palimg) { return NULL; }

void image_unload(image_data* data) { }

void image_unload_rgb(image_data* data) { }

int image_width(image_data* data) { return 10; }

int image_cmp_palette(image_data* img1, image_data* img2) { return 0; };

int image_height(image_data* data) { return 10; }

unsigned char* image_rgb(image_data* data) { return NULL; }

void image_resample(image_data* data, int n, int d) { }

void image_set_data(image_data* img, void* data, 
		    void (*destruct)(image_data*, void*)) { }

void* image_get_data(image_data* img) { return NULL; }

#endif
