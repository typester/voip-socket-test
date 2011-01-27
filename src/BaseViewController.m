#import "BaseViewController.h"

@implementation BaseViewController

-(id)initWithNibName:(NSString *)nibName bundle:(NSBundle *)nibBundle {
    if (self = [super initWithNibName:nibName bundle:nibBundle]) {
        [self initialize];
    }
    return self;
}

-(void)awakeFromNib {
    [self initialize];
}

-(void)initialize {
}

-(void)viewDidLoad {
    [super viewDidLoad];
}

-(void)viewDidUnload {
    [self releaseIBOutlets];
    [super viewDidUnload];
}

-(void)releaseIBOutlets {
}

@end
