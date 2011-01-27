//
//  iptestAppDelegate.h
//  iptest
//
//  Created by Daisuke Murase on 11/01/27.
//  Copyright 2011 KAYAC Inc. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface iptestAppDelegate : NSObject <UIApplicationDelegate> {
    UIWindow *window;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;

@end

