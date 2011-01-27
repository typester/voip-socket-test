#import "TableBaseViewController.h"

@implementation TableBaseViewController

@synthesize table = table_;

-(void)viewDidLoad {
    [super viewDidLoad];

    self.table.delegate = self;
    self.table.dataSource = self;
}

-(void)releaseIBOutlets {
    self.table.delegate = nil;
    self.table.dataSource = nil;
    self.table = nil;
    [super releaseIBOutlets];
}

#pragma mark -
#pragma mark UITableViewDataSource

-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    return nil;
}

-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

#pragma mark -
#pragma mark UITableViewDelegate

@end
