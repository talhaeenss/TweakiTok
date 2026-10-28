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
    self.staticTable = [[UITableView alloc] initWithFrame:CGRectZero];
    self.staticTable.translatesAutoresizingMaskIntoConstraints = NO;
    [self.staticTable registerClass:[UITableViewCell class] forCellReuseIdentifier:@"CellIdentifier"];

    [self.view addSubview:self.staticTable];
    [NSLayoutConstraint activateConstraints:@[
        [self.staticTable.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.staticTable.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.staticTable.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.staticTable.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor]
    ]];
    self.staticTable.dataSource = self;
    self.staticTable.delegate = self;
}


- (nonnull UITableViewCell *)tableView:(nonnull UITableView *)tableView cellForRowAtIndexPath:(nonnull NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"CellIdentifier"];
    NSNumber *speed = self.speeds[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@ x", speed];
    cell.tag = [speed floatValue];
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
