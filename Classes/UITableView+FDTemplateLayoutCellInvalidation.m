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

#import "UITableView+FDTemplateLayoutCellInvalidation.h"
#import "UITableView+FDTemplateLayoutCellHeightCache.h"
#import "UITableView+FDTemplateLayoutCellPrecache.h"
#import <objc/runtime.h>

@implementation UITableView (FDTemplateLayoutCellInvalidation)

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
    if (self.fd_autoInvalidateEnabled) {
        [self.fd_indexPathHeightCache clearAllheightCaches];
    }
    [self fd_reloadData]; // Primary call
}

- (void)fd_insertSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_autoInvalidateEnabled) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL *stop) {
            [self.fd_indexPathHeightCache insertSection:section];
        }];
    }
    [self fd_insertSections:sections withRowAnimation:animation]; // Primary call
}

- (void)fd_deleteSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_autoInvalidateEnabled) {
        [sections enumerateIndexesUsingBlock:^(NSUInteger section, BOOL *stop) {
            [self.fd_indexPathHeightCache deleteSection:section];
        }];
    }
    [self fd_deleteSections:sections withRowAnimation:animation]; // Primary call
}

- (void)fd_reloadSections:(NSIndexSet *)sections withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_autoInvalidateEnabled) {
        [sections enumerateIndexesUsingBlock: ^(NSUInteger section, BOOL *stop) {
            [self.fd_indexPathHeightCache reloadSection:section];
        }];
    }
    [self fd_reloadSections:sections withRowAnimation:animation]; // Primary call
}

- (void)fd_moveSection:(NSInteger)section toSection:(NSInteger)newSection {
    if (self.fd_autoInvalidateEnabled) {
        [self.fd_indexPathHeightCache exchangeHeightsFromSection:section toSection:newSection];
    }
    [self fd_moveSection:section toSection:newSection]; // Primary call
}

- (void)fd_insertRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_autoInvalidateEnabled) {
        [self.fd_indexPathHeightCache insertRowsAtIndexPaths:indexPaths];
    }
    [self fd_insertRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
}

- (void)fd_deleteRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_autoInvalidateEnabled) {
        [self.fd_indexPathHeightCache deleteRowsAtIndexPaths:indexPaths];
    }
    [self fd_deleteRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
}

- (void)fd_reloadRowsAtIndexPaths:(NSArray *)indexPaths withRowAnimation:(UITableViewRowAnimation)animation {
    if (self.fd_autoInvalidateEnabled) {
        [self.fd_indexPathHeightCache reloadRowsAtIndexPaths:indexPaths];
    }
    [self fd_reloadRowsAtIndexPaths:indexPaths withRowAnimation:animation]; // Primary call
}

- (void)fd_moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath {
    if (self.fd_autoInvalidateEnabled) {
        [self.fd_indexPathHeightCache moveRowAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath];
    }
    [self fd_moveRowAtIndexPath:sourceIndexPath toIndexPath:destinationIndexPath]; // Primary call
}

#pragma mark - Public

- (BOOL)fd_autoInvalidateEnabled {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_autoInvalidateEnabled:(BOOL)enabled {
    objc_setAssociatedObject(self, @selector(fd_autoInvalidateEnabled), @(enabled), OBJC_ASSOCIATION_RETAIN);
}

- (void)invalidateHeightAtIndexPath:(NSIndexPath *)indexPath {
    [self.fd_indexPathHeightCache clearHeightAtIndexPath:indexPath];
    [self fd_precacheIfNeeded];
}

- (void)invalidateHeightForKey:(id<NSCopying>)key {
    [self.fd_keyHeightCache clearHeightForKey:key];
    [self fd_precacheIfNeeded];
}

@end
