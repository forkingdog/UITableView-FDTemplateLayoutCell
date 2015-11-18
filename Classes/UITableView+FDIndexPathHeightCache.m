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

#import "UITableView+FDIndexPathHeightCache.h"
#import <objc/runtime.h>

@interface FDIndexPathHeightCache ()
@property (nonatomic, strong) NSMutableArray *heightsBySectionForPortrait;
@property (nonatomic, strong) NSMutableArray *heightsBySectionForLandscape;
@end

@implementation FDIndexPathHeightCache

- (instancetype)init {
    self = [super init];
    if (self) {
        _heightsBySectionForPortrait = [NSMutableArray array];
        _heightsBySectionForLandscape = [NSMutableArray array];
    }
    return self;
}

- (NSMutableArray *)heightsBySectionForCurrentOrientation {
    return UIDeviceOrientationIsPortrait([UIDevice currentDevice].orientation) ? self.heightsBySectionForPortrait: self.heightsBySectionForLandscape;
}

- (void)enumerateAllOrientationsUsingBlock:(void (^)(NSMutableArray *heightsBySection))block {
    block(self.heightsBySectionForPortrait);
    block(self.heightsBySectionForLandscape);
}

- (BOOL)existsHeightAtIndexPath:(NSIndexPath *)indexPath {
    [self buildCachesAtIndexPathsIfNeeded:@[indexPath]];
    NSNumber *number = self.heightsBySectionForCurrentOrientation[indexPath.section][indexPath.row];
    return ![number isEqualToNumber:@-1];
}

- (void)cacheHeight:(CGFloat)height byIndexPath:(NSIndexPath *)indexPath {
    self.automaticallyInvalidateEnabled = YES;
    [self buildCachesAtIndexPathsIfNeeded:@[indexPath]];
    self.heightsBySectionForCurrentOrientation[indexPath.section][indexPath.row] = @(height);
}

- (CGFloat)heightForIndexPath:(NSIndexPath *)indexPath {
    [self buildCachesAtIndexPathsIfNeeded:@[indexPath]];
    NSNumber *number = self.heightsBySectionForCurrentOrientation[indexPath.section][indexPath.row];
#if CGFLOAT_IS_DOUBLE
    return number.doubleValue;
#else
    return number.floatValue;
#endif
}

- (void)invalidateHeightAtIndexPath:(NSIndexPath *)indexPath {
    [self buildCachesAtIndexPathsIfNeeded:@[indexPath]];
    [self enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
        heightsBySection[indexPath.section][indexPath.row] = @-1;
    }];
}

- (void)invalidateAllHeightCache {
    [self enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
        [heightsBySection removeAllObjects];
    }];
}

- (void)buildCachesAtIndexPathsIfNeeded:(NSArray *)indexPaths {
    // Build every section array or row array which is smaller than given index path.
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        [self buildSectionsIfNeeded:indexPath.section];
        [self buildRowsIfNeeded:indexPath.row inExistSection:indexPath.section];
    }];
}

- (void)buildSectionsIfNeeded:(NSInteger)targetSection {
    [self enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
        for (NSInteger section = 0; section <= targetSection; ++section) {
            if (section >= heightsBySection.count) {
                heightsBySection[section] = [NSMutableArray array];
            }
        }
    }];
}

- (void)buildRowsIfNeeded:(NSInteger)targetRow inExistSection:(NSInteger)section {
    [self enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
        NSMutableArray *heightsByRow = heightsBySection[section];
        for (NSInteger row = 0; row <= targetRow; ++row) {
            if (row >= heightsByRow.count) {
                heightsByRow[row] = @-1;
            }
        }
    }];
}

@end

@implementation UITableView (FDIndexPathHeightCache)

- (FDIndexPathHeightCache *)fd_indexPathHeightCache {
    FDIndexPathHeightCache *cache = objc_getAssociatedObject(self, _cmd);
    if (!cache) {
        [self methodSignatureForSelector:nil];
        cache = [FDIndexPathHeightCache new];
        objc_setAssociatedObject(self, _cmd, cache, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return cache;
}

@end

@implementation UITableView (FDIndexPathHeightCacheInvalidation)

- (void)fd_reloadDataWithoutInvalidateIndexPathHeightCache {
    [self fd_reloadData]; // Primary call only
}

+ (void)load {
    // All methods that trigger height cache's invalidation
    SEL selectors[] = {
        @selector(reloadData),
        @selector(insertSections:withRowAnimation:),
        @selector(deleteSections:withRowAnimation:),
        @selector(reloadSections:withRowAnimation:),
        @selector(moveSection:toSection:),
        @selector(insertRowsAtIndexPaths:withRowAnimation:),
        @selector(deleteRowsAtIndexPaths:withRowAnimation:),
        @selector(reloadRowsAtIndexPaths:withRowAnimation:),
        @selector(moveRowAtIndexPath:toIndexPath:)
    };
    
    for (NSUInteger index = 0; index < sizeof(selectors) / sizeof(SEL); ++index) {
        SEL originalSelector = selectors[index];
        SEL swizzledSelector = NSSelectorFromString([@"fd_" stringByAppendingString:NSStringFromSelector(originalSelector)]);
        Method originalMethod = class_getInstanceMethod(self, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(self, swizzledSelector);
        method_exchangeImplementations(originalMethod, swizzledMethod);
    }
}

- (void)fd_reloadData {
    if (self.fd_indexPathHeightCache.automaticallyInvalidateEnabled) {
        [self.fd_indexPathHeightCache enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
            [heightsBySection removeAllObjects];
        }];
    }
    [self fd_reloadData]; // Primary call
}

- (void)fd_insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_indexPathHeightCache.automaticallyInvalidateEnabled) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL *stop) {
            [self.fd_indexPathHeightCache buildSectionsIfNeeded:section];
            [self.fd_indexPathHeightCache enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
                [heightsBySection insertObject:[NSMutableArray array] atIndex:section];
            }];
        }];
    }
    [self fd_insertSections:sections withRowAnimation:animation]; // Primary call
}

- (void)fd_deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_indexPathHeightCache.automaticallyInvalidateEnabled) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL *stop) {
            [self.fd_indexPathHeightCache buildSectionsIfNeeded:section];
            [self.fd_indexPathHeightCache enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
                [heightsBySection removeObjectAtIndex:section];
            }];
        }];
    }
    [self fd_deleteSections:sections withRowAnimation:animation]; // Primary call
}

- (void)fd_reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_indexPathHeightCache.automaticallyInvalidateEnabled) {
        [sections enumerateIndexesUsingBlock: ^(NSUInteger section, BOOL *stop) {
            [self.fd_indexPathHeightCache buildSectionsIfNeeded:section];
            [self.fd_indexPathHeightCache enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
                [heightsBySection[section] removeAllObjects];
            }];

        }];
    }
    [self fd_reloadSections:sections withRowAnimation:animation]; // Primary call
}

- (void)fd_moveSection:(NSInteger)section toSection:(NSInteger)newSection {
    if (self.fd_indexPathHeightCache.automaticallyInvalidateEnabled) {
        [self.fd_indexPathHeightCache buildSectionsIfNeeded:section];
        [self.fd_indexPathHeightCache buildSectionsIfNeeded:newSection];
        [self.fd_indexPathHeightCache enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
            [heightsBySection exchangeObjectAtIndex:section withObjectAtIndex:newSection];
        }];
    }
    [self fd_moveSection:section toSection:newSection]; // Primary call
}

- (void)fd_insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_indexPathHeightCache.automaticallyInvalidateEnabled) {
        [self.fd_indexPathHeightCache buildCachesAtIndexPathsIfNeeded:indexPaths];
        [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
            [self.fd_indexPathHeightCache enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
                NSMutableArray *rows = heightsBySection[indexPath.section];
                [rows insertObject:@-1 atIndex:indexPath.row];
            }];
        }];
    }
    [self fd_insertRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
}

- (void)fd_deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_indexPathHeightCache.automaticallyInvalidateEnabled) {
        [self.fd_indexPathHeightCache buildCachesAtIndexPathsIfNeeded:indexPaths];
        
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
            [self.fd_indexPathHeightCache enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
                NSMutableArray *rows = heightsBySection[key.integerValue];
                [rows removeObjectsAtIndexes:indexSet];
            }];
        }];
    }
    [self fd_deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
}

- (void)fd_reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_indexPathHeightCache.automaticallyInvalidateEnabled) {
        [self.fd_indexPathHeightCache buildCachesAtIndexPathsIfNeeded:indexPaths];
        [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
            [self.fd_indexPathHeightCache enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
                NSMutableArray *rows = heightsBySection[indexPath.section];
                rows[indexPath.row] = @-1;
            }];
        }];
    }
    [self fd_reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
}

- (void)fd_moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (self.fd_indexPathHeightCache.automaticallyInvalidateEnabled) {
        [self.fd_indexPathHeightCache buildCachesAtIndexPathsIfNeeded:@[sourceIndexPath, destinationIndexPath]];
        [self.fd_indexPathHeightCache enumerateAllOrientationsUsingBlock:^(NSMutableArray *heightsBySection) {
            NSMutableArray *sourceRows = heightsBySection[sourceIndexPath.section];
            NSMutableArray *destinationRows = heightsBySection[destinationIndexPath.section];
            NSNumber *sourceValue = sourceRows[sourceIndexPath.row];
            NSNumber *destinationValue = destinationRows[destinationIndexPath.row];
            sourceRows[sourceIndexPath.row] = destinationValue;
            destinationRows[destinationIndexPath.row] = sourceValue;
        }];
    }
    [self fd_moveRowAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath]; // Primary call
}

@end
