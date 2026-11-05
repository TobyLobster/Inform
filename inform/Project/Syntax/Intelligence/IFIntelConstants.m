//
//  IFIntelConstants.m
//  Inform
//
//  The intelligence's string constants. Each is declared in the header of the class that it
//  belongs to, and defined here, as Swift can't define a constant that Objective-C sees.
//

#import "IFIntelFile.h"
#import "IFIntelSymbol.h"

// Standard symbol types
NSString* const IFSectionSymbolType = @"IFSectionSymbolType";

// Sent a while after an intelligence file changes
NSString* const IFIntelFileHasChangedNotification = @"IFIntelFileHasChangedNotification";
