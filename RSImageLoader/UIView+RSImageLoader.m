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

#import "UIView+RSImageLoader.h"
#import "RSImageLoader.h"
#import <objc/runtime.h>

static const void * kImageUUIDKey = &kImageUUIDKey;

@implementation UIView (RSImageLoader)

- (NSUUID *)imageUUID {
    return objc_getAssociatedObject(self, kImageUUIDKey);
}

- (void)setImageUUID:(NSUUID *)uuid {
    objc_setAssociatedObject(self, kImageUUIDKey, uuid, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void (^)(UIImage *, NSError *))_rs_imageHandlerWithUUID:(NSUUID *)uuid url:(NSURL *)url
                                               contentMode:(NSNumber *)contentMode
                                                completion:(RSImageLoadCompletion)completion {

    typeof(self) weakSelf __weak = self;

    return ^(UIImage *image, NSError *error) {
        typeof(self) strongSelf __strong = weakSelf;

        if (!strongSelf || ![[strongSelf imageUUID] isEqual:uuid]) {
            return;
        }

        if (image) {
            [strongSelf rs_imageLoadDidFinish:image withURL:url];

            if (contentMode) {
                strongSelf.contentMode = contentMode.integerValue;
            }
        } else {
            [strongSelf rs_imageLoadDidFail:error withURL:url];
        }

        if (completion) {
            completion(image != nil);
        }
    };
}

- (void)rs_imageLoadDidFinish:(UIImage *)image withURL:(NSURL *)URL {
    @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                   reason:[NSString stringWithFormat:@"The method %@ must be overridden",
                                           NSStringFromSelector(_cmd)]
                                 userInfo:nil];
}

- (void)rs_imageLoadDidFail:(NSError *)error withURL:(NSURL *)URL {
    // do nothing
}

- (void)rs_abortImageLoading {
    [self rs_loadImageWithURL:nil];
}

- (void)rs_loadImageWithURL:(NSURL *)url {
    [self rs_loadImageWithURL:url completion:nil];
}

- (void)rs_loadImageWithURL:(NSURL *)url completion:(RSImageLoadCompletion)completion {
    [self rs_loadImageWithURL:url contentMode:nil onlyFromCache:NO completion:completion];
}

- (void)rs_loadImageWithURL:(NSURL *)url contentMode:(UIViewContentMode)contentMode {
    [self rs_loadImageWithURL:url contentMode:contentMode completion:nil];
}

- (void)rs_loadImageWithURL:(NSURL *)url contentMode:(UIViewContentMode)contentMode
                 completion:(RSImageLoadCompletion)completion {

    [self rs_loadImageWithURL:url contentMode:@(contentMode) onlyFromCache:NO completion:completion];
}

- (void)rs_loadImageWithURL:(NSURL *)url contentMode:(NSNumber *)contentMode
              onlyFromCache:(BOOL)onlyFromCache completion:(RSImageLoadCompletion)completion {

    NSUUID *uuid = [NSUUID UUID];

    [self setImageUUID:uuid];

    NSString *taskID = objc_getAssociatedObject(self, _cmd);

    if (taskID) {
        [[RSImageLoader sharedImageLoader] cancelDownloadTaskByID:taskID];

        objc_setAssociatedObject(self, _cmd, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }

    if (!url) {
        return;
    }

    taskID = [[RSImageLoader sharedImageLoader]
              loadImageWithURL:url onlyFromCache:onlyFromCache
              handler:[self _rs_imageHandlerWithUUID:uuid url:url contentMode:contentMode completion:completion]];

    objc_setAssociatedObject(self, _cmd, taskID, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (void)rs_loadImageFromFileAtPath:(NSString *)path {
    [self rs_loadImageFromFileAtPath:path withCompletion:nil];
}

- (void)rs_loadImageFromFileAtPath:(NSString *)path withContentMode:(UIViewContentMode)contentMode {
    [self rs_loadImageFromFileAtPath:path withContentMode:contentMode completion:nil];
}

- (void)rs_loadImageFromFileAtPath:(NSString *)path withCompletion:(RSImageLoadCompletion)completion {
    [self _rs_loadImageFromFileAtPath:path contentMode:nil completion:completion];
}

- (void)rs_loadImageFromFileAtPath:(NSString *)path withContentMode:(UIViewContentMode)contentMode
                        completion:(RSImageLoadCompletion)completion {

    [self _rs_loadImageFromFileAtPath:path contentMode:@(contentMode) completion:completion];
}

- (void)_rs_loadImageFromFileAtPath:(NSString *)path contentMode:(NSNumber *)contentMode
                         completion:(RSImageLoadCompletion)completion {

    NSUUID *uuid = [NSUUID UUID];

    [self setImageUUID:uuid];

    if (!path) {
        return;
    }

    [self.superview layoutIfNeeded];
    [self.superview setNeedsLayout];

    [[RSImageLoader sharedImageLoader]
     thumbnailForFileAtPath:path ofSize:self.bounds.size
     withHandler:[self _rs_imageHandlerWithUUID:uuid url:[NSURL fileURLWithPath:path]
                                    contentMode:contentMode completion:completion]];
}

@end

@implementation UIImageView (RSImageLoader)

- (void)rs_imageLoadDidFinish:(UIImage *)image withURL:(NSURL *)URL {
    self.image = image;
}

@end
