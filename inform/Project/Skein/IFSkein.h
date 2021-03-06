//
//  IFSkein.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

@class IFSkeinItem;

extern NSString* IFSkeinChangedNotification;
extern NSString* IFSkeinReplacedNotification;
extern NSString* IFSkeinChangedAnimateKey;
extern NSString* IFSkeinKeepActiveVisibleKey;

extern NSString* IFSkeinSelectionChangedNotification;
extern NSString* IFSkeinSelectionChangedItemKey;

@class IFProject;

@interface IFSkein : NSObject {
@private
    IFSkeinItem*    _rootItem;
    IFSkeinItem*    _activeItem;
}

// Retrieving the root / active / selected skein item
@property (atomic, readonly, strong)  IFSkeinItem * rootItem;
@property (atomic, strong)            IFSkeinItem * activeItem;
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

// Dirty flags
-(void) setLayoutDirty;     // Does the skein need laying out?

// Has the skein changed since we last reset the flag?
// Used to detect whether the skein actually changed due to executing a command in a story,
// which then is used to mark the document as changed, ie. needing save.
-(void) setSkeinChanged;

// Notification of change
- (void) postSkeinChangedWithAnimate: (BOOL) animate
                   keepActiveVisible: (BOOL) keepActiveVisible;


// Creating an input receiver
+ (id) inputSourceFromSkeinItem: (IFSkeinItem*) item1
						 toItem: (IFSkeinItem*) item2;


// Converting to strings / other file formats
- (NSString*) transcriptToPoint: (IFSkeinItem*) item;

-(IFSkeinItem*) nodeToReport;
-(NSString*) reportStateForSkein;

// Dragging
@property (atomic) IFSkeinItem*   draggingItem;                   // Current item being dragged
@property (atomic) BOOL           draggingSourceNeedsUpdating;    // Used to animate after dragging

// Undo helpers
- (void) setParentOf:                   (IFSkeinItem*) item parent:         (IFSkeinItem*) newParent;
- (void) removeFromChildrenArrayOf:     (IFSkeinItem*) item itemToRemove:   (IFSkeinItem*) itemToRemove;
- (void) addToChildrenArrayOf:          (IFSkeinItem*) item itemToAdd:      (IFSkeinItem*) itemToAdd;
- (void) setCommandOf:                  (IFSkeinItem*) item command:        (NSString*) newCommand;
- (void) setIdealOf:                    (IFSkeinItem*) item ideal:          (NSString*) newIdeal;
- (void) setActualOf:                   (IFSkeinItem*) item actual:         (NSString*) newActual;
- (void) setIsTestSubItemWithNSNumberOf:(IFSkeinItem*) item isTestSubItemWithNSNumber: (NSNumber*)newIsTestSubItem;

@end

// = Dealing with/creating XML data =

@interface IFSkein(IFSkeinXML)

- (NSString *)  getXMLString;                   // Create XML string for output
- (BOOL)        parseXmlData: (NSData*) data;   // Read XML input into skein data structure

@end
