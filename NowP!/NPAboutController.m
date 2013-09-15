//
//  NPAboutController.m
//  NowP!
//
//  Created by Mac on 9/15/13.
//  Copyright (c) 2013 Akki. All rights reserved.
//

#import "NPAboutController.h"

@interface NSAttributedString (Hyperlink)
+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL;
@end
@implementation NSAttributedString (Hyperlink)
+(id)hyperlinkFromString:(NSString*)inString withURL:(NSURL*)aURL
{
    NSMutableAttributedString* attrString = [[NSMutableAttributedString alloc] initWithString: inString];
    NSRange range = NSMakeRange(0, [attrString length]);
    [attrString beginEditing];
    [attrString addAttribute:NSLinkAttributeName value:[aURL absoluteString] range:range];
    // make the text appear in blue
    [attrString addAttribute:NSForegroundColorAttributeName value:[NSColor blueColor] range:range];
    // next make the text appear with an underline
    [attrString addAttribute:NSUnderlineStyleAttributeName value:[NSNumber numberWithInt:NSSingleUnderlineStyle] range:range];
    [attrString endEditing];
    return attrString;
}
@end


@interface NPAboutController ()
@property (weak) IBOutlet NSTextField *hyperlink;
@end

@implementation NPAboutController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)showWindow:(id)sender
{
    [super showWindow:sender];
    [self.window makeKeyAndOrderFront:sender];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    [self setHyperlinkWithTextField];
}

-(void)setHyperlinkWithTextField
{
    // both are needed, otherwise hyperlink won't accept mousedown
    [self.hyperlink setAllowsEditingTextAttributes: YES];
    [self.hyperlink setSelectable: YES];
    
    NSURL* url = [NSURL URLWithString:@"http://www.linkedin.com/profile/view?id=225327998"];
    
    NSMutableAttributedString* string = [[NSMutableAttributedString alloc] init];
    [string appendAttributedString: [NSAttributedString hyperlinkFromString:@"Copyright © 2013 Evgeniy Branitsky (Kratko). All rights reserved." withURL:url]];
    // set the attributed string to the NSTextField
    [self.hyperlink setAttributedStringValue: string];
}

@end
