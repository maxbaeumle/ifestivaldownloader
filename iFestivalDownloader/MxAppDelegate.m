//
//  MxAppDelegate.m
//  iFestivalDownloader
//
//  Created by Max Bäumle on 28.09.12.
//  Copyright (c) 2012 MxCreative. All rights reserved.
//

#import "MxAppDelegate.h"
#import "MxOperation.h"

@interface MxAppDelegate () {
    NSMutableDictionary *_resolutions;
    NSOperationQueue *_queue;
    
    SFAuthorization *_authorization;
    NSFileHandle *_fileHandle;
    
    int _urlCount;
}

@property (retain) NSString *urlPath;
@property (retain) NSString *token;

@property (retain) NSString *destinationPath;
@property (retain) NSString *temporaryPath;

- (void)fileHandleDataAvailable:(NSNotification *)notification;
- (void)urlReceived:(NSURL *)url;
- (void)download;
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context;

@end

@implementation MxAppDelegate

@synthesize window = _window;

@synthesize monitorITunesButton = _monitorITunesButton;
@synthesize activityIndicator = _activityIndicator;
@synthesize interface = _interface;

@synthesize filename = _filename;
@synthesize resolution = _resolution;
@synthesize downloadButton = _downloadButton;

@synthesize progressLabel = _progressLabel;
@synthesize progressBar = _progressBar;

@synthesize urlPath = _urlPath;
@synthesize token = _token;

@synthesize destinationPath = _destinationPath;
@synthesize temporaryPath = _temporaryPath;

- (void)dealloc
{
    [_resolutions release];
    [_queue release];
    
    [_authorization release];
    
    [_urlPath release];
    [_token release];
    
    [_destinationPath release];
    [_temporaryPath release];
    
    [super dealloc];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    _resolutions = [[NSMutableDictionary alloc] initWithObjectsAndKeys:@"", @"1920x1080",
                    @"", @"1280x720",
                    @"", @"960x540",
                    @"", @"800x448",
                    @"", @"640x360",
                    @"", @"400x224", nil];
    
    _queue = [[NSOperationQueue alloc] init];
    [_queue setMaxConcurrentOperationCount:2];
    
    BOOL success = [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"itms://search.itunes.apple.com/WebObjects/MZContentLink.woa/wa/link?path=festival"]];
    
    if (!success) {
        exit(1);
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

- (IBAction)monitorITunes:(id)sender {
    // http://cocoawithlove.com/2009/05/invoking-other-processes-in-cocoa.html
    
    NSError *error;
    
    if (!_authorization) {
        _authorization = [SFAuthorization authorization];
        BOOL success = [_authorization obtainWithRights:NULL
                                                  flags:kAuthorizationFlagExtendRights
                                            environment:kAuthorizationEmptyEnvironment
                                       authorizedRights:NULL
                                                  error:&error];
        
        if (!success) {
            //NSLog(@"%@", [error localizedDescription]);
            _authorization = nil;
            return;
        }
        
        [_authorization retain];
    }
    
    if (!_fileHandle) {
        NSString *processPath = @"/usr/sbin/tcpdump";
        NSArray *arguments = [NSArray arrayWithObjects:@"-s 0", @"-A", @"-i", [self.interface titleOfSelectedItem], @"port 80", nil];
        
        const char **argv = (const char **)malloc(sizeof(char *) * [arguments count] + 1);
        NSInteger argvIndex = 0;
        
        for (NSString *string in arguments) {
            argv[argvIndex] = [string UTF8String];
            argvIndex++;
        }
        
        argv[argvIndex] = nil;
        
        FILE *processOutput;
        OSErr processError = AuthorizationExecuteWithPrivileges([_authorization authorizationRef],
                                                                [processPath UTF8String],
                                                                kAuthorizationFlagDefaults,
                                                                (char *const *)argv,
                                                                &processOutput);
        free(argv);
        
        if (processError != errAuthorizationSuccess) {
            //NSLog(@"%hd", processError);
            return;
        }
        
        [sender setEnabled:NO];
        [self.activityIndicator startAnimation:nil];
        
        _fileHandle = [[NSFileHandle alloc] initWithFileDescriptor:fileno(processOutput)];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(fileHandleDataAvailable:)
                                                     name:NSFileHandleDataAvailableNotification
                                                   object:nil];
        
        [_fileHandle waitForDataInBackgroundAndNotify];
    }
}

- (void)fileHandleDataAvailable:(NSNotification *)notification {
    NSFileHandle *fileHandle = (NSFileHandle *)[notification object];
    NSData *data = [fileHandle availableData];
    NSString *string = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    NSRange range;
    range = [string rangeOfString:@"token"];
    
    if (range.location != NSNotFound) {
        NSRange lineRange = [string lineRangeForRange:range];
        NSString *substring;
        substring = [string substringWithRange:lineRange];
        
        range = [substring rangeOfString:@"GET "];
        
        if (range.location != NSNotFound) {
            substring = [substring substringFromIndex:range.location + range.length];
        }
        
        range = [substring rangeOfString:@" HTTP/1.1"];
        
        if (range.location != NSNotFound) {
            substring = [substring substringToIndex:range.location];
        }
        
        NSURL *url = [[NSURL alloc] initWithScheme:@"http" host:@"streaming.itunesfestival.com" path:substring];
        
        if ([[url pathExtension] isEqualToString:@"m3u8"]) {
            [self urlReceived:url];
            
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:NSFileHandleDataAvailableNotification
                                                          object:nil];
            
            [fileHandle closeFile];
            [_fileHandle release];
            _fileHandle = nil;
            
            [self.activityIndicator stopAnimation:nil];
            [self.monitorITunesButton setEnabled:YES];
        } else {
            [fileHandle waitForDataInBackgroundAndNotify];
        }
        
        [url release];
    } else {
        [fileHandle waitForDataInBackgroundAndNotify];
    }
    
    [string release];
}

- (void)urlReceived:(NSURL *)url {
    for (NSString *key in [_resolutions allKeys]) {
        [_resolutions setObject:@"" forKey:key];
    }
    
    [self.resolution removeAllItems];
    
    NSString *path = [url path];
    
    [self.filename setStringValue:[[path lastPathComponent] stringByDeletingPathExtension]];
    
    self.urlPath = [path stringByDeletingLastPathComponent];
    
    NSString *query = [url query];
    NSRange range;
    range = [query rangeOfString:@"token=expires="];
    
    self.token = [query substringFromIndex:range.location];
    
    NSStringEncoding stringEncoding;
    NSString *m3u8 = [NSString stringWithContentsOfURL:url usedEncoding:&stringEncoding error:NULL];
    
    range = [m3u8 rangeOfString:@"5500_256"];
    
    if (range.location != NSNotFound) {
        // Experimental
        
        NSString *substring = [m3u8 substringWithRange:[m3u8 lineRangeForRange:range]];
        
        [_resolutions setObject:substring forKey:@"1280x720"];
        
        range = [substring rangeOfString:@"5500_256"];
        substring = [substring stringByReplacingCharactersInRange:range withString:@"8500_256"];
        
        [_resolutions setObject:substring forKey:@"1920x1080"];
        
        [self.resolution addItemWithTitle:@"1920x1080"];
        [self.resolution addItemWithTitle:@"1280x720"];
    }
    
    range = [m3u8 rangeOfString:@"2400_256"];
    
    if (range.location != NSNotFound) {
        [_resolutions setObject:[m3u8 substringWithRange:[m3u8 lineRangeForRange:range]] forKey:@"960x540"];
        [self.resolution addItemWithTitle:@"960x540"];
    }
    
    range = [m3u8 rangeOfString:@"1200_256"];
    
    if (range.location != NSNotFound) {
        [_resolutions setObject:[m3u8 substringWithRange:[m3u8 lineRangeForRange:range]] forKey:@"800x448"];
        [self.resolution addItemWithTitle:@"800x448"];
    }
    
    range = [m3u8 rangeOfString:@"900_256"];
    
    if (range.location != NSNotFound) {
        [_resolutions setObject:[m3u8 substringWithRange:[m3u8 lineRangeForRange:range]] forKey:@"640x360"];
        [self.resolution addItemWithTitle:@"640x360"];
    }
    
    range = [m3u8 rangeOfString:@"600_256"];
    
    if (range.location != NSNotFound) {
        [_resolutions setObject:[m3u8 substringWithRange:[m3u8 lineRangeForRange:range]] forKey:@"400x224"];
        [self.resolution addItemWithTitle:@"400x224"];
    }
    
    [self.downloadButton setEnabled:YES];
}

- (IBAction)download:(id)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result) {
        if (result == NSFileHandlingPanelOKButton) {
            if (_fileHandle) {
                [[NSNotificationCenter defaultCenter] removeObserver:self
                                                                name:NSFileHandleDataAvailableNotification
                                                              object:nil];
                
                [_fileHandle closeFile];
                [_fileHandle release];
                _fileHandle = nil;
                
                [self.activityIndicator stopAnimation:nil];
            }
            
            [self.monitorITunesButton setEnabled:NO];
            [sender setEnabled:NO];
            
            NSURL *url = [savePanel URL];
            NSString *path;
            path = [url path];
            
            self.destinationPath = [path stringByDeletingPathExtension];
            
            path = [path stringByDeletingLastPathComponent];
            path = [path stringByAppendingPathComponent:[NSString stringWithFormat:@".cr.mx.iFestivalDownloader/%@", [[_resolutions objectForKey:[self.resolution titleOfSelectedItem]] stringByDeletingPathExtension]]];
            
            self.temporaryPath = path;
            
            NSFileManager *fileManager = [[NSFileManager alloc] init];
            
            if (![fileManager fileExistsAtPath:self.temporaryPath]) {
                [fileManager createDirectoryAtPath:self.temporaryPath
                       withIntermediateDirectories:YES
                                        attributes:nil
                                             error:nil];
            }
            
            [fileManager release];
            
            [self.progressBar setDoubleValue:0];
            
            [self download];
        }
    }];
}

- (void)download {
    [self.progressBar setUsesThreadedAnimation:YES];
    [self.progressBar startAnimation:nil];
    [self.progressBar setIndeterminate:YES];
    
    NSString *lastPathComponent = [_resolutions objectForKey:[self.resolution titleOfSelectedItem]];
    NSRange range;
    range = [lastPathComponent rangeOfString:@"m3u8"];
    lastPathComponent = [lastPathComponent substringToIndex:range.location + range.length];
    NSString *path = [NSString stringWithFormat:@"%@?%@", [self.urlPath stringByAppendingPathComponent:lastPathComponent], self.token];
    
    NSURL *url = [[NSURL alloc] initWithScheme:@"http" host:@"streaming.itunesfestival.com" path:path];
    
    NSStringEncoding stringEncoding;
    NSString *m3u8 = [NSString stringWithContentsOfURL:url usedEncoding:&stringEncoding error:NULL];
    
    range = [m3u8 rangeOfString:@".ts"];
    
    if (range.location != NSNotFound) {
        [self.progressBar stopAnimation:nil];
        [self.progressBar setIndeterminate:NO];
        
        __block int fileID = 0;
        
        [m3u8 enumerateLinesUsingBlock:^(NSString *line, BOOL *stop) {
            NSRange range = [line rangeOfString:@".ts"];
            
            if (range.location != NSNotFound) {
                NSString *urlString = [NSString stringWithFormat:@"http://streaming.itunesfestival.com%@/%@?%@", [[url path] stringByDeletingLastPathComponent], line, self.token];
                
                MxOperation *operation = [[MxOperation alloc] init];
                operation.url = [NSURL URLWithString:urlString];
                operation.destinationPath = [NSString stringWithFormat:@"%@/%d.ts", self.temporaryPath, fileID];
                
                [_queue addOperation:operation];
                
                [operation release];
                
                fileID++;
            }
        }];
        
        _urlCount = fileID;
        
        [_queue addObserver:self forKeyPath:@"operationCount" options:0 context:NULL];
    } else {
        [self.progressBar stopAnimation:nil];
        [self.progressBar setIndeterminate:NO];
        
        [self.monitorITunesButton setEnabled:YES];
        [self.downloadButton setEnabled:YES];
    }
    
    [url release];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == _queue) {
        if ([keyPath isEqualToString:@"operationCount"]) {
            NSUInteger operationCount = [_queue operationCount];
            
            if (operationCount > 0) {
                [self.progressLabel setStringValue:[NSString stringWithFormat:@"Downloading... (%ld parts remaining)", operationCount]];
                
                double d = (double)(_urlCount - operationCount) / _urlCount * 100;
                
                if (d < 100) {
                    [self.progressBar setDoubleValue:d];
                }
            } else {
                [_queue removeObserver:self forKeyPath:keyPath];
                
                [self.progressLabel setStringValue:@"Merging..."];
                
                [self.progressBar startAnimation:nil];
                [self.progressBar setIndeterminate:YES];
                
                NSFileManager *fileManager = [[NSFileManager alloc] init];
                
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    NSString *filePath;
                    NSData *data;
                    
                    filePath = [self.temporaryPath stringByAppendingPathComponent:@"0.ts"];
                    data = [[NSData alloc] initWithContentsOfFile:filePath];
                    
                    NSString *destinationPath = [self.destinationPath stringByAppendingPathExtension:@"ts"];
                    NSString *temporaryPath = [self.temporaryPath stringByAppendingPathComponent:[destinationPath lastPathComponent]];
                    
                    [fileManager createFileAtPath:temporaryPath contents:data attributes:nil];
                    
                    [data release];
                    
                    [fileManager removeItemAtPath:filePath error:nil];
                    
                    NSFileHandle *fileHandle = [NSFileHandle fileHandleForUpdatingAtPath:temporaryPath];
                    
                    for (int i = 1; i < _urlCount; i++) {
                        filePath = [self.temporaryPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%d.ts", i]];
                        data = [[NSData alloc] initWithContentsOfFile:filePath];
                        
                        [fileHandle writeData:data];
                        
                        [data release];
                        
                        [fileManager removeItemAtPath:filePath error:nil];
                    }
                    
                    [fileHandle closeFile];
                    
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.progressLabel setStringValue:@"Cleaning up..."];
                        
                        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                            [fileManager moveItemAtPath:temporaryPath toPath:destinationPath error:nil];
                            [fileManager removeItemAtPath:self.temporaryPath error:nil];
                            
                            dispatch_async(dispatch_get_main_queue(), ^{
                                // http://handbrake.fr
                                [self.progressLabel setStringValue:@"Use ffmpeg or HandBrake to convert to mp4 format."];
                                
                                [self.progressBar setUsesThreadedAnimation:NO];
                                [self.progressBar stopAnimation:nil];
                                [self.progressBar setDoubleValue:100];
                                [self.progressBar setIndeterminate:NO];
                                
                                [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:[NSArray arrayWithObject:[NSURL fileURLWithPath:destinationPath]]];
                                
                                [_monitorITunesButton setEnabled:YES];
                                [_downloadButton setEnabled:YES];
                            });
                        });
                    });
                });
                
                [fileManager release];
            }
        }
    }
}

@end
