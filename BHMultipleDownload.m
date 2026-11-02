#import "BHMultipleDownload.h"

@implementation BHMultipleDownload {
    NSMutableArray<NSURL *> *_downloadedFilePaths;
    NSInteger _completedDownloads;
    NSInteger _totalDownloads;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        NSURLSessionConfiguration *configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:configuration delegate:self delegateQueue:[NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)downloadFiles:(NSArray<NSURL *> *)fileURLs {
    _downloadedFilePaths = [NSMutableArray array];
    _completedDownloads = 0;
    _totalDownloads = fileURLs.count;

    for (NSURL *fileURL in fileURLs) {
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:fileURL];
        [request setValue:@"Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148" forHTTPHeaderField:@"User-Agent"];
        NSURLSessionDownloadTask *downloadTask = [self.session downloadTaskWithRequest:request];
        [downloadTask resume];
    }

    if (fileURLs.count == 0) {
        [self URLSession:self.session didBecomeInvalidWithError:[NSError errorWithDomain:NSURLErrorDomain code:99 userInfo:nil]];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask didWriteData:(int64_t)bytesWritten totalBytesWritten:(int64_t)totalBytesWritten totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite {
    float prog = (float)totalBytesWritten / (float)totalBytesExpectedToWrite;
    if ([self.delegate respondsToSelector:@selector(downloaderProgress:)]) {
        [self.delegate downloaderProgress:prog];
    }
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
  didFinishDownloadingToURL:(NSURL *)location {
    NSString *documentsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *safeName = [NSString stringWithFormat:@"%@.jpeg", [NSUUID UUID].UUIDString];
    NSURL *destURL = [NSURL fileURLWithPath:[documentsPath stringByAppendingPathComponent:safeName]];
    
    [[NSFileManager defaultManager] removeItemAtURL:destURL error:nil];
    NSError *error = nil;
    if (![[NSFileManager defaultManager] copyItemAtURL:location toURL:destURL error:&error]) {
        [[NSFileManager defaultManager] moveItemAtURL:location toURL:destURL error:nil];
    }
    
    [_downloadedFilePaths addObject:destURL];
    _completedDownloads++;
    
    if (_completedDownloads == _totalDownloads) {
        if ([self.delegate respondsToSelector:@selector(downloaderDidFinishDownloadingAllFiles:)]) {
            [self.delegate downloaderDidFinishDownloadingAllFiles:_downloadedFilePaths];
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        _completedDownloads++;
        if (_completedDownloads == _totalDownloads) {
            if ([self.delegate respondsToSelector:@selector(downloaderDidFinishDownloadingAllFiles:)]) {
                [self.delegate downloaderDidFinishDownloadingAllFiles:_downloadedFilePaths];
            }
        }
    }
}

- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(downloaderDidFailureWithError:)]) {
        [self.delegate downloaderDidFailureWithError:error];
    }
}
@end
