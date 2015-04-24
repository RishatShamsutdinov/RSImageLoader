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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef void (^RSImageLoaderHandler)(UIImage *image, NSError *error);

@interface RSImageLoader : NSObject

+ (NSURL *)cacheDirURL;

+ (instancetype)sharedImageLoader;

/**
 * @param handler will be performed on main thread.
 * @return id of download task.
 */
- (NSString *)loadImageWithURL:(NSURL *)url handler:(RSImageLoaderHandler)handler;

/**
 * @param onlyFromCache If \c YES download will not be started.
 If image exists in memory cache and current thread is main \c handler will be invoked immediately.
 * @param handler will be performed on main thread.
 * @return id of download task.
 */
- (NSString *)loadImageWithURL:(NSURL *)url onlyFromCache:(BOOL)onlyFromCache handler:(RSImageLoaderHandler)handler;

- (void)cancelDownloadTaskByID:(NSString *)taskID;

- (void)thumbnailForFileAtPath:(NSString *)path ofSize:(CGSize)size withHandler:(RSImageLoaderHandler)handler;

@end
