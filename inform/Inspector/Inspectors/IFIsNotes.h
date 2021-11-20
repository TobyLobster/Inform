//
//  IFIsNotes.h
//  Inform
//
//  Created by Andrew Hunter on Fri May 07 2004.
//  Copyright (c) 2004 Andrew Hunter. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "IFInspector.h"

extern NSString* const IFIsNotesInspector;

///
/// RTF notes inspector
///
@interface IFIsNotes : IFInspector

/// Gets the shared instance of the inspector class
+ (IFIsNotes*) sharedIFIsNotes;

@end
