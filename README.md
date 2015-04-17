# UITableView-FDTemplateLayoutCell
---

## Overview
Template auto layout cell for **automatically** UITableViewCell height calculating.

## Usage

First, a fully **self-satisfied** cell, constrainted by auto layout.  

a self-satisfied view has at least one subview's layout constraint against its "top", "left", "bottom", "right" edges.  
Here's a good one :)

Rather than this bad one :(

Then all you have to do is: 

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

## Installation

```
pod search UITableView+FDTemplateLayoutCell 
```
