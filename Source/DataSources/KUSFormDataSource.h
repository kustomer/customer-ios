//
//  KUSFormDataSource.h
//  Kustomer
//
//  Created by Daniel Amitay on 12/20/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSObjectDataSource.h"
#import "KUSForm.h"

@interface KUSFormDataSource : KUSObjectDataSource


- (instancetype)initWithUserSession:(KUSUserSession *)userSession formId:(NSString *)formId;
- (NSString *)getConversationalFormId;

@end
