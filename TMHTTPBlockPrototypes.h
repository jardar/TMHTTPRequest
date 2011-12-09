//
//  TMHTTPBlockPrototypes.h
//  TMWebRequestApp
//
//  Created by Tony Million on 09/12/2011.
//  Copyright (c) 2011 __MyCompanyName__. All rights reserved.
//

#ifndef TMWebRequestApp_TMHTTPBlockPrototypes_h
#define TMWebRequestApp_TMHTTPBlockPrototypes_h

typedef void (^TMHTTPBasicBlock)(void);
typedef void (^TMHTTPFailureBlock)(NSHTTPURLResponse *response, NSError * error);
typedef void (^TMHTTPSuccessBlock)(NSHTTPURLResponse *response, NSData * data);
typedef void (^TMHTTPProgressBlock)(unsigned long long size, unsigned long long total);


#endif
