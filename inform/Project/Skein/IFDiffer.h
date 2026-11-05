//
//  IFDiffer.h
//  Inform
//
//  Created by Toby Nelson in 2015
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(int, EFormOfEdit) {
    DELETE_EDIT           = -1,
    PRESERVE_EDIT         =  0,
    PRESERVE_ACTUAL_EDIT  =  1,
    INSERT_EDIT           =  2
};

// *******************************************************************************************
@interface IFDiffEdit : NSObject

@property (nonatomic, readonly) NSRange     fragment;
@property (nonatomic, readonly) EFormOfEdit formOfEdit;

-(instancetype) init NS_UNAVAILABLE;
-(instancetype) initWithRange: (NSRange) range
                         form: (EFormOfEdit) form;

@end

// *******************************************************************************************
@interface IFDiffer : NSObject

@property (nonatomic, nullable) NSString*       ideal;
@property (nonatomic, nullable) NSString*       actual;
@property (nonatomic) NSMutableArray<IFDiffEdit*>* differences;


-(BOOL) diffIdeal: (nullable NSString*) theIdeal
           actual: (nullable NSString*) theActual;

@end

NS_ASSUME_NONNULL_END
