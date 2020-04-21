//
//  KUSFormQuestion.m
//  Kustomer
//
//  Created by Daniel Amitay on 12/19/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSFormQuestion.h"
#import "KUSLocalization.h"

@implementation KUSFormQuestion

#pragma mark - Class methods

+ (NSString * _Nullable)modelType
{
    return nil;
}

+ (BOOL)enforcesModelType
{
    return NO;
}

#pragma mark - Lifecycle methods

- (instancetype)initWithJSON:(NSDictionary *)json
{
    self = [super initWithJSON:json];
    if (self) {
        _name = NSStringFromKeyPath(json, @"name");
        _prompt = NSStringFromKeyPath(json, @"prompt");
        _skipIfSatisfied = BOOLFromKeyPath(json, @"skipIfSatisfied");
        _type = KUSFormQuestionTypeFromString(NSStringFromKeyPath(json, @"type"));
        _property = KUSFormQuestionPropertyFromString(NSStringFromKeyPath(json, @"property"));
        if (_property == KUSFormQuestionPropertyMLV) {
            NSMutableDictionary *dic = [[NSMutableDictionary alloc]initWithDictionary:[json valueForKeyPath:@"valueMeta"]];
            [dic setObject:@"1" forKey:@"id"];
            _mlFormValues = [[KUSMLFormValue alloc] initWithJSON: dic];
        }
        if(_type == KUSFormQuestionTypeKBDeflectQuestion){
          NSString* followUpPrompt = NSStringFromKeyPath(json, @"followUpPrompt");
          if(!followUpPrompt){
            _followUpQuestion = [[KUSLocalization sharedInstance] localizedString:@"kus_com_kustomer_articles_followup_question"];
          }else{
            _followUpQuestion = NSStringFromKeyPath(json, @"followUpPrompt");
          }
          
          // NSArray *filteredArray = [jsonInputResponses filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id object, NSDictionary *bindings) {
          //   if([[object valueForKey:@"hasResults"] boolValue]){
          //     _hasResultResponse = NSStringFromKeyPath(object, @"displayValue");
          //   }else{
          //     _noResultResponse = NSStringFromKeyPath(object, @"displayValue");
          //   }
          //   return rv;
          // }]];
          NSArray *jsonInputResponses = NSArrayFromKeyPath(json, @"inputResponses");
          for(NSDictionary* item in jsonInputResponses){
            if([[item valueForKey:@"hasResults"] boolValue]){
              _hasResultResponse = NSStringFromKeyPath(item, @"displayValue");
            }else{
              _noResultResponse = NSStringFromKeyPath(item, @"displayValue");
            }
          }
          
          NSArray *jsonValues = NSArrayFromKeyPath(json, @"values");
          for(NSDictionary* item in jsonValues){
            if([[item valueForKey:@"endChat"] boolValue]){
              _endChatDisplayName = NSStringFromKeyPath(item, @"displayName");
            }else{
              _continueChatDisplayName = NSStringFromKeyPath(item, @"displayName");
            }
          }
          
          // _hasResultResponse = ;
          // _noResultResponse = ;
          // _endChatDisplayName = ;
          // _continueChatDisplayName = ;
        }
        
        NSArray<NSString *> *values = NSArrayFromKeyPath(json, @"values");
        if (values.count) {
            NSMutableArray<NSString *> *mappedValues = [[NSMutableArray alloc] initWithCapacity:values.count];
            for (NSString *value in values) {
                [mappedValues addObject:[[NSString alloc] initWithFormat:@"%@", value]];
            }
            _values =  mappedValues;
        }
    }
    return self;
}

+ (NSArray<KUSFormQuestion *> *_Nullable)objectsWithJSONs:(NSArray<NSDictionary *> * _Nullable)jsons
{
  NSMutableArray<KUSFormQuestion *> *objects = [[NSMutableArray alloc] initWithCapacity:jsons.count];
  for (NSDictionary *json in jsons) {
    KUSFormQuestion *object = [[self alloc] initWithJSON:json];
    if (object) {
      [objects addObject:object];
      if(object.type == KUSFormQuestionTypeKBDeflectQuestion){
        KUSFormQuestion* kbResponse = [[KUSFormQuestion alloc] initWithJSON:json];
        kbResponse.type = KUSFormQuestionTypeKBDeflectResponse;
        [objects addObject:kbResponse];
      }
    }
  }
  return objects;
}

static KUSFormQuestionType KUSFormQuestionTypeFromString(NSString *string)
{
    if ([string isEqualToString:@"message"]) {
        return KUSFormQuestionTypeMessage;
    } else if ([string isEqualToString:@"property"]) {
        return KUSFormQuestionTypeProperty;
    } else if ([string isEqualToString:@"response"]) {
        return KUSFormQuestionTypeResponse;
    } else if ([string isEqualToString:@"kbDeflect"]) {
      return KUSFormQuestionTypeKBDeflectQuestion;
    }
    return KUSFormQuestionTypeUnknown;
}

static KUSFormQuestionProperty KUSFormQuestionPropertyFromString(NSString *string)
{
    if ([string isEqualToString:@"customer_name"]) {
        return KUSFormQuestionPropertyCustomerName;
    } else if ([string isEqualToString:@"customer_email"]) {
        return KUSFormQuestionPropertyCustomerEmail;
    } else if ([string isEqualToString:@"conversation_team"]) {
        return KUSFormQuestionPropertyConversationTeam;
    } else if ([string isEqualToString:@"customer_phone"]) {
        return KUSFormQuestionPropertyCustomerPhone;
    } else if ([string isEqualToString:@"followup_channel"]) {
        return KUSFormQuestionPropertyFollowupChannel;
    } else if ([string hasSuffix:@"Tree"]) {
        return KUSFormQuestionPropertyMLV;
    } else if ([string hasSuffix:@"Str"] || [string hasSuffix:@"Num"]) {
        return KUSFormQuestionPropertyValues;
    }
    return KUSFormQuestionPropertyUnknown;
}

+ (BOOL)KUSFormQuestionRequiresResponse:(KUSFormQuestion *)question
{
  return question.type == KUSFormQuestionTypeProperty ||
  question.type == KUSFormQuestionTypeResponse ||
  question.type == KUSFormQuestionTypeKBDeflectQuestion ||
  question.type == KUSFormQuestionTypeKBDeflectResponse;
}

+ (BOOL)KUSFormQuestionIsEndChat:(KUSFormQuestion *)question
{
  if(question == nil || question.type == nil){
    return false;
  }
  return question.type == KUSFormQuestionTypeKBDeflectedSuccessfully;
}


@end
