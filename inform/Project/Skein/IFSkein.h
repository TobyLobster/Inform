//
//  IFSkein.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>
#import <ZoomView/ZoomView.h>

@class IFSkeinItem;

extern NSString* const IFSkeinChangedNotification;
extern NSString* const IFSkeinReplacedNotification;
extern NSString* const IFSkeinChangedAnimateKey;
extern NSString* const IFSkeinKeepActiveVisibleKey;

extern NSString* const IFSkeinSelectionChangedNotification;
extern NSString* const IFSkeinSelectionChangedItemKey;

@class IFProject;

@interface IFSkein : NSObject <ZoomViewOutputReceiver> {
@private
    IFSkeinItem*    _rootItem;
    IFSkeinItem*    _activeItem;
    IFSkeinItem*    _winningItem;
}

// Retrieving the root / active / selected skein item
@property (atomic, readonly, strong)  IFSkeinItem * rootItem;
@property (atomic, strong)            IFSkeinItem * activeItem;
@property (atomic, strong)            IFSkeinItem * winningItem;
@property (atomic)                    BOOL          skeinChanged;


// Get the list of commands previously executed
@property (atomic, readonly, strong)  NSMutableArray* previousCommands;

- (instancetype) init NS_UNAVAILABLE NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithProject:(IFProject*) theProject NS_DESIGNATED_INITIALIZER;

// Acting as an output receiver
- (void) inputCommand:   (NSString*) command;
- (void) inputCharacter: (NSString*) character;
- (void) outputText:     (NSString*) outputText;
- (void) waitingForInput;
- (void) interpreterRestart;
- (void) interpreterStop;

- (void) setWinningItem: (IFSkeinItem *) winningItem;
- (IFSkeinItem *) getWinningItem;
- (BOOL) isTheWinningItem: (IFSkeinItem *) item;

// Dirty flags
/// Does the skein need laying out?
-(void) setLayoutDirty;

/// Has the skein changed since we last reset the flag?
/// Used to detect whether the skein actually changed due to executing a command in a story,
/// which then is used to mark the document as changed, ie. needing save.
-(void) setSkeinChanged;

// Notification of change
- (void) postSkeinChangedWithAnimate: (BOOL) animate
                   keepActiveVisible: (BOOL) keepActiveVisible;


// Creating an input receiver
+ (id<ZoomViewInputSource>) inputSourceFromSkeinItem: (IFSkeinItem*) item1
                                              toItem: (IFSkeinItem*) item2;


// Converting to strings / other file formats
- (NSString*) transcriptToPoint: (IFSkeinItem*) item;

-(IFSkeinItem*) nodeToReport;
-(NSString*) reportStateForSkein;

// Dragging
/// Current item being dragged
@property (atomic) IFSkeinItem*   draggingItem;
/// Used to animate after dragging
@property (atomic) BOOL           draggingSourceNeedsUpdating;

// Undo helpers
- (void) setParentOf:                   (IFSkeinItem*) item parent:         (IFSkeinItem*) newParent;
- (void) removeFromChildrenArrayOf:     (IFSkeinItem*) item itemToRemove:   (IFSkeinItem*) itemToRemove;
- (void) addToChildrenArrayOf:          (IFSkeinItem*) item itemToAdd:      (IFSkeinItem*) itemToAdd;
- (void) setCommandOf:                  (IFSkeinItem*) item command:        (NSString*) newCommand;
- (void) setIdealOf:                    (IFSkeinItem*) item ideal:          (NSString*) newIdeal;
- (void) setActualOf:                   (IFSkeinItem*) item actual:         (NSString*) newActual;
- (void) setIsTestSubItemWithNSNumberOf:(IFSkeinItem*) item isTestSubItemWithNSNumber: (NSNumber*)newIsTestSubItem;

@end

#pragma mark - Dealing with/creating XML data

/// Dealing with/creating XML data
@interface IFSkein(IFSkeinXML)

/// Create XML string for output
- (NSString *)  getXMLString;
/// Read XML input into skein data structure
- (BOOL)        parseXmlData: (NSData*) data;

@end
