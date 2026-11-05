//
//  IFExtensionInfo.m
//  Inform
//
//  Created by Andrew Hunter on 06/03/2005.
//  Copyright 2005 Andrew Hunter. All rights reserved.
//  Rewritten by Toby Nelson in 2014.
//

#import "IFExtensionInfo.h"
#import "NSString+IFStringExtensions.h"

@implementation IFExtensionInfo

-(instancetype) initWithDisplayName: (NSString*) displayName
                 filepath: (NSString*) filepath
                   author: (NSString*) author
                  version: (NSString*) version
                isBuiltIn: (BOOL) isBuiltIn {
	self = [super init];
    
	if (self) {
        self.displayName = displayName;
        self.filepath    = filepath;
        self.author      = author;
        self.version     = version;
        self.isBuiltIn   = isBuiltIn;
    }

    return self;
}

-(NSComparisonResult) caseInsensitiveCompare:(IFExtensionInfo *) b {
    NSComparisonResult result = [self.displayName localizedCaseInsensitiveCompare: b.displayName];
    if( result != NSOrderedSame ) {
        return result;
    }
    result = [self.author localizedCaseInsensitiveCompare: b.author];
    if( result != NSOrderedSame ) {
        return result;
    }

    result = [self.filepath compare: b.filepath];
    if( result != NSOrderedSame ) {
        return result;
    }

    return NSOrderedSame;
}


+(NSString*) canonicalTitle: (NSString*) displayName {
    // Remove any initial "The " from the name.
    NSString* result = displayName;
    if( [result.lowercaseString startsWith: @"the "] ) {
        result = [result substringFromIndex:4];
    } else if( [result.lowercaseString startsWith: @"a "] ) {
        result = [result substringFromIndex:2];
    } else if( [result.lowercaseString startsWith: @"an "] ) {
        result = [result substringFromIndex:3];
    }
    
    // Remove proviso in brackets
    if ( [result endsWith:@")"] ) {
        // The name of the extension may be followed by a proviso in brackets: remove it
        NSUInteger location = [result rangeOfString:@" ("].location;
        if(( location != NSNotFound ) && (location > 1)) {
            result = [result substringToIndex: location];
        }
    }
    return result;
}

-(NSString*) safeVersion {
    if (self.version == nil) {
        return @"Version (none)";
    }
    return self.version;
}

-(IFSemVer*) semver {
    if (self.version == nil) {
        return [[IFSemVer alloc] init];
    }

    IFSemVer* result = [[IFSemVer alloc] initWithString: self.version];
    return result;
}

-(BOOL) stringEqual:(NSString*) string1 to:(NSString*) string2 {
    if(( string1 == nil ) || (string2 == nil ))
    {
        return (string1 == string2);
    }

    return [string1 isEqual: string2];
}


- (BOOL)isEqual:(id)other {
    if (other == self)
        return YES;
    if (!other || ![other isKindOfClass:[self class]])
        return NO;
    IFExtensionInfo * another = other;

    if( ![self stringEqual: self.displayName to: another.displayName] )
        return NO;
    if( ![self stringEqual: self.filepath to: another.filepath] )
        return NO;
    if( ![self stringEqual: self.author to: another.author] )
        return NO;
    if( ![self stringEqual: self.version to: another.version] )
        return NO;
    if( self.isBuiltIn != another.isBuiltIn )
        return NO;
    return YES;
}

- (NSUInteger)hash {
    return self.displayName.hash ^ self.filepath.hash ^ self.author.hash ^ self.version.hash ^ (NSUInteger) self.isBuiltIn;
}

@end
