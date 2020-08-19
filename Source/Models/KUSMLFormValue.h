//
//  KUSMLFormValue.h
//  Kustomer
//
//  Created by BrainX Technologies on 01/10/2018.
//  Copyright © 2018 Kustomer. All rights reserved.
//

#import "KUSModel.h"
#import "KUSMLNode.h"

@interface KUSMLFormValue : KUSModel

@property (nonatomic, copy, readonly) NSString * _Nonnull displayName;
@property (nonatomic, assign, readonly) BOOL lastNodeRequired;
@property (nonatomic, copy) NSArray<KUSMLNode *> * _Nullable mlNodes;

@end
