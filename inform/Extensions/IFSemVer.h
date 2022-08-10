//
//  IFSemVer.h
//  Inform
//
//  Created by Toby Nelson on 10/08/2022.
//

#ifndef IFSemVer_h
#define IFSemVer_h

#pragma mark -
@interface IFSemVer : NSObject

@property (atomic)      NSMutableArray* version_numbers;
@property (atomic)      NSMutableArray* prerelease_segments;
@property (atomic)      NSMutableString* build_metadata;

-(instancetype) init;
-(instancetype) initWithString: (NSString*) versionString;
-(NSString*) to_text;
-(int) cmp: (IFSemVer*) v2;

@end

#endif /* IFSemVer_h */
