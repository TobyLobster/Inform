//
//  IFSkeinConstants.m
//  Inform
//
//  The skein's string constants. Each is declared in the header of the class that it belongs
//  to, and defined here, as Swift can't define a constant that Objective-C sees.
//

#import "IFSkein.h"
#import "IFSkeinItem.h"

// Notifications and their keys

// Skein changed notification
NSString* const IFSkeinChangedNotification          = @"IFSkeinChangedNotification";
NSString* const IFSkeinChangedAnimateKey            = @"IFSkeinChangedAnimateKey";
NSString* const IFSkeinKeepActiveVisibleKey         = @"IFSkeinKeepActiveVisibleKey";

// Skein replaced notification
NSString* const IFSkeinReplacedNotification         = @"IFSkeinReplacedNotification";

// Skein selection changed notification
NSString* const IFSkeinSelectionChangedNotification = @"IFSkeinSelectionChangedNotification";
NSString* const IFSkeinSelectionChangedItemKey      = @"IFSkeinSelectionChangedItemKey";

// Paseboard type for drag and drop
NSString* const IFSkeinItemPboardType = @"com.inform7.IFSkeinItemPboardType";
