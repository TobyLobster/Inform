//
//  IFToolbar.m
//  Inform
//
//  Created by Toby Nelson, 2014.
//

#import "IFToolbar.h"
NSString* const IFToolbarChangedVisibility = @"IFToolbarChangedVisibility";

@implementation IFToolbar

- (void)setVisible:(BOOL)shown
{
    [super setVisible: shown];
    
	[[NSNotificationCenter defaultCenter] postNotificationName: IFToolbarChangedVisibility
														object: self];
}

@end
