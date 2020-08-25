//
//  KUSLocalizationManager.m
//  Kustomer
//
//  Created by Hunain Shahid on 03/05/2018.
//  Copyright © 2018 Kustomer. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "KUSLocalization.h"
#import "KUSLog.h"

@interface KUSLocalization ()
@end

@implementation KUSLocalization {
    NSString *highestConfidentLang;
}

#pragma mark - Lifecycle methods

+ (instancetype)sharedInstance
{
    static KUSLocalization *_sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedInstance = [[self alloc] init];
        [_sharedInstance setHighestConfidentLanguage];                      // Set Highest Confident Language on Start
    });
    return _sharedInstance;
}

#pragma mark - Public methods

- (void)printAllKeys
{
    NSBundle *bundle = [NSBundle bundleForClass:[self class]];
    bundle = [NSBundle bundleWithPath:[bundle pathForResource:@"Strings" ofType:@"bundle"]];
    NSString *path = [bundle pathForResource:@"Localizable" ofType:@"strings"];
    NSDictionary *dictionary = [NSDictionary dictionaryWithContentsOfFile:path];
    
    NSUInteger count = 0;
    NSString *keys = @"[";
    for (NSString* key in dictionary.allKeys) {
        keys = [keys stringByAppendingString:[NSString stringWithFormat:@"\"%@\"", key]];
        if (count < [dictionary.allKeys count] - 1) {
            keys = [keys stringByAppendingString:@", "];
        }
        count++;
    }
    keys = [keys stringByAppendingString:@"]"];
    KUSLogInfo(@"Localization Keys: %@", keys);
}

- (void)setLanguage:(NSString *)language
{
    _language = language;
    [self setHighestConfidentLanguage];
    
    if ([NSLocale characterDirectionForLanguage:highestConfidentLang] == NSLocaleLanguageDirectionRightToLeft) {
        [UIView appearance].semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
    } else {
        [UIView appearance].semanticContentAttribute = UISemanticContentAttributeForceLeftToRight;
    }
}

- (void)setKbDeflectLanguage:(NSString *)language
{
  _kbDeflectLanguage = language;
}

- (void)setTable:(NSString *)table
{
    _table = table;
}

- (NSString *)localizedString:(NSString *)key
{
    if (!highestConfidentLang) {
        [self setHighestConfidentLanguage];
    }
    
    NSString *customerKey = [NSString stringWithFormat:@"com.kustomer.%@", key];
    
    NSBundle *bundle = NSBundle.mainBundle;
    bundle = [NSBundle bundleWithPath:[bundle pathForResource:highestConfidentLang ofType:@"lproj"]];
    if (bundle != nil) {
        NSString *value = NSLocalizedStringWithDefaultValue(customerKey, _table, bundle, @"~.~", nil);
        if (![value isEqualToString:@"~.~"]) {
            return value;
        }
    }
    
    bundle = [NSBundle bundleForClass:[self class]];
    bundle = [NSBundle bundleWithPath:[bundle pathForResource:@"Strings" ofType:@"bundle"]];
    bundle = [NSBundle bundleWithPath:[bundle pathForResource:highestConfidentLang ofType:@"lproj"]];
    if (bundle != nil) {
        NSString *value = NSLocalizedStringWithDefaultValue(customerKey, nil, bundle, @"~.~", nil);
        if (![value isEqualToString:@"~.~"]) {
            return value;
        }
    }
    
    bundle = [NSBundle bundleForClass:[self class]];
    bundle = [NSBundle bundleWithPath:[bundle pathForResource:@"Strings" ofType:@"bundle"]];
    bundle = [NSBundle bundleWithPath:[bundle pathForResource:@"Base" ofType:@"lproj"]];
    return NSLocalizedStringWithDefaultValue(customerKey, nil, bundle, key, nil);
}

- (BOOL)isCurrentLanguageRTL
{
    if (!highestConfidentLang) {
        [self setHighestConfidentLanguage];
    }
    return ([NSLocale characterDirectionForLanguage:highestConfidentLang] == NSLocaleLanguageDirectionRightToLeft);
}

- (NSLocale *)currentLocale
{
    if (!highestConfidentLang) {
        [self setHighestConfidentLanguage];
    }
    return [[NSLocale alloc] initWithLocaleIdentifier:highestConfidentLang];
}

- (NSString *)currentLanguage
{
    if (!highestConfidentLang) {
        [self setHighestConfidentLanguage];
    }
    return highestConfidentLang;
}

- (void)setHighestConfidentLanguage
{
    NSBundle *bundle = nil;
    
    if (_language) {
        // Check language file in User Bundle (if exists)
        bundle = NSBundle.mainBundle;
        bundle = [NSBundle bundleWithPath:[bundle pathForResource:_language ofType:@"lproj"]];
        if (bundle != nil) {
            highestConfidentLang = _language;
            return;
        }
        
        // Check language file in Kustomer Bundle (if exists)
        bundle = [NSBundle bundleForClass:[self class]];
        bundle = [NSBundle bundleWithPath:[bundle pathForResource:@"Strings" ofType:@"bundle"]];
        bundle = [NSBundle bundleWithPath:[bundle pathForResource:_language ofType:@"lproj"]];
        if (bundle != nil) {
            highestConfidentLang = _language;
            return;
        }
    }
    
    NSArray<NSString *> *languages = [NSLocale preferredLanguages];
    NSUInteger size = MIN([languages count], 5);
    
    for (NSUInteger i = 0; i < size; i++) {
        // Check languages file of preffered language with region code
        bundle = NSBundle.mainBundle;
        bundle = [NSBundle bundleWithPath:[bundle pathForResource:languages[i] ofType:@"lproj"]];
        if (bundle != nil) {
            highestConfidentLang = languages[i];
            return;
        }
        
        bundle = [NSBundle bundleForClass:[self class]];
        bundle = [NSBundle bundleWithPath:[bundle pathForResource:@"Strings" ofType:@"bundle"]];
        bundle = [NSBundle bundleWithPath:[bundle pathForResource:languages[i] ofType:@"lproj"]];
        if (bundle != nil) {
            highestConfidentLang = languages[i];
            return;
        }
        
        // Check by removing region
        if ([languages[i] rangeOfString:@"-"].location != NSNotFound) {
            NSString *language = [languages[i] substringWithRange:NSMakeRange(0, [languages[i] rangeOfString:@"-"].location)];
            bundle = NSBundle.mainBundle;
            bundle = [NSBundle bundleWithPath:[bundle pathForResource:language ofType:@"lproj"]];
            if (bundle != nil) {
                highestConfidentLang = language;
                return;
            }
            
            bundle = [NSBundle bundleForClass:[self class]];
            bundle = [NSBundle bundleWithPath:[bundle pathForResource:@"Strings" ofType:@"bundle"]];
            bundle = [NSBundle bundleWithPath:[bundle pathForResource:language ofType:@"lproj"]];
            if (bundle != nil) {
                highestConfidentLang = language;
                return;
            }
        }
    }
    
    highestConfidentLang = @"en";               // If none of the specified language matched, set 'en' as default
}

@end
