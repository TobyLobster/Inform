//
//  main.m
//  CocoaGlk
//
//  Created by Andrew Hunter on 18/03/2005.
//  Copyright Andrew Hunter 2005. All rights reserved.
//

//
// Sample main() function for a Glk application.
//
// We're unable to use a default main function, as OS X does not support this in dynamic libraries.
//

#import <Cocoa/Cocoa.h>

#include <stdlib.h>

#include <GlkView/glk.h>
#include <GlkClient/cocoaglk.h>

int main(int argv, const char** argc) {
	@try {
		cocoaglk_start(argv, argc);
		glk_main();
		cocoaglk_flushbuffer("About to finish");
		glk_exit();
	} @catch (NSException* exception) {
		NSLog(@"Caught exception %@: %@", [exception name], [exception reason]);
		exit(1);
	}
	
	return 0;
}
