//
//  NSAttributedString+IFStringExtensions.m
//  Inform
//
//  Created by Toby Nelson in 2015.
//
// String extensions inspired by http://b2cloud.com.au/tutorial/changing-font-size-of-an-nsattributedstring/

#import "NSAttributedString+IFStringExtensions.h"

// *******************************************************************************************
@implementation NSAttributedString (IFStringAdditions)

- (NSAttributedString*) attributedStringWithFontSize:(CGFloat) fontSize
{
    NSMutableAttributedString* attributedString = [self mutableCopy];

    [attributedString beginEditing];
    [attributedString enumerateAttribute: NSFontAttributeName
                                 inRange: NSMakeRange(0, attributedString.length)
                                 options: 0
                              usingBlock: ^(id value, NSRange range, BOOL *stop) {
        NSFont* font = value;
        font = [NSFont fontWithName: font.fontName
                               size: fontSize];

        [attributedString removeAttribute:NSFontAttributeName range:range];
        [attributedString addAttribute:NSFontAttributeName value:font range:range];
    }];
    [attributedString endEditing];

    return [attributedString copy];
}

@end
