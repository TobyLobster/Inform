//
//  main.m
//  glkmain
//
//  Created by C.W. Betts on 10/11/21.
//

#import <Cocoa/Cocoa.h>

#include <stdlib.h>

#include <GlkView/glk.h>
#include <GlkClient/cocoaglk.h>
#include <GlkClient/glkstart.h>

static int inittime = FALSE;

int main(int argc, const char** argv) {
	glkunix_startup_t startdata;
	// Get everything running
	cocoaglk_start(argc, argv);
	
	/* Now some argument-parsing. This is probably going to hurt. */
	/* This hurt, so I killed it. */
	startdata.argc = argc;
	startdata.argv = malloc(argc * sizeof(char*));
	memcpy(startdata.argv, argv, argc * sizeof(char*));

	/* sleep to give us time to attach a gdb process */
	char *cugelwait = getenv("CUGELWAIT");
	if (cugelwait)
	{
		int cugelwaittime = atoi(cugelwait);
		if (cugelwaittime && cugelwaittime < 60)
			sleep(cugelwaittime);
	}
	
//	win_hello();

	inittime = TRUE;

	if (!glkunix_startup_code(&startdata))
	return 1;
	inittime = FALSE;
	
	glk_main();
	cocoaglk_flushbuffer("About to finish");

	glk_exit();

	return 0;
}
