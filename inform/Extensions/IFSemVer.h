//
//  IFSemVer.h
//  Inform
//
//  Created by Toby Nelson on 10/08/2022.
//

#ifndef IFSemVer_h
#define IFSemVer_h

#pragma mark -
NS_ASSUME_NONNULL_BEGIN

@interface IFSemVer : NSObject

@property (atomic)      NSMutableArray<NSNumber*>* version_numbers;
@property (atomic, nullable) NSMutableArray<NSString*>* prerelease_segments;
@property (atomic, nullable) NSMutableString* build_metadata;

-(instancetype) init NS_DESIGNATED_INITIALIZER;
-(instancetype) initWithString: (NSString*) versionString NS_DESIGNATED_INITIALIZER;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *to_text;
-(int) cmp: (IFSemVer*) v2;

@end

NS_ASSUME_NONNULL_END

#endif /* IFSemVer_h */
