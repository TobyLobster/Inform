//
//  IFSkeinItemView.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Cocoa/Cocoa.h>

@class IFSkeinLayoutItem;

///
/// Represents a single 'knot' in the skein
///
@interface IFSkeinItemView : NSView <NSDraggingSource, NSDraggingDestination>

// Properties
@property (atomic) IFSkeinLayoutItem*       layoutItem;
@property (atomic, readonly) unsigned long  drawnStateHash;

/// Get the size of a given command string
+ (NSSize) commandSize: (IFSkeinLayoutItem*) layoutItem;

/// Update attributes to new font size
+ (void) adjustAttributesToFontSize;

#if defined(DEBUG_EXPORT_HELP_IMAGES)
+ (void) exportHelpImages;
#endif // defined(DEBUG_EXPORT_HELP_IMAGES)

@end
