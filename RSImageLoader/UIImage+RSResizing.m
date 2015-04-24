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

#import "UIImage+RSResizing.h"

@implementation UIImage (RSResizing)

- (CGSize)_rs_realSize {
    CGFloat selfScale = self.scale;
    CGSize selfRealSize = self.size;

    selfRealSize.width *= selfScale;
    selfRealSize.height *= selfScale;

    return selfRealSize;
}

- (UIImage *)rs_imageWithScaleToSize:(CGSize)size considerAspectRatio:(BOOL)considerAspectRatio {
    CGFloat width = size.width;
    CGFloat height = size.height;

    CGSize selfRealSize = self._rs_realSize;

    CGFloat widthScale = width / selfRealSize.width;
    CGFloat heightScale = height / selfRealSize.height;
    CGFloat scale = considerAspectRatio ? MIN(widthScale, heightScale) : MAX(widthScale, heightScale);

    if (scale == 1 && (considerAspectRatio || CGSizeEqualToSize(size, selfRealSize))) {
        return self;
    }

    width = (int)(selfRealSize.width * scale);
    height = (int)(selfRealSize.height * scale);

    CGSize contextSize = considerAspectRatio ? CGSizeMake(width, height) : size;

    UIGraphicsBeginImageContext(contextSize);

    [self drawInRect:CGRectMake((contextSize.width - width) * 0.5f, (contextSize.height - height) * 0.5f,
                                width, height)];

    UIImage *scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
}

@end
