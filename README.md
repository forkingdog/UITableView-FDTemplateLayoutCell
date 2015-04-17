# UITableView-FDTemplateLayoutCell
---

## Overview
Template auto layout cell for **automatically** UITableViewCell height calculating.

![Demo Overview](https://github.com/forkingdog/UITableView-FDTemplateLayoutCell/blob/master/Sceenshots/screenshot2.gif)

## Usage

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
