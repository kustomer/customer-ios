<p align="center" >
  <img src="Assets/kustomer_logo.png" title="Kustomer logo" float=left>
</p>

----------------

<p align="center" >
  The iOS SDK for the <a href="https://www.kustomer.com/">Kustomer.com</a> mobile client
</p>

## Requirements

- A [Kustomer.com](https://www.kustomer.com/) API Key
- Xcode 8.0+
- iOS 9.0+

#### API Key

The Kustomer iOS SDK requires a valid API Key with role `org.tracking`. See [Getting Started - Create an API Key](https://dev.kustomer.com/v1/getting-started)


## Installation

#### CocoaPods

The preferred installation method is with [CocoaPods](https://cocoapods.org). Add the following to your `Podfile`:

```ruby
pod 'Kustomer', :git => 'https://github.com/kustomer/customer-ios.git', :tag => '0.1.1'
```

#### Carthage

For [Carthage](https://github.com/Carthage/Carthage), add the following to your `Cartfile`:

```ogdl
github "kustomer/customer-ios" ~> 0.1.1
```

## Setup

In your project's UIApplicationDelegate:
```objective-c
#import <Kustomer/Kustomer.h>

static NSString *const kKustomerAPIKey = @"YOUR_API_KEY";

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [Kustomer initializeWithAPIKey:kKustomerAPIKey];
    return YES;
}
```

When you want to present the Kustomer chat interface to your users:

```objective-c
KustomerViewController *kustomerViewController = [[KustomerViewController alloc] init];
[self presentViewController:kustomerViewController animated:YES completion:nil];
// or
[Kustomer presentSupport];
```

Enabling the ability for your users to upload images to conversations requires certain app privacy descriptions. If neither of these is present, the image attachments button will be hidden.
- [NSCameraUsageDescription](https://developer.apple.com/library/content/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/plist/info/NSCameraUsageDescription) is required to enable taking a photo
- [NSPhotoLibraryUsageDescription](https://developer.apple.com/library/content/documentation/General/Reference/InfoPlistKeyReference/Articles/CocoaKeys.html#//apple_ref/doc/plist/info/NSPhotoLibraryUsageDescription) is required to enable picking from your Camera Roll

### Additional API Reference

```objective-c
// Initialize the Kustomer iOS SDK with an API key, and start a user session.
[Kustomer initializeWithAPIKey:@"API_KEY"];
```

```objective-c
// Convenience method that will present the chat interface on the topmost view controller.
[Kustomer presentSupport];

// Convenience methods that will present a browser interface pointing to your KnowledgeBase.
[Kustomer presentKnowledgeBase];
```

```objective-c
// Resets the user session, clearing the user's access to any existing chats from the device.
[Kustomer resetTracking];
```

```objective-c
// Securely identify a customer. Requires a valid JSON Web Token.
[Kustomer identify:@"SECURE_ID_HASH"];

/*
 Identifying users is the best way to ensure your users have a great chat experience because
 it gives them access to all of the previous conversations across devices.
 By default, users can see their conversation history only on a single device. By including a secure
 hash with the ID of your user, you can securely identify that user and grant them access.

 JSON Web Token:
 The JWT used for secure identification must use HMAC SHA256 and include the following header and claims:
 Header: @{ @"alg" : @"HS256", @"typ" : @"JWT" }
 Claims: @{ @"externalId" : @"your_user_id", @"iat" : @"current_time_utc" }
 NOTE: tokens with an @"iat" older than 15 minutes will be rejected

 The JWT must be signed with your organization's secret. This secret is accessible to your server,
 via `/v1/auth/customer/settings`. The intent is that your own server fetches the secret, generates
 and signs the JWT and then sends it to your client which in turn calls the `+[Kustomer identify:]`
 method, preventing any risk of falsified indentification calls.
*/
```

```objective-c
/*
 Attach custom attributes to the user

 NOTE:
 Attached key-value pairs via the `custom` property must be enabled on the Customer Klass via the admin portal.
 This can be done by an admin via Settings > Platform Settings > Klasses > Customer
*/
KUSCustomerDescription *customerDescription = [[KUSCustomerDescription alloc] init];
customerDescription.email = @"address@example.com";
customerDescription.custom = @{ @"customAttributeStr": @"value" };
[Kustomer describeCustomer:customerDescription];

/*
 Attach custom attributes to the user's most recent conversation (or the first one they create)

 NOTE:
 These key-value pairs must be enabled on the Conversation Klass via the admin portal.
 This can be done by an admin via Settings > Platform Settings > Klasses > Conversation
*/
[Kustomer describeConversation:@{ @"customAttributeStr" : @"value" }];
```

### Appearance

The majority of the user interface for the support screens can be configured using `UIAppearance`. As an example, if you are designing a Halloween-themed support interface, you could re-skin the Kustomer iOS support screens using the following:

##### Sessions screen:
```objective-c
// Make the navigation bar have a dark gray background
[[KUSNavigationBarView appearance] setBackgroundColor:[UIColor colorWithWhite:0.25 alpha:1.0]];
// Make the navigation bar items orange
[[KUSNavigationBarView appearance] setTintColor:[KUSColor orangeColor]];

// Make the session table view and cells light gray
[[KUSSessionsTableView appearance] setBackgroundColor:[UIColor lightGrayColor]];
[[KUSChatSessionTableViewCell appearance] setBackgroundColor:[UIColor lightGrayColor]];
[[KUSChatSessionTableViewCell appearance] setSelectedBackgroundColor:[UIColor grayColor]];
[[KUSChatPlaceholderTableViewCell appearance] setBackgroundColor:[UIColor lightGrayColor]];

// Give the session table cell white text
[[KUSChatSessionTableViewCell appearance] setTitleColor:[UIColor whiteColor]];
[[KUSChatSessionTableViewCell appearance] setDateColor:[UIColor whiteColor]];
[[KUSChatSessionTableViewCell appearance] setSubtitleColor:[UIColor whiteColor]];

// Make the fake placeholder content lines semitransparent white
[[KUSChatPlaceholderTableViewCell appearance] setLineColor:[UIColor colorWithWhite:1.0 alpha:0.2]];

// Make the new conversation button orange
[[KUSNewSessionButton appearance] setColor:[KUSColor orangeColor]];
```

<p align="center" >
  Before and after:
  <br><br>
  <img src="Assets/before_sessions.png">&nbsp&nbsp&nbsp<img src="Assets/after_sessions.png">
</p>

##### Chat screen:
```objective-c
// Make the navigation bar text white
[[KUSNavigationBarView appearance] setNameColor:[UIColor whiteColor]];
[[KUSNavigationBarView appearance] setGreetingColor:[UIColor whiteColor]];

// Make the email input view have an orange tint and dark gray background
[[KUSEmailInputView appearance] setBackgroundColor:[UIColor colorWithWhite:0.25 alpha:1.0]];
[[KUSEmailInputView appearance] setBorderColor:[KUSColor orangeColor]];
[[KUSEmailInputView appearance] setPromptColor:[UIColor whiteColor]];

// Give the messages table view and cells a light gray background
// Make the bubbles orange for user message and dark gray for company messages
[[KUSChatTableView appearance] setBackgroundColor:[UIColor lightGrayColor]];
[[KUSChatMessageTableViewCell appearance] setBackgroundColor:[UIColor lightGrayColor]];
[[KUSChatMessageTableViewCell appearance] setCompanyTextColor:[UIColor whiteColor]];
[[KUSChatMessageTableViewCell appearance] setCompanyBubbleColor:[UIColor colorWithWhite:0.25 alpha:1.0]];
[[KUSChatMessageTableViewCell appearance] setUserBubbleColor:[KUSColor orangeColor]];

// Give the input bar an orange send button and cursor,
// and a dark background and keyboard
[[KUSInputBar appearance] setSendButtonColor:[KUSColor orangeColor]];
[[KUSInputBar appearance] setTintColor:[KUSColor orangeColor]];
[[KUSInputBar appearance] setPlaceholderColor:[UIColor colorWithWhite:0.9 alpha:1.0]];
[[KUSInputBar appearance] setTextColor:[UIColor whiteColor]];
[[KUSInputBar appearance] setBackgroundColor:[UIColor colorWithWhite:0.25 alpha:1.0]];
[[KUSInputBar appearance] setKeyboardAppearance:UIKeyboardAppearanceDark];
```

<p align="center" >
  Before and after:
  <br><br>
  <img src="Assets/before_chat.png">&nbsp&nbsp&nbsp<img src="Assets/after_chat.png">
</p>
