//
//  IFSyntaxStyles.h
//  Inform
//
//  Created by Toby Nelson on 19/04/2023.
//

#ifndef IFSyntaxStyles_h
#define IFSyntaxStyles_h

#import "IFSyntaxTypes.h"

@interface IFSyntaxStyles : NSObject

- (instancetype) init;
- (instancetype) initWithStyles: (IFSyntaxStyle*) styles
                  numCharStyles: (unsigned long) numCharStyles;
- (IFSyntaxStyle) read: (long) index;
- (void) write: (long) index value: (IFSyntaxStyle) value;

@property (atomic) IFSyntaxStyle*   styles;
@property (atomic) unsigned long    numCharStyles;

@end

#endif /* IFSyntaxStyles_h */