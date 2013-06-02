//
//	ThumbsViewController.m
//	Reader v2.6.1
//
//	Created by Julius Oklamcak on 2011-09-01.
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
#import "ThumbsViewController.h"
#import "ReaderThumbRequest.h"
#import "ReaderThumbCache.h"
#import "ReaderDocument.h"

@interface ThumbsViewController () <ReaderThumbsViewDelegate>

@end

@implementation ThumbsViewController
{
	ReaderDocument *document;

	ReaderThumbsView *theThumbsView;

	NSMutableArray *bookmarked;

	CGPoint thumbsOffset;
	CGPoint markedOffset;

	BOOL updateBookmarked;
	BOOL showBookmarked;
}

#pragma mark Properties

@synthesize delegate;




- (void)doneButtonTouchedUpInside:(UIBarButtonItem *)doneButton {
    [self dismissViewControllerAnimated:YES completion:^{
    }];
}

- (void)showControlTapped:(UISegmentedControl *)control {
	switch (control.selectedSegmentIndex) {
		case 0: {
			showBookmarked = NO;
			markedOffset = [theThumbsView insetContentOffset];
			[theThumbsView reloadThumbsContentOffset:thumbsOffset];
			break;
		}
            
		case 1: {
			showBookmarked = YES;
			thumbsOffset = [theThumbsView insetContentOffset];
            
			if (updateBookmarked == YES) {
				[bookmarked removeAllObjects];
                
				[document.bookmarks enumerateIndexesUsingBlock:
                 ^(NSUInteger page, BOOL *stop){
                     [bookmarked addObject:[NSNumber numberWithInteger:page]];
                }];
                
				markedOffset = CGPointZero; updateBookmarked = NO; // Reset
			}
            
			[theThumbsView reloadThumbsContentOffset:markedOffset];
            
			break;
		}
	}
}


#pragma mark UIViewController methods

- (id)initWithReaderDocument:(ReaderDocument *)object
{
	id thumbs = nil; // ThumbsViewController object

	if ((object != nil) && ([object isKindOfClass:[ReaderDocument class]]))
	{
		if ((self = [super initWithNibName:nil bundle:nil])) // Designated initializer
		{
			updateBookmarked = YES; bookmarked = [NSMutableArray new]; // Bookmarked pages

			document = object; // Retain the ReaderDocument object for our use

			thumbs = self; // Return an initialized ThumbsViewController object
		}
	}

	return thumbs;
}

- (void)viewDidLoad
{
	[super viewDidLoad];

	assert(delegate != nil); assert(document != nil);

	self.view.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
    
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Fertig" style:UIBarButtonItemStyleBordered target:self action:@selector(doneButtonTouchedUpInside:)];
    self.title = [document.fileName stringByDeletingPathExtension];
    
#if (READER_BOOKMARKS == TRUE) // Option
    
    UIImage *thumbsImage = [UIImage imageNamed:@"Reader-Thumbs"];
    UIImage *bookmarkImage = [UIImage imageNamed:@"Reader-Mark-Y"];
    NSArray *buttonItems = [NSArray arrayWithObjects:thumbsImage, bookmarkImage, nil];
    UISegmentedControl *showControl = [[UISegmentedControl alloc] initWithItems:buttonItems];
    
    showControl.segmentedControlStyle = UISegmentedControlStyleBar;
    showControl.selectedSegmentIndex = 0; // Default segment index
    
    [showControl addTarget:self action:@selector(showControlTapped:) forControlEvents:UIControlEventValueChanged];
    
    UIBarButtonItem *segmentBarItem = [[UIBarButtonItem alloc] initWithCustomView:showControl];
    self.navigationItem.rightBarButtonItem = segmentBarItem;
    
#endif // end of READER_BOOKMARKS Option
    

	CGRect viewRect = self.view.bounds; // View controller's view bounds

	CGRect thumbsRect = viewRect; UIEdgeInsets insets = UIEdgeInsetsZero;

	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad)
	{
		thumbsRect.origin.y += 40.f; thumbsRect.size.height -= 0.f;
	}
	else // Set UIScrollView insets for non-UIUserInterfaceIdiomPad case
	{
		insets.top = 40.f;
	}

	theThumbsView = [[ReaderThumbsView alloc] initWithFrame:thumbsRect]; // Rest

	theThumbsView.contentInset = insets; theThumbsView.scrollIndicatorInsets = insets;

	theThumbsView.delegate = self;
    
    theThumbsView.backgroundColor = [UIColor yellowColor];
    
    [self.view addSubview:theThumbsView];
    
    NSInteger thumbSize = 0;

	if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        thumbSize = self.view.bounds.size.width / 4.f;
    }
    else {
        thumbSize = self.view.bounds.size.width / 2.f;
    }

	[theThumbsView setThumbSize:CGSizeMake(thumbSize, thumbSize)]; // Thumb size based on device
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];

	[theThumbsView reloadThumbsCenterOnIndex:([document.lastPageNumber integerValue] - 1)]; // Page
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

#pragma mark UIThumbsViewDelegate methods

- (NSUInteger)numberOfThumbsInThumbsView:(ReaderThumbsView *)thumbsView
{
	return (showBookmarked ? bookmarked.count : document.pageCount);
}

- (id)thumbsView:(ReaderThumbsView *)thumbsView thumbCellWithFrame:(CGRect)frame
{
	return [[ThumbsPageThumb alloc] initWithFrame:frame];
}

- (void)thumbsView:(ReaderThumbsView *)thumbsView updateThumbCell:(ThumbsPageThumb *)thumbCell forIndex:(NSInteger)index
{
	CGSize size = [thumbCell maximumContentSize]; // Get the cell's maximum content size

	NSInteger page = (showBookmarked ? [[bookmarked objectAtIndex:index] integerValue] : (index + 1));

	[thumbCell showText:[NSString stringWithFormat:@"%d", page]]; // Page number place holder

	[thumbCell showBookmark:[document.bookmarks containsIndex:page]]; // Show bookmarked status

	NSURL *fileURL = document.fileURL; NSString *guid = document.guid; NSString *phrase = document.password; // Document info

	ReaderThumbRequest *thumbRequest = [ReaderThumbRequest newForView:thumbCell fileURL:fileURL password:phrase guid:guid page:page size:size];

	UIImage *image = [[ReaderThumbCache sharedInstance] thumbRequest:thumbRequest priority:YES]; // Request the thumbnail

	if ([image isKindOfClass:[UIImage class]]) [thumbCell showImage:image]; // Show image from cache
}

- (void)thumbsView:(ReaderThumbsView *)thumbsView refreshThumbCell:(ThumbsPageThumb *)thumbCell forIndex:(NSInteger)index
{
	NSInteger page = (showBookmarked ? [[bookmarked objectAtIndex:index] integerValue] : (index + 1));

	[thumbCell showBookmark:[document.bookmarks containsIndex:page]]; // Show bookmarked status
}

- (void)thumbsView:(ReaderThumbsView *)thumbsView didSelectThumbWithIndex:(NSInteger)index
{
	NSInteger page = (showBookmarked ? [[bookmarked objectAtIndex:index] integerValue] : (index + 1));

	[delegate thumbsViewController:self gotoPage:page]; // Show the selected page

	[delegate dismissThumbsViewController:self]; // Dismiss thumbs display
}

- (void)thumbsView:(ReaderThumbsView *)thumbsView didPressThumbWithIndex:(NSInteger)index
{
	NSInteger page = (showBookmarked ? [[bookmarked objectAtIndex:index] integerValue] : (index + 1));

	if ([document.bookmarks containsIndex:page]) [document.bookmarks removeIndex:page]; else [document.bookmarks addIndex:page];

	updateBookmarked = YES; [thumbsView refreshThumbWithIndex:index]; // Refresh page thumb
}

@end

#pragma mark -

//
//	ThumbsPageThumb class implementation
//

@implementation ThumbsPageThumb
{
	UIView *backView;

	UIView *tintView;

	UILabel *textLabel;

	UIImageView *bookMark;

	CGSize maximumSize;

	CGRect defaultRect;
}

#pragma mark Constants

#define CONTENT_INSET 8.0f

#pragma mark ThumbsPageThumb instance methods

- (CGRect)markRectInImageView
{
	CGRect iconRect = bookMark.frame; iconRect.origin.y = (-2.0f);

	iconRect.origin.x = (imageView.bounds.size.width - bookMark.image.size.width - 8.0f);

	return iconRect; // Frame position rect inside of image view
}

- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame]))
	{
		imageView.contentMode = UIViewContentModeCenter;

		defaultRect = CGRectInset(self.bounds, CONTENT_INSET, CONTENT_INSET);

		maximumSize = defaultRect.size; // Maximum thumb content size

		CGFloat newWidth = ((defaultRect.size.width / 4.0f) * 3.0f);

		CGFloat offsetX = ((defaultRect.size.width - newWidth) / 2.0f);

		defaultRect.size.width = newWidth; defaultRect.origin.x += offsetX;

		imageView.frame = defaultRect; // Update the image view frame

		CGFloat fontSize = (([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) ? 19.0f : 16.0f);

		textLabel = [[UILabel alloc] initWithFrame:defaultRect];

		textLabel.autoresizesSubviews = NO;
		textLabel.userInteractionEnabled = NO;
		textLabel.contentMode = UIViewContentModeRedraw;
		textLabel.autoresizingMask = UIViewAutoresizingNone;
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.font = [UIFont systemFontOfSize:fontSize];
		textLabel.textColor = [UIColor colorWithWhite:0.24f alpha:1.0f];
		textLabel.backgroundColor = [UIColor whiteColor];

		[self insertSubview:textLabel belowSubview:imageView];

		backView = [[UIView alloc] initWithFrame:defaultRect];

		backView.autoresizesSubviews = NO;
		backView.userInteractionEnabled = NO;
		backView.contentMode = UIViewContentModeRedraw;
		backView.autoresizingMask = UIViewAutoresizingNone;
		backView.backgroundColor = [UIColor whiteColor];

#if (READER_SHOW_SHADOWS == TRUE) // Option

		backView.layer.shadowOffset = CGSizeMake(0.0f, 1.0f);
		backView.layer.shadowRadius = 3.0f; backView.layer.shadowOpacity = 1.0f;
		backView.layer.shadowPath = [UIBezierPath bezierPathWithRect:backView.bounds].CGPath;

#endif // end of READER_SHOW_SHADOWS Option

		[self insertSubview:backView belowSubview:textLabel];

		tintView = [[UIView alloc] initWithFrame:imageView.bounds];

		tintView.hidden = YES;
		tintView.autoresizesSubviews = NO;
		tintView.userInteractionEnabled = NO;
		tintView.contentMode = UIViewContentModeRedraw;
		tintView.autoresizingMask = UIViewAutoresizingNone;
		tintView.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.25f];

		[imageView addSubview:tintView];

		UIImage *image = [UIImage imageNamed:@"Reader-Mark-Y"];

		bookMark = [[UIImageView alloc] initWithImage:image];

		bookMark.hidden = YES;
		bookMark.autoresizesSubviews = NO;
		bookMark.userInteractionEnabled = NO;
		bookMark.contentMode = UIViewContentModeCenter;
		bookMark.autoresizingMask = UIViewAutoresizingNone;
		bookMark.frame = [self markRectInImageView];

		[imageView addSubview:bookMark];
	}

	return self;
}

- (CGSize)maximumContentSize
{
	return maximumSize;
}

- (void)showImage:(UIImage *)image
{
	NSInteger x = (self.bounds.size.width / 2.0f);
	NSInteger y = (self.bounds.size.height / 2.0f);

	CGPoint location = CGPointMake(x, y); // Center point

	CGRect viewRect = CGRectZero; viewRect.size = image.size;

	textLabel.bounds = viewRect; textLabel.center = location; // Position

	imageView.bounds = viewRect; imageView.center = location; imageView.image = image;

	bookMark.frame = [self markRectInImageView]; // Position bookmark image

	tintView.frame = imageView.bounds; backView.bounds = viewRect; backView.center = location;

#if (READER_SHOW_SHADOWS == TRUE) // Option

	backView.layer.shadowPath = [UIBezierPath bezierPathWithRect:backView.bounds].CGPath;

#endif // end of READER_SHOW_SHADOWS Option
}

- (void)reuse
{
	[super reuse]; // Reuse thumb view

	textLabel.text = nil; textLabel.frame = defaultRect;

	imageView.image = nil; imageView.frame = defaultRect;

	bookMark.hidden = YES; bookMark.frame = [self markRectInImageView];

	tintView.hidden = YES; tintView.frame = imageView.bounds; backView.frame = defaultRect;

#if (READER_SHOW_SHADOWS == TRUE) // Option

	backView.layer.shadowPath = [UIBezierPath bezierPathWithRect:backView.bounds].CGPath;

#endif // end of READER_SHOW_SHADOWS Option
}

- (void)showBookmark:(BOOL)show
{
	bookMark.hidden = (show ? NO : YES);
}

- (void)showTouched:(BOOL)touched
{
	tintView.hidden = (touched ? NO : YES);
}

- (void)showText:(NSString *)text
{
	textLabel.text = text;
}












@end
