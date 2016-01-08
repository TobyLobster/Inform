//
//  IFNewInform6Project.m
//  Inform
//
//  Created by Andrew Hunter on Sat Sep 13 2003.
//  Copyright (c) 2003 Andrew Hunter. All rights reserved.
//

#import "IFNewInform6Project.h"
#import "IFUtility.h"
#import "IFProjectFile.h"
#import "NSBundle+IFBundleExtensions.h"

// Some useful functions
static NSString* quoteInformString(NSString* stringIn) {
    // Turns characters such as '"' into '^'
    NSMutableString* res = [[NSMutableString alloc] init];

    int x, len;

    len = (int)[stringIn length];

    // Strip spaces at the end of the string
    while ((len > 0) && ([stringIn characterAtIndex: len-1] == 10))
        len--;

    // Quote character appropriately
    for (x=0; x<len; x++) {
        unichar chr = [stringIn characterAtIndex: x];

        if (chr == 10) {
            [res appendString: @"^\n\t\t"];
        } else if (chr < 32) {
            // Ignore
        } else if (chr < 255) {
            switch (chr) {
                case '"':
                    [res appendString: @"~"];
                    break;

                case '@':
                    [res appendString: @"@@64"];
                    break;
                case '\\':
                    [res appendString: @"@@92"];
                    break;
                case '^':
                    [res appendString: @"@@94"];
                    break;
                case '~':
                    [res appendString: @"@@126"];
                    break;

                default:
                    [res appendFormat: @"%c", chr];
            }
        } else {
        }
    }

    return res;
}

@implementation IFNewInform6Project {
    IFNewInform6ProjectView* vw;
    NSRange initialSelectionRange;
}

-(instancetype) init {
    self = [super init];
    if( self != nil ) {
        initialSelectionRange = NSMakeRange(0, 0);
    }
    return self;
}

- (NSObject<IFNewProjectSetupView>*) configView {
    if( !vw ) {
        vw = [[IFNewInform6ProjectView alloc] init];
        [NSBundle oldLoadNibNamed: @"StandardProjectOptions"
                            owner: vw];
    }

    return vw;
}

- (void) setupFile: (IFProjectFile*) file
          fromView: (NSObject<IFNewProjectSetupView>*) view
         withStory: (NSString*) story
  withExtensionURL: (NSURL*) extensionURL {
    IFNewInform6ProjectView* theView = (IFNewInform6ProjectView*) view;

    NSError *error = nil;
    NSString* sourceTemplate = [NSString stringWithContentsOfFile: [[NSBundle mainBundle] pathForResource: @"standardMain" ofType: @"inf"]
                                                         encoding: NSISOLatin1StringEncoding
                                                            error: &error];

    NSString* sourceFile = [NSString stringWithFormat: sourceTemplate,
        quoteInformString([theView name]),
        quoteInformString([theView headline]),
        quoteInformString([theView initialRoom]),
        quoteInformString([theView initialRoomDescription]),
        quoteInformString([theView teaser])];

    initialSelectionRange = NSMakeRange([sourceFile length], 0);

    [file addSourceFile: @"main.inf"
           withContents: [sourceFile dataUsingEncoding: NSUTF8StringEncoding]];
}

- (void) setInitialFocus:(NSWindow *)window {
    [vw setInitialFocus: window];
}

-(NSRange) initialSelectionRange {
    return initialSelectionRange;
}

-(NSString*) typeName {
    return @"org.inform-fiction.project";
}

@end

// *******************************************************************************************
@implementation IFNewInform6ProjectView {
    IBOutlet NSTextField* name;						// Field that contains the initial name of the game
    IBOutlet NSTextField* headline;					// Field that contains the games initial headline
    IBOutlet NSTextView*  teaser;					// Field that contains the games initial teaser
    IBOutlet NSTextField* initialRoom;				// Field that contains the name of the games initial room
    IBOutlet NSTextView*  initialRoomDescription;	// Field that contains the description of the games initial room

    IBOutlet NSView*      view;						// View that contains the lot
}


- (NSView*) view {
    return view;
}

- (NSString*) name {
    return [name stringValue];
}

- (NSString*) headline {
    return [headline stringValue];
}

- (NSString*) teaser {
    return [[teaser textStorage] string];
}

- (NSString*) initialRoom {
    return [initialRoom stringValue];
}

- (NSString*) initialRoomDescription {
    return [[initialRoomDescription textStorage] string];
}

- (void) setInitialFocus:(NSWindow *)window {
    [window makeFirstResponder: name];
}

@end

