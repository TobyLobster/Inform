//
//  IFCompilerList.m
//  Inform
//
//  Created by Toby Nelson on 17/02/2019.
//

#import <Foundation/Foundation.h>
#import "RegEx.h"
#import "IFCompilerList.h"
#import "IFCompilerListEntry.h"

@implementation IFCompilerList

+ (NSMutableArray *)compilerList {
    static NSMutableArray *_compilerList = nil;
    if (_compilerList == nil) {
        _compilerList = [self readCompilerRetrospectiveFile];
    }
    return _compilerList;
}

+(NSMutableArray *) readCompilerRetrospectiveFile {
    NSString *filepath = [[NSBundle mainBundle] pathForResource:@"App/Compilers/retrospective" ofType:@"txt"];
    NSError *error;
    NSString *contents = [NSString stringWithContentsOfFile:filepath encoding: NSUTF8StringEncoding error:&error];
    NSArray *results = [contents componentsSeparatedByString:@"\n"];
    NSMutableArray *result = [[NSMutableArray alloc] init];

    NSString *regEx = @"\\s*\\'(.*?)\\'\\s*,\\s*\\'(.*?)\\'\\s*,\\s*\\'(.*?)\\'\\s*";

    for (NSString *line in results)
    {
        if ([line length] > 0)
        {
            NSString *id = [line stringByMatching:regEx capture:1L];
            NSString *displayName = [line stringByMatching:regEx capture:2L];
            NSString *description = [line stringByMatching:regEx capture:3L];

            IFCompilerListEntry * entry = [[IFCompilerListEntry alloc] initWithId:id displayName:displayName description:description];
            [result addObject: entry];
        }
    }

    return result;
}

@end
