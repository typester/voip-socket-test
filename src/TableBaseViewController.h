#import "BaseViewController.h"

@interface TableBaseViewController : BaseViewController <UITableViewDelegate, UITableViewDataSource> {
    UITableView* table_;
}

@property (nonatomic, retain) IBOutlet UITableView* table;

@end
