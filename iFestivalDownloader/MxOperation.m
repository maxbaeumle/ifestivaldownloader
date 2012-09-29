//
//  MxOperation.m
//  iFestivalDownloader
//
//  Created by Max Bäumle on 29.09.12.
//  Copyright (c) 2012 MxCreative. All rights reserved.
//

#import "MxOperation.h"

@implementation MxOperation

@synthesize url = _url;
@synthesize destinationPath = _destinationPath;

- (void)dealloc {
    [_url release];
    [_destinationPath release];
    
    [super dealloc];
}

- (void)main {
    if (![[NSFileManager defaultManager] fileExistsAtPath:self.destinationPath]) {
        NSURLRequest *request = [NSURLRequest requestWithURL:self.url];
        NSURLResponse *response;
        NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:NULL];
        
        if (data) {
            [data writeToFile:self.destinationPath atomically:YES];
        } else {
            
        }
    }
}

@end
