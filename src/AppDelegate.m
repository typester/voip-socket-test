#import "AppDelegate.h"

#include "stream_client.h"
#include <arpa/inet.h>

#define HOST inet_addr("127.0.0.1")
#define PORT htons(4423)

static AppDelegate* app;
static NSInputStream* read_stream = nil;

@interface AppDelegate (Private)
-(void)setup_watcher;
-(void)close_watcher;
-(void)reset_watcher;
@end

void err_handler(stream_client_t* client, int code, const char* msg) {
    fprintf(stderr, "network error: %d %s\n", code, msg);
    [app close_watcher];

//    // reconnect! XXX
    if (SC_CONNECTING != client->state) {
        stream_client_connect(client, HOST, PORT);
    }
}

void eof_handler(stream_client_t* client, int code, const char* msg) {
    fprintf(stderr, "eof error: %d %s\n", code, msg);
    [app close_watcher];

//    // reconnect! XXX
    stream_client_connect(client, HOST, PORT);
}

void read_handler(stream_client_t* client, const char* buf, int len) {
    NSString* data = [NSString stringWithUTF8String:buf];

    NSDictionary* info = [NSDictionary dictionaryWithObject:data forKey:@"data"];

    dispatch_async(dispatch_get_main_queue(), ^{
        NSNotification* n = [NSNotification notificationWithName:@"READ_DATA"
                                                          object:[UIApplication sharedApplication]
                                                        userInfo:info];
        [[NSNotificationCenter defaultCenter] postNotification:n];
    });
}

void connect_handler(stream_client_t* client) {
    [app setup_watcher];
}

@implementation AppDelegate

#pragma mark -
#pragma mark Application lifecycle

static stream_client_t* client;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // Override point for customization after application launch.
    [window makeKeyAndVisible];

    app = self;

    client = stream_client_init();
    client->error_callback = (void*)err_handler;
    client->eof_callback   = (void*)eof_handler;
    client->read_callback  = (void*)read_handler;
    client->connect_callback = (void*)connect_handler;

    stream_client_connect(client, HOST, PORT);
    assert(0 != client->fd);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            while (1)
                ev_run(ev_default_loop(0), 0);
    });

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onRecvData:)
                                                 name:@"READ_DATA"
                                               object:nil];

    LOG(@"application launched: %@", launchOptions);

    return YES;
}


- (void)applicationWillResignActive:(UIApplication *)application {
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}


- (void)applicationDidEnterBackground:(UIApplication *)application {
    /*
     Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
     If your application supports background execution, called instead of applicationWillTerminate: when the user quits.
     */

    LOG(@"enter BG");

    [[UIApplication sharedApplication] setKeepAliveTimeout:600
                                                   handler:^{
            //
            LOG(@"keep-alive handler");

            if (-1 == stream_client_keepalive(client)) {
                LOG(@"failed to send keep-alive packet");
            }
        }];
}


- (void)applicationWillEnterForeground:(UIApplication *)application {
    /*
     Called as part of  transition from the background to the inactive state: here you can undo many of the changes made on entering the background.
     */
    LOG_CURRENT_METHOD;
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}


-(void)applicationWillTerminate:(UIApplication *)application {
    /*
     Called when the application is about to terminate.
     See also applicationDidEnterBackground:.
     */
    LOG_CURRENT_METHOD;
}


#pragma mark -
#pragma mark Memory management

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application {
    /*
     Free up as much memory as possible by purging cached data objects that can be recreated (or reloaded from disk) later.
     */
}

- (void)dealloc {
    stream_client_disconnect(client);
    stream_client_free(client);
    [window release];
    [super dealloc];
}

#pragma mark -
#pragma mark Nofitication

-(void)onRecvData:(NSNotification*)n {
    LOG_CURRENT_METHOD;
    NSString* data = [[n userInfo] objectForKey:@"data"];
    LOG(@"read: %@", data);

    UILocalNotification* l = [[UILocalNotification alloc] init];
    l.alertBody = data;

    [[UIApplication sharedApplication] presentLocalNotificationNow:l];

    [l release];
}

#pragma mark -
#pragma mark stream

-(void)setup_watcher {
    assert(nil == read_stream);
    assert(0 != client->fd);

    CFStreamCreatePairWithSocket(
        kCFAllocatorDefault, client->fd,
        (CFReadStreamRef*)&read_stream, NULL
    );

    [read_stream setProperty:NSStreamNetworkServiceTypeVoIP
                      forKey:NSStreamNetworkServiceType];

    [read_stream scheduleInRunLoop:[NSRunLoop currentRunLoop]
                           forMode:NSDefaultRunLoopMode];
    [[read_stream retain] open];
}

-(void)close_watcher {
    if (nil != read_stream) {
        [read_stream close];
        [read_stream removeFromRunLoop:[NSRunLoop currentRunLoop]
                               forMode:NSDefaultRunLoopMode];
        [read_stream release];
        read_stream = nil;
    }
}

-(void)reset_watcher {
    [self close_watcher];
    [self setup_watcher];
}

@end
