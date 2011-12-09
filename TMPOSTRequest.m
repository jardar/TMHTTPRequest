/*
 Copyright (c) 2011, Tony Million.
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer.
 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
 POSSIBILITY OF SUCH DAMAGE. 
 */

#import "TMPOSTRequest.h"

#define kPOSTKey            @"POSTKEY"
#define kPOSTValue          @"POSTVAL"
#define kPOSTContentType    @"POSTCTP"
#define kPOSTFilename       @"POSTFILE"

@implementation TMPOSTRequest

@synthesize startedBlock            = _startedBlock;
@synthesize completedBlock          = _completedBlock;
@synthesize failedBlock             = _failedBlock;

@synthesize uploadProgressBlock     = _uploadProgressBlock;
@synthesize downloadProgressBlock   = _downloadProgressBlock;

@synthesize postData                = _postData;
@synthesize rawResponseData         = _rawResponseData;
@synthesize error                   = _error;
@synthesize response                = _response;

@synthesize ignoresInvalidSSLCerts  = _ignoresInvalidSSLCerts;

@synthesize networkTask             = _networkTask;
@synthesize useBackground           = _useBackground;

-(id)initWithURL:(NSURL*)url
{
    self = [super init];
    if(self)
    {
        NSLog(@"initWithURL: %@", url);
        
        request = [NSMutableURLRequest requestWithURL:url];
        [request setHTTPMethod:@"POST"];
        [request setHTTPShouldHandleCookies:YES];
        [request setHTTPShouldUsePipelining:YES];
        
        self.ignoresInvalidSSLCerts = NO;
        self.useBackground          = YES;
        self.networkTask            = UIBackgroundTaskInvalid;
    }
    
    return self;
}

-(void)dealloc
{
    if(self.networkTask != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.networkTask];
        self.networkTask = UIBackgroundTaskInvalid;
    }
}

-(NSData*)encodePostBodyWithBoundry:(NSString*)aBoundary
{
    if(!_postData.count)
        return nil;
    
    NSString *boundry   = [NSString stringWithFormat:@"--%@\r\n", aBoundary];
    NSMutableData *data = [NSMutableData dataWithCapacity:1];
    
    // iterate over the postData thing and spit out our post data!
    for (NSDictionary * dict in _postData) 
    {
        NSString * key = [dict objectForKey:kPOSTKey];
        id value = [dict objectForKey:kPOSTValue];
        
        [data appendData:[boundry dataUsingEncoding:NSUTF8StringEncoding]];
        
        if ([value isKindOfClass:[NSString class]]) 
        {
            [data appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:[[NSString stringWithFormat:@"%@", value] dataUsingEncoding:NSUTF8StringEncoding]];
        } 
        else if(([value isKindOfClass:[NSNumber class]])) 
        {
            [data appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", key] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:[[NSString stringWithFormat:@"%@", value] dataUsingEncoding:NSUTF8StringEncoding]];
        } 
        else if(([value isKindOfClass:[NSData class]])) 
        {
            NSString * contentType = [dict objectForKey:kPOSTContentType];
            NSStream * fileName = [dict objectForKey:kPOSTFilename];
            
            [data appendData:[[NSString stringWithFormat:@"Content-Disposition: form-data; name=\"%@\"; filename=\"%@\"\r\n", key, fileName] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:[[NSString stringWithFormat:@"Content-Type: %@\r\n\r\n", contentType] dataUsingEncoding:NSUTF8StringEncoding]];
            [data appendData:value];
        }
        
        [data appendData:[[NSString stringWithString:@"\r\n"] dataUsingEncoding:NSUTF8StringEncoding]];

    }
    
    [data appendData:[[NSString stringWithFormat:@"--%@--\r\n", aBoundary] dataUsingEncoding:NSUTF8StringEncoding]];
    
    return data;
}

-(void)addPostValue:(id <NSObject>)value forKey:(NSString *)key
{
	if(!key) 
    {
		return;
	}
	if(!self.postData) 
    {
		self.postData = [NSMutableArray array];
	}
    
	NSMutableDictionary *keyValuePair = [NSMutableDictionary dictionaryWithCapacity:2];
	[keyValuePair setValue:key forKey:kPOSTKey];
	[keyValuePair setValue:[value description] forKey:kPOSTValue];
	[self.postData addObject:keyValuePair];
}

-(void)setPostValue:(id <NSObject>)value forKey:(NSString *)key
{
	// Remove any existing value
    
    for (NSDictionary *val in _postData) 
    {
		if ([[val objectForKey:kPOSTKey] isEqualToString:key]) 
        {
			[_postData removeObject:val];
		}
    }
    
	[self addPostValue:value forKey:key];
}

- (void)addData:(NSData *)data forKey:(NSString *)key
{
	[self addData:data 
     withFileName:@"file" 
   andContentType:nil 
           forKey:key];
}

-(void)addData:(id)data withFileName:(NSString *)fileName andContentType:(NSString *)contentType forKey:(NSString *)key
{
	if(!self.postData) 
    {
        self.postData = [NSMutableArray array];
	}
	if (!contentType) 
    {
		contentType = @"application/octet-stream";
	}
    
	NSMutableDictionary *fileInfo = [NSMutableDictionary dictionaryWithCapacity:4];
	[fileInfo setValue:key forKey:kPOSTKey];
	[fileInfo setValue:data forKey:kPOSTValue];

	[fileInfo setValue:fileName forKey:kPOSTFilename];
	[fileInfo setValue:contentType forKey:kPOSTContentType];
    
	[_postData addObject:fileInfo];
}

-(void)setData:(NSData *)data forKey:(NSString *)key
{
	[self setData:data 
     withFileName:@"file" 
   andContentType:nil 
           forKey:key];
}

-(void)setData:(id)data withFileName:(NSString *)fileName andContentType:(NSString *)contentType forKey:(NSString *)key
{
    for (NSDictionary *val in _postData) 
    {
		if ([[val objectForKey:kPOSTKey] isEqualToString:key]) 
        {
			[_postData removeObject:val];
		}
    }

	[self addData:data 
     withFileName:fileName 
   andContentType:contentType 
           forKey:key];
}

-(NSString*)encodeURL:(NSString *)string
{
	NSString *newString = (__bridge_transfer NSString *)
    CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, 
                                            (__bridge CFStringRef)string, 
                                            NULL, 
                                            CFSTR(":/?#[]@!$ &'()*+,;=\"<>%{}|\\^~`"), 
                                            CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
	if (newString) 
    {
		return newString;
	}
    
	return @"";
}

-(void)realStartRequest
{
    if(self.useBackground)
    {
        self.networkTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
            [[UIApplication sharedApplication] endBackgroundTask:self.networkTask];
        }];
    }
    
    // We don't bother to check if post data contains the boundary, since it's pretty unlikely that it does.
	CFUUIDRef uuid = CFUUIDCreate(nil);
	NSString *uuidString = (__bridge_transfer NSString*)CFUUIDCreateString(nil, uuid);
	NSString *stringBoundary    = [NSString stringWithFormat:@"0xKhTmLbOuNdArY-%@",uuidString];
	CFRelease(uuid);
    
    NSString *contentType       = [NSString stringWithFormat:@"multipart/form-data; boundary=%@", stringBoundary];
    
    [request setValue:contentType 
   forHTTPHeaderField:@"Content-Type"];
    
    NSData* postBody = [self encodePostBodyWithBoundry:stringBoundary];
    if(postBody)
    {
        [request setHTTPBody:postBody];
    }
    
    connection = [[NSURLConnection alloc] initWithRequest:request 
                                                 delegate:self 
                                         startImmediately:NO];
    
    [connection setDelegateQueue:[NSOperationQueue currentQueue]];
    [connection start];
    [[NSRunLoop currentRunLoop] runUntilDate:[NSDate distantFuture]];
}

-(void)startRequest
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        [self realStartRequest];
    });
}

-(void)cancelRequest
{
    [connection cancel];
}

-(void)clearDelegatesAndCancelRequest
{
    // TODO: clear blocks and delegates and shit!
    self.startedBlock           = nil;
    self.completedBlock         = nil;
    self.failedBlock            = nil;
    
    self.uploadProgressBlock    = nil;
    self.downloadProgressBlock  = nil;
    
    [connection cancel];
    
    if(self.networkTask != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.networkTask];
        self.networkTask = UIBackgroundTaskInvalid;
    }
}

#pragma mark - NSURLConnectionDelegate methods

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    self.error = error;
    if(self.failedBlock)
    {
        self.failedBlock(self.response, error);
    }
    
    if(self.networkTask != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.networkTask];
        self.networkTask = UIBackgroundTaskInvalid;
    }
}

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)protectionSpace 
{
    return [protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust];
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge 
{
    if(_ignoresInvalidSSLCerts) 
    {
        // load up the credentials here
        [challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] 
             forAuthenticationChallenge:challenge];
    } 
    else 
    {
        // do nothing
    }
    
    [challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}


#pragma mark - NSURLConnectionDataDelegate methods

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    NSHTTPURLResponse * httpResponse = (NSHTTPURLResponse *)response;
    self.response = httpResponse;
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if(!self.rawResponseData)
        self.rawResponseData = [NSMutableData dataWithData:data];
    else
        [self.rawResponseData appendData:data];
    
    if(self.downloadProgressBlock)
    {
        self.downloadProgressBlock(self.rawResponseData.length, 0);
    }
}

- (void)connection:(NSURLConnection *)connection   
   didSendBodyData:(NSInteger)bytesWritten
 totalBytesWritten:(NSInteger)totalBytesWritten
totalBytesExpectedToWrite:(NSInteger)totalBytesExpectedToWrite
{
    if(self.uploadProgressBlock)
    {
        self.uploadProgressBlock(totalBytesWritten, totalBytesExpectedToWrite);
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection
{
    if(self.completedBlock)
    {
        self.completedBlock(self.response, self.rawResponseData);            
    }
    
    if(self.networkTask != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.networkTask];
        self.networkTask = UIBackgroundTaskInvalid;
    }
}

@end
