//
//  HostingTableViewCell.m
//  GamePlan
//
//  Created by Courtney Bohrer on 8/2/14.
//  Copyright (c) 2014 Courtney Bohrer. All rights reserved.
//

#import "HostingTableViewCell.h"

@implementation HostingTableViewCell

@synthesize eventName, editButton, thumbnailImageView;

- (void)awakeFromNib
{
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated
{
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

@end
