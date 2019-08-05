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
pod 'Kustomer', :git => 'https://github.com/kustomer/customer-ios.git', :tag => '0.2.3'
```

#### Carthage

For [Carthage](https://github.com/Carthage/Carthage), add the following to your `Cartfile`:

```ogdl
github "kustomer/customer-ios" ~> 0.2.3
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
// Convenience methods that will present the chat interface on the topmost view controller.

// Present new or recent chat conversation if there is any.
[Kustomer presentSupport];

// Present new chat conversation with message.
[Kustomer presentSupportWithMessage:@"MESSAGE"];

// Present new chat conversation with message and set custom attributes for that conversation.
[Kustomer presentSupportWithMessage:@"MESSAGE" customAttributes:@{ @"customAttributeStr" : @"value" }];

// Present new chat conversation with message and set chat assistant form for that conversation.
[Kustomer presentSupportWithMessage:@"MESSAGE" formId:@"FORM_ID"];

// Present new chat conversation with message, set chat assistant form and custom attributes for that conversation.
[Kustomer presentSupportWithMessage:@"MESSAGE" formId:@"FORM_ID" customAttributes:@{ @"customAttributeStr" : @"value" }];
```


```objective-c
// Convenience methods that will present a browser interface pointing to your KnowledgeBase.
[Kustomer presentKnowledgeBase];

// Convenience method that will present a specific web page interface
[Kustomer presentCustomWebPage:@"https://www.support.acme.com/specific-article-url"];
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

/*
 Attach custom attributes to the user's next new conversation

 NOTE:
 These key-value pairs must be enabled on the Conversation Klass via the admin portal.
 This can be done by an admin via Settings > Platform Settings > Klasses > Conversation
*/
[Kustomer describeNextConversation:@{ @"customAttributeStr" : @"value" }];
```

```objective-c
/*
 Mark the user as having navigated to a new page. By marking the user's progress around the app, you will be able to create proactive conversational campaigns that can be triggered as a result of the user's progress in your application flow.
*/
- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    // Track the current page on appearance
    [Kustomer setCurrentPageName:@"Home"];
}
```

```objective-c
/*
 Check the "turned on/off" status of your chat asynchronously. For example if chat is turned off, you may want to disable the button or deflect customers to contact an email)
*/
[Kustomer isChatAvailable:^(BOOL success, BOOL enabled) {
    // success variable show if the API call was successful or not.
    // enabled represent chat management settings. This is only valid if success is true as well.
}];
```

```objective-c
/*
 Show/Hide the "New Conversation" button in closed chat. By default, "Start New Conversation" button will appear in closed chat listing. You can update the settings by this method.
*/
[Kustomer hideNewConversationButtonInClosedChat:YES];
```

```objective-c
/*
 Return the total number of open conversations.
*/
[Kustomer openConversationsCount];
```

```objective-c
/*
 Return the current count of un-read messages. It might not be immediately available. 
*/
[Kustomer unreadMessageCount];
```

```objective-c
/*
 Override the conversation form directly from the sdk by setting the form id. 
*/
[Kustomer setFormId:FORM_ID];
```

### Localization

The Kustomer iOS SDK will automatically change the text strings to match the language of the device your customers are using. The SDK supports both <b>Right-to-left (RTL)</b> and <b>Left-to-right (LTR)</b> formatted languages. There are over 50 languages translated out of the box.

```objective-c
// To print all localised keys available in SDK
[Kustomer printLocalizationKeys];
```

#### Customize existing strings

If you are interested in an existing SDK translated language but would like to change the translations for certain values, you can override the strings. In order to enable this this, your project must have a <b>Localizable.strings</b> file. If your project does not yet have a <b>Localizable.strings</b> file with the different language variants, you must first create it. <br><br>
To do that:
<ol>
<li>In Xcode, select <b>File</b> > <b>New</b> > <b>File</b>, then select <b>Resource</b> in the iOS category in the sidebar.</li>
<li>Select <b>Strings</b> File from the files and click <b>Next</b>.</li>
<li>Name the file <b>Localizable</b> and click Create.</li>
</ol>

To customize the SDK strings with the new values:

<ol>
<li>Choose the strings to customize and add them to the <b>Localizable.strings</b> file as follows:<br>

```
// add a key and change the value to what you want
"com.kustomer.week" = "Your Custom String Value";
```
</li>
<li>Make sure that the file is in the <b>Copy Bundle Resources</b> section of the <b>Build Phases</b> tab in Xcode.</li>
</ol>

#### Add new localization

If the SDK does not include localized strings for the language you are interested in, you can add new ones.
Select your `Localizable.strings` file, and in the right pane click `Localize`. When you select the missing language a new variant of `Localizable.strings` will be created for it.

In the new file, add translations for all of the strings available in SDK.

#### Different strings file

If you would like to use a different strings file than the one provided with the Support SDK, you can easily change it.

`Localizable.strings` is the standard name for the strings files. If you need to use a strings file named `some-other-name.strings`, add the file to your project and register `some-other-name` as follows:

```objective-c
// Register Localizable String File
[Kustomer registerLocalizationTableName:@"some-other-name"];
```

#### Custom language

By default, the Kustomer iOS SDK will use the mobile device's preferred language. If you want to override this to use a different language, you can override the language shown to your customers: <br>
```objective-c
// Set Custom Language
[Kustomer setLanguage:@"language_code"];

// Example
[Kustomer setLanguage:@"en"];
```

You must set the language before calling `initializeWithAPIKey` method. The SDK will load only the language whose translation exists either in SDK or in project. If the specified language's translation doesn't exist, the SDK will try to load the translation of the mobile preferred languages before using default language.


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
// Update the typing indicator color
[[KUSChatTableView appearance] setBackgroundColor:[UIColor lightGrayColor]];
[[KUSChatMessageTableViewCell appearance] setBackgroundColor:[UIColor lightGrayColor]];
[[KUSChatMessageTableViewCell appearance] setCompanyTextColor:[UIColor whiteColor]];
[[KUSChatMessageTableViewCell appearance] setCompanyBubbleColor:[UIColor colorWithWhite:0.25 alpha:1.0]];
[[KUSChatMessageTableViewCell appearance] setUserBubbleColor:[KUSColor orangeColor]];
[[KUSTypingIndicatorTableViewCell appearance] setTypingIndicatorColor:[KUSColor orangeColor]];

// Give the input bar an orange send button and cursor,
// and a dark background and keyboard
[[KUSInputBar appearance] setSendButtonColor:[KUSColor orangeColor]];
[[KUSInputBar appearance] setTintColor:[KUSColor orangeColor]];
[[KUSInputBar appearance] setPlaceholderColor:[UIColor colorWithWhite:0.9 alpha:1.0]];
[[KUSInputBar appearance] setTextColor:[UIColor whiteColor]];
[[KUSInputBar appearance] setBackgroundColor:[UIColor colorWithWhite:0.25 alpha:1.0]];
[[KUSInputBar appearance] setKeyboardAppearance:UIKeyboardAppearanceDark];

// Update colors of a satisfaction form
[[KUSRatingView appearance] setLowScaleLabelColor:[UIColor whiteColor]];
[[KUSRatingView appearance] setHighScaleLabelColor:[UIColor whiteColor]];

[[KUSEditFeedbackTableViewCell appearance] setFeedbackTextColor:[UIColor whiteColor]];
[[KUSEditFeedbackTableViewCell appearance] setEditTextColor:[UIColor whiteColor]];

[[KUSSatisfactionFormTableViewCell appearance] setSubmitButtonBackgroundColor:[KUSColor orangeColor]];
[[KUSSatisfactionFormTableViewCell appearance] setSubmitButtonTextColor:[UIColor whiteColor]];
[[KUSSatisfactionFormTableViewCell appearance] setCommentQuestionColor:[UIColor whiteColor]];
[[KUSSatisfactionFormTableViewCell appearance] setCommentBoxBorderColor:[UIColor whiteColor]];
[[KUSSatisfactionFormTableViewCell appearance] setSatisfactionQuestionColor:[UIColor whiteColor]];
[[KUSSatisfactionFormTableViewCell appearance] setCommentBoxTextColor:[UIColor whiteColor]];
```

<p align="center" >
  Before and after:
  <br><br>
  <img src="Assets/before_chat.png">&nbsp&nbsp&nbsp<img src="Assets/after_chat.png">
</p>

### Development

#### Incrementing the build version

- Update the version number references in the above **Installation** section
- Update the `CFBundleShortVersionString` and `CFBundleVersion` references in the [Info.plist](/Source/Info.plist)
- Update the [changelog](CHANGELOG.md) if necessary
- Commit the changes
- Create a git tag reference with the version number:
```
git tag {version_number}
git push origin master
git push origin master --tags
```
