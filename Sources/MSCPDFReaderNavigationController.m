//
//  MSCPDFReaderNavigationController.m
//  BrauUnionEOE
//
//  Created by Manfred Scheiner on 09.07.13.
//  Copyright (c) 2013 Manfred Scheiner (@scheinem). All rights reserved.
//

#import "MSCPDFReaderNavigationController.h"

@interface MSCPDFReaderNavigationController ()

@end

@implementation MSCPDFReaderNavigationController

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

@end
