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

#import "TMGETRequest.h"

@interface TMGETRequest (private)
-(NSString*)encodeURL:(NSString *)string;
@end

@implementation TMGETRequest

@synthesize startedBlock            = _startedBlock;
@synthesize completedBlock          = _completedBlock;
@synthesize failedBlock             = _failedBlock;
@synthesize cancelledBlock;

@synthesize downloadProgressBlock   = _downloadProgressBlock;

@synthesize baseurl;
@synthesize rawResponseData         = _rawResponseData;
@synthesize error                   = _error;
@synthesize response                = _response;

@synthesize ignoresInvalidSSLCerts  = _ignoresInvalidSSLCerts;

@synthesize networkTask             = _networkTask;
@synthesize useBackground           = _useBackground;

@synthesize params;

-(id)initWithURL:(NSURL*)url
{
    self = [super init];
    if(self)
    {
        // we need this cos we add params later!
        self.baseurl = url;
        
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

#pragma mark -

- (BOOL)isConcurrent
{
	return(YES);
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
    
    NSURL * realURL = self.baseurl;
    
    if(self.params)
    {
        NSMutableString * paramString = [NSMutableString stringWithString:@"?"];
        for(NSString *key in params) 
        {
            //TODO: encode this shit eh?
            id temp = [params objectForKey:key];
            NSString * strParam = [NSString stringWithFormat:@"%@", temp];
            
            [paramString appendFormat:@"%@=%@&", key, [self encodeURL:strParam]];
        }
        NSString * urlstring = [[self.baseurl absoluteString] stringByAppendingString:paramString];
        
        if([urlstring hasSuffix:@"&"])
            urlstring = [urlstring substringToIndex:urlstring.length-1];
        realURL = [NSURL URLWithString:urlstring];
    }
    
    request = [NSMutableURLRequest requestWithURL:realURL];
    urlconnection = [[NSURLConnection alloc] initWithRequest:request 
                                                    delegate:self 
                                            startImmediately:NO];
    
    [urlconnection setDelegateQueue:[NSOperationQueue currentQueue]];
    [urlconnection start];
    if(self.startedBlock)
    {
        self.startedBlock();
    }
    
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
    [urlconnection cancel];

    if(self.cancelledBlock)
    {
        self.cancelledBlock();
    }
   
    if(self.networkTask != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.networkTask];
        self.networkTask = UIBackgroundTaskInvalid;
    }
}

-(void)clearDelegatesAndCancelRequest
{
    self.startedBlock           = nil;
    self.completedBlock         = nil;
    self.failedBlock            = nil;
    
    self.downloadProgressBlock  = nil;
    
    [urlconnection cancel];
    
    if(self.networkTask != UIBackgroundTaskInvalid)
    {
        [[UIApplication sharedApplication] endBackgroundTask:self.networkTask];
        self.networkTask = UIBackgroundTaskInvalid;
    }
}

-(void)setValue:(id <NSObject>)value forKey:(NSString *)key
{
    if(!self.params)
        self.params = [NSMutableDictionary dictionary];
    
    [self.params setValue:value forKey:key];
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
    
   // DLog(@"headers = %@", httpResponse.allHeaderFields);
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
