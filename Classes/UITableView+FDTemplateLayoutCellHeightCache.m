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

#import "UITableView+FDTemplateLayoutCellHeightCache.h"

static inline NSNumber *FDTemplateLayoutCellHeightCacheGetAbsentNumber() {
    return @-1;
}

static inline CGFloat FDTemplateLayoutCellHeightCacheGetCGFloatValue(NSNumber *number) {
#if CGFLOAT_IS_DOUBLE
    return number.doubleValue;
#else
    return number.floatValue;
#endif
}

@interface FDTemplateLayoutCellIndexPathHeightCache ()

/// Cache by indexPath, 2 dimensions.
@property (nonatomic, strong) NSMutableArray *heightsBySection;

@end

@implementation FDTemplateLayoutCellIndexPathHeightCache

- (instancetype)init {
    self = [super init];
    if (self) {
        _heightsBySection = [NSMutableArray array];
    }
    return self;
}

- (BOOL)existsHeightAtIndexPath:(NSIndexPath *)indexPath {
    [self buildCachesAtIndexPathsIfNeeded:@[indexPath]];
    NSNumber *number = self.heightsBySection[indexPath.section][indexPath.row];
    return ![number isEqualToNumber:FDTemplateLayoutCellHeightCacheGetAbsentNumber()];
}

- (void)cacheHeight:(CGFloat)height byIndexPath:(NSIndexPath *)indexPath {
    [self buildCachesAtIndexPathsIfNeeded:@[indexPath]];
    self.heightsBySection[indexPath.section][indexPath.row] = @(height);
}

- (CGFloat)heightForIndexPath:(NSIndexPath *)indexPath {
    [self buildCachesAtIndexPathsIfNeeded:@[indexPath]];
    NSNumber *number = self.heightsBySection[indexPath.section][indexPath.row];
    return FDTemplateLayoutCellHeightCacheGetCGFloatValue(number);
}

- (void)clearHeightAtIndexPath:(NSIndexPath *)indexPath {
    [self buildCachesAtIndexPathsIfNeeded:@[indexPath]];
    self.heightsBySection[indexPath.section][indexPath.row] = FDTemplateLayoutCellHeightCacheGetAbsentNumber();
}

- (void)clearAllheightCaches {
    [self.heightsBySection removeAllObjects];
}

- (void)insertSection:(NSInteger)section {
    [self buildSectionsIfNeeded:section];
    [self.heightsBySection insertObject:[NSMutableArray array] atIndex:section];
}

- (void)deleteSection:(NSInteger)section {
    [self buildSectionsIfNeeded:section];
    [self.heightsBySection removeObjectAtIndex:section];
}

- (void)reloadSection:(NSInteger)section {
    [self buildSectionsIfNeeded:section];
    [self.heightsBySection[section] removeAllObjects];
}

- (void)exchangeHeightsFromSection:(NSInteger)fromSection toSection:(NSInteger)toSection {
    [self buildSectionsIfNeeded:fromSection];
    [self buildSectionsIfNeeded:toSection];
    [self.heightsBySection exchangeObjectAtIndex:fromSection withObjectAtIndex:toSection];
}

- (void)insertRowsAtIndexPaths:(NSArray *)indexPaths {
    [self buildCachesAtIndexPathsIfNeeded:indexPaths];
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        NSMutableArray *rows = self.heightsBySection[indexPath.section];
        [rows insertObject:FDTemplateLayoutCellHeightCacheGetAbsentNumber() atIndex:indexPath.row];
    }];
}

- (void)deleteRowsAtIndexPaths:(NSArray *)indexPaths {
    [self buildCachesAtIndexPathsIfNeeded:indexPaths];
    
    NSMutableDictionary *mutableIndexSetsToRemove = [NSMutableDictionary dictionary];
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        
        NSMutableIndexSet *mutableIndexSet = mutableIndexSetsToRemove[@(indexPath.section)];
        if (!mutableIndexSet) {
            mutableIndexSet = [NSMutableIndexSet indexSet];
            mutableIndexSetsToRemove[@(indexPath.section)] = mutableIndexSet;
        }
        
        [mutableIndexSet addIndex:indexPath.row];
    }];
    
    [mutableIndexSetsToRemove enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSIndexSet *indexSet, BOOL *stop) {
        NSMutableArray *rows = self.heightsBySection[key.integerValue];
        [rows removeObjectsAtIndexes:indexSet];
    }];
}

- (void)reloadRowsAtIndexPaths:(NSArray *)indexPaths {
    [self buildCachesAtIndexPathsIfNeeded:indexPaths];
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        NSMutableArray *rows = self.heightsBySection[indexPath.section];
        rows[indexPath.row] = FDTemplateLayoutCellHeightCacheGetAbsentNumber();
    }];
}

- (void)moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
    [self buildCachesAtIndexPathsIfNeeded:@[fromIndexPath, toIndexPath]];
    
    NSMutableArray *sourceRows = self.heightsBySection[fromIndexPath.section];
    NSMutableArray *destinationRows = self.heightsBySection[toIndexPath.section];
    
    NSNumber *sourceValue = sourceRows[fromIndexPath.row];
    NSNumber *destinationValue = destinationRows[toIndexPath.row];
    
    sourceRows[fromIndexPath.row] = destinationValue;
    destinationRows[toIndexPath.row] = sourceValue;
}

#pragma mark - IndexPath Building

- (void)buildCachesAtIndexPathsIfNeeded:(NSArray *)indexPaths {
    // Build every section array or row array which is smaller than given index path.
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        [self buildSectionsIfNeeded:indexPath.section];
        [self buildRowsIfNeeded:indexPath.row inExistSection:indexPath.section];
    }];
}

- (void)buildSectionsIfNeeded:(NSInteger)targetSection {
    for (NSInteger section = 0; section <= targetSection; ++section) {
        if (section >= self.heightsBySection.count) {
            self.heightsBySection[section] = [NSMutableArray array];
        }
    }
}

- (void)buildRowsIfNeeded:(NSInteger)targetRow inExistSection:(NSInteger)section {
    NSMutableArray *heightsByRow = self.heightsBySection[section];
    for (NSInteger row = 0; row <= targetRow; ++row) {
        if (row >= heightsByRow.count) {
            heightsByRow[row] = FDTemplateLayoutCellHeightCacheGetAbsentNumber();
        }
    }
}

@end

@interface FDTemplateLayoutCellKeyHeightCache ()

/// Cache by key.
@property (nonatomic, strong) NSMutableDictionary *heightsByKey;

@end

@implementation FDTemplateLayoutCellKeyHeightCache

- (instancetype)init {
    self = [super init];
    if (self) {
        _heightsByKey = [NSMutableDictionary dictionary];
    }
    return self;
}

- (BOOL)existsHeightForKey:(id<NSCopying>)key {
    NSNumber *number = self.heightsByKey[key];
    return number && ![number isEqualToNumber:FDTemplateLayoutCellHeightCacheGetAbsentNumber()];
}

- (void)cacheHeight:(CGFloat)height byKey:(id<NSCopying>)key {
    self.heightsByKey[key] = @(height);
}

- (CGFloat)heightForKey:(id<NSCopying>)key {
    return FDTemplateLayoutCellHeightCacheGetCGFloatValue(self.heightsByKey[key]);
}

- (void)clearHeightForKey:(id<NSCopying>)key {
    [self.heightsByKey removeObjectForKey:key];
}

- (void)clearAllheightCaches {
    [self.heightsByKey removeAllObjects];
}

@end

#import <objc/runtime.h>

@implementation UITableView (FDTemplateLayoutCellHeightCache)

- (FDTemplateLayoutCellIndexPathHeightCache *)fd_indexPathHeightCache {
    return UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation) ? self.fd_indexPathHeightCacheForPortrait: self.fd_indexPathHeightCacheForLandscape;
}

- (FDTemplateLayoutCellKeyHeightCache *)fd_keyHeightCache {
    return UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation) ? self.fd_keyHeightCacheForPortrait: self.fd_keyHeightCacheForLandscape;
}

#pragma mark - Orientation

- (FDTemplateLayoutCellIndexPathHeightCache *)fd_indexPathHeightCacheForPortrait {
    FDTemplateLayoutCellIndexPathHeightCache *cache = objc_getAssociatedObject(self, _cmd);
    if (!cache) {
        cache = [FDTemplateLayoutCellIndexPathHeightCache new];
        objc_setAssociatedObject(self, _cmd, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}
- (FDTemplateLayoutCellIndexPathHeightCache *)fd_indexPathHeightCacheForLandscape {
    FDTemplateLayoutCellIndexPathHeightCache *cache = objc_getAssociatedObject(self, _cmd);
    if (!cache) {
        cache = [FDTemplateLayoutCellIndexPathHeightCache new];
        objc_setAssociatedObject(self, _cmd, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}

- (FDTemplateLayoutCellKeyHeightCache *)fd_keyHeightCacheForPortrait {
    FDTemplateLayoutCellKeyHeightCache *cache = objc_getAssociatedObject(self, _cmd);
    if (!cache) {
        cache = [FDTemplateLayoutCellKeyHeightCache new];
        objc_setAssociatedObject(self, _cmd, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}
- (FDTemplateLayoutCellKeyHeightCache *)fd_keyHeightCacheForLandscape {
    
    FDTemplateLayoutCellKeyHeightCache *cache = objc_getAssociatedObject(self, _cmd);
    if (!cache) {
        cache = [FDTemplateLayoutCellKeyHeightCache new];
        objc_setAssociatedObject(self, _cmd, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}

@end
