//
//  main.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 28/03/2005.
//  Copyright Andrew Hunter 2005. All rights reserved.
//

//
// Startup functions for the glulxe interpreter
//


#import <Cocoa/Cocoa.h>

#include <stdlib.h>

#include <GlkClient/glk.h>
#include <GlkClient/cocoaglk.h>

#include "git.h"

static strid_t gamefile = NULL;

#define CACHE_SIZE (256 * 1024L)
#define UNDO_SIZE (512 * 1024L)

void fatalError (const char * s)
{
	cocoaglk_error(s);
    exit (1);
}

void glk_main () {
    if (gamefile == NULL)
        fatalError ("could not open game file");
	
    gitWithStream (gamefile, CACHE_SIZE, UNDO_SIZE);
}

int main(int argv, const char** argc) {
	// Get everything running
	cocoaglk_start(argv, argc);
	
	// Get the game file that we'll be using
	gamefile = cocoaglk_get_input_stream();
	if (gamefile == NULL) {
		frefid_t gameref = glk_fileref_create_by_prompt(fileusage_cocoaglk_GameFile, filemode_Read, 0);
		
		if (gameref == NULL) {
			cocoaglk_error("No game file supplied");
			exit(1);
		}
		
		gamefile = glk_stream_open_file(gameref, filemode_Read, 0);
	}
	
	if (gamefile == NULL) {
		cocoaglk_error("Failed to open the game file");
		exit(1);
	}
	
	// Get the interpreter version
	glui32 version = gestalt(GESTALT_TERP_VERSION, 0);
	char vString[64];
	sprintf(vString, "Git interpreter version %u.%u.%u", (version>>16)&0xff, (version>>8)&0xff, version&0xff);
	cocoaglk_log_ex(vString, 1);
	version = gestalt(GESTALT_SPEC_VERSION, 0);
	sprintf(vString, "Glulxe VM version %u.%u.%u", (version>>16)&0xff, (version>>8)&0xff, version&0xff);
	cocoaglk_log_ex(vString, 1);
	
	// See if we're using a blorb or a ulx file
	unsigned char buf[12];
	
	glk_stream_set_position(gamefile, 0, seekmode_Start);
	glui32 res = glk_get_buffer_stream(gamefile, (char *)buf, 12);
	if (!res) {
		cocoaglk_error("The game file was invalid: it does not contain enough data.");
		exit(1);
	}
    
	if (buf[0] == 'G' && buf[1] == 'l' && buf[2] == 'u' && buf[3] == 'l') {
		// Is a ulx file
		//locate_gamefile(FALSE);
	}
	else if (buf[0] == 'F' && buf[1] == 'O' && buf[2] == 'R' && buf[3] == 'M'
			 && buf[8] == 'I' && buf[9] == 'F' && buf[10] == 'R' && buf[11] == 'S') {
		//locate_gamefile(TRUE);
	}

	// Memory-ify the file (FIXME: implement a proper buffered stream class - ie, read buffering)
	glk_stream_set_position(gamefile, 0, seekmode_End);
	int length = glk_stream_get_position(gamefile);
	
	unsigned char* data = malloc(length);
	glk_stream_set_position(gamefile, 0, seekmode_Start);
	glk_get_buffer_stream(gamefile, (char*)data, length);
	
	gamefile = glk_stream_open_memory((char*)data, length, filemode_Read, 0);

	// Pass off control
	glk_main();
	
	// Finish up
	cocoaglk_flushbuffer("About to finish");
	glk_exit();
	
	return 0;
}
