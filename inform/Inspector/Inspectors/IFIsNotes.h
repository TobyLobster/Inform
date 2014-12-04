//
//  IFIsNotes.h
//  Inform
//
//  Created by Andrew Hunter on Fri May 07 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IFInspector.h"
#import "IFProject.h"

extern NSString* IFIsNotesInspector;

//
// RTF notes inspector
//
@interface IFIsNotes : IFInspector {
	IFProject* activeProject;				// Currently selected project
	
	IBOutlet NSTextView* text;				// The text view that will contain the notes
}

+ (IFIsNotes*) sharedIFIsNotes;				// Gets the shared instance of the inspector class

@end
