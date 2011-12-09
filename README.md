# TMHTTPRequest

These are two ARC / iOS5 classes which wrap up NSURLRequests into a nicer backgrounded block based API. Each class wraps up a method (GET and POST).

There are many many of these wrappers around - the only thing this one has going for it is it uses the iOS5 operation queue functionality - which means, among other things, all of the delegate methods get called on a background thread and stay off the main thread (which is a boon for iPad2 / iPhone4S).

The block callbacks are similarly called on a **background thread**, hence **UI updated should be done in a dispatch_async(dispatch_get_main_queue(), ^{}); call**

The API has been made to be 'similar' to ASIHTTPRequest on purpose.

## A Simple GET example

	NSURL * url = [NSURL URLWithString:@"http://search.twitter.com/search.json"];

	TMGETRequest * req = [[TMGETRequest alloc] initWithURL:url];

	[req setValue:@"tonymillion" forKey:@"q"];
	[req setValue:@"20" forKey:@"rpp"];

	req.completedBlock = ^(NSHTTPURLResponse *response, NSData * data)
	{
	    NSLog(@"response = %@", [response allHeaderFields]);
    
	    NSError * err;
	    NSDictionary * JSONresponse = [NSJSONSerialization JSONObjectWithData:data 
	                                                              options:0 
	                                                                error:&err];
    
	    if(!JSONresponse)
	    {
	        NSLog(@"JSON Decoding error: %@", err);
	    }
	    else
	    {
	        NSLog(@"JSON: %@", JSONresponse);
	        dispatch_async(dispatch_get_main_queue(), ^{
	            [self.tableView reloadData];
	            NSLog(@"ReloadData Done!");
	        });
	    }
	};

	[req startRequest];
	
## Post

Posting is virtually identical to GET with the exception that you can use addPostData with a filename/content type in the same way you can with ASIHTTPRequest.