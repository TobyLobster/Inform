//
//  IFUtility.m
//  Inform
//
//  Created by Toby Nelson, 2014
//

#import "IFUtility.h"
#import "IFPreferences.h"
#import <Foundation/NSCache.h>

static NSLock*       uniqueIdLock;
static unsigned long uniqueId = 1000;
static NSURL*        temporaryFolder = nil;

float lerp(float progress, float from, float to) {
    return from + progress * (to - from);
}

float smoothstep(float t) {
    return t*t*(3-2*t);
}

float easeOutQuad(float t) {
    return -t*(t-2);
};

float easeOutCubic(float t) {
    t--;
    return (t*t*t + 1);
};

#pragma mark - "IFUtility"
@implementation IFUtility

// = Initialisation =
+ (void) initialize {
    uniqueIdLock = [[NSLock alloc] init];
}

#pragma mark - Generating unique IDs
+ (unsigned long) generateID {
    unsigned long new_id;
    [uniqueIdLock lock];
    new_id = uniqueId++;
    [uniqueIdLock unlock];
    return new_id;
}

#pragma mark - String handling
// Are the strings equal, where the strings may be nil...
+ (bool) safeString:(NSString*) string1 insensitivelyEqualsSafeString:(NSString*) string2 {
    if(( string1 == nil ) || ( string2 == nil )) {
        return (string1 == string2);
    }
    return ([string1 caseInsensitiveCompare: string2] == NSOrderedSame);
}

+(bool) url: (NSURL*) url1
     equals: (NSURL*) url2 {
    bool sameScheme = [IFUtility safeString: [url1 scheme]
              insensitivelyEqualsSafeString: [url2 scheme]];
    bool samePath   = [IFUtility safeString: [url1 path]
              insensitivelyEqualsSafeString: [url2 path]];
    bool sameQuery  = [IFUtility safeString: [url1 query]
              insensitivelyEqualsSafeString: [url2 query]];
    return sameScheme && samePath && sameQuery;
}

+ (NSString*) localizedString: (NSString*) key {
    return [[NSBundle mainBundle] localizedStringForKey: key
                                                  value: key
                                                  table: nil];
}

+ (NSString*) localizedString: (NSString*) key
                      default: (NSString*) value {
    return [[NSBundle mainBundle] localizedStringForKey: key
                                                  value: value
                                                  table: nil];
}

+ (NSString*) localizedString: (NSString*) key
                      default: (NSString*) value
                        table: (NSString*) table {
    return [[NSBundle mainBundle] localizedStringForKey: key
                                                  value: value
                                                  table: table];
}

#pragma mark - URL scheme parsing
+ (NSDictionary*) queryParametersFromURL:(NSURL*) sourceURL {
    NSMutableDictionary* results = [[NSMutableDictionary alloc] init];

    NSString* path = [[sourceURL resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding: NSASCIIStringEncoding];
    NSArray* query = [path componentsSeparatedByString: @"?"];
    if( [query count] < 2 ) {
        return results;
    }
    query = [query[1] componentsSeparatedByString:@"#"];

    NSArray* keyValues = [query[0] componentsSeparatedByString: @"="];

    for( int i = 0; i < (keyValues.count-1); i += 2 ) {
        [results setObject:keyValues[i+1] forKey:keyValues[i]];
    }
    return results;
}

+ (NSString*) fragmentFromURL:(NSURL*) sourceURL {
    NSString* path = [[sourceURL resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding: NSASCIIStringEncoding];
    NSArray* array = [path componentsSeparatedByString:@"#"];
    if( [array count] < 2 ) {
        return @"";
    }
    return array[1];
}

+ (NSString*) heirarchyFromURL:(NSURL*) sourceURL {
    NSString* path = [[sourceURL resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding: NSASCIIStringEncoding];
    int query  = [path indexOf:@"?"];
    int hash   = [path indexOf:@"#"];
    int result = (int) [path length];
    if( query >= 0 ) result = MIN(result, query);
    if( hash  >= 0 ) result = MIN(result, hash);

    return [path substringToIndex: result];
}

+ (NSArray*) decodeSourceSchemeURL:(NSURL*) sourceURL {
    NSString* path = [[sourceURL resourceSpecifier] stringByReplacingPercentEscapesUsingEncoding: NSASCIIStringEncoding];

    // Get line number from fragment
    NSString* fragment = [IFUtility fragmentFromURL: sourceURL];
    if ([fragment length] == 0) {
        NSLog(@"Bad source URL, no fragment: %@", path);
        return @[];
    }

    // sourceLine can have format 'line10' or '10'. 'line10' is more likely
    int lineNumber = [fragment intValue];

    if (lineNumber == 0 && [[fragment substringToIndex: 4] isEqualToString: @"line"]) {
        lineNumber = [[fragment substringFromIndex: 4] intValue];
    }

    // Get source filename
    NSString* sourceFile = [IFUtility heirarchyFromURL: sourceURL];
    if( sourceFile == nil ) {
        return nil;
    }

    // Get test case from query parameters
    NSDictionary * parameters = [IFUtility queryParametersFromURL: sourceURL];
    NSString* testCase = [parameters objectForKey:@"case"];
    if( testCase == nil ) testCase = @"";

    return @[sourceFile, testCase, @(lineNumber)];
}

+ (NSArray*) decodeSkeinSchemeURL:(NSURL*) skeinURL {
    // e.g: Input 'skein:1003?case=B' returns [B,1003]

    if( ![[skeinURL scheme] isEqualToStringCaseInsensitive: @"skein"] )
    {
        return nil;
    }

    // Get node id from heirarchy
    NSString* nodeIdString = [IFUtility heirarchyFromURL: skeinURL];
    unsigned long nodeId = [nodeIdString integerValue];

    // Get test case from query parameters
    NSDictionary * parameters = [IFUtility queryParametersFromURL: skeinURL];
    NSString* testCase = [parameters objectForKey:@"case"];
    if( testCase == nil ) testCase = @"";

    return @[testCase, @(nodeId)];
}

#pragma mark - Alert dialogs
+ (void) runAlertWarningWindow: (NSWindow*) window
                         title: (NSString*) title
                       message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);
    
    [[self class] runAlertWindow: window
                       localized: NO
                         warning: YES
                           title: [self localizedString: title]
                         message: @"%@", contents];
}

+ (void) runAlertInformationWindow: (NSWindow*) window
                             title: (NSString*) title
                           message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);
    
    [[self class] runAlertWindow: window
                       localized: NO
                         warning: NO
                           title: [self localizedString: title]
                         message: @"%@", contents];
}


+ (void) runAlertWindow: (NSWindow*) window
              localized: (BOOL) alreadyLocalized
                warning: (BOOL) warningStyle
                  title: (NSString*) title
                message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: alreadyLocalized ? formatString : [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:  [self localizedString: @"OK"]];
    [alert setMessageText:      alreadyLocalized ? title : [self localizedString: title]];
    [alert setInformativeText:  contents];
    [alert setAlertStyle:       warningStyle ? NSWarningAlertStyle : NSInformationalAlertStyle];

    // NOTE: We don't use [NSAlert beginSheetModalForWindow:completionHandler:] because it is only available in 10.9
    [alert beginSheetModalForWindow: window
                      modalDelegate: nil
                     didEndSelector: nil
                        contextInfo: nil];
}

+ (void) runAlertYesNoWindow: (NSWindow*) window
                       title: (NSString*) title
                         yes: (NSString*) yes
                          no: (NSString*) no
               modalDelegate: (id) modalDelegate
              didEndSelector: (SEL) alertDidEndSelector
                 contextInfo: (void *) contextInfo
                     message: (NSString*) formatString, ... {
    va_list args;
    va_start(args, formatString);
    NSString* contents = [[NSString alloc] initWithFormat: [self localizedString:formatString]
                                                 arguments: args];
    va_end(args);

    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:  [self localizedString: yes]];
    [alert addButtonWithTitle:  [self localizedString: no]];
    [alert setMessageText:      [self localizedString: title]];
    [alert setInformativeText:  contents];
    [alert setAlertStyle: NSInformationalAlertStyle];

    // NOTE: We don't use [NSAlert beginSheetModalForWindow:completionHandler:] because it is only available in 10.9
    [alert beginSheetModalForWindow: window
                      modalDelegate: modalDelegate
                     didEndSelector: alertDidEndSelector
                        contextInfo: contextInfo];
}

// Save transcript (handles save dialog)
+(void) saveTranscriptPanelWithString: (NSString*) string
                               window: (NSWindow*) window {

    NSSavePanel* panel = [NSSavePanel savePanel];

    [panel setAllowedFileTypes: @[@"txt"]];

    // Work out starting directory
    NSString*   prefString   = [[NSUserDefaults standardUserDefaults] objectForKey: @"IFTranscriptURL"];
    NSURL*      directoryURL = [NSURL URLWithString: prefString];
    if (directoryURL == nil) {
        directoryURL = [NSURL fileURLWithPath: NSHomeDirectory()];
    }

    [panel setDirectoryURL: directoryURL];

    // Show it
    [panel beginSheetModalForWindow: window completionHandler:^(NSInteger returnCode)
     {
         if (returnCode != NSOKButton) return;

         // Remember the directory we last saved into
         if ( [[panel directoryURL] absoluteString] != nil ) {
             NSString* writePrefString = [[panel directoryURL] absoluteString];
             [[NSUserDefaults standardUserDefaults] setObject: writePrefString
                                                       forKey: @"IFTranscriptURL"];
         }

         // Save the data
         NSData* stringData = [string dataUsingEncoding: NSUTF8StringEncoding];
         [stringData writeToURL: [panel URL]
                     atomically: YES];
     }];
}


#pragma mark - Sandboxing
+ (BOOL) isSandboxed {
    NSDictionary* environ = [[NSProcessInfo processInfo] environment];
    return (nil != environ[@"APP_SANDBOX_CONTAINER_ID"]);
}

#pragma mark - Getting useful paths / URLs
+(NSURL*) publicLibraryURL {
    NSString* publicLibraryURLString;
    if( [[IFPreferences sharedPreferences] publicLibraryDebug] && ![IFUtility isSandboxed]) {
        publicLibraryURLString = [NSHomeDirectory() stringByAppendingPathComponent:@"Documents"];
        publicLibraryURLString = [publicLibraryURLString stringByAppendingPathComponent:@"InformPublicLibrary"];
        publicLibraryURLString = [publicLibraryURLString stringByAppendingPathComponent:@"index.html"];
        return [NSURL fileURLWithPath: publicLibraryURLString];
    }
    return [NSURL URLWithString: [IFUtility localizedString: @"PublicLibraryURL"]];
}

+ (NSString*) informSupportPath: (NSString *)firstArg, ... {
    // Get library directory (possibly in a sandboxed container).
    NSString *newPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];

    // Add inform subdirectory
    newPath = [newPath stringByAppendingPathComponent:@"Inform"];

    // Add any additional subdirectories
    va_list args;
    va_start(args, firstArg);
    for (NSString *arg = firstArg; arg != nil; arg = va_arg(args, NSString*))
    {
        newPath = [newPath stringByAppendingPathComponent: arg];
    }
    va_end(args);

    // Return path
    return newPath;
}

+ (NSString*) pathForInformExternalAppSupport {
    return [self informSupportPath: nil, nil];
}

+ (NSString*) pathForInformExternalExtensions {
    return [IFUtility informSupportPath: @"Extensions", nil];
}

+ (NSString*) pathForInformExternalLibraries {
    return [IFUtility informSupportPath: @"Libraries", nil];
}

+ (NSString*) pathForInformExternalDocumentation {
    return [IFUtility informSupportPath: @"Documentation", nil];
}

+ (NSString*) pathForInformInternalAppSupport {
    return [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent: @"Internal"];
}

+ (NSString*) pathForInformInternalExtensions {
    return [[IFUtility pathForInformInternalAppSupport] stringByAppendingPathComponent:@"Extensions"];
}

+ (NSString*) pathForInformInternalLibraries {
    return [[IFUtility pathForInformInternalAppSupport] stringByAppendingPathComponent:@"Libraries"];
}

+ (NSString*) pathForInformInternalDocumentation {
    return [[IFUtility pathForInformInternalAppSupport] stringByAppendingPathComponent:@"Documentation"];
}

+(NSURL*) temporaryDirectoryURL {
    if( temporaryFolder == nil ) {
        NSError* error;
        temporaryFolder = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:[[NSProcessInfo processInfo] globallyUniqueString]] isDirectory:YES];
        [[NSFileManager defaultManager] createDirectoryAtPath: temporaryFolder.path
                                  withIntermediateDirectories: YES
                                                   attributes: nil
                                                        error: &error];
    }
    return temporaryFolder;
}

+(BOOL) hasFullscreenSupportFeature {
    // Lion (10.7) introduced fullscreen support
    return NSAppKitVersionNumber >= NSAppKitVersionNumber10_7;
}

+(BOOL) hasScrollElasticityFeature {
    // Lion (10.7) introduced elasticity on scrolling
    return NSAppKitVersionNumber >= NSAppKitVersionNumber10_7;
}

+ (BOOL) hasUpdatedToolbarFeature {
    return NSAppKitVersionNumber > NSAppKitVersionNumber10_10_Max;
}

+(void) performSelector:(SEL) selector object:(id) object {
    if( [object respondsToSelector: selector] ) {
        // ARC safe way to do performSelector (see http://stackoverflow.com/a/20058585/4786529 ) ...
        IMP imp = [object methodForSelector: selector];
        void (*func)(id, SEL) = (void *) imp;
        func(object, selector);
    }
}

+(NSDictionary*) adjustAttributesFontSize: (NSDictionary*) dictionary
                                     size: (float) fontSize {
    NSMutableDictionary* mutableResult = [dictionary mutableCopy];
    NSFont* font = mutableResult[NSFontAttributeName];
    font = [NSFont fontWithName: font.fontName
                           size: fontSize];
    [mutableResult setObject: font forKey: NSFontAttributeName];
    return [mutableResult copy];
}


@end
