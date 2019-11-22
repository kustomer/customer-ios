//
//  KUSText.m
//  Kustomer
//
//  Created by Daniel Amitay on 7/30/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSText.h"

#import <TSMarkdownParser/TSMarkdownParser.h>

@implementation KUSText

+ (NSAttributedString *)attributedStringFromText:(NSString *)text fontSize:(CGFloat)fontSize
{
    return [self attributedStringFromText:text fontSize:fontSize color:nil];
}

+ (NSAttributedString *)attributedStringFromText:(NSString *)text fontSize:(CGFloat)fontSize color:(UIColor *)color
{
    if (text == nil) {
        return nil;
    }

    TSMarkdownParser *parser = [TSMarkdownParser standardParser];

    parser.defaultAttributes = KUSAttributedFontWithSize(parser.defaultAttributes, fontSize, color);
    parser.imageAttributes = KUSAttributedFontWithSize(parser.imageAttributes, fontSize, color);
    parser.linkAttributes = KUSAttributedFontWithSize(parser.linkAttributes, fontSize, color);
    parser.monospaceAttributes = KUSAttributedFontWithSize(parser.monospaceAttributes, fontSize, color);
    parser.strongAttributes = KUSAttributedFontWithSize(parser.strongAttributes, fontSize, color);
    parser.emphasisAttributes = KUSAttributedFontWithSize(parser.emphasisAttributes, fontSize, color);

    return [parser attributedStringFromMarkdown:text];
}

NSDictionary<NSString *, id> *KUSAttributedFontWithSize(NSDictionary<NSString *, id> *attributes, CGFloat fontSize, UIColor *color) {
    NSMutableDictionary<NSString *, id> *mutableAttributes = [attributes mutableCopy];

    UIFont *currentFont = [attributes objectForKey:NSFontAttributeName];
    UIFont *newFont = nil;
    if (currentFont && currentFont.pointSize != fontSize) {
        newFont = [UIFont fontWithName:currentFont.familyName size:fontSize];
        [mutableAttributes setObject:newFont forKey:NSFontAttributeName];

    }

    if (color) {
        [mutableAttributes setObject:color forKey:NSForegroundColorAttributeName];
    }

    // Fix for emoji layout issue
    // https://github.com/TTTAttributedLabel/TTTAttributedLabel/issues/405#issuecomment-135864151
    NSMutableParagraphStyle *paragraphStyle = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineHeightMultiple = 1.0;
    if (newFont) {
        paragraphStyle.minimumLineHeight = newFont.lineHeight;
        paragraphStyle.maximumLineHeight = newFont.lineHeight;
    }
    [mutableAttributes setObject:paragraphStyle forKey:NSParagraphStyleAttributeName];

    return mutableAttributes;
};

static NSString *kEmailRegex = @"[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,5}";
+ (BOOL)isValidEmail:(NSString *)text
{
    if (text.length == 0) {
        return NO;
    }
    NSPredicate *emailPredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", kEmailRegex];
    return [emailPredicate evaluateWithObject:text];
}

static NSString *kPhoneRegex = @"(\\+\\d{1,2}\\s)?\\(?\\d{3}\\)?[\\s.-]?\\d{3}[\\s.-]?\\d{4}";
+ (BOOL)isValidPhone:(NSString *)text
{
    if (text.length == 0) {
        return NO;
    }
    NSPredicate *phonePredicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", kPhoneRegex];
    return [phonePredicate evaluateWithObject:text];
}
@end
