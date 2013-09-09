//
//	ReaderDocument.m
//	Reader v2.6.1
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

#import "ReaderDocument.h"
#import "CGPDFDocument.h"
#import <fcntl.h>

@implementation ReaderDocument {
	NSString *_guid;
    
	NSDate *_lastOpen;
    
	NSNumber *_lastPageNumber;
    
	NSString *_password;
    
	NSURL *_fileURL;
}

#pragma mark Properties

#pragma mark ReaderDocument class methods

+ (NSString *)GUID
{
	CFUUIDRef theUUID = CFUUIDCreate(NULL);
    
	CFStringRef theString = CFUUIDCreateString(NULL, theUUID);
    
	NSString *unique = [NSString stringWithString:(__bridge id)theString];
    
	CFRelease(theString); CFRelease(theUUID); // Cleanup CF objects
    
	return unique;
}

+ (NSString *)applicationSupportPath
{
	NSFileManager *fileManager = [NSFileManager new]; // File manager instance
    
	NSURL *pathURL = [fileManager URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:NULL];
    
	return [pathURL path]; // Path to the application's "~/Library/Application Support" directory
}

+ (NSString *)archiveFilePathForFileNamed:(NSString *)filename {
	assert(filename != nil); // Ensure that the archive file name is not nil
    
	NSString *archivePath = [ReaderDocument applicationSupportPath]; // Application's "~/Library/Application Support" path
    
	NSString *archiveName = [[filename stringByDeletingPathExtension] stringByAppendingPathExtension:@"plist"];
    
	return [archivePath stringByAppendingPathComponent:archiveName]; // "{archivePath}/'filename'.plist"
}

+ (ReaderDocument *)pdfFromFilePath:(NSString *)filePath {
    return [ReaderDocument pdfFromFilePath:filePath password:nil ignoreStoredMetadata:NO];
}

+ (ReaderDocument *)pdfFromFilePath:(NSString *)filePath password:(NSString *)phrase ignoreStoredMetadata:(BOOL)ignore {
    
    if (![ReaderDocument isPDF:filePath]) {
        return nil;
    }
    
	ReaderDocument *document = nil; // ReaderDocument object
    
	NSString *archiveFilePath = [ReaderDocument archiveFilePathForFileNamed:[filePath lastPathComponent]];
    
    if (!ignore) {
        @try // Unarchive an archived ReaderDocument object from its property list
        {
            document = [NSKeyedUnarchiver unarchiveObjectWithFile:archiveFilePath];
        
            if ((document != nil) && (phrase != nil)) // Set the document password
            {
                [document setValue:[phrase copy] forKey:@"password"];
            }
        }
        @catch (NSException *exception) // Exception handling (just in case O_o)
        {
#ifdef DEBUG
            NSLog(@"%s Caught %@: %@", __FUNCTION__, [exception name], [exception reason]);
#endif
        }
    }
    
	if (document == nil) // Unarchive failed so we create a new ReaderDocument object
	{
		document = [[ReaderDocument alloc] initWithFilePath:filePath password:phrase];
	}
    
	return document;
}

+ (BOOL)isPDF:(NSString *)filePath
{
	BOOL state = NO;
    
	if (filePath != nil) // Must have a file path
	{
		const char *path = [filePath fileSystemRepresentation];
        
		int fd = open(path, O_RDONLY); // Open the file
        
		if (fd > 0) // We have a valid file descriptor
		{
			const char sig[1024]; // File signature buffer
            
			ssize_t len = read(fd, (void *)&sig, sizeof(sig));
            
			state = (strnstr(sig, "%PDF", len) != NULL);
            
			close(fd); // Close the file
		}
	}
    
	return state;
}

#pragma mark ReaderDocument instance methods

- (id)initWithFilePath:(NSString *)fullFilePath password:(NSString *)phrase {
    if (self = [super init]) {
        _guid = [ReaderDocument GUID]; // Create a document GUID
        
        _password = [phrase copy]; // Keep copy of any document password
        
        _lastPageNumber = [NSNumber numberWithInteger:1]; // Start on page 1
        
        _fileURL = [NSURL fileURLWithPath:fullFilePath];
        
        _lastOpen = [NSDate dateWithTimeIntervalSinceReferenceDate:0.0]; // Last opened
    }
    
	return self;
}

- (BOOL)saveReaderDocument {
    NSString *archiveFilePath = [ReaderDocument archiveFilePathForFileNamed:self.fileName];
    
	return [NSKeyedArchiver archiveRootObject:self toFile:archiveFilePath];
}

#pragma mark NSCoding protocol methods

- (void)encodeWithCoder:(NSCoder *)encoder {
	[encoder encodeObject:_guid forKey:@"FileGUID"];
    
    [encoder encodeObject:_fileURL forKey:@"FileURL"];
    
	[encoder encodeObject:_lastPageNumber forKey:@"PageNumber"];
    
	[encoder encodeObject:_lastOpen forKey:@"LastOpen"];
}

- (id)initWithCoder:(NSCoder *)decoder {
	if (self = [super init]) {
		_guid = [decoder decodeObjectForKey:@"FileGUID"];
        
        _fileURL = [decoder decodeObjectForKey:@"FileURL"];
        
		_lastPageNumber = [decoder decodeObjectForKey:@"PageNumber"];
        
		_lastOpen = [decoder decodeObjectForKey:@"LastOpen"];
        
		if (!_guid) {
            _guid = [ReaderDocument GUID];
        }
	}
    
	return self;
}




#pragma mark - NEW FROM scheinem


- (CGPDFDocumentRef)cgPDFDocumentReference {
    CFURLRef docURLRef = (__bridge CFURLRef)self.fileURL;
    
    return CGPDFDocumentCreateX(docURLRef, self.password);
}

- (NSDictionary *)fileAttributes {
    return [[NSFileManager defaultManager] attributesOfItemAtPath:self.fileURL.path error:NULL];
}



- (NSString *)fileName {
    return [self.fileURL lastPathComponent];
}

- (unsigned long long)fileSize {
    return [[self fileAttributes] fileSize];
}

- (NSInteger)pageCount {
    CGPDFDocumentRef pdfDocumentReference = [self cgPDFDocumentReference];
    
    if (pdfDocumentReference != NULL) {
        return CGPDFDocumentGetNumberOfPages(pdfDocumentReference);
        
        CGPDFDocumentRelease(pdfDocumentReference);
    }
    
    return 0;
}

- (NSDate *)lastModified {
    return [[[NSFileManager defaultManager] attributesOfItemAtPath:self.fileURL.path error:NULL] fileModificationDate];
}

@end
