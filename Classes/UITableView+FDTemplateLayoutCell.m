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

#import "UITableView+FDTemplateLayoutCell.h"
#import <objc/runtime.h>

#pragma mark - UITableView + FDTemplateLayoutCellDebugLog

@implementation UITableView (FDTemplateLayoutCellDebugLog)

- (BOOL)fd_debugLogEnabled
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_debugLogEnabled:(BOOL)debugLogEnabled
{
    objc_setAssociatedObject(self, @selector(fd_debugLogEnabled), @(debugLogEnabled), OBJC_ASSOCIATION_RETAIN);
}

- (void)fd_debugLog:(NSString *)message
{
    if (!self.fd_debugLogEnabled) {
        return;
    }
    NSLog(@"** FDTemplateLayoutCell ** %@", message);
}

@end

#pragma mark - _FDTemplateLayoutCellHeightCache

@interface _FDTemplateLayoutCellHeightCache : NSObject
// 2 dimensions array, sections-rows-height
@property (nonatomic, strong) NSMutableArray *sections;
@end

// Tag a absent height cache value which will be set to a real value.
static CGFloat const _FDTemplateLayoutCellHeightCacheAbsentValue = -1;

@implementation _FDTemplateLayoutCellHeightCache

- (void)buildHeightCachesAtIndexPathsIfNeeded:(NSArray *)indexPaths
{
    if (indexPaths.count == 0) {
        return;
    }
    
    if (!self.sections) {
        self.sections = @[].mutableCopy;
    }
    
    // Build every section array or row array which is smaller than given index path.
    [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
        for (NSInteger section = 0; section <= indexPath.section; ++section) {
            if (section >= self.sections.count) {
                self.sections[section] = @[].mutableCopy;
            }
        }
        NSMutableArray *rows = self.sections[indexPath.section];
        for (NSInteger row = 0; row <= indexPath.row; ++row) {
            if (row >= rows.count) {
                rows[row] = @(_FDTemplateLayoutCellHeightCacheAbsentValue);
            }
        }
    }];
}

- (BOOL)hasCachedHeightAtIndexPath:(NSIndexPath *)indexPath
{
    [self buildHeightCachesAtIndexPathsIfNeeded:@[indexPath]];
    NSNumber *cachedNumber = self.sections[indexPath.section][indexPath.row];
    return ![cachedNumber isEqualToNumber:@(_FDTemplateLayoutCellHeightCacheAbsentValue)];
}

- (void)cacheHeight:(CGFloat)height byIndexPath:(NSIndexPath *)indexPath
{
    [self buildHeightCachesAtIndexPathsIfNeeded:@[indexPath]];
    self.sections[indexPath.section][indexPath.row] = @(height);
}

- (CGFloat)cachedHeightAtIndexPath:(NSIndexPath *)indexPath
{
    [self buildHeightCachesAtIndexPathsIfNeeded:@[indexPath]];
#if CGFLOAT_IS_DOUBLE
    return [self.sections[indexPath.section][indexPath.row] doubleValue];
#else
    return [self.sections[indexPath.section][indexPath.row] floatValue];
#endif
}

@end

#pragma mark - UITableView + FDTemplateLayoutCellPrivateAssociations

@interface UITableView (FDTemplateLayoutCellPrivateAssociations)
/// This is a private switch that I don't think caller should concern.
/// Auto turn on when you use "-fd_heightForCellWithIdentifier:cacheByIndexPath:configuration".
@property (nonatomic, assign) BOOL fd_autoCacheInvalidationEnabled;
@end

@implementation UITableView (FDTemplateLayoutCellPrivateAssociations)

- (id)fd_templateCellForReuseIdentifier:(NSString *)identifier;
{
    NSAssert(identifier.length > 0, @"Expects a valid identifier - %@", identifier);
    
    NSMutableDictionary *templateCellsByIdentifiers = objc_getAssociatedObject(self, _cmd);
    if (!templateCellsByIdentifiers) {
        templateCellsByIdentifiers = @{}.mutableCopy;
        objc_setAssociatedObject(self, _cmd, templateCellsByIdentifiers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    UITableViewCell *templateCell = templateCellsByIdentifiers[identifier];
    if (!templateCell) {
        templateCell = [self dequeueReusableCellWithIdentifier:identifier];
        templateCellsByIdentifiers[identifier] = templateCell;
    }
    
    return templateCell;
}

- (_FDTemplateLayoutCellHeightCache *)fd_cellHeightCache
{
    _FDTemplateLayoutCellHeightCache *cache = objc_getAssociatedObject(self, _cmd);
    if (!cache) {
        cache = [_FDTemplateLayoutCellHeightCache new];
        objc_setAssociatedObject(self, _cmd, cache, OBJC_ASSOCIATION_RETAIN);
    }
    return cache;
}

- (BOOL)fd_autoCacheInvalidationEnabled
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_autoCacheInvalidationEnabled:(BOOL)enabled
{
    objc_setAssociatedObject(self, @selector(fd_autoCacheInvalidationEnabled), @(enabled), OBJC_ASSOCIATION_RETAIN);
}

@end

#pragma mark - UITableView + FDTemplateLayoutCellHeightPrecaching

@implementation UITableView (FDTemplateLayoutCellHeightPrecaching)

- (void)fd_precacheIfNeeded
{
    if (!self.fd_precacheEnabled) {
        return;
    }
    
    // Delegate could use "rowHeight" rather than implements this method.
    if (![self.delegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return;
    }
    
    CFRunLoopRef runLoop = [[NSRunLoop currentRunLoop] getCFRunLoop];
    // This is a idle mode of RunLoop, when UIScrollView scrolls, it jumps into "UITrackingRunLoopMode"
    // and won't perform any cache task to keep a smooth scroll.
    CFStringRef runLoopMode = kCFRunLoopDefaultMode;
    
    // Setup a observer to get a perfect moment for precaching tasks.
    // We use a "kCFRunLoopBeforeWaiting" state to keep RunLoop has done everything and about to sleep
    // (mach_msg_trap), when all tasks finish, it will remove itself.
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler
    (kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity _) {
        // Collect all index paths to be precached.
        NSMutableArray *allIndexPathsToBePrecached = self.fd_allIndexPathsToBePrecached.mutableCopy;
        if (allIndexPathsToBePrecached.count == 0) {
            CFRunLoopRemoveObserver(runLoop, observer, runLoopMode);
            return;
        }
        
        // This method creates a "source0" task in "idle" mode of RunLoop, and will be
        // performed in a future RunLoop iteration only when user is not scrolling.
        [self performSelector:@selector(fd_precacheOneOfAllIndexPathsToBePrecached:)
                     onThread:[NSThread mainThread]
                   withObject:allIndexPathsToBePrecached
                waitUntilDone:NO
                        modes:@[NSDefaultRunLoopMode]];
    });
    
    CFRunLoopAddObserver(runLoop, observer, runLoopMode);
}

- (void)fd_precacheOneOfAllIndexPathsToBePrecached:(NSMutableArray *)allIndexPaths
{
    NSIndexPath *indexPath = allIndexPaths.firstObject;
    if (![self.fd_cellHeightCache hasCachedHeightAtIndexPath:indexPath]) {
        CGFloat height = [self.delegate tableView:self heightForRowAtIndexPath:indexPath];
        [self.fd_cellHeightCache cacheHeight:height byIndexPath:indexPath];
        [self fd_debugLog:[NSString stringWithFormat:
                           @"precached - [%@:%@] %@",
                           @(indexPath.section),
                           @(indexPath.row),
                           @(height)]];
    }
    [allIndexPaths removeObjectAtIndex:0];
}

- (NSArray *)fd_allIndexPathsToBePrecached
{
    NSMutableArray *allIndexPaths = @[].mutableCopy;
    for (NSInteger section = 0; section < [self numberOfSections]; ++section) {
        for (NSInteger row = 0; row < [self numberOfRowsInSection:section]; ++row) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
            if (![self.fd_cellHeightCache hasCachedHeightAtIndexPath:indexPath]) {
                [allIndexPaths addObject:indexPath];
            }
        }
    }
    return allIndexPaths.copy;
}

@end

#pragma mark - UITableView + FDTemplateLayoutCellAutomaticallyCacheInvalidation

@implementation UITableView (FDTemplateLayoutCellAutomaticallyCacheInvalidation)

+ (void)load
{
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

- (void)fd_reloadData
{
    if (self.fd_autoCacheInvalidationEnabled) {
        [self.fd_cellHeightCache.sections removeAllObjects];
    }
    [self fd_reloadData]; // Primary call
    [self fd_precacheIfNeeded];
}

- (void)fd_insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.fd_autoCacheInvalidationEnabled) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [self.fd_cellHeightCache.sections insertObject:@[].mutableCopy atIndex:idx];
        }];
    }
    [self fd_insertSections:sections withRowAnimation:animation]; // Primary call
    [self fd_precacheIfNeeded];
}

- (void)fd_deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.fd_autoCacheInvalidationEnabled) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            [self.fd_cellHeightCache.sections removeObjectAtIndex:idx];
        }];
    }
    [self fd_deleteSections:sections withRowAnimation:animation]; // Primary call
}

- (void)fd_reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.fd_autoCacheInvalidationEnabled) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL *stop) {
            NSMutableArray *rows = self.fd_cellHeightCache.sections[idx];
            for (NSInteger row = 0; row < rows.count; ++row) {
                rows[row] = @(_FDTemplateLayoutCellHeightCacheAbsentValue);
            }
        }];
    }
    [self fd_reloadSections:sections withRowAnimation:animation]; // Primary call
    [self fd_precacheIfNeeded];
}

- (void)fd_moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
    if (self.fd_autoCacheInvalidationEnabled) {
    [self.fd_cellHeightCache.sections exchangeObjectAtIndex:section withObjectAtIndex:newSection];
    }
    [self fd_moveSection:section toSection:newSection]; // Primary call
}

- (void)fd_insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.fd_autoCacheInvalidationEnabled) {
        [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
            NSMutableArray *rows = self.fd_cellHeightCache.sections[indexPath.section];
            [rows insertObject:@(_FDTemplateLayoutCellHeightCacheAbsentValue) atIndex:indexPath.row];
        }];
    }
    [self fd_insertRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
    [self fd_precacheIfNeeded];
}

- (void)fd_deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.fd_autoCacheInvalidationEnabled) {
        [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
            [self.fd_cellHeightCache.sections[indexPath.section] removeObjectAtIndex:indexPath.row];
        }];
    }
    [self fd_deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
}

- (void)fd_reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.fd_autoCacheInvalidationEnabled) {
        [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
            NSMutableArray *rows = self.fd_cellHeightCache.sections[indexPath.section];
            rows[indexPath.row] = @(_FDTemplateLayoutCellHeightCacheAbsentValue);
        }];
    }
    [self fd_reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
    [self fd_precacheIfNeeded];
}

- (void)fd_moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    if (self.fd_autoCacheInvalidationEnabled) {
        NSMutableArray *sourceRows = self.fd_cellHeightCache.sections[sourceIndexPath.section];
        NSMutableArray *destinationRows = self.fd_cellHeightCache.sections[destinationIndexPath.section];
        
        NSNumber *sourceValue = sourceRows[sourceIndexPath.row];
        NSNumber *destinationValue = destinationRows[destinationIndexPath.row];
        
        sourceRows[sourceIndexPath.row] = destinationValue;
        destinationRows[destinationIndexPath.row] = sourceValue;
    }
    [self fd_moveRowAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath]; // Primary call
}

@end

#pragma mark - [Public] UITableView + FDTemplateLayoutCell

@implementation UITableView (FDTemplateLayoutCell)

- (CGFloat)fd_heightForCellWithIdentifier:(NSString *)identifier configuration:(void (^)(id))configuration
{
    if (!identifier) {
        return 0;
    }
    
    // Fetch a cached template cell for `identifier`.
    UITableViewCell *cell = [self fd_templateCellForReuseIdentifier:identifier];
    
    // Manually calls to ensure consistent behavior with actual cells (that are displayed on screen).
    [cell prepareForReuse];
    
    // Customize and provide content for our template cell.
    if (configuration) {
        configuration(cell);
    }
    
    // Add a hard width constraint to make dynamic content views (like labels) expand vertically instead
    // of growing horizontally, in a flow-layout manner.
    NSLayoutConstraint *tempWidthConstraint =
    [NSLayoutConstraint constraintWithItem:cell.contentView
                                 attribute:NSLayoutAttributeWidth
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:1.0
                                  constant:CGRectGetWidth(self.frame)];
    [cell.contentView addConstraint:tempWidthConstraint];
    
    // Auto layout engine does its math
    CGSize fittingSize = [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    
    [cell.contentView removeConstraint:tempWidthConstraint];
    
    // Add 1px extra space for separator line if needed, simulating default UITableViewCell.
    if (self.separatorStyle != UITableViewCellSeparatorStyleNone) {
        fittingSize.height += 1.0 / [UIScreen mainScreen].scale;
    }
    
    return fittingSize.height;
}

- (CGFloat)fd_heightForCellWithIdentifier:(NSString *)identifier cacheByIndexPath:(NSIndexPath *)indexPath configuration:(void (^)(id))configuration
{
    if (!identifier || !indexPath) {
        return 0;
    }
    
    // Enable auto cache invalidation if you use this "cacheByIndexPath" API.
    self.fd_autoCacheInvalidationEnabled = YES;
    
    // Hit the cache
    if ([self.fd_cellHeightCache hasCachedHeightAtIndexPath:indexPath]) {
        [self fd_debugLog:[NSString stringWithFormat:
                           @"hit cache - [%@:%@] %@",
                           @(indexPath.section),
                           @(indexPath.row),
                           @([self.fd_cellHeightCache cachedHeightAtIndexPath:indexPath])]];
        return [self.fd_cellHeightCache cachedHeightAtIndexPath:indexPath];
    }
    
    // Do calculations
    CGFloat height = [self fd_heightForCellWithIdentifier:identifier configuration:configuration];
    [self fd_debugLog:[NSString stringWithFormat:
                       @"calculate - [%@:%@] %@",
                       @(indexPath.section),
                       @(indexPath.row),
                       @(height)]];

    // Cache it
    [self.fd_cellHeightCache cacheHeight:height byIndexPath:indexPath];
    
    return height;
}

- (BOOL)fd_precacheEnabled
{
    NSNumber *associatedNumber = objc_getAssociatedObject(self, _cmd);
    if (!associatedNumber) {
        objc_setAssociatedObject(self, _cmd, @YES, OBJC_ASSOCIATION_RETAIN);
    }
    return associatedNumber.boolValue;
}

- (void)setFd_precacheEnabled:(BOOL)precacheEnabled
{
    objc_setAssociatedObject(self, @selector(fd_precacheEnabled), @(precacheEnabled), OBJC_ASSOCIATION_RETAIN);
}

@end
