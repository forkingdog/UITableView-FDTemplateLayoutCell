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

typedef NS_ENUM(NSInteger, FDSimulatedCacheMode) {
    FDSimulatedCacheModeNone = 0,
    FDSimulatedCacheModeCacheByIndexPath,
    FDSimulatedCacheModeCacheByKey
};

@interface FDFeedViewController () <UIActionSheetDelegate>

@property (nonatomic, copy) NSArray *prototypeEntitiesFromJSON;
@property (nonatomic, strong) NSMutableArray *feedEntitySections; // 2d array
@property (nonatomic, strong) NSMutableArray *sectionTitles;
@property (nonatomic, weak) IBOutlet UISegmentedControl *cacheModeSegmentControl;
@property (weak, nonatomic) IBOutlet UISwitch *sectionTitleSwitch;

@end

@implementation FDFeedViewController

- (void)viewDidLoad {
    [super viewDidLoad];
   
    self.tableView.fd_debugLogEnabled = YES;
    self.tableView.sectionIndexBackgroundColor = [UIColor colorWithRed:245/255. green:245/255. blue:245/255. alpha:1.];
    self.tableView.sectionIndexColor = [UIColor colorWithRed:0. green:0. blue:108/255. alpha:1.];
    
    // Cache by index path initial
    self.cacheModeSegmentControl.selectedSegmentIndex = 1;
    
    [self buildTestDataThen:^{
        self.feedEntitySections = @[].mutableCopy;
        self.sectionTitles = @[].mutableCopy;
        [self.sectionTitles addObject:[self demoSectionTitle]];
        [self.feedEntitySections addObject:self.prototypeEntitiesFromJSON.mutableCopy];
        [self.tableView reloadData];
    }];
}

- (void)buildTestDataThen:(void (^)(void))then {
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
        self.prototypeEntitiesFromJSON = entities;
        
        // Callback
        dispatch_async(dispatch_get_main_queue(), ^{
            !then ?: then();
        });
    });
}

static NSArray <NSString *>*titles;
- (NSString *)demoSectionTitle {
    if (!titles) {
        titles = @[@"A",@"BB",@"CCC",@"DDDDD",@"EEE",@"FF",@"G",@"H",@"I",@"J",@"K",@"L",@"M",@"N",@"O",@"P",@"Q"];
    }
    NSInteger index = self.feedEntitySections.count%titles.count;
    return titles[index];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.feedEntitySections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.feedEntitySections[section] count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return self.sectionTitles[section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    FDFeedCell *cell = [tableView dequeueReusableCellWithIdentifier:@"FDFeedCell"];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(FDFeedCell *)cell atIndexPath:(NSIndexPath *)indexPath {
    cell.fd_enforceFrameLayout = NO; // Enable to use "-sizeThatFits:"
    if (indexPath.row % 2 == 0) {
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    } else {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    }
    cell.entity = self.feedEntitySections[indexPath.section][indexPath.row];
}

- (NSArray <NSString *>*)sectionIndexTitlesForTableView:(UITableView *)tableView {
    return self.sectionTitleSwitch.on ? self.sectionTitles : nil;
}

#pragma mark - UITableViewDelegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    FDSimulatedCacheMode mode = self.cacheModeSegmentControl.selectedSegmentIndex;
    switch (mode) {
        case FDSimulatedCacheModeNone:
            return [tableView fd_heightForCellWithIdentifier:@"FDFeedCell" configuration:^(FDFeedCell *cell) {
                [self configureCell:cell atIndexPath:indexPath];
            }];
        case FDSimulatedCacheModeCacheByIndexPath:
            return [tableView fd_heightForCellWithIdentifier:@"FDFeedCell" cacheByIndexPath:indexPath configuration:^(FDFeedCell *cell) {
                [self configureCell:cell atIndexPath:indexPath];
            }];
        case FDSimulatedCacheModeCacheByKey: {
            FDFeedEntity *entity = self.feedEntitySections[indexPath.section][indexPath.row];

            return [tableView fd_heightForCellWithIdentifier:@"FDFeedCell" cacheByKey:entity.identifier configuration:^(FDFeedCell *cell) {
                [self configureCell:cell atIndexPath:indexPath];
            }];
        };
        default:
            break;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 20.;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSMutableArray *mutableEntities = self.feedEntitySections[indexPath.section];
        [mutableEntities removeObjectAtIndex:indexPath.row];
        [self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

#pragma mark - Actions

- (IBAction)refreshControlAction:(UIRefreshControl *)sender {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self.feedEntitySections removeAllObjects];
        [self.sectionTitles removeAllObjects];
        [self.sectionTitles addObject:[self demoSectionTitle]];
        [self.feedEntitySections addObject:self.prototypeEntitiesFromJSON.mutableCopy];
        [self.tableView reloadData];
        [sender endRefreshing];
    });
}

- (IBAction)rightNavigationItemAction:(id)sender {
    [[[UIActionSheet alloc]
      initWithTitle:@"Actions"
      delegate:self
      cancelButtonTitle:@"Cancel"
      destructiveButtonTitle:nil
      otherButtonTitles:
      @"Insert a row",
      @"Insert a section",
      @"Delete a section", nil]
     showInView:self.view];
}

- (IBAction)sectionTitleSwitchChange:(UISwitch *)sender {
    [self.tableView reloadData];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    SEL selectors[] = {
        @selector(insertRow),
        @selector(insertSection),
        @selector(deleteSection)
    };

    if (buttonIndex < sizeof(selectors) / sizeof(SEL)) {
        void(*imp)(id, SEL) = (typeof(imp))[self methodForSelector:selectors[buttonIndex]];
        imp(self, selectors[buttonIndex]);
    }
}

#pragma mark - TableView Editing

- (FDFeedEntity *)randomEntity {
    NSUInteger randomNumber = arc4random_uniform((int32_t)self.prototypeEntitiesFromJSON.count);
    FDFeedEntity *randomEntity = self.prototypeEntitiesFromJSON[randomNumber];
    return randomEntity;
}

- (void)insertRow {
    if (self.feedEntitySections.count == 0) {
        [self insertSection];
    } else {
        [self.feedEntitySections[0] insertObject:self.randomEntity atIndex:0];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
        [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

- (void)insertSection {
    [self.sectionTitles insertObject:[self demoSectionTitle] atIndex:0];
    [self.feedEntitySections insertObject:@[self.randomEntity].mutableCopy atIndex:0];
    [self.tableView insertSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)deleteSection {
    if (self.feedEntitySections.count > 0) {
        [self.sectionTitles removeObjectAtIndex:0];
        [self.feedEntitySections removeObjectAtIndex:0];
        [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationAutomatic];
    }
}

@end
