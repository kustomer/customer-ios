//
//  KUSImage.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/4/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface KUSImage : NSObject

+ (UIImage *)imageNamed:(NSString *)name;
+ (UIImage *)noImage;
+ (UIImage *)kustyImage;
+ (UIImage *)attachImage;
+ (UIImage *)sendArrowImage;
+ (UIImage *)checkmarkImage;
+ (UIImage *)pencilImage;
+ (UIImage *)errorImage;
+ (UIImage *)awayImage;
+ (UIImage *)tickImage;

+ (UIImage *)docIconExcel;
+ (UIImage *)docIconOther;
+ (UIImage *)docIconText;
+ (UIImage *)docIconVideo;
+ (UIImage *)docIconWord;
+ (UIImage *)docIconZip;
+ (UIImage *)docIconPdf;

+ (UIImage *)attachImageWithSize:(CGSize)size;
+ (UIImage *)sendImageWithSize:(CGSize)size color:(UIColor *)color;
+ (UIImage *)submitImageWithSize:(CGSize)size color:(UIColor *)color;
+ (UIImage *)circularImageWithSize:(CGSize)size color:(UIColor *)color;

+ (UIImage *)defaultAvatarImageForName:(NSString *)name;

+ (UIImage *)resizeImage:(UIImage *)image toFixedPixelCount:(CGFloat)maximumPixelCount;
+ (UIImage *)xImageWithColor:(UIColor *)color size:(CGSize)size lineWidth:(CGFloat)lineWidth;
+ (UIImage *)leftChevronWithColor:(UIColor *)color size:(CGSize)size lineWidth:(CGFloat)lineWidth;
+ (UIImage *)rightChevronWithColor:(UIColor *)color size:(CGSize)size lineWidth:(CGFloat)lineWidth;

@end
