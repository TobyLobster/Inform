//
//  IFIsNotes.h
//  Inform
//
//  Created by Andrew Hunter on Fri May 07 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IFInspector.h"

extern NSString* IFIsNotesInspector;

//
// RTF notes inspector
//
@interface IFIsNotes : IFInspector

+ (IFIsNotes*) sharedIFIsNotes;				// Gets the shared instance of the inspector class

@end
