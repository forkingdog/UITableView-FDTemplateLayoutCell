// The MIT License (MIT)
//
// Copyright (c) 2015-2016 forkingdog ( https://github.com/forkingdog )
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#import <UIKit/UIKit.h>

@interface FDTemplateLayoutCellIndexPathHeightCache : NSObject

- (BOOL)existsHeightAtIndexPath:(NSIndexPath *)indexPath;
- (void)cacheHeight:(CGFloat)height byIndexPath:(NSIndexPath *)indexPath;
- (CGFloat)heightForIndexPath:(NSIndexPath *)indexPath;
- (void)clearHeightAtIndexPath:(NSIndexPath *)indexPath;
- (void)clearAllheightCaches;
- (void)insertSection:(NSInteger)section;
- (void)deleteSection:(NSInteger)section;
- (void)reloadSection:(NSInteger)section;

- (void)exchangeHeightsFromSection:(NSInteger)fromSection toSection:(NSInteger)toSection;
- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths;
- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths;
- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths;
- (void)moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath;

@end

@interface FDTemplateLayoutCellKeyHeightCache : NSObject

- (BOOL)existsHeightForKey:(id<NSCopying>)key;
- (void)cacheHeight:(CGFloat)height byKey:(id<NSCopying>)key;
- (CGFloat)heightForKey:(id<NSCopying>)key;
- (void)clearHeightForKey:(id<NSCopying>)key;
- (void)clearAllheightCaches;

@end

/// Do not use directly.
@interface UITableView (FDTemplateLayoutCellHeightCache)

@property (nonatomic, strong, readonly) FDTemplateLayoutCellIndexPathHeightCache *fd_indexPathHeightCache;
@property (nonatomic, strong, readonly) FDTemplateLayoutCellKeyHeightCache *fd_keyHeightCache;

@end
