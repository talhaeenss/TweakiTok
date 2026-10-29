#import "CountryTable.h"
#import "../BHIManager.h"
#import <objc/message.h>

@interface AWEToast : NSObject
+ (void)showSuccess:(NSString *)title;
+ (void)showError:(NSString *)title;
@end

@interface CountryTable () <UITableViewDelegate, UITableViewDataSource>

@property (nonatomic, strong) NSArray<NSDictionary *> *regionCodes;  // Holds dictionaries of country details
@property (nonatomic, strong) UITableView *tableView; // The table view to show the list

@end

@implementation CountryTable

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = [BHIManager isTurkish] ? @"Bölgeler" : @"Regions";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    self.regionCodes = @[
        @{@"area": @"Saudi Arabia 🇸🇦", @"area_tr": @"Suudi Arabistan 🇸🇦", @"name": @"Saudi Arabia", @"name_tr": @"Suudi Arabistan", @"code": @"SA", @"mcc": @"420", @"mnc": @"01"},
        @{@"area": @"Taiwan 🇹🇼", @"area_tr": @"Tayvan 🇹🇼", @"name": @"Taiwan", @"name_tr": @"Tayvan", @"code": @"TW", @"mcc": @"466", @"mnc": @"01"},
        @{@"area": @"Hong Kong 🇭🇰", @"area_tr": @"Hong Kong 🇭🇰", @"name": @"Hong Kong", @"name_tr": @"Hong Kong", @"code": @"HK", @"mcc": @"454", @"mnc": @"00"},
        @{@"area": @"Macao 🇲🇴", @"area_tr": @"Makao 🇲🇴", @"name": @"Macao", @"name_tr": @"Makao", @"code": @"MO", @"mcc": @"455", @"mnc": @"00"},
        @{@"area": @"Japan 🇯🇵", @"area_tr": @"Japonya 🇯🇵", @"name": @"Japan", @"name_tr": @"Japonya", @"code": @"JP", @"mcc": @"440", @"mnc": @"00"},
        @{@"area": @"South Korea 🇰🇷", @"area_tr": @"Güney Kore 🇰🇷", @"name": @"South Korea", @"name_tr": @"Güney Kore", @"code": @"KR", @"mcc": @"450", @"mnc": @"05"},
        @{@"area": @"United Kingdom 🇬🇧", @"area_tr": @"Birleşik Krallık 🇬🇧", @"name": @"United Kingdom", @"name_tr": @"Birleşik Krallık", @"code": @"GB", @"mcc": @"234", @"mnc": @"30"},
        @{@"area": @"United States 🇺🇸", @"area_tr": @"Amerika Birleşik Devletleri 🇺🇸", @"name": @"United States", @"name_tr": @"Amerika Birleşik Devletleri", @"code": @"US", @"mcc": @"310", @"mnc": @"00"},
        @{@"area": @"Australia 🇦🇺", @"area_tr": @"Avustralya 🇦🇺", @"name": @"Australia", @"name_tr": @"Avustralya", @"code": @"AU", @"mcc": @"505", @"mnc": @"02"},
        @{@"area": @"Canada 🇨🇦", @"area_tr": @"Kanada 🇨🇦", @"name": @"Canada", @"name_tr": @"Kanada", @"code": @"CA", @"mcc": @"302", @"mnc": @"720"},
        @{@"area": @"Argentina 🇦🇷", @"area_tr": @"Arjantin 🇦🇷", @"name": @"Argentina", @"name_tr": @"Arjantin", @"code": @"AR", @"mcc": @"722", @"mnc": @"07"},
        @{@"area": @"Philippines 🇵🇭", @"area_tr": @"Filipinler 🇵🇭", @"name": @"Philippines", @"name_tr": @"Filipinler", @"code": @"PH", @"mcc": @"515", @"mnc": @"02"},
        @{@"area": @"Laos 🇱🇦", @"area_tr": @"Laos 🇱🇦", @"name": @"Laos", @"name_tr": @"Laos", @"code": @"LA", @"mcc": @"457", @"mnc": @"01"},
        @{@"area": @"Malaysia 🇲🇾", @"area_tr": @"Malezya 🇲🇾", @"name": @"Malaysia", @"name_tr": @"Malezya", @"code": @"MY", @"mcc": @"502", @"mnc": @"13"},
        @{@"area": @"Thailand 🇹🇭", @"area_tr": @"Tayland 🇹🇭", @"name": @"Thailand", @"name_tr": @"Tayland", @"code": @"TH", @"mcc": @"520", @"mnc": @"18"},
        @{@"area": @"Singapore 🇸🇬", @"area_tr": @"Singapur 🇸🇬", @"name": @"Singapore", @"name_tr": @"Singapur", @"code": @"SG", @"mcc": @"525", @"mnc": @"01"},
        @{@"area": @"Indonesia 🇮🇩", @"area_tr": @"Endonezya 🇮🇩", @"name": @"Indonesia", @"name_tr": @"Endonezya", @"code": @"ID", @"mcc": @"510", @"mnc": @"01"},
        @{@"area": @"Vietnam 🇻🇳", @"area_tr": @"Vietnam 🇻🇳", @"name": @"Vietnam", @"name_tr": @"Vietnam", @"code": @"VN", @"mcc": @"452", @"mnc": @"01"},
        @{@"area": @"Anguilla 🇦🇮", @"area_tr": @"Anguilla 🇦🇮", @"name": @"Anguilla", @"name_tr": @"Anguilla", @"code": @"AI", @"mcc": @"365", @"mnc": @"840"},
        @{@"area": @"Panama 🇵🇦", @"area_tr": @"Panama 🇵🇦", @"name": @"Panama", @"name_tr": @"Panama", @"code": @"PA", @"mcc": @"714", @"mnc": @"04"},
        @{@"area": @"Germany 🇩🇪", @"area_tr": @"Almanya 🇩🇪", @"name": @"Germany", @"name_tr": @"Almanya", @"code": @"DE", @"mcc": @"262", @"mnc": @"01"},
        @{@"area": @"Russia 🇷🇺", @"area_tr": @"Rusya 🇷🇺", @"name": @"Russia", @"name_tr": @"Rusya", @"code": @"RU", @"mcc": @"250", @"mnc": @"01"},
        @{@"area": @"France 🇫🇷", @"area_tr": @"Fransa 🇫🇷", @"name": @"France", @"name_tr": @"Fransa", @"code": @"FR", @"mcc": @"208", @"mnc": @"10"},
        @{@"area": @"Finland 🇫🇮", @"area_tr": @"Finlandiya 🇫🇮", @"name": @"Finland", @"name_tr": @"Finlandiya", @"code": @"FI", @"mcc": @"244", @"mnc": @"91"},
        @{@"area": @"Italy 🇮🇹", @"area_tr": @"İtalya 🇮🇹", @"name": @"Italy", @"name_tr": @"İtalya", @"code": @"IT", @"mcc": @"222", @"mnc": @"10"},
        @{@"area": @"Pakistan 🇵🇰", @"area_tr": @"Pakistan 🇵🇰", @"name": @"Pakistan", @"name_tr": @"Pakistan", @"code": @"PK", @"mcc": @"410", @"mnc": @"01"},
        @{@"area": @"Denmark 🇩🇰", @"area_tr": @"Danimarka 🇩🇰", @"name": @"Denmark", @"name_tr": @"Danimarka", @"code": @"DK", @"mcc": @"238", @"mnc": @"01"},
        @{@"area": @"Norway 🇳🇴", @"area_tr": @"Norveç 🇳🇴", @"name": @"Norway", @"name_tr": @"Norveç", @"code": @"NO", @"mcc": @"242", @"mnc": @"01"},
        @{@"area": @"Sudan 🇸🇩", @"area_tr": @"Sudan 🇸🇩", @"name": @"Sudan", @"name_tr": @"Sudan", @"code": @"SD", @"mcc": @"634", @"mnc": @"01"},
        @{@"area": @"Romania 🇷🇴", @"area_tr": @"Romanya 🇷🇴", @"name": @"Romania", @"name_tr": @"Romanya", @"code": @"RO", @"mcc": @"226", @"mnc": @"01"},
        @{@"area": @"United Arab Emirates 🇦🇪", @"area_tr": @"Birleşik Arap Emirlikleri 🇦🇪", @"name": @"United Arab Emirates", @"name_tr": @"Birleşik Arap Emirlikleri", @"code": @"AE", @"mcc": @"424", @"mnc": @"02"},
        @{@"area": @"Egypt 🇪🇬", @"area_tr": @"Mısır 🇪🇬", @"name": @"Egypt", @"name_tr": @"Mısır", @"code": @"EG", @"mcc": @"602", @"mnc": @"01"},
        @{@"area": @"Lebanon 🇱🇧", @"area_tr": @"Lübnan 🇱🇧", @"name": @"Lebanon", @"name_tr": @"Lübnan", @"code": @"LB", @"mcc": @"415", @"mnc": @"01"},
        @{@"area": @"Mexico 🇲🇽", @"area_tr": @"Meksika 🇲🇽", @"name": @"Mexico", @"name_tr": @"Meksika", @"code": @"MX", @"mcc": @"334", @"mnc": @"030"},
        @{@"area": @"Brazil 🇧🇷", @"area_tr": @"Brezilya 🇧🇷", @"name": @"Brazil", @"name_tr": @"Brezilya", @"code": @"BR", @"mcc": @"724", @"mnc": @"06"},
        @{@"area": @"Turkey 🇹🇷", @"area_tr": @"Türkiye 🇹🇷", @"name": @"Turkey", @"name_tr": @"Türkiye", @"code": @"TR", @"mcc": @"286", @"mnc": @"01"},
        @{@"area": @"Kuwait 🇰🇼", @"area_tr": @"Kuveyt 🇰🇼", @"name": @"Kuwait", @"name_tr": @"Kuveyt", @"code": @"KW", @"mcc": @"419", @"mnc": @"02"},
        @{@"area": @"Algeria 🇩🇿", @"area_tr": @"Cezayir 🇩🇿", @"name": @"Algeria", @"name_tr": @"Cezayir", @"code": @"DZ", @"mcc": @"603", @"mnc": @"01"}
    ];

    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:[BHIManager isTurkish] ? @"Kapat" : @"Done"
                                                                             style:UIBarButtonItemStyleDone
                                                                            target:self
                                                                            action:@selector(dismissTable)];

    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.backgroundColor = [UIColor systemBackgroundColor];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
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

- (void)dismissTable {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - UITableView DataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.regionCodes.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"CountryCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }

    BOOL tr = [BHIManager isTurkish];
    NSDictionary *regionDict = self.regionCodes[indexPath.row];
    NSString *title = tr ? (regionDict[@"area_tr"] ?: regionDict[@"area"]) : regionDict[@"area"];
    cell.textLabel.text = title;
    cell.backgroundColor = [UIColor systemBackgroundColor];
    cell.textLabel.textColor = [UIColor labelColor];

    NSDictionary *currentRegion = [BHIManager selectedRegion];
    if (currentRegion && [currentRegion[@"code"] isEqualToString:regionDict[@"code"]]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }

    return cell;
}

#pragma mark - UITableView Delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

    NSDictionary *selectedRegion = self.regionCodes[indexPath.row];

    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    [defaults setObject:selectedRegion forKey:@"region"];
    [defaults setBool:YES forKey:@"en_region"];
    [defaults synchronize];

    [self.tableView reloadData];

    [[NSNotificationCenter defaultCenter] postNotificationName:@"RegionSelectedNotification"
                                                        object:nil
                                                      userInfo:selectedRegion];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"StoreRegionChangedNotification"
                                                        object:nil];

    BOOL tr = [BHIManager isTurkish];
    NSString *displayName = tr ? (selectedRegion[@"area_tr"] ?: selectedRegion[@"area"]) : selectedRegion[@"area"];
    NSString *title = tr ? @"Bölge Seçildi" : @"Region Selected";
    NSString *message = tr ? [NSString stringWithFormat:@"%@ bölgesi seçildi ve bölge değiştirme aktif edildi.\n\nDeğişikliklerin akışınızda tamamen etkili olması için uygulamayı kapatıp açmanız önerilir.", displayName]
                           : [NSString stringWithFormat:@"%@ region selected and region changing enabled.\n\nRestarting the app is recommended for changes to take full effect.", displayName];

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okAction = [UIAlertAction actionWithTitle:tr ? @"Tamam" : @"OK" style:UIAlertActionStyleDefault handler:nil];
    [alert addAction:okAction];
    [self presentViewController:alert animated:YES completion:nil];

    Class toastCls = NSClassFromString(@"AWEToast");
    if (toastCls && [toastCls respondsToSelector:@selector(showSuccess:)]) {
        ((void (*)(id, SEL, id))objc_msgSend)(toastCls, @selector(showSuccess:), tr ? @"Bölge Değiştirildi" : @"Region Changed");
    }
}

@end
