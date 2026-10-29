//
//  OfflineVideosLimit.m
//  StaticTableView
//

#import "OfflineVideosLimit.h"
#import "../BHIManager.h"

@interface OfflineVideosLimit () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSArray *limitTitles;
@property (nonatomic, strong) NSArray *limitValues;
@property (nonatomic, strong) UITableView *tableView;

@end

@implementation OfflineVideosLimit

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.title = [BHIManager isTurkish] ? @"Çevrimdışı Video Limiti" : @"Offline Videos Limit";
    // 0 = Default (stock behavior); the rest override TikTok's offline video count
    self.limitTitles = [BHIManager isTurkish] ? @[@"Varsayılan", @"50 video", @"100 video", @"200 video", @"500 video", @"1000 video"] : @[@"Default", @"50 videos", @"100 videos", @"200 videos", @"500 videos", @"1000 videos"];
    self.limitValues = @[@0, @50, @100, @200, @500, @1000];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[BHIManager isTurkish] ? @"Kapat" : @"Done"
                                                                             style:UIBarButtonItemStyleDone
                                                                            target:self
                                                                            action:@selector(dismissLimit)];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    [self.view addSubview:self.tableView];

    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    [self setupNavBarAppearance];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavBarAppearance];
    [self.tableView reloadData];
}

- (void)setupNavBarAppearance {
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithDefaultBackground];
        appearance.backgroundColor = [UIColor systemBackgroundColor];
        appearance.titleTextAttributes = @{
            NSForegroundColorAttributeName: [UIColor labelColor]
        };
        self.navigationController.navigationBar.standardAppearance = appearance;
        self.navigationController.navigationBar.scrollEdgeAppearance = appearance;
        self.navigationController.navigationBar.compactAppearance = appearance;
    }
}

- (void)dismissLimit {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.limitValues.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"LimitCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];

    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellIdentifier];
    }

    cell.textLabel.text = self.limitTitles[indexPath.row];
    cell.backgroundColor = [UIColor systemBackgroundColor];
    cell.textLabel.textColor = [UIColor labelColor];

    NSNumber *currentLimit = [[NSUserDefaults standardUserDefaults] objectForKey:@"offline_videos_limit"] ?: @0;
    if ([currentLimit isEqual:self.limitValues[indexPath.row]]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSNumber *selectedLimit = self.limitValues[indexPath.row];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:selectedLimit forKey:@"offline_videos_limit"];
    [defaults synchronize];

    [self.tableView reloadData];

    BOOL tr = [BHIManager isTurkish];
    NSString *title = tr ? @"Çevrimdışı Video Limiti" : @"Offline Videos Limit";
    NSString *message = tr ? [NSString stringWithFormat:@"Seçilen limit: %@", self.limitTitles[indexPath.row]]
                           : [NSString stringWithFormat:@"You selected: %@", self.limitTitles[indexPath.row]];
    if ([selectedLimit integerValue] >= 500) {
        message = [message stringByAppendingString:tr ? @"\nİndirmeler kademeli olarak doldurulur ve yeterli depolama alanı gerektirir." : @"\nDownloads refill gradually and need enough free storage."];
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:tr ? @"Tamam" : @"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RegionSelectedNotification"
                                                        object:nil
                                                      userInfo:@{@"selected limit": selectedLimit}];
}

@end
