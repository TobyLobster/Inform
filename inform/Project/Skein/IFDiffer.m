//
//  IFDiffer.m
//  Inform
//
//  Created by Toby Nelson in 2015
//  Algorithm supplied by Graham Nelson
//

#import "IFDiffer.h"
#import "NSString+IFStringExtensions.h"
#import "Regex.h"
#include <wctype.h>

static const int MINIMUM_SPLICE_WORTH_BOTHERING_WITH = 5;
static const BOOL trace_diff = NO;

// *******************************************************************************************
@implementation IFDiffEdit

-(instancetype) initWithRange: (NSRange) range
                         form: (EFormOfEdit) form {
    self = [super init];
    if( self ) {
        fragment   = range;
        formOfEdit = form;
    }
    return self;
}

@end

// *******************************************************************************************
/*
 The Differ.

 Purpose: To provide text matching in the style of the Unix tool diff.

 Our task is to take two strings, "ideal" and "actual", and return a
 fairly minimal, fairly legible sequence of edits which would turn ideal
 into actual. We won't use Myers's algorithm because it's overkill for the
 text sizes we have here, and because we want to pay more attention to
 word boundaries so as to produce human-readable results; the running
 time below is worst-case quadratic in the number of words scanned, but
 plenty fast enough for IF transcript use in practice.
*/
@implementation IFDiffer

-(instancetype) init {
    self = [super init];
    if( self )
    {
        _differences = [[NSMutableArray alloc] init];
    }
    return self;
}

-(void) print {
    NSMutableString* message = [[NSMutableString alloc] init];
    for( IFDiffEdit* edit in _differences ) {
        switch( edit->formOfEdit ) {
            case DELETE_EDIT:           [message appendFormat: @"<delete>%@</delete>", [_ideal  substringWithRange:edit->fragment]]; break;
            case PRESERVE_EDIT:         [message appendFormat: @"%@",                  [_ideal  substringWithRange:edit->fragment]]; break;
            case PRESERVE_ACTUAL_EDIT:  [message appendFormat: @"%@",                  [_actual substringWithRange:edit->fragment]]; break;
            case INSERT_EDIT:           [message appendFormat: @"<insert>%@</insert>", [_actual substringWithRange:edit->fragment]]; break;
        }
    }
    NSLog(@"%@", message);
}

/*
 The diff algorithm.
 We do this in the simplest way possible. This outer routine, which is not
 recursively called, sets up the returned structure and sends it back.

 Note that a sequence of edits with no insertions or deletions means the
 match was in fact perfect, and is converted to the null edit list.
 */
-(BOOL) diffIdeal: (NSString*) theIdeal
           actual: (NSString*) theActual {
    if (theIdeal == nil) theIdeal = @"";
    if (theActual == nil) theActual = @"";

    _ideal = theIdeal;
    _actual = theActual;
    [_differences removeAllObjects];

    [self diffOuterRangeA: NSMakeRange(0, [theIdeal length])
                   rangeB: NSMakeRange(0, [theActual length])];

    for( IFDiffEdit* edit in _differences ) {
        if( ( edit->formOfEdit != PRESERVE_EDIT ) &&
            ( edit->formOfEdit != PRESERVE_ACTUAL_EDIT ) ) {
            return YES;
        }
    }
    [_differences removeAllObjects];
    return NO;
}

/*
 The first level down is also non-recursive and simply looks for a typical
 I7 banner line. Any correctly formed I7 banner matches any other; this
 ensures that transcripts of the same interaction, taken from builds on
 different days or with different compiler versions, continue to match.

 If text A (as we call the ideal version) and text B (the actual) both
 contain I7 banners, we split them into before, then the banner, then
 after. The result then consists of a diff of the before-texts, followed
 by preserving the actual banner, followed by a diff of the after-texts.
 */
-(void) diffOuterRangeA: (NSRange) rangeA
                 rangeB: (NSRange) rangeB {
    // Performance optimisation: Don't bother checking for the complex RegEx expression below
    // unless both strings are a good candidate, i.e. each string contains the words "Serial number".
    if( [_ideal  containsSubstring:@"Serial number"] &&
        [_actual containsSubstring:@"Serial number"] ) {
        NSString *regEx = @"(.*?)(Release \\d+ / Serial number \\d+ / Inform 7 build .... .I6.+?lib .+?SD).*";

        NSRange matchRangeA2 = [_ideal rangeOfRegex: regEx
                                            options: RKLNoOptions
                                            inRange: rangeA
                                            capture: 2
                                              error: NULL];
        if( matchRangeA2.location != NSNotFound ) {
            NSAssert(matchRangeA2.location >= rangeA.location, @"oops #1");
            NSRange matchRangeA1 = NSMakeRange(rangeA.location, matchRangeA2.location - rangeA.location);

            NSInteger A_pre_len  = matchRangeA1.length;
            NSInteger A_ver_len  = matchRangeA2.length;
            NSInteger A_post_len = rangeA.length - A_pre_len - A_ver_len;

            NSRange matchRangeB2 = [_actual rangeOfRegex: regEx
                                                 options: RKLNoOptions
                                                 inRange: rangeB
                                                 capture: 2
                                                   error: NULL];
            if( matchRangeB2.location != NSNotFound ) {
                NSAssert(matchRangeB2.location >= rangeB.location, @"oops #2");
                NSRange matchRangeB1 = NSMakeRange(rangeB.location, matchRangeB2.location - rangeB.location);

                NSInteger B_pre_len  = matchRangeB1.length;
                NSInteger B_ver_len  = matchRangeB2.length;
                NSInteger B_post_len = rangeB.length - B_pre_len - B_ver_len;

                [self diffInnerRangeA: matchRangeA1 rangeB: matchRangeB1];
                [_differences addObject: [[IFDiffEdit alloc] initWithRange: matchRangeB2 form: PRESERVE_ACTUAL_EDIT]];
                [self diffInnerRangeA: NSMakeRange(rangeA.location + A_pre_len + A_ver_len, A_post_len)
                               rangeB: NSMakeRange(rangeB.location + B_pre_len + B_ver_len, B_post_len)];
                return;
            }
        }
    }

    [self diffInnerRangeA: rangeA rangeB: rangeB];
}

/* The second level is at last recursive. */
-(void) diffInnerRangeA: (NSRange) rangeA
                 rangeB: (NSRange) rangeB {
    // If A is empty B must be inserted, if B is empty A must be deleted
    if((rangeA.length == 0) && (rangeB.length == 0)) {
        return;
    }
    if(rangeA.length == 0) {
        [_differences addObject: [[IFDiffEdit alloc] initWithRange: rangeB form: INSERT_EDIT]];
        return;
    }
    if(rangeB.length == 0) {
        [_differences addObject: [[IFDiffEdit alloc] initWithRange: rangeA form: DELETE_EDIT]];
        return;
    }

    /* 
     We look for the longest common prefix consisting of a sequence of entire
     words, or at any rate, ending at a word boundary (in both texts).
     */
    // Any common prefix can be preserved
    NSInteger i;
    for( i = 0; (i < rangeA.length) && (i < rangeB.length); i++ ) {
        if( charAt(_ideal, rangeA.location+i) != charAt(_actual, rangeB.location+i) ) {
            break;
        }
    }
    if (i < rangeA.length) {
        while ((i > 0) && (!isWordBoundary(_ideal, rangeA.location+i-1))) {
            i--;
        }
    }
    if (i > 0) {
        [_differences addObject: [[IFDiffEdit alloc] initWithRange:NSMakeRange(rangeA.location, i) form: PRESERVE_EDIT]];
        [self diffInnerRangeA: NSMakeRange(rangeA.location+i, rangeA.length - i)
                       rangeB: NSMakeRange(rangeB.location+i, rangeB.length - i)];
        return;
    }

    /*
     Similarly, we're only interested in a common suffix going back to the start
     of a whole word.
     */
    // Any common suffix can be preserved
    NSUInteger rangeEndA = rangeA.location + rangeA.length;
    NSUInteger rangeEndB = rangeB.location + rangeB.length;
    for( i = 0; (i < rangeA.length) && (i < rangeB.length); i++ ) {
        if( charAt(_ideal, rangeEndA-1-i) != charAt(_actual, rangeEndB-1-i) ) {
            break;
        }
    }
    if (i < rangeEndA) {
        while ((i > 0) && (!isWordBoundary(_ideal, rangeEndA-i-1))) {
            i--;
        }
    }

    if (i > 0) {
        [self diffInnerRangeA: NSMakeRange(rangeA.location, rangeA.length - i)
                       rangeB: NSMakeRange(rangeB.location, rangeB.length - i)];
        [_differences addObject: [[IFDiffEdit alloc] initWithRange: NSMakeRange(rangeEndA-i, i) form: PRESERVE_EDIT]];
        return;
    }

    /*
     In the typical use case most of the strings will now be gone, and this is
     where the algorithm goes quadratic. We're going to look for the longest
     common substring between A and B, provided it occurs at word boundaries,
     and is not trivially short. If we find this, we'll recurse to diff the
     text before the substring, then preserve the substring, then recurse to
     diff the text afterwards.
     */
    // Splice around the longest common substring
    NSInteger max_i = -1;
    NSInteger max_j = -1;
    NSInteger max_len = 0;

    for (i = 0; i < (int) rangeA.length; i++) {
        if ((i == 0) || (isWordBoundary(_ideal, rangeA.location + i-1))) {
            for (int j = 0; j < rangeB.length; j++) {
                if ((j == 0) || (isWordBoundary(_actual, rangeB.location + j-1))) {
                    NSInteger k;
                    for (k = 0; (i+k < rangeA.length) && (j+k < rangeB.length) && (charAt(_ideal, rangeA.location + i+k) == charAt(_actual, rangeB.location + j+k)); k++)
                        ;
                    while ((k > MINIMUM_SPLICE_WORTH_BOTHERING_WITH) &&
                           (!(isWordBoundary(_ideal, rangeA.location + i+k-1)))) {
                        k--;
                    }
                    if (k > max_len) {
                        max_len = k;
                        max_i = i;
                        max_j = j;
                    }
                }
            }
        }
    }
    if (max_len >= MINIMUM_SPLICE_WORTH_BOTHERING_WITH) {
        if (trace_diff) NSLog(@"substring: ");
        for (NSInteger c=0; c<max_len; c++) {
            if (trace_diff) NSLog(@"%c", charAt(_ideal, rangeA.location + max_i+c));
            NSAssert( charAt(_ideal, rangeA.location + max_i+c) == charAt(_actual, rangeB.location + max_j+c), @"oops #3");
        }
        if (trace_diff) NSLog(@"\n---\n");

        [self diffInnerRangeA: NSMakeRange(rangeA.location, max_i)
                       rangeB: NSMakeRange(rangeB.location, max_j)];
        [_differences addObject: [[IFDiffEdit alloc] initWithRange: NSMakeRange(rangeA.location + max_i, max_len)
                                                             form: PRESERVE_EDIT]];
        [self diffInnerRangeA: NSMakeRange(rangeA.location + max_i + max_len, rangeA.length - max_i - max_len)
                       rangeB: NSMakeRange(rangeB.location + max_j + max_len, rangeB.length - max_j - max_len)];

        if (trace_diff) [self print];
        if (trace_diff) NSLog(@"\n---\n");
        return;
    }

    /*
     If we can't find any good substring, all we can usefully do is say that
     the text has entirely changed, and we display this as cleanly as possible:
     */
    // If all else fails we can always just delete A and insert B
    [_differences addObject: [[IFDiffEdit alloc] initWithRange: rangeA
                                                          form: DELETE_EDIT]];
    [_differences addObject: [[IFDiffEdit alloc] initWithRange: rangeB
                                                          form: INSERT_EDIT]];
}

static unichar charAt(NSString* string, NSUInteger index) {
    // Report a zero terminator (a sentinal for the purposes of this algorithm)
    if( index == [string length] ) return 0;
    return [string characterAtIndex: index];
}

static BOOL isWordBoundary(NSString* string, NSUInteger index) {
    unichar a = charAt(string, index);
    unichar b = charAt(string, index+1);

    // The letterCharacterSet contains the Unicode categories "Letters" and "Marks".
    // See eg. http://www.fileformat.info/info/unicode/category/index.htm
    NSCharacterSet* charSet = [NSCharacterSet letterCharacterSet];
    if ( [charSet characterIsMember: a] && [charSet characterIsMember: b] ) return NO;
    return YES;
}

@end
