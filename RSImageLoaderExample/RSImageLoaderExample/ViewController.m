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

#import "ViewController.h"
#import <RSImageLoader.h>
#import <UIView+RSImageLoader.h>
#import "CollectionViewCell.h"

@interface ViewController () <UICollectionViewDataSource, UICollectionViewDelegate> {
    NSArray *_imagesURLs;
}

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    NSMutableArray *URLs = [NSMutableArray new];

    [@[@"https://im2-tub-ru.yandex.net/i?id=416cf92cfcdc62edae1678ef277e83a7&n=11",
       @"https://im2-tub-ru.yandex.net/i?id=73ba62d789b6fb88b7c125f41ac0ced2&n=11",
       @"https://im2-tub-ru.yandex.net/i?id=b49675ee254bd78001b85337192f8bf9&n=11",
       @"https://im2-tub-ru.yandex.net/i?id=d2246da975482d7217782a2097264367&n=11",
       @"https://im2-tub-ru.yandex.net/i?id=f2630eac1fcc576e97ea765a0a2c2277&n=11",
       @"https://im2-tub-ru.yandex.net/i?id=aad6055780c69cd50d404db38d4f7958&n=11",
       @"https://im2-tub-ru.yandex.net/i?id=164822cd1f5b403cc82665630de66c1d&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=791b1e8928554a9aa9546aea4365356f&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=14caef97b74f42bb46424070e840feb0&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=a97643369ddbf770b597491e446f33a4&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=293c144bb1e8f922ba67aa3b40f70736&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=2b5b25f5312e6790df934e1917bb41ca&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=25d10b71eafb0c305e7a06266a8065cc&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=76157fca723f921a93c05e3653627df0&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=79fd6dfaa877e740440cfe82f8642c3e&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=ee150f074959f937b1f7c34c148bcd7d&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=b336460d43038e2a620cfdb962007082&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=dce630600d2c39454c197fdb47e33c64&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=99ac83d906d3ef5e927c738585cc1405&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=9cac2d454719ff6132cd2bcd6bdd4517&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=37dc7a4342797ad00106c3e214a2dfea&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=fa9f8ec0e9df41edfb33197ecb01ef61&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=05e843b00555fd825e236b6c20152ee1&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=480649ea7c705dc8098267709dc8f8f5&n=21",
       @"https://im2-tub-ru.yandex.net/i?id=1dfd4bd65feb219a5c2f4a62a7620b5c&n=21"]
     enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
         [URLs addObject:[NSURL URLWithString:obj]];
     }];

    _imagesURLs = [URLs copy];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _imagesURLs.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    CollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"Cell" forIndexPath:indexPath];

    return cell;
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(CollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    [cell.imageView rs_loadImageWithURL:_imagesURLs[indexPath.item]];
}

@end
