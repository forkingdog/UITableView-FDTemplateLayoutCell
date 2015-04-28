# UITableView-FDTemplateLayoutCell
![forkingdog](https://cloud.githubusercontent.com/assets/219689/7244961/4209de32-e816-11e4-87bc-b161c442d348.png)

## Overview
Template auto layout cell for **automatically** UITableViewCell height calculating.

![Demo Overview](https://github.com/forkingdog/UITableView-FDTemplateLayoutCell/blob/master/Sceenshots/screenshot2.gif)

## Basic usage

If you have a **self-satisfied** cell, then all you have to do is: 

``` objc
#import "UITableView+FDTemplateLayoutCell.h"

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView fd_heightForCellWithIdentifier:@"reuse identifer" configuration:^(id cell) {
        // Configure this cell with data, same as what you've done in "-tableView:cellForRowAtIndexPath:"
        // Like:
        //    cell.entity = self.feedEntities[indexPath.row];
    }];
}
```
## Advanced usage with height caching

Since iOS8, `-tableView:heightForRowAtIndexPath:` will be called more times than we expect, we can feel these extra calculations when scrolling. So we provide another extension with caches:   

```
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView fd_heightForCellWithIdentifier:@"identifer" cacheByIndexPath:indexPath configuration:^(id cell) {
        // configurations
    }];
}
```

Extra calculations will be saved if a height at an index path has been cached, besides, **NO NEED** to worry about invalidating cached heights when data source changes, it will be done **automatically** when you call "-reloadData" or any method that triggers UITableView's reloading.

## About self-satisfied cell

a fully **self-satisfied** cell is constrainted by auto layout and each edge("top", "left", "bottom", "right") has at least one layout constraint against it.  

A bad one :( - missing right and bottom
![non-self-satisfied](https://github.com/forkingdog/UITableView-FDTemplateLayoutCell/blob/master/Sceenshots/screenshot0.png)   

A good one :)  
![self-satisfied](https://github.com/forkingdog/UITableView-FDTemplateLayoutCell/blob/master/Sceenshots/screenshot1.png)   

## Installation

```
pod search UITableView+FDTemplateLayoutCell 
```

## License
MIT
