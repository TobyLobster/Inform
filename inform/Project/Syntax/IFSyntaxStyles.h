//
//  IFSyntaxStyles.h
//  Inform
//
//  Created by Toby Nelson on 19/04/2023.
//

#ifndef IFSyntaxStyles_h
#define IFSyntaxStyles_h

#import "IFSyntaxTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface IFSyntaxStyles : NSObject

- (instancetype) init NS_DESIGNATED_INITIALIZER;
- (instancetype) initWithStyles: (IFSyntaxStyle*) styles
                  numCharStyles: (unsigned long) numCharStyles NS_DESIGNATED_INITIALIZER;
- (IFSyntaxStyle) read: (long) index;
- (void) write: (long) index value: (IFSyntaxStyle) value;

@property (atomic, nullable) IFSyntaxStyle* styles;
@property (atomic) unsigned long    numCharStyles;

@end

NS_ASSUME_NONNULL_END

#endif /* IFSyntaxStyles_h */
