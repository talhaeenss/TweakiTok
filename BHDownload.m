//
//  BHDownload.m
//  DIYTableView
//
//  Created by BandarHelal on 12/01/1442 AH.
//  Copyright © 1442 BandarHelal. All rights reserved.
//

#import "BHDownload.h"

@implementation BHDownload
- (instancetype)init {
    self = [super init];
    if (self) {
        self.Session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration] delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)downloadFileWithURL:(NSURL *)url {
    if (url) {
        NSString *cleanName = url.path.lastPathComponent;
        if (cleanName.length == 0 || [cleanName containsString:@"?"]) {
            cleanName = [NSUUID UUID].UUIDString;
        }
        self.fileName = cleanName;
        
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148" forHTTPHeaderField:@"User-Agent"];
        NSURLSessionDownloadTask *downloadTask = [self.Session downloadTaskWithRequest:request];
        [downloadTask resume];
    }
}
- (void)setDelegate:(id)newDelegate {
    if (newDelegate) {
        delegate = newDelegate;
    }
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    float prog = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    [delegate downloadProgress:prog];
}
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didFinishDownloadingToURL:(nonnull NSURL *)location {
    NSString *docPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *safeName = [NSUUID UUID].UUIDString;
    NSString *ext = downloadTask.originalRequest.URL.pathExtension;
    if (ext.length == 0 || ext.length > 5 || [ext containsString:@"?"]) {
        NSString *mime = downloadTask.response.MIMEType.lowercaseString;
        if ([mime containsString:@"video"]) {
            ext = @"mp4";
        } else if ([mime containsString:@"audio"]) {
            ext = @"mp3";
        } else if ([mime containsString:@"png"]) {
            ext = @"png";
        } else if ([mime containsString:@"webp"]) {
            ext = @"webp";
        } else {
            NSString *urlStr = downloadTask.originalRequest.URL.absoluteString.lowercaseString;
            if ([urlStr containsString:@"video"] || [urlStr containsString:@"play"] || [urlStr containsString:@"mp4"]) {
                ext = @"mp4";
            } else if ([urlStr containsString:@"music"] || [urlStr containsString:@"audio"] || [urlStr containsString:@"mp3"]) {
                ext = @"mp3";
            } else {
                ext = @"jpeg";
            }
        }
    }
    safeName = [NSString stringWithFormat:@"%@.%@", safeName, ext];
    NSURL *destURL = [[NSURL fileURLWithPath:docPath] URLByAppendingPathComponent:safeName];
    
    [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] copyItemAtURL:location toURL:destURL error:&error]) {
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:nil];
    }
    [delegate downloadDidFinish:destURL Filename:safeName];
}
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    [delegate downloadDidFailureWithError:error];
}
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    [delegate downloadDidFailureWithError:error];
}
@end
