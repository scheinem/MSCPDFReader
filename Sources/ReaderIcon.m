//
//  ReaderIcon.m
//  MSCPDFReader
//
//  Created by Manfred Scheiner on 26.06.13.
//  Copyright (c) 2013 Manfred Scheiner (@scheinem). All rights reserved.
//

#import "ReaderIcon.h"

static BOOL brightIcons = NO;

@implementation ReaderIcon

+ (void)setUseBrightIcons:(BOOL)useBrightIcons {
    brightIcons = useBrightIcons;
}

+ (UIImage *)mailIcon {
    if (brightIcons) {
        return [UIImage imageNamed:@"Reader-Email-Bright.png"];
    }
    else {
        return [UIImage imageNamed:@"Reader-Email.png"];
    }
}

+ (UIImage *)markedIcon {
    return [UIImage imageNamed:@"Reader-Mark-Y.png"];
}

+ (UIImage *)notMarkedIcon {
    if (brightIcons) {
        return [UIImage imageNamed:@"Reader-Mark-N-Bright.png"];
    }
    else {
        return [UIImage imageNamed:@"Reader-Mark-N.png"];
    }
}

+ (UIImage *)thumbsIcon {
    if (brightIcons) {
        return [UIImage imageNamed:@"Reader-Thumbs-Bright.png"];
    }
    else {
        return [UIImage imageNamed:@"Reader-Thumbs.png"];
    }
}

+ (UIImage *)printIcon {
    if (brightIcons) {
        return [UIImage imageNamed:@"Reader-Print-Bright.png"];
    }
    else {
        return [UIImage imageNamed:@"Reader-Print.png"];
    }
}

@end
