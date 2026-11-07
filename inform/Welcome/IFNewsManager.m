//
//  IFNewsManager.m
//  Inform
//
//  Created by Toby Nelson on 20/06/2022.
//

#import <Foundation/Foundation.h>
#import "IFNewsManager.h"

@implementation IFNewsManager {
    /// Where the news is kept, with when it was downloaded
    NSUserDefaults* defaults;
    /// What downloads the news
    NSURLSession* session;
}

-(instancetype) init {
    return [self initWithDefaults: [NSUserDefaults standardUserDefaults]
                          session: [NSURLSession sharedSession]];
}

-(instancetype) initWithDefaults: (NSUserDefaults*) newDefaults
                         session: (NSURLSession*) newSession {
    self = [super init];
    if( self ) {
        defaults = newDefaults;
        session = newSession;
        self.newsSchemeHandler = [[IFNewsCustomSchemeHandler alloc] init];
    }
    return self;
}

-(void)     getNewsWithCompletionHandler: (void (^)(NSString * _Nullable news, NSURLResponse * _Nullable response, NSError * _Nullable error)) completionHandler {
    __block NSString* latestNews = @"";

    NSDate* now = [NSDate date];

    // Do we have a recent cached news?
    // Step 1: Get timestamp of previous news
    NSDate* newsTimestamp = [defaults objectForKey: @"newsTimestamp"];
    if (newsTimestamp != nil) {
        // Step 2: Check that it was recent
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSInteger components = (NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear);

        // Extract the day itself for now, and the cached version
        NSDateComponents *nowComponents  = [calendar components:components fromDate:now];
        NSDateComponents *cachedComponents = [calendar components:components fromDate:newsTimestamp];

        NSDate *nowDate     = [calendar dateFromComponents:nowComponents];
        NSDate *cachedDate  = [calendar dateFromComponents:cachedComponents];

        NSComparisonResult result = [nowDate compare:cachedDate];
        if (result == NSOrderedSame) {
            // Step 3: Get cached news
            latestNews = [defaults stringForKey: @"newsString"];
            [self gotNews: latestNews completionHandler: completionHandler response: nil error: nil];
            return;
        }
    }

    // No - download latest news
    NSURL* url = [NSURL URLWithString:@"https://iftechfoundation.org/calendar/cal.txt"];

    NSURLSessionDataTask* task = [session dataTaskWithURL: url
                                        completionHandler: ^(NSData* data, NSURLResponse* response, NSError* error) {
        // A server's error page isn't news
        BOOL serverFailed = NO;
        if ([response isKindOfClass: [NSHTTPURLResponse class]]) {
            NSInteger status = ((NSHTTPURLResponse*) response).statusCode;
            serverFailed = (status < 200) || (status >= 300);
        }

        if (data != nil && !serverFailed) {
            latestNews = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (latestNews == nil) {
                latestNews = @"";
            }

            // Save latest news in cache
            [self->defaults setObject: now forKey:@"newsTimestamp"];
            [self->defaults setObject: latestNews forKey:@"newsString"];

            [self gotNews: latestNews completionHandler: completionHandler response: response error: error];
        }
        else {
            // log but basically ignore any error downloading the news
            NSLog(@"%@", error ?: response);
            completionHandler(@"", response, error);
            return;
        }
    }];
    [task resume];
}

-(void)     gotNews: (NSString*) latestNews
  completionHandler: (void (^)(NSString * _Nullable news, NSURLResponse * _Nullable response, NSError * _Nullable error)) completionHandler
           response: (NSURLResponse*) response
              error: (NSError*) error {
    // Call the completion handler on another thread, as the download's is
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    dispatch_async(queue,
    ^{
        completionHandler(latestNews, response, error);
    });
}

@end
