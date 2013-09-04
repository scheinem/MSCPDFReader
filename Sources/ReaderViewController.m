//
//	ReaderViewController.m
//	Reader v2.6.0
//
//	Created by Julius Oklamcak on 2011-07-01.
//	Copyright © 2011-2012 Julius Oklamcak. All rights reserved.
//
//	Permission is hereby granted, free of charge, to any person obtaining a copy
//	of this software and associated documentation files (the "Software"), to deal
//	in the Software without restriction, including without limitation the rights to
//	use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
//	of the Software, and to permit persons to whom the Software is furnished to
//	do so, subject to the following conditions:
//
//	The above copyright notice and this permission notice shall be included in all
//	copies or substantial portions of the Software.
//
//	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
//	OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//	WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
//	CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//

#import "ReaderConstants.h"
#import "ReaderViewController.h"
#import "ThumbsViewController.h"
#import "ReaderMainPagebar.h"
#import "ReaderContentView.h"
#import "ReaderThumbCache.h"
#import "ReaderThumbQueue.h"

#import <MessageUI/MessageUI.h>

#define PAGING_VIEWS 3
#define TAP_AREA_SIZE 48.0f

@interface ReaderViewController () <UIScrollViewDelegate, UIGestureRecognizerDelegate, MFMailComposeViewControllerDelegate, ReaderMainPagebarDelegate, ReaderContentViewDelegate, ThumbsViewControllerDelegate>

@property (nonatomic, strong) ReaderMainPagebar *pageBar;
@property (nonatomic, strong) ReaderDocument *document;

@property (nonatomic, assign) NSInteger currentPage;
@property (nonatomic, strong) UIScrollView *scrollView;
@property (nonatomic, strong) NSMutableDictionary *contentViews;

@end

@implementation ReaderViewController

////////////////////////////////////////////////////////////////////////
#pragma mark - Life Cycle
////////////////////////////////////////////////////////////////////////

- (id)initWithReaderDocument:(ReaderDocument *)object {
	self = [super initWithNibName:nil bundle:nil];
	if (self) {
        self.document = object;
        
        [ReaderThumbCache touchThumbCacheWithGUID:object.guid]; // Touch the document thumb cache directory
        
        self.edgesForExtendedLayout = UIRectEdgeAll;
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillTerminateNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWill:) name:UIApplicationWillResignActiveNotification object:nil];
    }
	return self;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UIViewController
////////////////////////////////////////////////////////////////////////

- (void)viewDidLoad {
	[super viewDidLoad];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds]; // All
    
	self.scrollView.scrollsToTop = NO;
	self.scrollView.pagingEnabled = YES;
	self.scrollView.delaysContentTouches = NO;
	self.scrollView.showsVerticalScrollIndicator = NO;
	self.scrollView.showsHorizontalScrollIndicator = NO;
	self.scrollView.backgroundColor = [UIColor colorWithRed:239.f/255.f green:239.f/255.f blue:244.f/255.f alpha:1.f];
	self.scrollView.contentMode = UIViewContentModeRedraw;
	self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	self.scrollView.userInteractionEnabled = YES;
	self.scrollView.autoresizesSubviews = NO;
	self.scrollView.delegate = self;
    
    [self.view addSubview:self.scrollView];
    
    
    NSMutableArray *leftBarButtons = [NSMutableArray array];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Done", @"button") style:UIBarButtonItemStyleBordered target:self action:@selector(doneButtonPressed:)];
    [leftBarButtons addObject:doneButton];
    
    UIBarButtonItem *thumsButton = [[UIBarButtonItem alloc] initWithImage:[ReaderIcon thumbsIcon] style:UIBarButtonItemStyleBordered target:self action:@selector(thumbsButtonPressed:)];
    [leftBarButtons addObject:thumsButton];
    
    self.navigationItem.leftBarButtonItems = leftBarButtons;
    
    
    NSMutableArray *rightBarButtons = [NSMutableArray array];
    
#if (READER_ENABLE_MAIL == TRUE)
    
    if ([MFMailComposeViewController canSendMail] == YES) {
        unsigned long long fileSize = self.document.fileSize;
        
        // Check mail-attachement size 15MB
        if (fileSize < (unsigned long long)15728640) {
            UIBarButtonItem *mailButton = [[UIBarButtonItem alloc] initWithImage:[ReaderIcon mailIcon] style:UIBarButtonItemStyleBordered target:self action:@selector(mailButtonPressed:)];
            [rightBarButtons addObject:mailButton];
        }
    }
    
#endif
    
#if (READER_ENABLE_PRINT == FALSE)
    
    // We can only print documents without passwords
    if (self.document.password == nil)  {
        if ([UIPrintInteractionController isPrintingAvailable]) {
            UIBarButtonItem *printButton = [[UIBarButtonItem alloc] initWithImage:[ReaderIcon printIcon] style:UIBarButtonItemStyleBordered target:self action:@selector(printButtonPressed:)];
            [rightBarButtons addObject:printButton];
        }
    }
    
#endif
    
    self.navigationItem.rightBarButtonItems = rightBarButtons;
	
	CGRect pagebarRect = self.view.bounds;
	pagebarRect.size.height = 49.f;
	pagebarRect.origin.y = (self.view.bounds.size.height - pagebarRect.size.height);
    
	self.pageBar = [[ReaderMainPagebar alloc] initWithFrame:(CGRect){{0.f, self.view.bounds.size.height - pagebarRect.size.height}, {320.f, pagebarRect.size.height}} document:self.document];
	self.pageBar.delegate = self;
	[self.view addSubview:self.pageBar];
    
	UITapGestureRecognizer *singleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleSingleTap:)];
	singleTapOne.numberOfTouchesRequired = 1;
    singleTapOne.numberOfTapsRequired = 1;
    singleTapOne.delegate = self;
	[self.view addGestureRecognizer:singleTapOne];
    
	UITapGestureRecognizer *doubleTapOne = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapOne.numberOfTouchesRequired = 1;
    doubleTapOne.numberOfTapsRequired = 2;
    doubleTapOne.delegate = self;
	[self.view addGestureRecognizer:doubleTapOne];
    
	UITapGestureRecognizer *doubleTapTwo = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
	doubleTapTwo.numberOfTouchesRequired = 2;
    doubleTapTwo.numberOfTapsRequired = 2;
    doubleTapTwo.delegate = self;
	[singleTapOne requireGestureRecognizerToFail:doubleTapOne];
	[self.view addGestureRecognizer:doubleTapTwo];
    
	self.contentViews = [NSMutableDictionary new];
    
    // First step of customization. Still a lot to do.
    self.view.tintColor = [UIApplication sharedApplication].keyWindow.tintColor;
    self.pageBar.tintColor = self.view.tintColor;
    self.pageBar.translucent = NO;
    
    self.navigationController.navigationBar.tintColor = self.view.tintColor;
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
    
	if (CGSizeEqualToSize(self.scrollView.contentSize, CGSizeZero)) {
		[self showDocumentPage:[self.document.lastPageNumber integerValue]];
        
        self.document.lastOpen = [NSDate date];
	}
    
    [self updateScrollViews];
    
#if (READER_DISABLE_IDLE == TRUE) // Option
    
	[UIApplication sharedApplication].idleTimerDisabled = YES;
    
#endif // end of READER_DISABLE_IDLE Option
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
    
#if (READER_DISABLE_IDLE == TRUE)
    
	[UIApplication sharedApplication].idleTimerDisabled = NO;
    
#endif
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAllButUpsideDown;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation duration:(NSTimeInterval)duration {
	[self updateScrollViews];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UIScrollViewDelegate
////////////////////////////////////////////////////////////////////////

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	__block NSInteger page = 0;
    
	CGFloat contentOffsetX = scrollView.contentOffset.x;
    
	[self.contentViews enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
        ReaderContentView *contentView = object;
        
        if (contentView.frame.origin.x == contentOffsetX) {
            page = contentView.tag; *stop = YES;
        }
    }];
    
	if (page != 0) {
        [self showDocumentPage:page];
    }
}

- (void)scrollViewDidEndScrollingAnimation:(UIScrollView *)scrollView {
	[self showDocumentPage:self.scrollView.tag];
    
	self.scrollView.tag = 0;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - ReaderContentViewDelegate
////////////////////////////////////////////////////////////////////////

- (void)contentView:(ReaderContentView *)contentView touchesBegan:(NSSet *)touches {
    if (touches.count == 1) {
        CGPoint point = [[touches anyObject] locationInView:self.view];
        CGRect areaRect = CGRectInset(self.view.bounds, TAP_AREA_SIZE, TAP_AREA_SIZE);
        
        if (CGRectContainsPoint(areaRect, point) == false) {
            return;
        }
    }
}

////////////////////////////////////////////////////////////////////////
#pragma mark - MFMailComposeViewControllerDelegate
////////////////////////////////////////////////////////////////////////

- (void)mailComposeController:(MFMailComposeViewController *)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error {
	[self dismissViewControllerAnimated:YES completion:nil];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - ThumbsViewControllerDelegate
////////////////////////////////////////////////////////////////////////

- (void)dismissThumbsViewController:(ThumbsViewController *)viewController {
	[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)thumbsViewController:(ThumbsViewController *)viewController gotoPage:(NSInteger)page {
	[self showDocumentPage:page];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - ReaderMainPagebarDelegate
////////////////////////////////////////////////////////////////////////

- (void)pagebar:(ReaderMainPagebar *)pagebar gotoPage:(NSInteger)page {
	[self showDocumentPage:page];
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UIGestureRecognizerDelegate
////////////////////////////////////////////////////////////////////////

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)recognizer shouldReceiveTouch:(UITouch *)touch {
	if ([touch.view isKindOfClass:[UIScrollView class]]) return YES;
    
	return NO;
}

////////////////////////////////////////////////////////////////////////
#pragma mark - UIGestureRecognizer
////////////////////////////////////////////////////////////////////////

- (void)manipulatePageNumber:(NSInteger)pages {
    if (self.scrollView.tag == 0) {
		NSInteger page = [self.document.lastPageNumber integerValue];
		NSInteger maxPage = self.document.pageCount;
		NSInteger minPage = 1; // Minimum
        
		if ((maxPage > minPage) && (page != minPage)) {
			CGPoint contentOffset = self.scrollView.contentOffset;
            
			contentOffset.x += pages * self.scrollView.bounds.size.width;
            
			[self.scrollView setContentOffset:contentOffset animated:YES];
            
			self.scrollView.tag = (page + pages);
		}
	}
}

- (void)handleSingleTap:(UITapGestureRecognizer *)recognizer {
	if (recognizer.state == UIGestureRecognizerStateRecognized) {
		CGRect viewRect = recognizer.view.bounds; // View bounds
        
		CGPoint point = [recognizer locationInView:recognizer.view];
        
		CGRect areaRect = CGRectInset(viewRect, TAP_AREA_SIZE, 0.0f); // Area
        
        // Single tap is inside the area
		if (CGRectContainsPoint(areaRect, point)) {
			NSInteger page = [self.document.lastPageNumber integerValue]; // Current page #
            
			NSNumber *key = [NSNumber numberWithInteger:page]; // Page number key
            
			ReaderContentView *targetView = [self.contentViews objectForKey:key];
            
            // Handle the returned target object
			id target = [targetView processSingleTap:recognizer];
            
			if (target != nil) {
				if ([target isKindOfClass:[NSURL class]]) {
					NSURL *url = (NSURL *)target;
                    
                    // Handle a missing URL scheme
					if (url.scheme == nil) {
						NSString *www = url.absoluteString; // Get URL string
                        
						if ([www hasPrefix:@"www"] == YES) {
							NSString *http = [NSString stringWithFormat:@"http://%@", www];
                            
							url = [NSURL URLWithString:http]; // Proper http-based URL
						}
					}
				}
                // go to page
				else if ([target isKindOfClass:[NSNumber class]]) {
                    NSInteger value = [target integerValue];
                    [self showDocumentPage:value];
				}
			}
			else {
				[self toggleVisibilityOfBars];
			}
            
			return;
		}
        
		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);
        
		if (CGRectContainsPoint(nextPageRect, point)) {
			[self manipulatePageNumber:1];
            return;
		}
        
		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;
        
		if (CGRectContainsPoint(prevPageRect, point)) {
			[self manipulatePageNumber:-1];
            return;
		}
	}
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)recognizer {
	if (recognizer.state == UIGestureRecognizerStateRecognized) {
		CGRect viewRect = recognizer.view.bounds; // View bounds
        
		CGPoint point = [recognizer locationInView:recognizer.view];
        
		CGRect zoomArea = CGRectInset(viewRect, TAP_AREA_SIZE, TAP_AREA_SIZE);
        
		if (CGRectContainsPoint(zoomArea, point)) {
			NSInteger page = [self.document.lastPageNumber integerValue]; // Current page #
            
			NSNumber *key = [NSNumber numberWithInteger:page]; // Page number key
            
			ReaderContentView *targetView = [self.contentViews objectForKey:key];
            
			switch (recognizer.numberOfTouchesRequired) {
				case 1: {
					[targetView zoomIncrement];
                    break;
				}
				case 2: {
					[targetView zoomDecrement];
                    break;
				}
			}
			return;
		}
        
		CGRect nextPageRect = viewRect;
		nextPageRect.size.width = TAP_AREA_SIZE;
		nextPageRect.origin.x = (viewRect.size.width - TAP_AREA_SIZE);
        
		if (CGRectContainsPoint(nextPageRect, point)) {
			[self manipulatePageNumber:1];
            return;
		}
        
		CGRect prevPageRect = viewRect;
		prevPageRect.size.width = TAP_AREA_SIZE;
        
		if (CGRectContainsPoint(prevPageRect, point)) {
			[self manipulatePageNumber:-1];
            return;
		}
	}
}

////////////////////////////////////////////////////////////////////////
#pragma mark - private methods
////////////////////////////////////////////////////////////////////////

- (void)doneButtonPressed:(UIBarButtonItem *)doneButton {
	if (self.presentedViewController.isBeingPresented) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
    
	[self.document saveReaderDocument]; // Save any ReaderDocument object changes
    
	[[ReaderThumbQueue sharedInstance] cancelOperationsWithGUID:self.document.guid];
    
	[[ReaderThumbCache sharedInstance] removeAllObjects]; // Empty the thumb cache
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)thumbsButtonPressed:(UIBarButtonItem *)thumbsButton {
	if (self.presentedViewController.isBeingPresented) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
    
	ThumbsViewController *thumbsViewController = [[ThumbsViewController alloc] initWithReaderDocument:self.document];
    
	thumbsViewController.delegate = self;
    
	thumbsViewController.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    
    UINavigationController *thumbsViewNavigationController = [[UINavigationController alloc] initWithRootViewController:thumbsViewController];
    
	[self presentViewController:thumbsViewNavigationController animated:YES completion:nil];
}

- (void)printButtonPressed:(UIBarButtonItem *)printButton {
	if ([UIPrintInteractionController isPrintingAvailable]) {
		NSURL *fileURL = self.document.fileURL; // Document file URL
        
		if ([UIPrintInteractionController canPrintURL:fileURL]) {
			UIPrintInfo *printInfo = [UIPrintInfo printInfo];
            
			printInfo.duplex = UIPrintInfoDuplexLongEdge;
			printInfo.outputType = UIPrintInfoOutputGeneral;
			printInfo.jobName = self.document.fileName;
            
            UIPrintInteractionController *printInteraction = [UIPrintInteractionController sharedPrintController];
			printInteraction.printInfo = printInfo;
			printInteraction.printingItem = fileURL;
			printInteraction.showsPageRange = YES;
            
			if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
				[printInteraction presentFromBarButtonItem:printButton animated:YES completionHandler:nil];
			}
			else {
				[printInteraction presentAnimated:YES completionHandler:nil];
			}
		}
	}
}

- (void)mailButtonPressed:(UIBarButtonItem *)mailButton {
    
	if ([MFMailComposeViewController canSendMail] == NO) return;
    
	if (self.presentedViewController.isBeingPresented) {
        [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
    }
    
	unsigned long long fileSize = self.document.fileSize;
    
    // Check attachment size limit (15MB)
	if (fileSize < (unsigned long long)15728640) {
		NSURL *fileURL = self.document.fileURL;
        NSString *fileName = self.document.fileName; // Document
        
		NSData *attachment = [NSData dataWithContentsOfURL:fileURL options:(NSDataReadingMapped|NSDataReadingUncached) error:nil];
        
		if (attachment) {
			MFMailComposeViewController *mailComposer = [MFMailComposeViewController new];
            mailComposer.view.tintColor = self.view.tintColor;
            
			[mailComposer addAttachmentData:attachment mimeType:@"application/pdf" fileName:fileName];
            
			[mailComposer setSubject:fileName]; // Use the document file name for the subject
            
			mailComposer.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
			mailComposer.modalPresentationStyle = UIModalPresentationFormSheet;
            
			mailComposer.mailComposeDelegate = self; // Set the delegate
            
			[self presentViewController:mailComposer animated:YES completion:nil];
		}
	}
}


- (void)toggleVisibilityOfBars {
    if (self.navigationController.navigationBar.hidden && self.pageBar.hidden) {
        [self showBars];
    }
    else {
        [self hideBars];
    }
}

- (void)hideBars {
    [UIView animateWithDuration:0.25 delay:0.0
                        options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {
                         self.navigationController.navigationBar.alpha = 0.f;
                         self.pageBar.alpha = 0.f;
                     }                completion:^(BOOL finished) {
                         self.navigationController.navigationBar.hidden = YES;
                         self.pageBar.hidden = YES;
                     }];
}

- (void)showBars {
    [UIView animateWithDuration:0.25 delay:0.0
                        options:UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction
                     animations:^(void) {
                         self.navigationController.navigationBar.hidden = NO;
                         self.navigationController.navigationBar.alpha = 1.f;
                         self.pageBar.hidden = NO;
                         self.pageBar.alpha = 1.f;
                     } completion:nil];
}

- (void)updateScrollViews {
	[self updateScrollViewContentSize]; // Update the content size
    
	NSMutableIndexSet *pageSet = [NSMutableIndexSet indexSet];
    
	[self.contentViews enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
        ReaderContentView *contentView = object; [pageSet addIndex:contentView.tag];
    }];
    
	__block CGRect viewRect = CGRectZero;
    viewRect.size = self.scrollView.bounds.size;
	__block CGPoint contentOffset = CGPointZero;
    NSUInteger page = [self.document.lastPageNumber unsignedIntegerValue];
    
	[pageSet enumerateIndexesUsingBlock:^(NSUInteger number, BOOL *stop) {
        NSNumber *key = [NSNumber numberWithInteger:number]; // # key
        
        ReaderContentView *contentView = [self.contentViews objectForKey:key];
        
        contentView.frame = viewRect;
        
        if (page == number) {
            contentOffset = viewRect.origin;
        }
        
        viewRect.origin.x += viewRect.size.width; // Next view frame position
    }];
    
	if (CGPointEqualToPoint(self.scrollView.contentOffset, contentOffset) == false) {
		self.scrollView.contentOffset = contentOffset; // Update content offset
	}
}

- (void)updateScrollViewContentSize {
	NSInteger count = self.document.pageCount;
    
    // Limit
	if (count > PAGING_VIEWS) {
        count = PAGING_VIEWS;
    }
    
	CGFloat contentHeight = self.scrollView.bounds.size.height;
	CGFloat contentWidth = (self.scrollView.bounds.size.width * count);
    
	self.scrollView.contentSize = CGSizeMake(contentWidth, contentHeight);
}

- (void)showDocumentPage:(NSInteger)page {
	if (page != self.currentPage) {
		NSInteger minValue; NSInteger maxValue;
		NSInteger maxPage = self.document.pageCount;
		NSInteger minPage = 1;
        
		if ((page < minPage) || (page > maxPage)) return;
        
		if (maxPage <= PAGING_VIEWS) {
			minValue = minPage;
			maxValue = maxPage;
		}
		else {
			minValue = (page - 1);
			maxValue = (page + 1);
            
			if (minValue < minPage) {
                minValue++;
                maxValue++;
            }
			else if (maxValue > maxPage) {
                minValue--;
                maxValue--;
            }
		}
        
		NSMutableIndexSet *newPageSet = [NSMutableIndexSet new];
        
		NSMutableDictionary *unusedViews = [self.contentViews mutableCopy];
        
		CGRect viewRect = CGRectZero; viewRect.size = self.scrollView.bounds.size;
        
		for (NSInteger number = minValue; number <= maxValue; number++) {
			NSNumber *key = [NSNumber numberWithInteger:number]; // # key
            
			ReaderContentView *contentView = [self.contentViews objectForKey:key];
            
			if (contentView == nil) {
				NSURL *fileURL = self.document.fileURL;
                NSString *phrase = self.document.password; // Document properties
                
				contentView = [[ReaderContentView alloc] initWithFrame:viewRect fileURL:fileURL page:number password:phrase];
                
				[self.scrollView addSubview:contentView]; [self.contentViews setObject:contentView forKey:key];
                
				contentView.message = self; [newPageSet addIndex:number];
			}
			else {
				contentView.frame = viewRect;
                [contentView zoomReset];
                
				[unusedViews removeObjectForKey:key];
			}
            
			viewRect.origin.x += viewRect.size.width;
		}
        
        // Removed unused views
		[unusedViews enumerateKeysAndObjectsUsingBlock:^(id key, id object, BOOL *stop) {
            [self.contentViews removeObjectForKey:key];
            
            ReaderContentView *contentView = object;
            
            [contentView removeFromSuperview];
        }];
        
		unusedViews = nil; // Release unused views
        
		CGFloat viewWidthX1 = viewRect.size.width;
		CGFloat viewWidthX2 = (viewWidthX1 * 2.0f);
        
		CGPoint contentOffset = CGPointZero;
        
		if (maxPage >= PAGING_VIEWS)
		{
			if (page == maxPage)
				contentOffset.x = viewWidthX2;
			else
				if (page != minPage)
					contentOffset.x = viewWidthX1;
		}
		else if (page == (PAGING_VIEWS - 1)) {
            contentOffset.x = viewWidthX1;
        }
        
		if (CGPointEqualToPoint(self.scrollView.contentOffset, contentOffset) == false) {
			self.scrollView.contentOffset = contentOffset; // Update content offset
		}
        
		if ([self.document.lastPageNumber integerValue] != page) {
			self.document.lastPageNumber = [NSNumber numberWithInteger:page]; // Update page number
		}
        
        // Preview visible page first
		if ([newPageSet containsIndex:page] == YES) {
			NSNumber *key = [NSNumber numberWithInteger:page]; // # key
            
			ReaderContentView *targetView = [self.contentViews objectForKey:key];
            
			[targetView showPageThumb:self.document.fileURL page:page password:self.document.password guid:self.document.guid];
            
			[newPageSet removeIndex:page]; // Remove visible page from set
		}
        
        // Show thumbs
		[newPageSet enumerateIndexesWithOptions:NSEnumerationReverse usingBlock:^(NSUInteger number, BOOL *stop) {
            NSNumber *key = [NSNumber numberWithInteger:number]; // # key
            
            ReaderContentView *targetView = [self.contentViews objectForKey:key];
            
            [targetView showPageThumb:self.document.fileURL page:number password:self.document.password guid:self.document.guid];
        }];
        
		[self.pageBar updatePagebar]; // Update the pagebar display
        
		self.currentPage = page; // Track current page number
	}
}

- (void)applicationWill:(NSNotification *)notification {
	[self.document saveReaderDocument];
}

@end
