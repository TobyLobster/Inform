//
//  ZoomPlugInCell.h
//  ZoomCocoa
//
//  Created by Andrew Hunter on 29/09/2007.
//  Copyright 2007 Andrew Hunter. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <ZoomPlugIns/ZoomPlugInInfo.h>


///
/// NSCell implementation for the plugin table
///
@interface ZoomPlugInCell : NSCell {
	/// The value for this cell
	ZoomPlugInInfo* objectValue;
}

@end
