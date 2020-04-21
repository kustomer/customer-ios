//
//  KUSChatMessage.h
//  Kustomer
//
//  Created by Daniel Amitay on 7/4/17.
//  Copyright © 2017 Kustomer. All rights reserved.
//

#import "KUSModel.h"
#import "KUSChatAttachment.h"

typedef NS_ENUM(NSInteger, KUSChatMessageDirection) {
    KUSChatMessageDirectionIn,
    KUSChatMessageDirectionOut
};

typedef NS_ENUM(NSInteger, KUSChatMessageType) {
    KUSChatMessageTypeText,
    KUSChatMessageTypeImage,
    KUSChatMessageTypeAttachment,
    KUSChatMessageTypeArticle
};

typedef NS_ENUM(NSInteger, KUSChatMessageState) {
    KUSChatMessageStateSent,
    KUSChatMessageStateSending,
    KUSChatMessageStateFailed
};

NS_ASSUME_NONNULL_BEGIN

@interface KUSChatMessage : KUSModel

@property (nonatomic, copy, readonly) NSString *trackingId;
@property (nonatomic, copy, readonly) NSString *body;
@property (nonatomic, copy, readonly) NSURL *imageURL;  // Only if type is Image
@property (nonatomic, copy, readonly) NSArray<NSString *> *attachmentIds;

@property (nonatomic, copy, readonly) NSDate *createdAt;
@property (nonatomic, copy, readonly) NSDate *importedAt;
@property (nonatomic, assign, readonly) KUSChatMessageDirection direction;
@property (nonatomic, copy, readonly, nullable) NSString *sentById;
@property (nonatomic, copy, readonly, nullable) NSString *campaignId;

@property (nonatomic, assign, readwrite) KUSChatMessageType type;
@property (nonatomic, assign, readwrite) KUSChatMessageState state;
@property (nonatomic, copy, readwrite, nullable) NSString *value;

@property (nonatomic, copy, readwrite) NSString *attachmentFileName;
@property (nonatomic, copy, readwrite) NSString *displayAttachmentFileName;
@property (nonatomic, copy, readwrite) NSString *attachmentContentLength;
@property (nonatomic, copy, readwrite) NSString *attachmentMIMEType;
@property (atomic, readwrite) Boolean *isVerifiedAnImage;
@property (atomic, readwrite) Boolean *isVerifiedAnAttachment;

@property (atomic, readwrite) NSMutableDictionary* kbArticle;

- (NSString *)displayAttachmentSize;

+ (NSURL *)attachmentURLForMessageId:(NSString *)messageId attachmentId:(NSString *)attachmentId;

@end

static inline BOOL KUSChatMessageSentByUser(KUSChatMessage *message)
{
    return message.direction == KUSChatMessageDirectionIn;
}

static inline BOOL KUSChatMessagesSameSender(KUSChatMessage *message1, KUSChatMessage *message2)
{
    return (message1 && message2
            && message1.direction == message2.direction
            && (message1.sentById == message2.sentById
            || [message1.sentById isEqualToString:message2.sentById]));
}

NS_ASSUME_NONNULL_END
