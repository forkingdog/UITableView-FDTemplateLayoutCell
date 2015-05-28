# UITableView-FDTemplateLayoutCell
<img src="https://cloud.githubusercontent.com/assets/219689/7244961/4209de32-e816-11e4-87bc-b161c442d348.png" width="640">

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

## Height Caching API

Since iOS8, `-tableView:heightForRowAtIndexPath:` will be called more times than we expect, we can feel these extra calculations when scrolling. So we provide another API with caches:   

``` objc
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [tableView fd_heightForCellWithIdentifier:@"identifer" cacheByIndexPath:indexPath configuration:^(id cell) {
        // configurations
    }];
}
```

### Auto cache invalidation

Extra calculations will be saved if a height at an index path has been cached, besides, **NO NEED** to worry about invalidating cached heights when data source changes, it will be done **automatically** when you call "-reloadData" or any method that triggers UITableView's reloading.

## Precache

Pre-cache is an advanced function which helps to cache the rest of offscreen UITableViewCells automatically, just in **"idle"** time. It helps to improve scroll performance, because no extra height calculating will be used when scrolls. It's enabled by default if you use "fd_heightForCellWithIdentifier:cacheByIndexPath:configuation:" API.

## About estimatedRowHeight
`estimatedRowHeight` helps to delay all cells' height calculation from load time to scroll time. Feel free to set it or not when you're using FDTemplateLayoutCell. If you use "cacheByIndexPath" API, setting this estimatedRowHeight property is a better practice for imporve load time, and it **DOES NO LONGER** affect scroll performance because of "precache".
``` objc
self.tableView.estimatedRowHeight = 200;
```
## Frame layout mode

`FDTemplateLayoutCell` offers 2 modes for asking cell's height.  

1. Auto layout mode using "-systemLayoutSizeFittingSize:"  
2. Frame layout mode using "-sizeThatFits:"  

Generally, no need to care about modes, it will **automatically** choose a proper mode by whether you have set auto layout constrants on cell's content view. If you want to enforce frame layout mode, enable this property in your cell's configuration block:  

``` objc
cell.fd_enforceFrameLayout = YES;
```
And if you're using frame layout mode, you must override `-sizeThatFits:` in your customized cell and return content view's height (separator excluded)

```
- (CGSize)sizeThatFits:(CGSize)size
{
    return CGSizeMake(size.width, A+B+C+D+E+....);
}
```

## Debug log

Debug log helps to debug or inspect what is this "FDTemplateLayoutCell" extention doing, turning on to print logs when "calculating", "precaching" or "hitting cache".Default to "NO", log by "NSLog".

``` objc
self.tableView.fd_debugLogEnabled = YES;
```

It will print like this:  

``` objc
** FDTemplateLayoutCell ** layout cell created - FDFeedCell
** FDTemplateLayoutCell ** calculate - [0:0] 233.5
** FDTemplateLayoutCell ** calculate - [0:1] 155.5
** FDTemplateLayoutCell ** calculate - [0:2] 258
** FDTemplateLayoutCell ** calculate - [0:3] 284
** FDTemplateLayoutCell ** precached - [0:3] 284
** FDTemplateLayoutCell ** calculate - [0:4] 278.5
** FDTemplateLayoutCell ** precached - [0:4] 278.5
** FDTemplateLayoutCell ** hit cache - [0:3] 284
** FDTemplateLayoutCell ** hit cache - [0:4] 278.5
** FDTemplateLayoutCell ** hit cache - [0:5] 156
** FDTemplateLayoutCell ** hit cache - [0:6] 165
```

## About self-satisfied cell

a fully **self-satisfied** cell is constrainted by auto layout and each edge("top", "left", "bottom", "right") has at least one layout constraint against it. It's the same concept introduced as "self-sizing cell" in iOS8 using auto layout.

A bad one :( - missing right and bottom
![non-self-satisfied](https://github.com/forkingdog/UITableView-FDTemplateLayoutCell/blob/master/Sceenshots/screenshot0.png)   

A good one :)  
![self-satisfied](https://github.com/forkingdog/UITableView-FDTemplateLayoutCell/blob/master/Sceenshots/screenshot1.png)   

## Note

A template layout cell is created by `-dequeueReusableCellWithIdentifier:` method, it means that you MUST have registered this cell reuse identifier by one of:  

- A prototype cell of UITableView in storyboard.
- Use `-registerNib:forCellReuseIdentifier:` 
- Use `-registerClass:forCellReuseIdentifier:`

## 如果你在天朝
可以看这篇中文博客： 
[http://blog.sunnyxx.com/2015/05/17/cell-height-calculation/](http://blog.sunnyxx.com/2015/05/17/cell-height-calculation/)

## Installation

Latest version: **1.3**

```
pod search UITableView+FDTemplateLayoutCell 
```
If you cannot search out the latest version, try:  

```
pod setup
```

## Release Notes

We recommend to use the latest release in cocoapods.

- 1.3  
Frame layout mode, handle cell's accessory view/type

- 1.2  
Precache and auto cache invalidation

- 1.1  
Height cache

- 1.0  
Basic automatically height calculation

## License
MIT
