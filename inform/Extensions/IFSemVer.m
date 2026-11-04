//
//  IFSemVer.m
//  Inform
//
//  Created by Toby Nelson on 10/08/2022.
//

#import <Foundation/Foundation.h>
#import "IFSemVer.h"
#import "NSString+IFStringExtensions.h"

static const int SEMVER_NUMBER_DEPTH = 3;

typedef NS_ENUM(NSUInteger, SemVerPart) {
    MMP = 1,
    PRE = 2,
    BM  = 3,
};

@implementation IFSemVer

-(instancetype) init {
    self = [super init];

    if (self) {
        [self set_null];
    }
    return self;
}

-(instancetype) set_null {
    self.version_numbers     =[[NSMutableArray alloc] init];
    for(int i = 0; i < SEMVER_NUMBER_DEPTH; i++) {
        [self.version_numbers addObject:@-1];
    }
    self.prerelease_segments = nil;
    self.build_metadata      = nil;
    return self;
}

-(NSString*) to_text {
    if ([self is_null]) return(@"null");

    NSMutableString* result = [[NSMutableString alloc] init];
    for (int i=0; (i<SEMVER_NUMBER_DEPTH) && ([self.version_numbers[i] intValue] >= 0); i++) {
        if (i>0) [result appendFormat:@"%c", '.'];
        [result appendFormat:@"%d", [self.version_numbers[i] intValue]];
    }
    if (self.prerelease_segments != nil) {
        int c = 0;
        unichar chr;

        for (int i = 0; i < (self.prerelease_segments).count; i++) {
            if (c++ == 0) chr = '-'; else chr = '.';
            [result appendFormat:@"%C%@", chr, self.prerelease_segments[i]];
        }
   }
    if (self.build_metadata != nil) [result appendFormat:@"+%@", self.build_metadata];
    return result;
}


-(bool) is_null {
    bool allow = true;
    for(int i = 0; i < SEMVER_NUMBER_DEPTH; i++) {
        if ([self.version_numbers[i] intValue] < -1) return true;    // should never happen
        if ([self.version_numbers[i] intValue] == -1) allow = false;
        else if (allow == false) return true;             // should never happen
    }
    if ([self.version_numbers[0] intValue] < 0) return true;
    return false;
}

-(instancetype) add_prerelease_content: (NSString*__strong*) pprerelease {
    if ((*pprerelease).length == 0) { return [self set_null]; }

    if (self.prerelease_segments == nil) {
        self.prerelease_segments = [[NSMutableArray alloc] init];
    }
    [self.prerelease_segments addObject:*pprerelease];
    *pprerelease = [[NSMutableString alloc] init];
    return self;
}

-(instancetype) initWithString: (NSString*) str {
    self = [super init];

    if (self) {
        [self set_null];

        // Rempve 'Version ' at start if present
        if ([str startsWithCaseInsensitive: @"Version "]) {
            str = [str substringFromIndex:8];
        }

        // Trim any whitespace
        str = str.stringByTrimmingWhitespace;

        int component    = 0;
        int val          = -1;
        int dots_used    = 0;
        int slashes_used = 0;
        int count        = 0;
        int part         = MMP;
        NSMutableString* prerelease = [[NSMutableString alloc] init];

        for (int pos = 0; pos < str.length; pos++) {
            unichar c = [str characterAtIndex:pos];
            switch(part) {
                case MMP:
                    if (c == '.') dots_used++;
                    if (c == '/') slashes_used++;
                    if ((c == '.') || (c == '/') || (c == '-') || (c == '+')) {
                        if (val == -1) return [self set_null];
                        if (component >= SEMVER_NUMBER_DEPTH) return [self set_null];

                        self.version_numbers[component] = @(val);
                        component++; val = -1; count = 0;
                        if (c == '-') part = PRE;
                        if (c == '+') part = BM;
                    } else if (isdigit(c)) {
                        int digit = c - '0';
                        if ((val == 0) && (slashes_used == 0)) return [self set_null];
                        if (val < 0) val = digit; else val = 10*val + digit;
                        count++;
                    } else return [self set_null];
                    break;
                case PRE:
                    if (c == '.') {
                        [self add_prerelease_content: &prerelease];
                    } else if (c == '+') {
                        [self add_prerelease_content: &prerelease];
                        part = BM;
                    } else {
                        [prerelease appendFormat:@"%C", c];
                    }
                    break;
                case BM:
                    if (self.build_metadata == nil) {
                        self.build_metadata = [[NSMutableString alloc] init];
                    }
                    [self.build_metadata appendFormat:@"%C", c];
                    break;
            }
        }

        if ((part == PRE) && (prerelease.length > 0)) [self add_prerelease_content: &prerelease];

        if ((dots_used > 0) && (slashes_used > 0)) return [self set_null];
        if (slashes_used > 0) {
            if (component > 1) return [self set_null];
            if (count != 6) return [self set_null];
            self.version_numbers[1] = @0;
            component = 2;
        }
        if (part == MMP) {
            if (val == -1) return [self set_null];
            if (component >= SEMVER_NUMBER_DEPTH) return [self set_null];
            self.version_numbers[component] = @(val);
        }
    }
    return self;
}

// The effect of this is to read unspecified versions of major, minor or patch as if they were 0:
-(int) floor:(int) N {
    if (N < 0) return 0;
    return N;
}

// This returns a non-negative integer if T contains only digits, and -1 otherwise. If the value has more than about 10 digits, then the result will not be meaningful, which I think is a technical violation of the standard.
-(int) strict_atoi: (NSString*) str {
    for(int i =0; i < str.length; i++) {
        unichar c = [str characterAtIndex:i];
        if (isdigit(c) == false) {
            return -1;
        }
    }
    unichar c = [str characterAtIndex:0];
    if ((c == '0') && str.length > 1) return -1;
    return str.intValue;
}

-(bool) le: (IFSemVer*) v2 {
    IFSemVer*v1 = self;

    for (int i=0; i<SEMVER_NUMBER_DEPTH; i++) {
        int N1 = [self floor:[v1.version_numbers[i] intValue]];
        int N2 = [self floor:[v2.version_numbers[i] intValue]];
        if (N1 > N2) return false;
        if (N1 < N2) return true;
    }

    int i1 = 0;
    int i2 = 0;

    NSString *str1 = v1.prerelease_segments && (v1.prerelease_segments.count>i1) ? v1.prerelease_segments[i1] : nil;
    NSString *str2 = v2.prerelease_segments && (v2.prerelease_segments.count>i2) ? v2.prerelease_segments[i2] : nil;

    if ((str1 == nil) && (str2 != nil)) return false;
    if ((str1 != nil) && (str2 == nil)) return true;
    do {
        int N1 = [self strict_atoi: str1];
        int N2 = [self strict_atoi: str2];
        if ((N1 >= 0) && (N2 >= 0)) {
            if (N1 < N2) return true;
            if (N1 > N2) return false;
        } else {
            NSComparisonResult c = [str1 compare: str2];
            if (c == NSOrderedAscending) return true;
            if (c == NSOrderedDescending) return false;
        }
        i1++;
        i2++;
        str1 = v1.prerelease_segments && (v1.prerelease_segments.count>i1) ? v1.prerelease_segments[i1] : nil;
        str2 = v2.prerelease_segments && (v2.prerelease_segments.count>i2) ? v2.prerelease_segments[i2] : nil;
    } while ((str1 != nil) && (str2 != nil));
    if ((str1 == nil) && (str2 != nil)) return true;
    if ((str1 != nil) && (str2 == nil)) return false;
    return true;
}

-(bool) eq: (IFSemVer*) v2 {
    if ([self le: v2] && [v2 le: self])
        return TRUE;
    return FALSE;
}

-(bool) ne: (IFSemVer*) v2 {
    return ![self eq: v2];
}

-(bool) gt: (IFSemVer*) v2 {
    return ![self le: v2];
}

-(bool) ge: (IFSemVer*) v2 {
    return [v2 le: self];
}

-(bool) lt: (IFSemVer*) v2 {
    return ![self ge: v2];
}

// And the following can be used for sorting, following the strcmp convention.
-(int) cmp: (IFSemVer*) v2 {
    if ([self eq: v2]) return 0;
    if ([self gt: v2]) return 1;
    return -1;
}

@end
