//
//  PlaybackSpeed.m
//  StaticTableView
//
//  Created by raul on 16/10/2024.
//

#import "PlaybackSpeed.h"
#import "../BHIManager.h"

@interface PlaybackSpeed ()
@property (nonatomic, strong) UITableView *staticTable;
@property (nonatomic, strong) NSArray <NSNumber *> *speeds;
@end

@implementation PlaybackSpeed

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    self.speeds = @[@0.5, @1.0, @1.5, @2.0];
    self.title = [BHIManager isTurkish] ? @"Hız Seçin" : @"Select Speed";

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[BHIManager isTurkish] ? @"Kapat" : @"Done"
                                                                             style:UIBarButtonItemStyleDone
                                                                            target:self
                                                                            action:@selector(dismissSpeed)];

    self.staticTable = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.staticTable.translatesAutoresizingMaskIntoConstraints = NO;
    self.staticTable.backgroundColor = [UIColor systemBackgroundColor];
    self.staticTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    [self.staticTable registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CellIdentifier"];

    [self.view addSubview:self.staticTable];
    [NSLayoutConstraint activateConstraints:@[
        [self.staticTable.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.staticTable.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.staticTable.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.staticTable.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];
    self.staticTable.dataSource = self;
    self.staticTable.delegate = self;

    [self setupNavBarAppearance];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self setupNavBarAppearance];
    [self.staticTable reloadData];
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

- (void)dismissSpeed {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellIdentifier"];
    NSNumber *speed = self.speeds[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ x", speed];
    cell.tag = [speed floatValue];
    cell.backgroundColor = [UIColor systemBackgroundColor];
    cell.textLabel.textColor = [UIColor labelColor];

    NSNumber *currentSpeed = [BHIManager selectedSpeed];
    if (fabs([currentSpeed floatValue] - [speed floatValue]) < 0.001) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    return cell;
}

- (NSInteger)tableView:(nonnull UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.speeds.count;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSNumber *selectedSpeed = self.speeds[indexPath.row];
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setValue:selectedSpeed forKey:@"playback_speed"];
    [defaults synchronize];
    [self.staticTable reloadData];

    BOOL tr = [BHIManager isTurkish];
    NSString *title = tr ? @"Oynatma Hızı Seçildi" : @"Playback Speed Selected";
    NSString *msg = tr ? [NSString stringWithFormat:@"Seçilen hız: %@ x", selectedSpeed] : [NSString stringWithFormat:@"You selected: %@ x", selectedSpeed];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:tr ? @"Tamam" : @"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"RegionSelectedNotification"
                                                        object:nil
                                                      userInfo:@{@"selected Speed": selectedSpeed}];
}

@end
