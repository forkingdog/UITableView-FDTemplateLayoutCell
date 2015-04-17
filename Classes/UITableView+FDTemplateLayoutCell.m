// The MIT License (MIT)
//
// Copyright (c) 2015-1016 forkingdog ( https://github.com/forkingdog )
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
    NSAssert(identifier.length > 0, @"Expect a valid identifier - %@", identifier);
    
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
    // Fetch a cached template cell for indentifier
    UITableViewCell *cell = [self fd_templateCellForReuseIdentifier:identifier];
    
    // Reset to default
    cell.contentView.bounds = CGRectMake(0, 0, CGRectGetWidth(self.frame), self.rowHeight);
    
    // Keep what real cells do
    [cell prepareForReuse];
    
    // Configure our template cell
    if (configuration) {
        configuration(cell);
    }
    
    // TODO: What's this fucking temp constraint?
    NSLayoutConstraint *tempWidthConstraint =
    [NSLayoutConstraint constraintWithItem:cell.contentView
                                 attribute:NSLayoutAttributeWidth
                                 relatedBy:NSLayoutRelationEqual
                                    toItem:nil
                                 attribute:NSLayoutAttributeNotAnAttribute
                                multiplier:1.0
                                  constant:CGRectGetWidth(self.frame)];
    [cell.contentView addConstraint:tempWidthConstraint];
    
    // Auto layout system does its math
    CGSize fittingSize = [cell.contentView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize];
    
    [cell.contentView removeConstraint:tempWidthConstraint];
    
    // Add 1px for separator line if needed, screen scale respected
    if (self.separatorStyle != UITableViewCellSeparatorStyleNone) {
        fittingSize.height += 1.0 / [UIScreen mainScreen].scale;
    }
    
    return fittingSize.height;
}

@end
