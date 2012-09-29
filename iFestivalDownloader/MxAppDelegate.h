//
//  MxAppDelegate.h
//  iFestivalDownloader
//
//  Created by Max Bäumle on 28.09.12.
//  Copyright (c) 2012 MxCreative. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <SecurityFoundation/SFAuthorization.h>

@interface MxAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (assign) IBOutlet NSButton *monitorITunesButton;
@property (assign) IBOutlet NSProgressIndicator *activityIndicator;
@property (assign) IBOutlet NSPopUpButton *interface;

@property (assign) IBOutlet NSTextField *filename;
@property (assign) IBOutlet NSPopUpButton *resolution;
@property (assign) IBOutlet NSButton *downloadButton;

@property (assign) IBOutlet NSTextField *progressLabel;
@property (assign) IBOutlet NSProgressIndicator *progressBar;

- (IBAction)monitorITunes:(id)sender;
- (IBAction)download:(id)sender;

@end
