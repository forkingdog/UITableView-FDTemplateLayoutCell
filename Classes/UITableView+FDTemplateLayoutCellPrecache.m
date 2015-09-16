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

#import "UITableView+FDTemplateLayoutCellPrecache.h"
#import "UITableView+FDTemplateLayoutCellHeightCache.h"
#import "UITableView+FDTemplateLayoutCellDebug.h"
#import <objc/runtime.h>

@implementation UITableView (FDTemplateLayoutCellPrecache)

- (BOOL)fd_precacheEnabled {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setFd_precacheEnabled:(BOOL)precacheEnabled {
    objc_setAssociatedObject(self, @selector(fd_precacheEnabled), @(precacheEnabled), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

//static void recursivePerformSinglePrecacheTask(NSMutableArray *mutableIndexPathsToBePrecached) {
//    if (mutableIndexPathsToBePrecached.count == 0) {
//        return;
//    }
//    
//    NSIndexPath *singleTaskIndexPath = mutableIndexPathsToBePrecached.firstObject;
//    [mutableIndexPathsToBePrecached removeObject:singleTaskIndexPath];
//    
//    if (singleTaskIndexPath.section >= [self numberOfSections] || singleTaskIndexPath.row >= [self numberOfRowsInSection:singleTaskIndexPath.section]) {
//        return;
//    }
//    
//    CGFloat height = [self.delegate tableView:self heightForRowAtIndexPath:singleTaskIndexPath];
//    [self fd_debugLog:[NSString stringWithFormat:
//                       @"precached index path[%@:%@] - %@",
//                       @(singleTaskIndexPath.section),
//                       @(singleTaskIndexPath.row),
//                       @(height)]];
//    
//    static const CFTimeInterval after = 1.0;
//    CFRunLoopTimerRef singleTaskTimer = CFRunLoopTimerCreateWithHandler(NULL, CFAbsoluteTimeGetCurrent() + after, 0, 0, 0, ^(CFRunLoopTimerRef timer) {
//        recursivePerformSinglePrecacheTask();
//    });
//    CFRunLoopAddTimer(runLoop, singleTaskTimer, workingRunLoopMode);
//}

- (void)fd_precacheIfNeeded {
    if (!self.fd_precacheEnabled) {
        return;
    }
    
    // Delegate could use "rowHeight" rather than implement this method.
    if (![self.delegate respondsToSelector:@selector(tableView:heightForRowAtIndexPath:)]) {
        return;
    }
    
//    // Collect all index paths to be precached.
//    NSMutableArray *mutableIndexPathsToBePrecached = [NSMutableArray array];
//    for (NSInteger section = 0; section < [self numberOfSections]; ++section) {
//        for (NSInteger row = 0; row < [self numberOfRowsInSection:section]; ++row) {
//            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
//            [mutableIndexPathsToBePrecached addObject:indexPath];
//        }
//    }
//    
//    if (mutableIndexPathsToBePrecached.count == 0) {
//        return;
//    }
//    
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();

    // This is a idle mode of RunLoop, when UIScrollView scrolls, it jumps into "UITrackingRunLoopMode"
    // and won't perform any cache task to keep a smooth scroll.
    CFStringRef workingRunLoopMode = kCFRunLoopDefaultMode;
    
    NSMutableArray *mutableIndexPathsToBePrecached = [self fd_allIndexPathsToBePrecached].mutableCopy;
//
//    CFRunLoopTimerRef workingRunLoopModeEntranceTimer = CFRunLoopTimerCreateWithHandler(NULL, CFAbsoluteTimeGetCurrent(), 0, 0, 0, ^(CFRunLoopTimerRef timer) {
//        void (^recursivePerformSinglePrecacheTask)(void) = ^{
//           
//        };
//        recursivePerformSinglePrecacheTask();
//    });
//    CFRunLoopAddTimer(runLoop, workingRunLoopModeEntranceTimer, workingRunLoopMode);
    
    // Setup a observer to get a perfect moment for precaching tasks.
    // We use a "kCFRunLoopBeforeWaiting" state to keep RunLoop has done everything and about to sleep
    // (mach_msg_trap), when all tasks finish, it will remove itself.
    CFRunLoopObserverRef observer = CFRunLoopObserverCreateWithHandler(kCFAllocatorDefault, kCFRunLoopBeforeWaiting, true, 0, ^(CFRunLoopObserverRef observer, CFRunLoopActivity _) {
        
        // Remove observer when all precache tasks are done.
        if (mutableIndexPathsToBePrecached.count == 0) {
            CFRunLoopRemoveObserver(runLoop, observer, workingRunLoopMode);
            CFRelease(observer);
            return;
        }
        // Pop first index path record as this RunLoop iteration's task.
        NSIndexPath *indexPath = mutableIndexPathsToBePrecached.firstObject;
        [mutableIndexPathsToBePrecached removeObject:indexPath];
        
        
        // This method creates a "source 0" task in "idle" mode of RunLoop, and will be
        // performed in a future RunLoop iteration only when user is not scrolling.
        [self performSelector:@selector(fd_precacheHeightAtIndexPathIfNeeded:)
                     onThread:[NSThread mainThread]
                   withObject:indexPath
                waitUntilDone:NO
                        modes:@[NSDefaultRunLoopMode]];
    });
    
    CFRunLoopAddObserver(runLoop, observer, workingRunLoopMode);
}

- (void)fd_precacheHeightAtIndexPathIfNeeded:(NSIndexPath *)indexPath {
    // A cached indexPath
    if ([self.fd_indexPathHeightCache existsHeightAtIndexPath:indexPath]) {
        return;
    }
    
    // This RunLoop source may have been invalid at this point when data source
    // changes during precache's dispatching.
    if (indexPath.section >= [self numberOfSections] ||
        indexPath.row >= [self numberOfRowsInSection:indexPath.section]) {
        return;
    }
    
    CGFloat height = [self.delegate tableView:self heightForRowAtIndexPath:indexPath];
    [self fd_debugLog:[NSString stringWithFormat:
                       @"precached index path[%@:%@] - %@",
                       @(indexPath.section),
                       @(indexPath.row),
                       @(height)]];
}

- (NSArray *)fd_allIndexPathsToBePrecached {
    NSMutableArray *allIndexPaths = @[].mutableCopy;
    for (NSInteger section = 0; section < [self numberOfSections]; ++section) {
        for (NSInteger row = 0; row < [self numberOfRowsInSection:section]; ++row) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:section];
            if (![self.fd_indexPathHeightCache existsHeightAtIndexPath:indexPath]) {
                [allIndexPaths addObject:indexPath];
            }
        }
    }
    return allIndexPaths.copy;
}

@end
