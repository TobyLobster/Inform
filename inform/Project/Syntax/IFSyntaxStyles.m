//
//  IFSyntaxStyles.m
//  Inform
//
//  Created by Toby Nelson on 19/04/2023.
//

#import <Foundation/Foundation.h>
#import "IFSyntaxStyles.h"

@implementation IFSyntaxStyles

- (instancetype) initWithStyles: (IFSyntaxStyle*) styles
                  numCharStyles: (unsigned long) numCharStyles {
    self = [super init];

    if (self) {
        self.styles = styles;
        self.numCharStyles = numCharStyles;
    }

    return self;
}

- (instancetype) init {
    self = [super init];

    if (self) {
        self.styles = NULL;
        self.numCharStyles = 0;
    }

    return self;
}

- (IFSyntaxStyle) read: (long) index {

    NSAssert(index >= 0, @"style index out of range");

    // Allow index == numCharStyles, counting it as a terminator
    NSAssert(index <= self.numCharStyles, @"style index out of range");

    if ((index < 0) || (index >= self.numCharStyles)) {
        return IFSyntaxNone;
    }
    return self.styles[index];
}

- (void) write: (long) index value: (IFSyntaxStyle) value {
    NSAssert(index >= 0, @"style index out of range");
    NSAssert(index < self.numCharStyles, @"style index out of range");

    if ((index >= 0) && (index < self.numCharStyles)) {
        self.styles[index] = value;
    }
}

@end
