//
//  glk_misc.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#include "glk.h"
#include "glk_client.h"
#import "cocoaglk.h"

#include "gi_blorb.h"
#include "gi_dispa.h"

static giblorb_map_t *cocoaglk_blorbmap = NULL;

gidispatch_rock_t (*cocoaglk_register)(void *obj, glui32 objclass) = NULL;
void (*cocoaglk_unregister)(void *obj, glui32 objclass, gidispatch_rock_t objrock) = NULL;

gidispatch_rock_t (*cocoaglk_register_memory)(void *array, glui32 len, char *typecode) = NULL;
void (*cocoaglk_unregister_memory)(void *array, glui32 len, char *typecode, gidispatch_rock_t objrock) = NULL;

giblorb_err_t giblorb_set_resource_map(strid_t file) {
	if (cocoaglk_blorbmap) {
		giblorb_destroy_map(cocoaglk_blorbmap);
		cocoaglk_blorbmap = NULL;
	}
	
	return giblorb_create_map(file, &cocoaglk_blorbmap);
}

giblorb_map_t *giblorb_get_resource_map(void) {
	return cocoaglk_blorbmap;
}

void gidispatch_set_object_registry(gidispatch_rock_t (*reg)(void *obj, glui32 objclass), 
									void (*unreg)(void *obj, glui32 objclass, gidispatch_rock_t objrock)) {
	cocoaglk_register = reg;
	cocoaglk_unregister = unreg;
	
	// Register existing objects
	winid_t win = glk_window_iterate(NULL, NULL);
	while (win != NULL) {
		win->giRock = reg(win, gidisp_Class_Window);
		win = glk_window_iterate(win, NULL);
	}

	strid_t str = glk_stream_iterate(NULL, NULL);
	while (str != NULL) {
		str->giRock = reg(str, gidisp_Class_Stream);
		str = glk_stream_iterate(str, NULL);
	}

	frefid_t ref = glk_fileref_iterate(NULL, NULL);
	while (ref != NULL) {
		ref->giRock = reg(ref, gidisp_Class_Fileref);
		ref = glk_fileref_iterate(ref, NULL);
	}
}

gidispatch_rock_t gidispatch_get_objrock(void *obj, glui32 objclass) {
	gidispatch_rock_t res = {0};
	
	switch (objclass) {
		case gidisp_Class_Window:
			if (!cocoaglk_winid_sane(obj)) {
				// Not sure about this. There isn't really a lot we can do when passed a bad winid.
				gidispatch_rock_t res;
				res.ptr = NULL;
				
				cocoaglk_warning("gidispatch_get_objrock called with an invalid winid");
				return res;
			}
			
			res = ((winid_t)obj)->giRock;
			break;
			
		case gidisp_Class_Stream:
			if (!cocoaglk_strid_sane(obj)) {
				cocoaglk_error("gidispatch_get_objrock called with an invalid strid");
			}
			
			res = ((strid_t)obj)->giRock;
			break;
			
		case gidisp_Class_Fileref:
			if (!cocoaglk_frefid_sane(obj)) {
				cocoaglk_error("gidispatch_get_objrock called with an invalid frefid");
			}
			
			res = ((frefid_t)obj)->giRock;
			break;
			
		default:
			cocoaglk_error("gidispatch_get_objrock called with an unknown object type");
	}
	
	return res;
}

void gidispatch_set_retained_registry(gidispatch_rock_t (*reg)(void *array, glui32 len, char *typecode), 
									  void (*unreg)(void *array, glui32 len, char *typecode, gidispatch_rock_t objrock)) {
	cocoaglk_register_memory = reg;
	cocoaglk_unregister_memory = unreg;
}
