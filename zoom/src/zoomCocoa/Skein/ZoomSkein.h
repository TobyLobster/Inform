//
//  ZoomSkein.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on Thu Jul 01 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <WebKit/WebKit.h>

#import "ZoomSkeinItem.h"

extern NSString* ZoomSkeinChangedNotification;

@interface ZoomSkein : NSObject {
	ZoomSkeinItem* rootItem;
	
	NSMutableString* currentOutput;
	ZoomSkeinItem* activeItem;
	
	// Web data
	NSMutableData* webData;
}

// Retrieving the root skein item
- (ZoomSkeinItem*) rootItem;
- (ZoomSkeinItem*) activeItem;
- (void) setActiveItem: (ZoomSkeinItem*) active;

// Acting as a Zoom output receiver
- (void) inputCommand:   (NSString*) command;
- (void) inputCharacter: (NSString*) character;
- (void) outputText:     (NSString*) outputText;
- (void) zoomWaitingForInput;
- (void) zoomInterpreterRestart;

// Notifying of changed
- (void) zoomSkeinChanged;

// Removing temporary items
- (void) removeTemporaryItems: (int) maxTemps;

// Creating a Zoom input receiver
+ (id) inputSourceFromSkeinItem: (ZoomSkeinItem*) item1
						 toItem: (ZoomSkeinItem*) item2;
- (id) inputSourceFromSkeinItem: (ZoomSkeinItem*) item1
						 toItem: (ZoomSkeinItem*) item2;

// Annotation lists
- (NSArray*) annotations;
- (NSMenu*)  populateMenuWithAction: (SEL) action
							 target: (id) target;
- (void)	 populatePopupButton: (NSPopUpButton*) button;
- (NSArray*) itemsWithAnnotation: (NSString*) annotation;

// Converting to strings/other file formats
- (NSString*) transcriptToPoint: (ZoomSkeinItem*) item;
- (NSString*) recordingToPoint: (ZoomSkeinItem*) item;

@end

// = Dealing with/creating XML data =

@interface ZoomSkein(ZoomSkeinXML)

- (NSString*) xmlData;
- (BOOL)      parseXmlData: (NSData*) data;

@end

// = WebKit interface (b0rked: webkit doesn't really support this) =

@interface ZoomSkein(ZoomSkeinWebDocRepresentation)<WebDocumentRepresentation>
@end
