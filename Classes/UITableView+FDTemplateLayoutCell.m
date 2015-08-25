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
        
        NSAssert(indexPath.section >= 0, @"Expect a positive section rather than '%@'.", @(indexPath.section));
        
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

#pragma mark - UITableView + FDTemplateLayoutCellPrivate

/// These methods are private for internal use, maybe public some day.
@interface UITableView (FDTemplateLayoutCellPrivate)

/// Returns a template cell created by reuse identifier, it has to be registered to table view.
/// Lazy getter, and associated to table view.
- (id)fd_templateCellForReuseIdentifier:(NSString *)identifier;

/// A private height cache data structure.
@property (nonatomic, strong, readonly) _FDTemplateLayoutCellHeightCache *fd_cellHeightCache;

/// This is a private switch that I don't think caller should concern.
/// Auto turn on when you use "-fd_heightForCellWithIdentifier:cacheByIndexPath:configuration".
@property (nonatomic, assign) BOOL fd_autoCacheInvalidationEnabled;

/// It helps to improve scroll performance by "pre-cache" height of cells that have not
/// been displayed on screen. These calculation tasks are collected and performed only
/// when "RunLoop" is in "idle" time.
///
/// Auto turn on when you use "-fd_heightForCellWithIdentifier:cacheByIndexPath:configuration".
@property (nonatomic, assign) BOOL fd_precacheEnabled;

/// Debug log controlled by "fd_debugLogEnabled".
- (void)fd_debugLog:(NSString *)message;

@end

@implementation UITableView (FDTemplateLayoutCellPrivate)

- (id)fd_templateCellForReuseIdentifier:(NSString *)identifier
{
    NSAssert(identifier.length > 0, @"Expect a valid identifier - %@", identifier);
    
    NSMutableDictionary *templateCellsByIdentifiers = objc_getAssociatedObject(self, _cmd);
    if (!templateCellsByIdentifiers) {
        templateCellsByIdentifiers = @{}.mutableCopy;
        objc_setAssociatedObject(self, _cmd, templateCellsByIdentifiers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    UITableViewCell *templateCell = templateCellsByIdentifiers[identifier];
    
    if (!templateCell) {
        templateCell = [self dequeueReusableCellWithIdentifier:identifier];
        NSAssert(templateCell != nil, @"Cell must be registered to table view for identifier - %@", identifier);
        templateCell.fd_isTemplateLayoutCell = YES;
        templateCell.contentView.translatesAutoresizingMaskIntoConstraints = NO;
        templateCellsByIdentifiers[identifier] = templateCell;
        [self fd_debugLog:[NSString stringWithFormat:@"layout cell created - %@", identifier]];
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

- (BOOL)fd_precacheEnabled
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_precacheEnabled:(BOOL)precacheEnabled
{
    objc_setAssociatedObject(self, @selector(fd_precacheEnabled), @(precacheEnabled), OBJC_ASSOCIATION_RETAIN);
}

- (void)fd_debugLog:(NSString *)message
{
    if (!self.fd_debugLogEnabled) {
        return;
    }
    NSLog(@"** FDTemplateLayoutCell ** %@", message);
}

@end

#pragma mark - UITableView + FDTemplateLayoutCellPrecache

@implementation UITableView (FDTemplateLayoutCellPrecache)

- (void)fd_precacheIfNeeded
{
    if (!self.fd_precacheEnabled) {
        return;
    }
    
    // Delegate could use "rowHeight" rather than implements this method.
    if (![self.delegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return;
    }
    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    
    // This is a idle mode of RunLoop, when UIScrollView scrolls, it jumps into "UITrackingRunLoopMode"
    // and won't perform any cache task to keep a smooth scroll.
    CFStringRef runLoopMode = kCFRunLoopDefaultMode;
    
    // Collect all index paths to be precached.
    NSMutableArray *mutableIndexPathsToBePrecached = self.fd_allIndexPathsToBePrecached.mutableCopy;
    
    // Setup a observer to get a perfect moment for precaching tasks.
    // We use a "kCFRunLoopBeforeWaiting" state to keep RunLoop has done everything and about to sleep
    // (mach_msg_trap), when all tasks finish, it will remove itself.
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler
    (kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity _) {
        // Remove observer when all precache tasks are done.
        if (mutableIndexPathsToBePrecached.count == 0) {
            CFRunLoopRemoveObserver(runLoop, observer, runLoopMode);
            CFRelease(observer);
            return;
        }
        // Pop first index path record as this RunLoop iteration's task.
        NSIndexPath *indexPath = mutableIndexPathsToBePrecached.firstObject;
        [mutableIndexPathsToBePrecached removeObject:indexPath];
        
        // This method creates a "source 0" task in "idle" mode of RunLoop, and will be
        // performed in a future RunLoop iteration only when user is not scrolling.
        [self performSelector:@selector(fd_precacheIndexPathIfNeeded:)
                     onThread:[NSThread mainThread]
                   withObject:indexPath
                waitUntilDone:NO
                        modes:@[NSDefaultRunLoopMode]];
    });
    
    CFRunLoopAddObserver(runLoop, observer, runLoopMode);
}

- (void)fd_precacheIndexPathIfNeeded:(NSIndexPath *)indexPath
{
    // A cached indexPath
    if ([self.fd_cellHeightCache hasCachedHeightAtIndexPath:indexPath]) {
        return;
    }
    
    // This RunLoop source may have been invalid at this point when data source
    // changes during precache's dispatching.
    if (indexPath.section >= [self numberOfSections] ||
        indexPath.row >= [self numberOfRowsInSection:indexPath.section]) {
        return;
    }
    
    CGFloat height = [self.delegate tableView:self heightForRowAtIndexPath:indexPath];
    [self.fd_cellHeightCache cacheHeight:height byIndexPath:indexPath];
    [self fd_debugLog:[NSString stringWithFormat:
                       @"finished precache - [%@:%@] %@",
                       @(indexPath.section),
                       @(indexPath.row),
                       @(height)]];
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
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
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
    });
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
        [sections enumerateIndexesUsingBlock: ^(NSUInteger idx, BOOL *stop) {
            if (idx < self.fd_cellHeightCache.sections.count) {
                NSMutableArray *rows = self.fd_cellHeightCache.sections[idx];
                for (NSInteger row = 0; row < rows.count; ++row) {
                    rows[row] = @(_FDTemplateLayoutCellHeightCacheAbsentValue);
                }
            }
        }];
    }
    [self fd_reloadSections:sections withRowAnimation:animation]; // Primary call
    [self fd_precacheIfNeeded];
}

- (void)fd_moveSection:(NSInteger)section toSection:(NSInteger)newSection
{
    if (self.fd_autoCacheInvalidationEnabled) {
        NSInteger sectionCount = self.fd_cellHeightCache.sections.count;
        if (section < sectionCount && newSection < sectionCount) {
            [self.fd_cellHeightCache.sections exchangeObjectAtIndex:section withObjectAtIndex:newSection];
        }
    }
    [self fd_moveSection:section toSection:newSection]; // Primary call
}

- (void)fd_insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.fd_autoCacheInvalidationEnabled) {
        [self.fd_cellHeightCache buildHeightCachesAtIndexPathsIfNeeded:indexPaths];
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
        [self.fd_cellHeightCache buildHeightCachesAtIndexPathsIfNeeded:indexPaths];
        
        NSMutableDictionary *mutableIndexSetsToRemove = @{}.mutableCopy;
        [indexPaths enumerateObjectsUsingBlock:^(NSIndexPath *indexPath, NSUInteger idx, BOOL *stop) {
            
            NSMutableIndexSet *mutableIndexSet = mutableIndexSetsToRemove[@(indexPath.section)];
            if (!mutableIndexSet) {
                mutableIndexSetsToRemove[@(indexPath.section)] = [NSMutableIndexSet indexSet];
            }
            
            [mutableIndexSet addIndex:indexPath.row];
        }];
        
        [mutableIndexSetsToRemove enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, NSIndexSet *indexSet, BOOL *stop) {
            NSMutableArray *rows = self.fd_cellHeightCache.sections[key.integerValue];
            [rows removeObjectsAtIndexes:indexSet];
        }];
    }
    [self fd_deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
}

- (void)fd_reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation
{
    if (self.fd_autoCacheInvalidationEnabled) {
        [self.fd_cellHeightCache buildHeightCachesAtIndexPathsIfNeeded:indexPaths];
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
        [self.fd_cellHeightCache buildHeightCachesAtIndexPathsIfNeeded:@[sourceIndexPath, destinationIndexPath]];

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
    
    CGFloat contentViewWidth = CGRectGetWidth(self.frame);

    // If a cell has accessory view or system accessory type, its content view's width is smaller
    // than cell's by some fixed values.
    if (cell.accessoryView) {
        contentViewWidth -= 16 + CGRectGetWidth(cell.accessoryView.frame);
    } else {
        static CGFloat systemAccessoryWidths[] = {
            [UITableViewCellAccessoryNone] = 0,
            [UITableViewCellAccessoryDisclosureIndicator] = 34,
            [UITableViewCellAccessoryDetailDisclosureButton] = 68,
            [UITableViewCellAccessoryCheckmark] = 40,
            [UITableViewCellAccessoryDetailButton] = 48
        };
        contentViewWidth -= systemAccessoryWidths[cell.accessoryType];
    }
    
    CGSize fittingSize = CGSizeZero;

    // If auto layout enabled, cell's contentView must have some constraints.
    BOOL autoLayoutEnabled = cell.contentView.constraints.count > 0 && !cell.fd_enforceFrameLayout;
    if (autoLayoutEnabled) {
        
        // Add a hard width constraint to make dynamic content views (like labels) expand vertically instead
        // of growing horizontally, in a flow-layout manner.
        NSLayoutConstraint *tempWidthConstraint =
        [NSLayoutConstraint constraintWithItem:cell.contentView
                                     attribute:NSLayoutAttributeWidth
                                     relatedBy:NSLayoutRelationEqual
                                        toItem:nil
                                     attribute:NSLayoutAttributeNotAnAttribute
                                    multiplier:1.0
                                      constant:contentViewWidth];
        [cell.contentView addConstraint:tempWidthConstraint];
        // Auto layout engine does its math
        fittingSize = [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
        [cell.contentView removeConstraint:tempWidthConstraint];
        
    } else {
        
        // If not using auto layout, you have to override "-sizeThatFits:" to provide a fitting size by yourself.
        // This is the same method used in iOS8 self-sizing cell's implementation.
        // Note: fitting height should not include separator view.
        SEL selector = @selector(sizeThatFits:);
        BOOL inherited = ![cell isMemberOfClass:UITableViewCell.class];
        BOOL overrided = [cell.class instanceMethodForSelector:selector] != [UITableViewCell instanceMethodForSelector:selector];
        if (inherited && !overrided) {
            NSAssert(NO, @"Customized cell must override '-sizeThatFits:' method if not using auto layout.");
        }
        fittingSize = [cell sizeThatFits:CGSizeMake(contentViewWidth, 0)];
    }
    
    // Add 1px extra space for separator line if needed, simulating default UITableViewCell.
    if (self.separatorStyle != UITableViewCellSeparatorStyleNone) {
        fittingSize.height += 1.0 / [UIScreen mainScreen].scale;
    }
    
    if (autoLayoutEnabled) {
        [self fd_debugLog:[NSString stringWithFormat:@"calculate using auto layout - %@", @(fittingSize.height)]];
    } else {
        [self fd_debugLog:[NSString stringWithFormat:@"calculate using frame layout - %@", @(fittingSize.height)]];
    }

    return fittingSize.height;
}

- (CGFloat)fd_heightForCellWithIdentifier:(NSString *)identifier cacheByIndexPath:(NSIndexPath *)indexPath configuration:(void (^)(id))configuration
{
    if (!identifier || !indexPath) {
        return 0;
    }
    
    // Enable auto cache invalidation if you use this "cacheByIndexPath" API.
    if (!self.fd_autoCacheInvalidationEnabled) {
        self.fd_autoCacheInvalidationEnabled = YES;
    }
    
    // Enable precache if you use this "cacheByIndexPath" API.
    if (!self.fd_precacheEnabled) {
        self.fd_precacheEnabled = YES;
        // Manually trigger precache only for the first time.
        [self fd_precacheIfNeeded];
    }
    
    // Hit the cache
    if ([self.fd_cellHeightCache hasCachedHeightAtIndexPath:indexPath]) {
        [self fd_debugLog:[NSString stringWithFormat:
                           @"hit cache - [%@:%@] %@",
                           @(indexPath.section),
                           @(indexPath.row),
                           @([self.fd_cellHeightCache cachedHeightAtIndexPath:indexPath])]];
        return [self.fd_cellHeightCache cachedHeightAtIndexPath:indexPath];
    }
    
    // Call basic height calculation method.
    CGFloat height = [self fd_heightForCellWithIdentifier:identifier configuration:configuration];
    [self fd_debugLog:[NSString stringWithFormat:
                       @"cached - [%@:%@] %@",
                       @(indexPath.section),
                       @(indexPath.row),
                       @(height)]];
    
    // Cache it
    [self.fd_cellHeightCache cacheHeight:height byIndexPath:indexPath];
    
    return height;
}

- (BOOL)fd_debugLogEnabled
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_debugLogEnabled:(BOOL)debugLogEnabled
{
    objc_setAssociatedObject(self, @selector(fd_debugLogEnabled), @(debugLogEnabled), OBJC_ASSOCIATION_RETAIN);
}

@end

#pragma mark - [Public] UITableViewCell + FDTemplateLayoutCell

@implementation UITableViewCell (FDTemplateLayoutCell)

- (BOOL)fd_isTemplateLayoutCell
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_isTemplateLayoutCell:(BOOL)isTemplateLayoutCell
{
    objc_setAssociatedObject(self, @selector(fd_isTemplateLayoutCell), @(isTemplateLayoutCell), OBJC_ASSOCIATION_RETAIN);
}

- (BOOL)fd_enforceFrameLayout
{
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_enforceFrameLayout:(BOOL)enforceFrameLayout
{
    objc_setAssociatedObject(self, @selector(fd_enforceFrameLayout), @(enforceFrameLayout), OBJC_ASSOCIATION_RETAIN);
}

@end
