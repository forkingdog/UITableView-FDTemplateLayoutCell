//
//  FDFeedEntity.h
//  Demo
//
//  Created by sunnyxx on 15/4/16.
//  Copyright (c) 2015年 forkingdog. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FDFeedEntity : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *content;
@property (nonatomic, copy) NSString *username;
@property (nonatomic, copy) NSString *time;
@property (nonatomic, copy) NSString *imageName;

@end
