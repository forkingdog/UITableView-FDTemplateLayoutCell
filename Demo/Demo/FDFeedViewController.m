//
//  FDFeedViewController.m
//  Demo
//
//  Created by sunnyxx on 15/4/16.
//  Copyright (c) 2015年 forkingdog. All rights reserved.
//

#import "FDFeedViewController.h"
#import "UITableView+FDTemplateLayoutCell.h"
#import "FDFeedEntity.h"
#import "FDFeedCell.h"

@interface FDFeedViewController ()

@property (nonatomic, copy) NSArray *feedEntities;

@end

@implementation FDFeedViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self buildTestDataThen:^{
        [self.tableView reloadData];
    }];
}

- (void)buildTestDataThen:(void (^)(void))then
{
    // Simulate an async request
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        // Data from `data.json`
        NSString *dataFilePath = [[NSBundle mainBundle] pathForResource:@"data" ofType:@"json"];
        NSData *data = [NSData dataWithContentsOfFile:dataFilePath];
        NSDictionary *rootDict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingAllowFragments error:nil];
        NSArray *feedDicts = rootDict[@"feed"];
        
        // Convert to `FDFeedEntity`
        NSMutableArray *entities = @[].mutableCopy;
        [feedDicts enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [entities addObject:[[FDFeedEntity alloc] initWithDictionary:obj]];
        }];
        self.feedEntities = entities;
        
        // Callback
        dispatch_async(dispatch_get_main_queue(), ^{
            !then ?: then();
        });
    });
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.feedEntities.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    FDFeedCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FDFeedCell" forIndexPath:indexPath];
    cell.entity = self.feedEntities[indexPath.row];
    return cell;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView fd_heightForCellWithIdentifier:@"FDFeedCell" configuration:^(FDFeedCell *cell) {
        cell.entity = self.feedEntities[indexPath.row];
    }];
}


@end
