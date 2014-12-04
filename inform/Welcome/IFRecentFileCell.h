//
//  IFRecentFileCell.h
//  Inform
//
//  Created by Toby Nelson in 2014
//

#import <Cocoa/Cocoa.h>

@interface IFRecentFileCell : NSTextFieldCell {
@private
    NSImage *   image;
}

@property (readwrite, retain) NSImage * image;

@end
