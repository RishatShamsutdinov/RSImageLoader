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

#import <UIKit/UIKit.h>

typedef void(^RSImageLoadCompletion)(BOOL success);

@interface UIView (RSImageLoader)

/**
 * Must be overridden
 */
- (void)rs_imageLoadDidFinish:(UIImage *)image withURL:(NSURL *)URL;

- (void)rs_imageLoadDidFail:(NSError *)error withURL:(NSURL *)URL;

- (void)rs_abortImageLoading;

- (void)rs_loadImageWithURL:(NSURL *)url;
- (void)rs_loadImageWithURL:(NSURL *)url completion:(RSImageLoadCompletion)completion;

/**
 * @param contentMode will be setted on completion
 */
- (void)rs_loadImageWithURL:(NSURL *)url contentMode:(UIViewContentMode)contentMode;

/**
 * @param contentMode will be setted on completion
 */
- (void)rs_loadImageWithURL:(NSURL *)url contentMode:(UIViewContentMode)contentMode
                 completion:(RSImageLoadCompletion)completion;

/**
 * @param contentMode is optional
 */
- (void)rs_loadImageWithURL:(NSURL *)url contentMode:(NSNumber *)contentMode
              onlyFromCache:(BOOL)onlyFromCache completion:(RSImageLoadCompletion)completion;

#pragma mark -

- (void)rs_loadImageFromFileAtPath:(NSString *)path;
- (void)rs_loadImageFromFileAtPath:(NSString *)path withCompletion:(RSImageLoadCompletion)completion;

/**
 * @param contentMode will be setted on completion
 */
- (void)rs_loadImageFromFileAtPath:(NSString *)path withContentMode:(UIViewContentMode)contentMode;

/**
 * @param contentMode will be setted on completion
 */
- (void)rs_loadImageFromFileAtPath:(NSString *)path withContentMode:(UIViewContentMode)contentMode
                        completion:(RSImageLoadCompletion)completion;

@end

@interface UIImageView (RSImageLoader)

@end
