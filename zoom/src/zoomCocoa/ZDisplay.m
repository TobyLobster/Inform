//
//  ZDisplay.m
//  ZoomCocoa
//
//  Created by Andrew Hunter on Wed Sep 10 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "ZoomProtocol.h"
#import "ZoomZMachine.h"
#import "ZoomServer.h"

#include "file.h"
#include "display.h"
#include "v6display.h"
#include "zmachine.h"
#include "blorb.h"
#include "zscii.h"
#include "rc.h"

#ifdef DEBUG
# define NOTE(x) NSLog(@"ZDisplay: %@", x)
#else
# define NOTE(x)
#endif

#pragma mark - Display state
static BOOL zDisplayForceFixed[8] = { NO, NO, NO, NO, NO, NO, NO, NO };
static int is_v6 = 0;

int zDisplayCurrentWindow = 0;
ZStyle* zDisplayCurrentStyle = nil;

BOOL zPixmapDisplay = NO;

#pragma mark - Display

static int cocoa_to_zscii(int theChar) {
	// Convert the character to ZSCII
	unichar badChar = '?';
	unichar key = 0;
	
	// Deal with special keys (ie, convert to ZSCII)
	switch (theChar) {
		// Arrow keys
		case NSUpArrowFunctionKey: case 129: key = 129; break;
		case NSDownArrowFunctionKey: case 130: key = 130; break;
		case NSLeftArrowFunctionKey: case 131: key = 131; break;
		case NSRightArrowFunctionKey: case 132: key = 132; break;
			
			// Delete/return
		case 10: key = 13; break;
		case NSDeleteFunctionKey: key = 8; break;
			
			// Function keys
		case NSF1FunctionKey: case 133: key = 133; break;
		case NSF2FunctionKey: case 134: key = 134; break;
		case NSF3FunctionKey: case 135: key = 135; break;
		case NSF4FunctionKey: case 136: key = 136; break;
		case NSF5FunctionKey: case 137: key = 137; break;
		case NSF6FunctionKey: case 138: key = 138; break;
		case NSF7FunctionKey: case 139: key = 139; break;
		case NSF8FunctionKey: case 140: key = 140; break;
		case NSF9FunctionKey: case 141: key = 141; break;
		case NSF10FunctionKey: case 142: key = 142; break;
		case NSF11FunctionKey: case 143: key = 143; break;
		case NSF12FunctionKey: case 144: key = 144; break;
			
			// Mouse buttons (we use fake function keys for this)
		case NSF33FunctionKey: case 252: key = 252; break;
		case NSF34FunctionKey: case 254: key = 254; break;
		case NSF35FunctionKey: case 253: key = 253; break;
			
			// Numeric keypad
		case '0': case '1': case '2': case '3': case '4': case '5': case '6': case '7':
		case '8': case '9':
			/*
			 if ([event modifierFlags]&NSNumericPadKeyMask) {
				 // Report this as a numeric keypad event
				 key = 145 + (chr-'0');
			 }
			 */
			break;
			
		default:
			// Unicode/other characters
			if (theChar >= 127) {
				// The character must be in the equivalence table...
				key = zscii_get_char(theChar);
				
				if (key <= 0) key = badChar;
			}
			break;
	}
	
	if (key > 0) theChar = key;
	
	return theChar;
}

#pragma mark - Debugging functions

void printf_debug(const char* format, ...) {
    va_list  ap;
    char     string[8192];

    va_start(ap, format);
    vsnprintf(string, 8192, format, ap);
	string[8191] = 0;
    va_end(ap);

	NSLog(@"DEBUG: %s", string);
    fputs(string, stdout);
}

void printf_info (const char* format, ...) {
    NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
}
void printf_info_done(void) {
    NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
}
void printf_error(const char* format, ...) {
    NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
}
void printf_error_done(void) {
    NSLog(@"Function not implemented: %s %s:%i", __FUNCTION__, __FILE__, __LINE__);
}

ZDisplay* display_get_info(void) {
    static ZDisplay dis;

    dis.status_line   = 1;
    dis.can_split     = 1;
    dis.variable_font = 1;
    dis.colours       = 1;
    dis.boldface      = 1;
    dis.italic        = 1;
    dis.fixed_space   = 1;
    dis.sound_effects = 0;
    dis.timed_input   = 1;
    dis.mouse         = 1;

    int xsize, ysize;
    int pxsize, pysize;
	int fontwidth, fontheight;
    [[mainMachine display] dimensionX: &xsize
                                    Y: &ysize];
    [[mainMachine display] pixmapX: &pxsize
								 Y: &pysize];
	[[mainMachine display] fontWidth: &fontwidth
							  height: &fontheight];

    dis.lines         = ysize;
    dis.columns       = xsize;
    dis.width         = pxsize;
    dis.height        = pysize;
    
    dis.font_width    = fontwidth;
    dis.font_height   = fontheight + 2.0;
    dis.pictures      = 1;
    dis.fore          = rc_get_foreground();
    dis.back          = rc_get_background();
	
	NOTE(@"display_get_info");
	
    return &dis;
}

void display_initialise(void) {
	NOTE(@"display_initialise");

    zDisplayCurrentStyle = [[ZStyle alloc] init];
	
	// Clear out the image cache
	if (zoomImageCache != NULL) free(zoomImageCache);
	zoomImageCache = NULL;
	zoomImageCacheSize = 0;
		
    //display_clear(); (Commented out to support autosave)
}

void display_reinitialise(void) {
	NOTE(@"display_reinitialise");
	
    zDisplayCurrentStyle = [[ZStyle alloc] init];
	
	// Clear out the image cache
	if (zoomImageCache != NULL) free(zoomImageCache);
	zoomImageCache = NULL;
	zoomImageCacheSize = 0;

    display_clear();
}

void display_finalise(void) {
	NOTE(@"display_finalise");
	
    [mainMachine flushBuffers];
    zDisplayCurrentStyle = nil;
}

void display_exit(int code) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_exit(%i)", code);
#endif
	
    [mainMachine flushBuffers];
    NSLog(@"Server exited with code %i (clean)", code);
    exit(code);
}

// Clearing/erasure functions
void display_clear(void) {
    id<ZWindow> win;
	
	NOTE(@"display_clear");
    
    zDisplayCurrentWindow = 0;

    [mainMachine flushBuffers];

    win = [mainMachine windowNumber: 1];
    [win clearWithStyle: zDisplayCurrentStyle];
    [(id<ZUpperWindow>)win startAtLine: 0];
    [(id<ZUpperWindow>)win endAtLine: 0];

    win = [mainMachine windowNumber: 2];
    [win clearWithStyle: zDisplayCurrentStyle];
    [(id<ZUpperWindow>)win startAtLine: 0];
    [(id<ZUpperWindow>)win endAtLine: 0];
    
    win = [mainMachine windowNumber: 0];
    [win clearWithStyle: zDisplayCurrentStyle];
}

void display_erase_window(void) {
	NOTE(@"display_erase_window");
	
    [[mainMachine buffer] clearWindow: [mainMachine windowNumber: zDisplayCurrentWindow]
                            withStyle: zDisplayCurrentStyle];
}

void display_erase_line(int val) {
	NOTE(@"display_erase_line");
	
    [[mainMachine buffer] eraseLineInWindow: (id<ZUpperWindow>)[mainMachine windowNumber: zDisplayCurrentWindow]
                                  withStyle: zDisplayCurrentStyle];
}

#pragma mark - Display functions

void display_prints(const int* buf) {
	if (is_v6)
    {
#ifdef DEBUG
		NSLog(@"display_prints: redirecting to v6...");
#endif
		
		v6_prints(buf);
		return;
    }

    // Convert buf to an NSString
    int length;
    for (length=0; buf[length] != 0; length++) {}
    
    if (length == 0) return;
    
    NSString *str = [[NSString alloc] initWithData: [NSData dataWithBytes: buf
                                                                   length: length * sizeof(int)]
                                          encoding: NSUTF32LittleEndianStringEncoding];

    if (!str) {
    unichar* bufU = NULL;

    for (length=0; buf[length] != 0; length++) {
        bufU = realloc(bufU, sizeof(unichar)*((length>>4)+1)<<4);
        bufU[length] = buf[length];
    }

        str = [[NSString alloc] initWithCharactersNoCopy: bufU
                                                  length: length
                                            freeWhenDone: YES];
    }
	
#ifdef DEBUG
	NSLog(@"ZDisplay: display_prints(\"%@\")", str);
#endif

    // Send to the window
    [[mainMachine buffer] writeString: str
                            withStyle: zDisplayCurrentStyle
                             toWindow: [mainMachine windowNumber: zDisplayCurrentWindow]];
}

void display_prints_c(const char* buf) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_prints_c(\"%s\")", buf);
#endif
	
	if ([mainMachine windowNumber: zDisplayCurrentWindow] == nil) {
		NSLog(@"No window: leaking '%s'", buf);
		return;
	}
	
    NSString* str = @(buf);
    [[mainMachine buffer] writeString: str
                            withStyle: zDisplayCurrentStyle
                             toWindow: [mainMachine windowNumber: zDisplayCurrentWindow]];
}

void display_printc(int chr) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_printc(\"%c\")", chr);
#endif
	
	if ([mainMachine windowNumber: zDisplayCurrentWindow] == nil) {
		NSLog(@"No window: leaking '%c'", chr);
		return;
	}

    unichar bufU[1];

    bufU[0] = chr;

    NSString* str = [NSString stringWithCharacters: bufU
                                            length: 1];
    [[mainMachine buffer] writeString: str
                            withStyle: zDisplayCurrentStyle
                             toWindow: [mainMachine windowNumber: zDisplayCurrentWindow]];
}

void display_printf(const char* format, ...) {
    va_list  ap;
    char     string[512];
	
	NOTE(@"display_printf");

    va_start(ap, format);
    vsnprintf(string, 512, format, ap);
	string[511] = 0;
    va_end(ap);

    display_prints_c(string);
}

#pragma mark - Input

int display_readline(int* buf, int len, long int timeout) {
	NOTE(@"display_readline");
    [mainMachine flushBuffers];
    
    id<ZDisplay> display = [mainMachine display];
	
	if (len <= 0) {
		zmachine_fatal("display_readline called with a buffer length of %i", len);
		return 0;
	}
	
	// Prefix
    NSString* prefix = @"";
	
    if (buf[0] != 0) {
        prefix = [[NSString alloc] initWithData: [NSData dataWithBytes: buf
                                                                length: len * sizeof(int)]
                                       encoding: NSUTF32LittleEndianStringEncoding];
        
        if (!prefix) {
            unichar* prefixBuf = malloc(sizeof(unichar)*len);
            int x;
            
            for (x=0; x<len && buf[x] != 0; x++) {
                prefixBuf[x] = buf[x];
            }
            
            prefix = [[NSString alloc] initWithCharactersNoCopy: prefixBuf
                                                         length: x
                                                   freeWhenDone: YES];
        }
    }

    // Cycle the autorelease pool
    @autoreleasepool {
	
	// Reset the terminating character
	[mainMachine inputTerminatedWithCharacter: 0];
	
	// Send the input style across
	[[mainMachine windowNumber: zDisplayCurrentWindow] setInputStyle: zDisplayCurrentStyle];
	
    // Request input
    [[mainMachine inputBuffer] setString: @""];
    
    [[mainMachine windowNumber: zDisplayCurrentWindow] setFocus];
    [display shouldReceiveText: len];
	
	if (prefix != nil && [prefix length] > 0) {
		// Ask the display to backtrack input if possible
        prefix = [display backtrackInputOver: prefix];
	}

    NSDate* when;

    if (timeout > 0) {
        when = [NSDate dateWithTimeIntervalSinceNow: ((double)timeout)/1000.0];
    } else {
        when = [NSDate distantFuture];
    }
    
    // Wait for input
    while (mainMachine != nil &&
		   [mainMachine terminatingCharacter] == 0 &&
           [[mainMachine inputBuffer] length] == 0 &&
           [when compare: [NSDate date]] == NSOrderedDescending) @autoreleasepool {
        [mainLoop acceptInputForMode: NSDefaultRunLoopMode
                          beforeDate: when];
    }
    
    }

	// If there was a timeout, get the text so far
	NSString* inputToDate = nil;
	if ([mainMachine terminatingCharacter] == 0 &&
		[[mainMachine inputBuffer] length] == 0) {
		inputToDate = [display receivedTextToDate];
	}
	
    // Finish up
    [display stopReceiving];
	
    // Copy the data
    NSMutableString* inputBuffer = inputToDate==nil?[mainMachine inputBuffer]:[inputToDate mutableCopy];
	
	// Add the prefix, if any
	if (prefix) {
		[inputBuffer insertString: prefix 
						  atIndex: 0];
	}

#ifdef DEBUG
	NSLog(@"ZDisplay: display_readline = %@", inputBuffer);
#endif

    NSInteger realLen = [inputBuffer length];
    if (realLen > (len-1)) {
        realLen = len-1;
    }

	// Remove any newlines at the end
	// If there's a newline at the end, then we didn't get a terminating character or timeout
    int chr;
    int termChar = 0;

    for (chr = 0; chr<realLen; chr++) {
        buf[chr] = [inputBuffer characterAtIndex: chr];

        if (buf[chr] == 10 ||
            buf[chr] == 13) {
            realLen = chr;
            termChar = 10;

            [inputBuffer deleteCharactersInRange: NSMakeRange(chr, 1)];
            break;
        }
    }

    buf[realLen] = 0;
	
	// Set the terminating character if required
	if (termChar != 10) {
		termChar = [mainMachine terminatingCharacter];
		
		if (termChar != 0) termChar = cocoa_to_zscii(termChar);
	}
	
	// For version 6: write the string we received
	if (zPixmapDisplay) {
		static int newline[] = { '\n', 0 };
		
		display_prints(buf);
		if (termChar == 10 || termChar == 13) display_prints(newline);
	}
	
    [inputBuffer deleteCharactersInRange: NSMakeRange(0, realLen)];

    return termChar;
}

int display_readchar(long int timeout) {
	NOTE(@"display_readchar");
	
    [mainMachine flushBuffers];

    id<ZDisplay> display = [mainMachine display];

    // Cycle the autorelease pool
    @autoreleasepool {
	// Send the input style across
	[[mainMachine windowNumber: zDisplayCurrentWindow] setInputStyle: zDisplayCurrentStyle];
	
    // Request input
    [[mainMachine inputBuffer] setString: @""];

    [[mainMachine windowNumber: zDisplayCurrentWindow] setFocus];
    [display shouldReceiveCharacters];

    NSDate* when;

    if (timeout > 0) {
        when = [NSDate dateWithTimeIntervalSinceNow: ((double)timeout)/1000.0];
    } else {
        when = [NSDate distantFuture];
    }

    // Wait for input
    while (mainMachine != nil &&
           [[mainMachine inputBuffer] length] == 0 &&
           [when compare: [NSDate date]] == NSOrderedDescending) {
        [mainLoop acceptInputForMode: NSDefaultRunLoopMode
                          beforeDate: when];
    }
    }

    // Finish up
    [display stopReceiving];

    // Copy the data
    unichar theChar;
    
    if ([[mainMachine inputBuffer] length] == 0) {
        theChar = 0; // Timeout occured
    } else {
        NSMutableString* inputBuffer = [mainMachine inputBuffer];
        theChar = cocoa_to_zscii([inputBuffer characterAtIndex: 0]);
    }

#ifdef DEBUG
	NSLog(@"ZDisplay: display_readchar = %i", theChar);
#endif
	
    return theChar;
}

#pragma mark - Used by the debugger

static int old_win;
static int old_fore, old_back;
static int old_style;

void display_sanitise  (void) {
    NOTE(@"display_santise");
    if (is_v6)
    {
        v6_reset_windows();
        return;
    }

    old_win = zDisplayCurrentWindow;

    display_set_window(0);

    old_fore = zDisplayCurrentStyle.foregroundColour;
    old_back = zDisplayCurrentStyle.backgroundColour;
    old_style = ((zDisplayCurrentStyle.reversed?1:0)|
                 (zDisplayCurrentStyle.bold?2:0)|
                 (zDisplayCurrentStyle.underline?4:0)|
                 (zDisplayCurrentStyle.fixed?8:0)|
                 (zDisplayCurrentStyle.symbolic?16:0));

    display_set_style(0);
    display_set_colour(4, 7);
}

void display_desanitise(void) {
    NOTE(@"display_desanitise");
    // TODO: handle v6 games.
    display_set_colour(old_fore, old_back);
    display_set_style(old_style);
    display_set_window(old_win);
}

#pragma mark - Display styling

void display_is_v6(void) { 
	NOTE(@"display_is_v6");
	
	is_v6 = 1;
}

int display_set_font(int font) {
	switch (font)
    {
		case -1:
			display_set_style(-16);
			break;
			
		default:
			break;
    }
	
	return 0;
}

int display_set_style(int style) {
	NOTE(@"display_set_style");
	
	if (is_v6) {
		v6_set_style(style);
		return style;
	}
	
    // Copy the old style
    ZStyle* newStyle = [zDisplayCurrentStyle copy];

    int oldStyle =
        (newStyle.reversed?1:0)|
        (newStyle.bold?2:0)|
        (newStyle.underline?4:0)|
        (newStyle.fixed?8:0)|
        (newStyle.symbolic?16:0);
    
    // Not using this any more
    if (zDisplayCurrentStyle) zDisplayCurrentStyle = nil;

    BOOL flag = (style<0)?NO:YES;
    if (style < 0) style = -style;
     
    // Set the flags
    if (style == 0) {
        [newStyle setBold: NO];
        [newStyle setUnderline: NO];
        [newStyle setFixed: NO];
        [newStyle setSymbolic: NO];
        [newStyle setReversed: NO];

        zDisplayCurrentStyle = newStyle;
        return oldStyle;
    }

    if (style&1)  [newStyle setReversed: flag];
    if (style&2)  [newStyle setBold: flag];
    if (style&4)  [newStyle setUnderline: flag];
    if (style&8)  [newStyle setFixed: flag];
    if (style&16) [newStyle setSymbolic: flag];
	
	[newStyle setForceFixed: zDisplayForceFixed[zDisplayCurrentWindow]];

    // Set as the current style
    zDisplayCurrentStyle = newStyle;

    return oldStyle;
}

static NSColor* getTrue(int col) {
    double r,g,b;

    r = ((double)(col&0x1f))/31.0;
    g = ((double)(col&0x3e0))/992.0;
    b = ((double)(col&0x7c00))/31744.0;

    return [NSColor colorWithSRGBRed: r
                               green: g
                                blue: b
                               alpha: 1.0];
}

void display_set_colour(int fore, int back) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_set_colour(%i, %i)", fore, back);
#endif
	
    zDisplayCurrentStyle = [zDisplayCurrentStyle copy];

    if (fore == -1) fore = rc_get_foreground();
    if (back == -1) back = rc_get_background();
    
    if (fore < 16) {
        if (fore >= 0) {
            [zDisplayCurrentStyle setForegroundTrue: nil];
            [zDisplayCurrentStyle setForegroundColour: fore];
        }
    } else {
        [zDisplayCurrentStyle setForegroundTrue: getTrue(fore-16)];
    }

    if (back < 16) {
        if (back >= 0) {
            [zDisplayCurrentStyle setBackgroundTrue: nil];
            [zDisplayCurrentStyle setBackgroundColour: back];
        }
    } else {
        [zDisplayCurrentStyle setBackgroundTrue: getTrue(back-16)];
    }
}

void display_split(int lines, int window) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_split(%i, %i)", lines, window);
#endif

    [[mainMachine buffer] setWindow: (id<ZUpperWindow>)[mainMachine windowNumber: window]
                          startLine: 0
                            endLine: lines];
}

void display_join(int win1, int win2) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_join(%i, %i)", win1, win2);
#endif
	
    [[mainMachine buffer] setWindow: (id<ZUpperWindow>)[mainMachine windowNumber: win2]
                          startLine: 0
                            endLine: 0];
}

void display_set_window(int window) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_set_window(%i)", window);
#endif

    zDisplayCurrentWindow = window;
	
	// Set the 'force fixed' attribute appropriately
	ZStyle* newStyle = [zDisplayCurrentStyle copy];
	[newStyle setForceFixed: zDisplayForceFixed[zDisplayCurrentWindow]];

	zDisplayCurrentStyle = newStyle;
}

int  display_get_window(void) {
	NOTE(@"display_get_window");
    return zDisplayCurrentWindow;
}

void display_set_cursor(int x, int y) {
#ifdef DEBUG
	NSLog(@"ZDisplay: display_set_cursor(%i, %i)", x, y);
#endif

    if (zDisplayCurrentWindow > 0) {
        [[mainMachine buffer] moveCursorToPoint: NSMakePoint(x,y)
                                       inWindow: (id<ZUpperWindow>)[mainMachine windowNumber: zDisplayCurrentWindow]];
    }
}

int display_get_cur_x(void) {
	NOTE(@"display_get_cur_x");
	
    if (zDisplayCurrentWindow == 0) {
        NSLog(@"Get_cur_x called for lower window");
        return -1; // No cursor position for the lower window
    }

    [mainMachine flushBuffers];
    
    NSPoint pos = [(id<ZUpperWindow>)[mainMachine windowNumber: zDisplayCurrentWindow]
        cursorPosition];
    return pos.x;
}

int display_get_cur_y(void) {
	NOTE(@"display_get_cur_y");
	
    if (zDisplayCurrentWindow == 0) {
        NSLog(@"Get_cur_y called for lower window");
        return -1; // No cursor position for the lower window
    }

    [mainMachine flushBuffers];

    NSPoint pos = [(id<ZUpperWindow>)[mainMachine windowNumber: zDisplayCurrentWindow]
        cursorPosition];
    return pos.y;
}

void display_force_fixed (int window, int val) {
	if (window >= 0 && window <= 8) 
		zDisplayForceFixed[window] = (val!=0);
	
	NOTE(@"display_force_fixed");
}

BOOL zdisplay_is_fixed(int window) {
	if (window >= 0 && window <= 8) 
		return zDisplayForceFixed[window];
	else
		return NO;
}

void display_terminating (unsigned char* table) {
	NOTE(@"display_terminating");
	
	if (table == NULL) {
		[[mainMachine display] setTerminatingCharacters: nil];
		return;
	}
	
	// Create a set of characters
	NSMutableSet* term = [NSMutableSet set];
	
	int x, y;
	for (x=0; table[x] != 0; x++) {
		switch (table[x]) {
			// Arrow keys
			case 129: [term addObject: @(NSUpArrowFunctionKey)]; break;
			case 130: [term addObject: @(NSDownArrowFunctionKey)]; break;
			case 131: [term addObject: @(NSLeftArrowFunctionKey)]; break;
			case 132: [term addObject: @(NSRightArrowFunctionKey)]; break;
				
			// Function keys
			case 133: [term addObject: @(NSF1FunctionKey)]; break;
			case 134: [term addObject: @(NSF2FunctionKey)]; break;
			case 135: [term addObject: @(NSF3FunctionKey)]; break;
			case 136: [term addObject: @(NSF4FunctionKey)]; break;
			case 137: [term addObject: @(NSF5FunctionKey)]; break;
			case 138: [term addObject: @(NSF6FunctionKey)]; break;
			case 139: [term addObject: @(NSF7FunctionKey)]; break;
			case 140: [term addObject: @(NSF8FunctionKey)]; break;
			case 141: [term addObject: @(NSF9FunctionKey)]; break;
			case 142: [term addObject: @(NSF10FunctionKey)]; break;
			case 143: [term addObject: @(NSF11FunctionKey)]; break;
			case 144: [term addObject: @(NSF12FunctionKey)]; break;
				
			// Keypad not currently supported
				
			// Various click characters
			case 252: [term addObject: @(NSF33FunctionKey)]; break; // Menu click
			case 253: [term addObject: @(NSF35FunctionKey)]; break; // Double click
			case 254: [term addObject: @(NSF34FunctionKey)]; break; // Single click
			
			case 255:
				// Same as 129-154 and 252-254
			{
				// Deal with this by passing an alternative table
				unsigned char newTable[30];
				int p = 0;
				
				for (y=129; y<=154; y++) newTable[p++] = y;
				for (y=252; y<=254; y++) newTable[p++] = y;
				newTable[p++] = 0;
				
				display_terminating(newTable);
				return;
			}
			
			default:
				if ((table[x] >= 129 && table[x] <= 154) || (table[x] >= 252 /* && table[x] <= 255 - always true*/)) {
					//NSLog(@"Oops, character '%i' is a valid terminating character, but isn't supported", (int)table[x]);
				} else {
					NSLog(@"Character '%i' is not a valid terminating character", (int)table[x]);
				}
		}
	}
	
	// Pass the table to the interpreter
	[[mainMachine display] setTerminatingCharacters: term];
}

int display_get_mouse_x(void) {
	return [mainMachine mousePosX];
}

int display_get_mouse_y(void) {
	return [mainMachine mousePosY];
}

void display_set_title(const char* title) {
	NOTE(@"display_set_title");
    [mainMachine setWindowTitle: title ? @(title) : nil];
}

void display_update(void) {
	NOTE(@"display_update");
    [mainMachine flushBuffers];
}

void display_beep(void) {
	[mainMachine flushBuffers];
	[[mainMachine display] beep];
	
	NOTE(@"display_beep");
}

#pragma mark - Getting files

static ZFileType convert_file_type(ZFile_type typein) {
    switch (typein) {
        case ZFile_save:
            return ZFileQuetzal;
            
        case ZFile_data:
            return ZFileData;
            
        case ZFile_transcript:
            return ZFileTranscript;
            
        case ZFile_recording:
            return ZFileRecording;
            
        default:
            return ZFileData;
    }
}

static void wait_for_file(void) {
    [mainMachine flushBuffers];
        
    while (mainMachine != nil &&
           ![mainMachine filePromptFinished]) {
        [mainLoop acceptInputForMode: NSDefaultRunLoopMode
                          beforeDate: [NSDate distantFuture]];
    }
}

ZFile* get_file_write(int* size, const char* name, ZFile_type purpose) {
    // FIXME: fill in size
    id<ZFile> res = NULL;
    
    [mainMachine filePromptStarted];
    [[mainMachine display] promptForFileToWrite: convert_file_type(purpose)
                                    defaultName: name ? @(name) : nil];
    
    wait_for_file();
    res = [mainMachine lastFile];
    [mainMachine clearFile];

    if (res) {
        if (size) *size = (int)[mainMachine lastSize];
        return open_file_from_object(res);
    } else {
        if (size) *size = -1;
        return NULL;
    }
}

ZFile* get_file_read(int* size, const char* name, ZFile_type purpose) {
    id<ZFile> res = NULL;
    
    [mainMachine filePromptStarted];
    [[mainMachine display] promptForFileToRead: convert_file_type(purpose)
                                   defaultName: name ? @(name) : nil];
    
    wait_for_file();
    res = [mainMachine lastFile];
    [mainMachine clearFile];

    if (res) {
        if (size) *size = (int)[mainMachine lastSize];
        return open_file_from_object(res);
    } else {
        if (size) *size = -1;
        return NULL;
    }
}
