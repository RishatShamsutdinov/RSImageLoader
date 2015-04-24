/**
 *
 * Copyright 2015 Rishat Shamsutdinov
 * 
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 * 
 *     http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import "RSImageLoader.h"
#import "UIImage+RSResizing.h"
#import <ImageIO/ImageIO.h>

static UInt64 const kMaxCacheSize = 50 * 1024 * 1024;

static NSUInteger const kMaxConnectionsPerHost = 9;

#define DATE_ATTRIBUTE_KEY (NSURLContentModificationDateKey)

#pragma mark - _RSImageLoadResult

@interface _RSImageLoadResult : NSObject

@property (nonatomic, readonly) UIImage *image;
@property (nonatomic, readonly) NSError *error;

- (instancetype)initWithImage:(UIImage *)image;
- (instancetype)initWithError:(NSError *)error;

@end

@implementation _RSImageLoadResult

- (instancetype)initWithImage:(UIImage *)image {
    if (self = [self init]) {
        _image = image;
    }

    return self;
}

- (instancetype)initWithError:(NSError *)error {
    if (self = [self init]) {
        _error = error;
    }

    return self;
}

@end

#pragma mark - RSImageLoader

@interface RSImageLoader () {
    NSCache *_cache;
    dispatch_queue_t _serialQueue;

    NSURLSession *_urlSession;
    NSMutableDictionary *_downloadTasks;

    NSMutableDictionary *_handlers;
    NSMutableDictionary *_taskIDToHandlersKeyMapping;
}

@end

@implementation RSImageLoader

+ (NSURL *)cacheDirURL {
    NSArray *cacheDirURLs = [[NSFileManager defaultManager] URLsForDirectory:NSCachesDirectory inDomains:NSUserDomainMask];

    return [[cacheDirURLs lastObject] URLByAppendingPathComponent:@"rs-image-loader"];
}

+ (instancetype)sharedImageLoader {
    static RSImageLoader *loader;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        loader = [RSImageLoader new];
    });

    return loader;
}

- (instancetype)init {
    if (self = [super init]) {
        _serialQueue = dispatch_queue_create("ru.rees.images-loader", DISPATCH_QUEUE_SERIAL);

        _cache = [NSCache new];
        _handlers = [NSMutableDictionary new];
        _taskIDToHandlersKeyMapping = [NSMutableDictionary new];
        _downloadTasks = [NSMutableDictionary new];

        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];

        sessionConfig.HTTPMaximumConnectionsPerHost = kMaxConnectionsPerHost;
        sessionConfig.HTTPShouldUsePipelining = NO;
        sessionConfig.URLCache = nil;

        _urlSession = [NSURLSession sessionWithConfiguration:sessionConfig delegate:nil delegateQueue:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeLowMemoryWarning:)
                                                     name:UIApplicationDidReceiveMemoryWarningNotification object:nil];

        dispatch_async(_serialQueue, ^{
            [self clearCacheIfNeeded];
        });
    }

    return self;
}

- (void)observeLowMemoryWarning:(NSNotification *)notif {
    dispatch_sync(_serialQueue, ^{
        [_cache removeAllObjects];
    });
}

- (void)clearCacheIfNeeded {
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSArray *files = [fileManager contentsOfDirectoryAtURL:[[self class] cacheDirURL]
                                includingPropertiesForKeys:@[DATE_ATTRIBUTE_KEY]
                                                   options:(NSDirectoryEnumerationSkipsSubdirectoryDescendants |
                                                            NSDirectoryEnumerationSkipsPackageDescendants |
                                                            NSDirectoryEnumerationSkipsHiddenFiles)
                                                     error:NULL];

    UInt64 (^getFileSize)(NSString *) = ^UInt64(NSString *path) {
        NSDictionary *attributes = [fileManager attributesOfItemAtPath:path error:NULL];

        return [attributes[NSFileSize] unsignedLongLongValue];
    };

    __block UInt64 cachePathSize = 0;

    [files enumerateObjectsUsingBlock:^(NSURL *obj, NSUInteger idx, BOOL *stop) {
        cachePathSize += getFileSize(obj.path);
    }];

    if (cachePathSize <= kMaxCacheSize) {
        return;
    }

    [[files sortedArrayUsingComparator:^NSComparisonResult(NSURL *obj1, NSURL *obj2) {
        NSDate *date1, *date2;

        if ([obj1 getResourceValue:&date1 forKey:DATE_ATTRIBUTE_KEY error:NULL] &&
            [obj2 getResourceValue:&date2 forKey:DATE_ATTRIBUTE_KEY error:NULL])
        {
            return [date1 compare:date2];
        }

        return NSOrderedSame;
    }] enumerateObjectsUsingBlock:^(NSURL *obj, NSUInteger idx, BOOL *stop) {
        UInt64 fileSize = getFileSize(obj.path);

        if ([fileManager removeItemAtURL:obj error:NULL]) {
            cachePathSize -= fileSize;

            *stop = (cachePathSize <= kMaxCacheSize);
        }
    }];
}

- (NSString *)pathOfFileForImageWithURL:(NSURL *)imageURL {
    NSString *fileName = [[imageURL absoluteString] stringByAddingPercentEncodingWithAllowedCharacters:
                          [NSCharacterSet alphanumericCharacterSet]];

    NSString *cachePath = [[[self class] cacheDirURL] absoluteString];

    return [cachePath stringByAppendingPathComponent:fileName];
}

- (void)updateDateAttributeOfFileForImageWithURL:(NSURL *)imageURL {
    NSString *filePath = [self pathOfFileForImageWithURL:imageURL];

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileManager = [NSFileManager defaultManager];

        BOOL isDirectory;
        BOOL fileExists;

        fileExists = [fileManager fileExistsAtPath:filePath isDirectory:&isDirectory];

        if (fileExists && !isDirectory) {
            [fileManager setAttributes:@{DATE_ATTRIBUTE_KEY: [NSDate date]} ofItemAtPath:filePath error:NULL];
        }
    });
}

/**
 * @abstract Must be performed on \c _serialQueue
 */
- (BOOL)setHandler:(RSImageLoaderHandler)handler forKey:(NSString *)key taskID:(out NSString **)outTaskID {
    NSMutableDictionary *handlers = [_handlers objectForKey:key];

    if (!handlers) {
        handlers = [NSMutableDictionary new];

        [_handlers setObject:handlers forKey:key];
    }

    BOOL result = (handlers.count != 0);

    NSString *taskID = [[NSUUID UUID] UUIDString];

    handlers[taskID] = [handler copy];

    _taskIDToHandlersKeyMapping[taskID] = [key copy];

    if (outTaskID) {
        *outTaskID = taskID;
    }
    
    return result;
}

- (void)handleResult:(nullable _RSImageLoadResult *)result withImageKey:(NSString *)imageKey
         handlersKey:(NSString *)handlersKey performOnSerialQueue:(BOOL)performOnSerialQueue {

    void (^handleResult)() = ^{
        if (result.image) {
            [_cache setObject:result.image forKey:imageKey];
        }

        NSDictionary *handlers = [[_handlers objectForKey:handlersKey] copy];

        [_taskIDToHandlersKeyMapping removeObjectsForKeys:[handlers allKeys]];
        [_handlers removeObjectForKey:handlersKey];

        if (result) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [[handlers allValues] enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    RSImageLoaderHandler handler = obj;

                    if (result.image) {
                        handler(result.image, nil);
                    } else {
                        handler(nil, result.error);
                    }
                }];
            });
        }
    };

    if (performOnSerialQueue) {
        dispatch_async(_serialQueue, handleResult);
    } else {
        handleResult();
    }
}

- (NSString *)loadImageWithURL:(NSURL *)url handler:(RSImageLoaderHandler)handler {
    return [self loadImageWithURL:url onlyFromCache:NO handler:handler];
}

- (NSString *)loadImageWithURL:(NSURL *)url onlyFromCache:(BOOL)onlyFromCache handler:(RSImageLoaderHandler)handler {
    NSString __block *taskID;
    UIImage __block *image;

    dispatch_sync(_serialQueue, ^{
        NSString *key = [url absoluteString];

        NSString *imageKey = key;
        NSString *handlersKey = onlyFromCache ? [@"only-from-cache@" stringByAppendingString:key] : key;

        image = [_cache objectForKey:imageKey];

        if (onlyFromCache && image) {
            return;
        }

        BOOL imageIsLoading = [self setHandler:handler forKey:handlersKey taskID:&taskID];

        if (image) {
            [self handleResult:[[_RSImageLoadResult alloc] initWithImage:image] withImageKey:imageKey
                   handlersKey:handlersKey performOnSerialQueue:NO];

            [self updateDateAttributeOfFileForImageWithURL:url];
        } else if (!imageIsLoading) {
            typeof(self) __weak weakSelf = self;

            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                [self downloadImageWithUrl:url onlyFromCache:onlyFromCache
                           withHandlersKey:handlersKey handler:
                 ^(UIImage *image, NSError *error, BOOL finished) {
                     typeof(self) __strong strongSelf = weakSelf;

                     if (!strongSelf) {
                         return;
                     }

                     _RSImageLoadResult *result;

                     if (!finished) {
                         result = nil;
                     } else if (image) {
                         result = [[_RSImageLoadResult alloc] initWithImage:image];
                     } else {
                         result = [[_RSImageLoadResult alloc] initWithError:error];
                     }

                     [strongSelf handleResult:result withImageKey:imageKey
                                  handlersKey:handlersKey performOnSerialQueue:YES];
                 }];
            });
        }
    });

    if (onlyFromCache && image) {
        void (^block)() = ^{
            handler(image, nil);
        };

        if ([NSThread isMainThread]) {
            block();
        } else {
            dispatch_async(dispatch_get_main_queue(), block);
        }
    }
    
    return taskID;
}

- (void)downloadImageWithUrl:(NSURL *)url onlyFromCache:(BOOL)onlyFromCache
             withHandlersKey:(NSString *)handlersKey handler:(void (^)(UIImage *, NSError *, BOOL finished))handler {

    BOOL isDirectory;
    BOOL fileExists;

    NSString *cachePath = [[[self class] cacheDirURL] absoluteString];
    NSString *filePath = [self pathOfFileForImageWithURL:url];
    NSFileManager *fileManager = [NSFileManager defaultManager];

    fileExists = [fileManager fileExistsAtPath:cachePath isDirectory:&isDirectory];

    if (!fileExists) {
        [fileManager createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:NULL];
    } else if (isDirectory) {
        fileExists = [fileManager fileExistsAtPath:filePath isDirectory:&isDirectory];
    } else {
        fileExists = NO;
    }

    if (fileExists && !isDirectory) {
        [self updateDateAttributeOfFileForImageWithURL:url];

        NSData *data = [NSData dataWithContentsOfFile:filePath];

        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            handler([UIImage imageWithData:data], nil, YES);
        });
    } else if (!onlyFromCache) {
        typeof(self) __weak weakSelf = self;

        void (^completionHandler)(NSData *, NSURLResponse *, NSError *) =
        ^(NSData *data, NSURLResponse *response, NSError *error) {
            if (data && !error) {
                dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                    UIImage *image = data ? [UIImage imageWithData:data] : nil;

                    if (image) {
                        [data writeToFile:filePath atomically:YES];

                        [self updateDateAttributeOfFileForImageWithURL:url];
                    }

                    handler(image, nil, YES);
                });
            } else if (![error.domain isEqualToString:NSURLErrorDomain] || error.code != NSURLErrorCancelled) {
                handler(nil, error, YES);
            }

            typeof(self) __strong strongSelf = weakSelf;

            if (strongSelf) {
                dispatch_sync(strongSelf->_serialQueue, ^{
                    [strongSelf->_downloadTasks removeObjectForKey:handlersKey];
                });
            }
        };

        NSURLSessionTask *task = [_urlSession dataTaskWithURL:url completionHandler:completionHandler];

        dispatch_sync(_serialQueue, ^{
            if (_handlers[handlersKey]) {
                _downloadTasks[handlersKey] = task;

                [task resume];
            }
        });
    } else {
        handler(nil, nil, NO);
    }
}

- (void)cancelDownloadTaskByID:(NSString *)taskID {
    if (!taskID) {
        return;
    }

    dispatch_sync(_serialQueue, ^{
        NSString *handlersKey = _taskIDToHandlersKeyMapping[taskID];

        if (handlersKey) {
            NSMutableDictionary *handlers = _handlers[handlersKey];

            [handlers removeObjectForKey:taskID];

            [_taskIDToHandlersKeyMapping removeObjectForKey:taskID];

            if (handlers.count == 0) {
                NSURLSessionTask *task = _downloadTasks[handlersKey];

                [task cancel];

                [_downloadTasks removeObjectForKey:handlersKey];
                [_handlers removeObjectForKey:handlersKey];
            }
        }
    });
}

- (void)thumbnailForFileAtPath:(NSString *)path ofSize:(CGSize)size withHandler:(RSImageLoaderHandler)handler {
    if (!path) {
        return;
    }

    dispatch_sync(_serialQueue, ^{
        NSString *key = [NSString stringWithFormat:@"file-thumbnail@@/%@/%@", path, NSStringFromCGSize(size), nil];

        BOOL thumbnailIsCreating = [self setHandler:handler forKey:key taskID:NULL];

        UIImage *image = [_cache objectForKey:key];

        if (image) {
            [self handleResult:[[_RSImageLoadResult alloc] initWithImage:image] withImageKey:key
                   handlersKey:key performOnSerialQueue:NO];
        } else if (!thumbnailIsCreating) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
                NSError *error;
                UIImage *image = [self thumbnailForFileAtPath:path size:size error:&error];

                _RSImageLoadResult *result;

                if (image) {
                    result = [[_RSImageLoadResult alloc] initWithImage:image];
                } else {
                    result = [[_RSImageLoadResult alloc] initWithError:error];
                }

                [self handleResult:result withImageKey:key handlersKey:key performOnSerialQueue:YES];
            });
        }
    });
}

/**
 * https://developer.apple.com/library/ios/documentation/GraphicsImaging/Conceptual/ImageIOGuide/imageio_source/ikpg_source.html
 */
- (UIImage *)thumbnailForFileAtPath:(NSString *)path size:(CGSize)size error:(NSError **)error {
    CGImageRef imageRef = NULL;
    CGImageSourceRef imageSourceRef;

    imageSourceRef = CGImageSourceCreateWithURL((__bridge_retained CFURLRef)[NSURL fileURLWithPath:path], NULL);

    if (imageSourceRef == NULL) {
        return nil;
    }

    NSDictionary *props = ((__bridge_transfer NSDictionary *)
                           CGImageSourceCopyPropertiesAtIndex(imageSourceRef, 0, NULL));
    NSNumber *orientation = props[(__bridge NSString *)kCGImagePropertyOrientation];
    CGFloat imgWidth = [props[(__bridge NSString *)kCGImagePropertyPixelWidth] floatValue];
    CGFloat imgHeight = [props[(__bridge NSString *)kCGImagePropertyPixelHeight] floatValue];

    static NSInteger const kCGImageOrientationLeftTop = 5; // see CGImageProperties.h for details

    if ([orientation integerValue] >= kCGImageOrientationLeftTop) {
        CGFloat width = imgWidth;

        imgWidth = imgHeight;
        imgHeight = width;
    }

    CGFloat screenScale = [UIScreen mainScreen].scale;

    size.width = ceilf(size.width * screenScale);
    size.height = ceilf(size.height * screenScale);

    CGFloat aspectRatio = imgWidth / imgHeight;
    CGFloat invertedAspectRatio = 1 / aspectRatio;

    CGFloat maxPixelSize;

    if (isnormal(aspectRatio * invertedAspectRatio)) {
        maxPixelSize = MAX(aspectRatio * size.width, invertedAspectRatio * size.height);
    } else {
        maxPixelSize = MAX(size.width, size.height);
    }

    maxPixelSize = ceilf(maxPixelSize);

    NSDictionary *options = @{(__bridge NSString *)kCGImageSourceCreateThumbnailWithTransform: @YES,
                              (__bridge NSString *)kCGImageSourceCreateThumbnailFromImageAlways: @YES,
                              (__bridge NSString *)kCGImageSourceThumbnailMaxPixelSize: @(maxPixelSize)};


    imageRef = CGImageSourceCreateThumbnailAtIndex(imageSourceRef, 0, (__bridge CFDictionaryRef)options);

    CFRelease(imageSourceRef);

    if (imageRef == NULL) {
        return nil;
    }

    UIImage *image = [[UIImage imageWithCGImage:imageRef] rs_imageWithScaleToSize:size considerAspectRatio:NO];

    CGImageRelease(imageRef);

    return image;
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
