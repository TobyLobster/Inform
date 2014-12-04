//
//  ZoomZMachine.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomZMachine.h"
#import "ZoomServer.h"

#include "sys/time.h"


#include "zmachine.h"
#include "interp.h"
#include "random.h"
#include "file.h"
#include "zscii.h"
#include "display.h"
#include "rc.h"
#include "stream.h"
#include "blorb.h"
#include "v6display.h"
#include "state.h"
#include "debug.h"
#include "zscii.h"

@implementation ZoomZMachine

- (id) init {
    self = [super init];

    if (self) {
        display = nil;
        machineFile = NULL;

        inputBuffer = [[NSMutableString alloc] init];
        outputBuffer = [[ZBuffer alloc] init];
        lastFile = nil;
		terminatingCharacter = 0;

        windows[0] = windows[1] = windows[2] = nil;

        int x;
        for(x=0; x<3; x++) {
            windowBuffer[x] = [[NSMutableAttributedString alloc] init];
        }
		
		[[NSNotificationCenter defaultCenter] addObserver: self
												 selector: @selector(flushBuffers)
													 name: ZBufferNeedsFlushingNotification
												   object: nil];
    }

    return self;
}

- (void) dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver: self];
	
    if (windows[0])
        [windows[0] release];
    if (windows[1])
        [windows[1] release];
    if (windows[2])
        [windows[2] release];

    int x;
    for (x=0; x<3; x++) {
        [windowBuffer[x] release];
    }

    [display release];
    [inputBuffer release];
    [outputBuffer release];

    mainMachine = nil;
    
    if (lastFile) [lastFile release];

    if (machineFile) {
        close_file(machineFile);
    }
	if (storyData) [storyData release];
    
    [super dealloc];
}

- (NSString*) description {
    return @"Zoom 1.1.6 ZMachine object";
}

- (void) connectionDied: (NSNotification*) notification {
	NSLog(@"Connection died!");
	abort();
}

// = Setup =
- (void) loadStoryFile: (NSData*) storyFile {
    // Create the machine file
	storyData = [storyFile retain];
    ZDataFile* file = [[ZDataFile alloc] initWithData: storyFile];
    machineFile = open_file_from_object([file autorelease]);
	
	// Start initialising the Z-Machine
	// (We do this so that we can load a save state at any time after this call)
	
	wasRestored = NO;
	
    // RNG
    struct timeval tv;
    gettimeofday(&tv, NULL);
    random_seed(tv.tv_sec^tv.tv_usec);
	
    // Some default options
	// rc_load(); // DELETEME: TEST FOR BUG
	rc_hash = hash_create();
	
	rc_defgame = malloc(sizeof(rc_game));
	rc_defgame->name = "";
	rc_defgame->interpreter = 3;
	rc_defgame->revision = 'Z';
	rc_defgame->fonts = NULL;
	rc_defgame->n_fonts = 0;
	rc_defgame->colours = NULL;
	rc_defgame->n_colours = 0;
	rc_defgame->gamedir = rc_defgame->savedir = rc_defgame->sounds = rc_defgame->graphics = NULL;
	rc_defgame->xsize = 80;
	rc_defgame->ysize = 25;
	rc_defgame->antialias = 1;
	rc_defgame->fg_col = [display foregroundColour];
	rc_defgame->bg_col = [display backgroundColour];
	
	hash_store(rc_hash, "default", 7, rc_defgame);
	
    // Load the story
    machine.story_length = get_size_of_file(machineFile);
    zmachine_load_file(machineFile, &machine);
	machine.blorb = blorb_loadfile(NULL);

	// Set up the rc system (we do this twice: this particular case helps with the )
    rc_set_game(zmachine_get_serial(), Word(ZH_release), Word(ZH_checksum));
}

// = Running =
- (void) startRunningInDisplay: (in byref NSObject<ZDisplay>*) disp {
    NSAutoreleasePool* mainPool = [[NSAutoreleasePool alloc] init];
    
	// Remember the display
    display = [disp retain];
	
	// Set up colours
	if (rc_defgame) {
		rc_defgame->fg_col = [display foregroundColour];
		rc_defgame->bg_col = [display backgroundColour];
	}

    // OK, we can now set up the ZMachine and get running
	rc_defgame->interpreter = [display interpreterVersion];
	rc_defgame->revision	= [display interpreterRevision];

    // Setup the display
    windows[0] = NULL;
    windows[1] = NULL;
    windows[2] = NULL;

    // Cycle the autorelease pool
    displayPool = [[NSAutoreleasePool alloc] init];
    
    switch (machine.header[0]) {
        case 3:
            // Status window

        case 4:
        case 5:
        case 7:
        case 8:
            // Upper/lower window
            windows[0] = [[display createLowerWindow] retain];
            windows[1] = [[display createUpperWindow] retain];
            windows[2] = [[display createUpperWindow] retain];
            break;

        case 6:
			windows[0] = [[display createPixmapWindow] retain];
            break;
    }

    int x;
    for (x=0; x<3; x++) {
        [(NSDistantObject*)windows[x] setProtocolForProxy: @protocol(ZWindow)];
    }

    // Setup the display, etc
    rc_set_game(zmachine_get_serial(), Word(ZH_release), Word(ZH_checksum));
    display_initialise();

	// Clear the display to the default colours
	if (!wasRestored) {
		display_set_colour(rc_get_foreground(), rc_get_background());
		display_clear();
	}

	if (wasRestored) zmachine_setup_header();

    // Start running the machine
    switch (machine.header[0])
    {
#ifdef SUPPORT_VERSION_3
        case 3:
            display_split(1, 1);

            display_set_colour(rc_get_foreground(), rc_get_background()); display_set_font(0);
            display_set_window(0);
            if (!wasRestored) zmachine_run(3, NULL); else zmachine_runsome(3, machine.zpc);
            break;
#endif
#ifdef SUPPORT_VERSION_4
        case 4:
            if (!wasRestored) zmachine_run(4, NULL); else zmachine_runsome(4, machine.zpc);
            break;
#endif
#ifdef SUPPORT_VERSION_5
        case 5:
            if (!wasRestored) zmachine_run(5, NULL); else zmachine_runsome(5, machine.zpc);
            break;
        case 7:
            if (!wasRestored) zmachine_run(7, NULL); else zmachine_runsome(7, machine.zpc);
            break;
        case 8:
            if (!wasRestored) zmachine_run(8, NULL); else zmachine_runsome(8, machine.zpc);
            break;
#endif
#ifdef SUPPORT_VERSION_6
        case 6:
            v6_startup();
            v6_set_cursor(1,1);
			
            if (!wasRestored) zmachine_run(6, NULL); else zmachine_runsome(6, machine.zpc);
            break;
#endif

        default:
            zmachine_fatal("Unsupported ZMachine version %i", machine.header[0]);
            break;
    }

	stream_flush_buffer();
	display_flush();

    display_finalise();
    [mainPool release];
	
	display_exit(0);
}

// = Debugging =
void cocoa_debug_handler(ZDWord pc) {
	[mainMachine breakpoint: pc];
}

- (void) breakpoint: (ZDWord) pc {
	if (display) {
		// Notify the display of the breakpoint
		waitingForBreakpoint = YES;
		[self flushBuffers];
		[display hitBreakpointAt: pc];
		
		// Wait for the display to request resumption
		NSAutoreleasePool* breakpointPool = [[NSAutoreleasePool alloc] init];
		
		while (waitingForBreakpoint && (mainMachine != nil)) {
			[breakpointPool release];
			breakpointPool = [[NSAutoreleasePool alloc] init];
			
			[mainLoop acceptInputForMode: NSDefaultRunLoopMode
							  beforeDate: [NSDate distantFuture]];
		}
		
		[breakpointPool release];
	}
}

- (void) continueFromBreakpoint {
	if (!waitingForBreakpoint) {
		[NSException raise: @"BreakpointException" format: @"Attempt to call a continuation function when Zoom was not waiting at a breakpoint"];
		return;
	}
	
	waitingForBreakpoint = NO;
}

- (void) stepFromBreakpoint {
	if (!waitingForBreakpoint) {
		[NSException raise: @"BreakpointException" format: @"Attempt to call a continuation function when Zoom was not waiting at a breakpoint"];
		return;
	}
	
	debug_set_temp_breakpoints(debug_step_over);
	waitingForBreakpoint = NO;
}

- (void) stepIntoFromBreakpoint {
	if (!waitingForBreakpoint) {
		[NSException raise: @"BreakpointException" format: @"Attempt to call a continuation function when Zoom was not waiting at a breakpoint"];
		return;
	}
	
	debug_set_temp_breakpoints(debug_step_into);
	waitingForBreakpoint = NO;
}

- (void) finishFromBreakpoint {
	if (!waitingForBreakpoint) {
		[NSException raise: @"BreakpointException" format: @"Attempt to call a continuation function when Zoom was not waiting at a breakpoint"];
		return;
	}
	
	debug_set_temp_breakpoints(debug_step_out);
	waitingForBreakpoint = NO;
}

- (NSData*) staticMemory {
	NSData* result = [NSData dataWithBytesNoCopy: machine.memory 
										  length: machine.story_length<65536?machine.story_length:65536];
	
	return result;
}

// Macros from interp.c (copy those back for preference if they ever need to change)
#define UnpackR(x) (machine.packtype==packed_v4?4*((ZUWord)x):(machine.packtype==packed_v8?8*((ZUWord)x):4*((ZUWord)x)+machine.routine_offset))
#define UnpackS(x) (machine.packtype==packed_v4?4*((ZUWord)x):(machine.packtype==packed_v8?8*((ZUWord)x):4*((ZUWord)x)+machine.string_offset))
#define Obj3(x) (machine.memory + GetWord(machine.header, ZH_objs) + 62+(((x)-1)*9))
#define Obj4(x) ((machine.memory + (GetWord(machine.header, ZH_objs))) + 126 + ((((ZUWord)x)-1)*14))
#define GetPropAddr4(x) (((x)[12]<<8)|(x)[13])

- (int) zRegion: (int) addr {
	// Being a port of the Z__Region function from Inform
	if (addr > 0x7fff) addr |= 0xffff0000;
	int top = addr;
	
	if (machine.version == 6 || machine.version == 7) top >>= 1; // (?? might be wrong ??)
	
	// Outside the file?
	if (((unsigned)top&0xffff) > Word(0x1a)) return 0;
	
	// Is this an object?
	if (addr >= 1 && addr <= debug_syms.largest_object) return 1;
	
	// Is this a string?
	ZDWord strUnpack = UnpackS(addr);
	if (strUnpack >= debug_syms.stringarea) return 3;
	
	// Is this a routine?
	ZDWord routUnpack = UnpackR(addr);
	if (routUnpack >= debug_syms.codearea) return 2;
	
	// Is unknown
	return 0;
}

- (unsigned) typeMasksForValue: (unsigned) value {
	unsigned mask = 0;
	
	// Get the region
	int region = [self zRegion: value];
	
	// Is value a valid object number?
	if (region == 1) {
		mask |= ZValueObject;
	}
	
	// Is value a valid routine number?
	if (region == 2) {
		// Check through the list of routines for this one
		ZDWord routineAddr = UnpackR(value);
		int x;
		BOOL isRoutine = NO;
		
		for (x=0; x<debug_syms.nroutines; x++) {
			if (debug_syms.routine[x].start == routineAddr) isRoutine = YES;
		}
		
		if (isRoutine) mask |= ZValueRoutine;
	}
	
	// Is value a valid string number?
	if (region == 3) {
		mask |= ZValueString;
	}
		
	return mask;
}

static NSString* zscii_to_string(ZByte* buf) {
	int len;
	int* unistr = zscii_to_unicode(buf, &len);
	
	int x;
	int strLen = 0;
	
	for (x=0; unistr[x]!=0; x++) strLen++;
	
	unichar* cBuf = malloc(sizeof(unichar)*(strLen+1));
	
	for (x=0; x<strLen; x++) {
		if (unistr[x] <= 0xffff) cBuf[x] = unistr[x]; else cBuf[x] = '?';
	}
	cBuf[strLen] = 0;
	
	NSString* res = [NSString stringWithCharacters: cBuf
											length: strLen];
	
	free(cBuf);
	return res;
}

- (NSString*) descriptionForValue: (unsigned) value {
	NSMutableString* description = [NSMutableString string];
	unsigned mask = [self typeMasksForValue: value];
	
	// If the value could be an object, get the name
	if ((mask&ZValueObject)) {
		ZUWord uarg1 = value&0xffff;

		// 'Object (' at the start of the string
		[description appendString: @"Object ("];
		
		// Built-in name of the object if available
		debug_symbol* symbol;
		for (symbol = debug_syms.first_symbol; symbol != NULL; symbol = symbol->next) {
			if (symbol->type == dbg_object &&
				symbol->data.object.number == uarg1) {
				if (symbol->data.object.name != NULL &&
					symbol->data.object.name[0] != 0) {
					[description appendFormat: @"%s ", symbol->data.object.name];
				}
				break;
			}
		}
		
		// Short name of the object
		if (machine.version <= 3) {
			ZByte* obj;
			ZByte* prop;
			
			obj = Obj3(uarg1);
			prop = machine.memory + ((obj[7]<<8)|obj[8]) + 1;
			
			[description appendFormat: @"\"%@\"", zscii_to_string(prop)];
		} else {
			ZByte* obj;
			ZByte* prop;
			
			obj = Obj4(uarg1);
			prop = Address((ZUWord)GetPropAddr4(obj)+1);
			
			[description appendFormat: @"\"%@\"", zscii_to_string(prop)];
		}
		
		[description appendString: @") "];
	}
	
	// If the value could be a string, convert it
	if ((mask&ZValueString)) {
		[description appendFormat: @"String (\"%@\") ", zscii_to_string(machine.memory + UnpackS(value))];
	}
	
	// If the value could be a routine, find the name
	if ((mask&ZValueRoutine)) {
		ZDWord routineAddr = UnpackR(value);
		int x;
		
		for (x=0; x<debug_syms.nroutines; x++) {
			if (debug_syms.routine[x].start == routineAddr) {
				[description appendFormat: @"Routine ([ %s; ]) ", debug_syms.routine[x].name];
			}
		}
	}
	
	// If nothing, then just use the value
	if ([description length] <= 0) {
		int signedValue = value;
		if (signedValue > 0x7fff) signedValue &= 0xffff0000;
		
		[description appendFormat: @"%i", signedValue];
	}
	
	return description;
}

- (void) loadDebugSymbolsFrom: (NSString*) symbolFile
			   withSourcePath: (NSString*) sourcePath {	
	debug_load_symbols((char*)[symbolFile cString], (char*)[sourcePath cString]);

	// Setup our debugger callback
	debug_set_bp_handler(cocoa_debug_handler);
}

- (int) evaluateExpression: (NSString*) expression {
	debug_address addr;
	
	addr = debug_find_address(machine.zpc);

	debug_expr = malloc(sizeof(int) * ([expression length]+1));
	int x;
	for (x=0; x<[expression length]; x++) {
		debug_expr[x] = [expression characterAtIndex: x];
	}
	debug_expr[x] = 0;

	debug_expr_routine = addr.routine;
	debug_error = NULL;
	debug_expr_pos = 0;
	debug_eval_parse();
	free(debug_expr);
	
	if (debug_error != NULL) return 0x7fffffff;
	
	return debug_eval_result;
}

- (void) setBreakpointAt: (int) address {
	debug_set_breakpoint(address, 0, 0);
}

- (BOOL) setBreakpointAtName: (NSString*) name {
	int address = [self addressForName: name];
	
	if (address >= 0) {
		[self setBreakpointAt: address];
		return YES;
	} else {
		return NO;
	}
}

- (void) removeBreakpointAt: (int) address {
	debug_clear_breakpoint(debug_get_breakpoint(address));
}

- (void) removeBreakpointAtName: (NSString*) name {
	int address = [self addressForName: name];
	
	if (address >= 0) {
		[self removeBreakpointAt: address];
	}
}

- (void) removeAllBreakpoints {
	while (debug_nbps > 0) {
		// NOT temporary breakpoints
		int index = 0;
		while (index < debug_nbps && debug_bplist[index].temporary != 0) index++;
		if (index >= debug_nbps) break;
		
		debug_clear_breakpoint(debug_bplist + index);
	}
}

- (int) addressForName: (NSString*) name {
	return debug_find_named_address([name cString]);
}

- (NSString*) nameForAddress: (int) address {
	debug_address addr = debug_find_address(address);
	
	if (addr.routine != NULL) {
		return [NSString stringWithCString: addr.routine->name];
	}
	
	return nil;
}

- (NSString*) sourceFileForAddress: (int) address {
	debug_address addr = debug_find_address(address);
	
	if (addr.line == NULL) return nil;

	return [NSString stringWithCString: debug_syms.files[addr.line->fl].realname];
}

- (NSString*) routineForAddress: (int) address {
	debug_address addr = debug_find_address(address);
	
	if (addr.routine == NULL) return nil;
	
	return [NSString stringWithCString: addr.routine->name];
}

- (int) lineForAddress: (int) address {
	debug_address addr = debug_find_address(address);
	
	if (addr.line == NULL) return -1;
	
	return addr.line->ln;
}

- (int) characterForAddress: (int) address {
	debug_address addr = debug_find_address(address);
	
	if (addr.line == NULL) return -1;
	
	return addr.line->ch;
}

// = Autosave =
- (NSData*) createGameSave {
	// Create a save game, for autosave purposes
	int len;
	
	if (machine.autosave_pc <= 0) return nil;
	
	void* gameData = state_compile(&machine.stack, machine.autosave_pc, &len, 1);
	
	NSData* result = [NSData dataWithBytes: gameData length: len];
	
	free(gameData);
	
	return result;
}

- (NSData*) storyFile {
	return storyData;
}

- (NSString*) restoreSaveState: (NSData*) saveData {
	const ZByte* gameData = [saveData bytes];
	
	// NOTE: suppresses a warning (but it should be OK)
	if (!state_decompile((ZByte*)gameData, &machine.stack, &machine.zpc, [saveData length])) {
		NSLog(@"ZoomServer: restoreSaveState: failed");
		return [NSString stringWithCString: state_fail()];
	} else {
		zmachine_setup_header();
		
		// Must do the same setup tasks as zmachine_run would do
		switch (machine.memory[0]) {
			case 3:
				machine.packtype = packed_v3;
				break;
			
			case 4:
			case 5:
				machine.packtype = packed_v4;
				break;
				
			case 8:
				machine.packtype = packed_v8;
				break;
				
			case 6:
			case 7:	
				machine.packtype = packed_v6;
				machine.routine_offset = 8*Word(ZH_routines);
				machine.string_offset = 8*Word(ZH_staticstrings);
				break;
		}
		
		int x;
		for (x=0; x<UNDO_LEVEL; x++) {
			machine.undo[x] = NULL;
		}
		
		// Note that we're restoring, not restarting
		wasRestored = YES;
	}
	
	return nil;
}

// = Receiving text/characters =
- (void) inputText: (NSString*) text {
    [inputBuffer appendString: text];
}

- (void) inputTerminatedWithCharacter: (unsigned int) termChar {
	terminatingCharacter = termChar;
}

- (void) inputMouseAtPositionX: (int) posX
							 Y: (int) posY {
	mousePosX = posX;
	mousePosY = posY;
}

- (int)	terminatingCharacter {
	return terminatingCharacter;
}

- (int) mousePosX {
	return mousePosX;
}

- (int) mousePosY {
	return mousePosY;
}

// = Receiving files =
- (void) filePromptCancelled {
    if (lastFile) {
        [lastFile release];
        lastFile = nil;
        lastSize = -1;
    }
    
    filePromptFinished = YES;
}

- (void) promptedFileIs: (NSObject<ZFile>*) file
                   size: (int) size {
    if (lastFile) [lastFile release];
    
    lastFile = [file retain];
    lastSize = size;
    
    filePromptFinished = YES;
}

- (void) filePromptStarted {
    filePromptFinished = NO;
    if (lastFile) {
        [lastFile release];
        lastFile = nil;
    }
}

- (BOOL) filePromptFinished {
    return filePromptFinished;
}

- (NSObject<ZFile>*) lastFile {
    return lastFile;
}

- (int) lastSize {
    return lastSize;
}

- (void) clearFile {
    if (lastFile) {
        [lastFile release];
        lastFile = nil;
    }
}

// = Our own functions =
- (NSObject<ZWindow>*) windowNumber: (int) num {
    if (num < 0 || num > 2) {
        NSLog(@"*** BUG - window %i does not exist", num);
        return nil;
    }
    
    return windows[num];
}

- (NSObject<ZDisplay>*) display {
    return display;
}

- (NSMutableString*) inputBuffer {
    return inputBuffer;
}

// = Buffering =

- (ZBuffer*) buffer {
    return outputBuffer;
}

- (void) flushBuffers {
    [display flushBuffer: outputBuffer];
    [outputBuffer release];
    outputBuffer = [[ZBuffer alloc] init];
}

// = Display size =

- (void) displaySizeHasChanged {
    zmachine_resize_display(display_get_info());
}

@end

// = Fatal errors and warnings =
void zmachine_fatal(char* format, ...) {
	char fatalBuf[512];
	va_list  ap;
	
	va_start(ap, format);
	vsnprintf(fatalBuf, 512, format, ap);
	va_end(ap);
	
	fatalBuf[511] = 0;
	
	stream_flush_buffer();
	display_flush();
	
	[[mainMachine display] displayFatalError: [NSString stringWithFormat: @"%s (PC=#%x)", fatalBuf, machine.zpc]];
	NSLog(@"%s (PC=#%x)", fatalBuf, machine.zpc);
	
	display_exit(1);
}

void zmachine_warning(char* format, ...) {
	char fatalBuf[512];
	va_list  ap;
	
	va_start(ap, format);
	vsnprintf(fatalBuf, 512, format, ap);
	va_end(ap);
	
	fatalBuf[511] = 0;
	
#ifdef DEBUG
	NSLog(@"Warning: %s", fatalBuf);
#endif
	
	stream_flush_buffer();
	display_flush();
	
	[[mainMachine display] displayWarning: [NSString stringWithFormat: @"%s (PC=#%x)", fatalBuf, machine.zpc]];
}
