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

@implementation UITableView (FDTemplateLayoutCell)

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

- (CGFloat)fd_heightForCellWithIdentifier:(NSString *)identifier configuration:(void (^)(id))configuration
{
    // Fetch a cached template cell for `identifier`.
    UITableViewCell *cell = [self fd_templateCellForReuseIdentifier:identifier];
    
    // Reset to initial height as first created, otherwise the cell's height wouldn't retract if it
    // had larger height before it gets reused.
    cell.contentView.bounds = CGRectMake(0, 0, CGRectGetWidth(self.frame), self.rowHeight);
    
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
    
    // Auto layout does its math
    CGSize fittingSize = [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];

    [cell.contentView removeConstraint:tempWidthConstraint];
    
    // Add 1px extra space for separator line if needed, simulating default UITableViewCell.
    if (self.separatorStyle != UITableViewCellSeparatorStyleNone) {
        fittingSize.height += 1.0 / [UIScreen mainScreen].scale;
    }
    
    return fittingSize.height;
}

@end

@implementation UITableView (FDTemplateLayoutCellHeightCaching)

// The entry point where we could trigger automatically cache invalidation. This hacking
// doesn't belong to UITableView itself, so it's better to use a c++ constructor instead of "+load".
// It will be called after all classes have mapped and loaded into runtime.
__attribute__((constructor)) static void FDTemplateLayoutCellHeightCacheInvalidationEntryPoint()
{
    // Swizzle a private method in a private class "UISectionRowData", we try to assemble this
    // selector instead of using the whole literal string, which may be more safer when submit
    // to App Store.
    NSString *privateSelectorString = [@"refreshWithSection:" stringByAppendingString:@"tableView:tableViewRowData:"];
    SEL originalSelector = NSSelectorFromString(privateSelectorString);
    Method originalMethod = class_getInstanceMethod(NSClassFromString(@"UISectionRowData"), originalSelector);
    if (!originalMethod) {
        return;
    }
    void (*originalIMP)(id, SEL, NSUInteger, id, id) = (typeof(originalIMP))method_getImplementation(originalMethod);
    void (^swizzledBlock)(id, NSUInteger, id, id) = ^(id self, NSUInteger section, UITableView *tableView, id rowData) {
        
        // Invalidate height caches first
        [tableView fd_invalidateHeightCaches];
        
        // Call original implementation
        originalIMP(self, originalSelector, section, tableView, rowData);
    };
    method_setImplementation(originalMethod, imp_implementationWithBlock(swizzledBlock));
}

- (NSMutableDictionary *)fd_cellHeightCachesByIndexPath
{
    NSMutableDictionary *cachesByIndexPath = objc_getAssociatedObject(self, _cmd);
    if (!cachesByIndexPath) {
        cachesByIndexPath = @{}.mutableCopy;
        objc_setAssociatedObject(self, _cmd, cachesByIndexPath, OBJC_ASSOCIATION_RETAIN);
    }
    return cachesByIndexPath;
}

- (void)fd_invalidateHeightCaches
{
    if (self.fd_cellHeightCachesByIndexPath.count > 0) {
        [self.fd_cellHeightCachesByIndexPath removeAllObjects];
    }
}

- (CGFloat)fd_heightForCellWithIdentifier:(NSString *)identifier cacheByIndexPath:(NSIndexPath *)indexPath configuration:(void (^)(id))configuration
{
    NSString *keyForIndexPath = [NSString stringWithFormat:@"%@:%@", @(indexPath.section), @(indexPath.row)];
    if (self.fd_cellHeightCachesByIndexPath[keyForIndexPath]) {
#if CGFLOAT_IS_DOUBLE
        return [self.fd_cellHeightCachesByIndexPath[keyForIndexPath] doubleValue];
#else
        return [self.fd_cellHeightCachesByIndexPath[keyForIndexPath] floatValue];
#endif
    }

    CGFloat height = [self fd_heightForCellWithIdentifier:identifier configuration:configuration];
    self.fd_cellHeightCachesByIndexPath[keyForIndexPath] = @(height);
    
    return height;
}

@end