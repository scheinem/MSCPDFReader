//
//  ReaderIcon.h
//  MSCPDFReader
//
//  Created by Manfred Scheiner on 26.06.13.
//  Copyright (c) 2013 Manfred Scheiner (@scheinem). All rights reserved.
//

@interface ReaderIcon : UIImage

+ (void)setUseBrightIcons:(BOOL)useBrightIcons;

+ (UIImage *)mailIcon;
+ (UIImage *)markedIcon;
+ (UIImage *)notMarkedIcon;
+ (UIImage *)printIcon;
+ (UIImage *)thumbsIcon;

@end
