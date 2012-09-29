//
//  MxOperation.h
//  iFestivalDownloader
//
//  Created by Max Bäumle on 29.09.12.
//  Copyright (c) 2012 MxCreative. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MxOperation : NSOperation

@property (retain) NSURL *url;
@property (retain) NSString *destinationPath;

@end
