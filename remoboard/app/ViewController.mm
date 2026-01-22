//
//  ViewController.m
//  remotekb
//
//  Created by everettjf on 2019/6/16.
//  Copyright © 2019 everettjf. All rights reserved.
//

#import "ViewController.h"
#import "Masonry.h"
#import "SCLAlertView.h"
#import "KBSetting.h"
#import "PAAUI.h"
#import "QuickWordsListViewController.h"
#import "TestInputViewController.h"
#import "AppUtil.h"
#import "AppMemoryData.h"
#import <StoreKit/StoreKit.h>
#import "WeeklyExecutionManager.h"

@interface ViewController () <UITableViewDelegate, UITableViewDataSource>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) NSArray *groups;
@property (assign, nonatomic) BOOL shouldShowConnectionMode;
@property (assign, nonatomic) NSInteger appVersionTapCount;

@property (strong, nonatomic) NSUserActivity *userActivity;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    // Do any additional setup after loading the view.
    NSString *systemTitle = ttt(@"app.longname");
    NSString *topBarTitle = systemTitle;
    
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.navigationController setNavigationBarHidden:YES];
    
    self.title = systemTitle;
    
    CGRect bounds = [UIScreen mainScreen].bounds;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0,0,bounds.size.width,100)];
    UILabel *titleLabel = [[UILabel alloc] init];
    [header addSubview:titleLabel];
    
    titleLabel.text = topBarTitle;
    titleLabel.font = [UIFont systemFontOfSize:38 weight:UIFontWeightBold];
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(header.mas_left).offset(20);
        make.bottom.equalTo(header.mas_bottom).offset(-10);
        make.right.equalTo(header.mas_right);
    }];
    UIView *sep = [[UIView alloc] init];
    sep.backgroundColor = [UIColor lightGrayColor];
    [header addSubview:sep];
    [sep mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(header.mas_left);
        make.right.equalTo(header.mas_right);
        make.bottom.equalTo(header.mas_bottom);
        make.height.equalTo(@(0.5));
    }];
    
    
    self.tableView.tableHeaderView = header;
    
    [self.tableView registerClass:UITableViewCell.class forCellReuseIdentifier:@"cell"];
    self.tableView.delegate = self;
    self.tableView.dataSource = self;
    self.tableView.showsVerticalScrollIndicator = NO;
    self.tableView.showsHorizontalScrollIndicator = NO;
    
    ttt_zhcn;
    
    __weak typeof(self) wself = self;
    self.shouldShowConnectionMode = NO;
    self.appVersionTapCount = 0;
    [self rebuildGroups];
    
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"HandoffUrl" object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
        NSString *handoffUrl = note.object;
        if (handoffUrl.length > 0 ) {
            self.userActivity = [[NSUserActivity alloc] initWithActivityType:NSUserActivityTypeBrowsingWeb];
            self.userActivity.webpageURL = [NSURL URLWithString:handoffUrl];
            [self.userActivity becomeCurrent];
            
            SCLAlertView *alert = [[SCLAlertView alloc] initWithNewWindow];
            [alert showInfo:@"Tips" subTitle:ttt(@"message.handoffcompleted") closeButtonTitle:@"Okay" duration:5.0f]; // Error
        }
        
    }];
}

- (void)rebuildGroups {
    __weak typeof(self) wself = self;
    NSMutableArray *moreItems = [NSMutableArray arrayWithArray:@[
        @{
            @"icon":@"star",
            @"title":ttt(@"title.starapp"),
            @"action": ^{
                NSLog(@"action");
                NSString * url = [NSString stringWithFormat:@"itms-apps://itunes.apple.com/app/id%@?action=write-review",@"1474458879"];
                [wself openUrl:url];
            }
        },
        @{
            @"icon":@"share",
            @"title":ttt(@"title.shareapp"),
            @"action": ^{
                NSLog(@"action");
                NSString *str;
                ttt_zhcn;
                if (hasLang) {
                    str = @"远程输入法 - 电脑打字，手机输入 https://itunes.apple.com/cn/app/id1474458879";
                } else {
                    str = @"Remoboard - Type From Desktop https://apps.apple.com/us/app/id1474458879";
                }
                [wself openShare:str];
            }
        },
        @{
            @"icon":@"products",
            @"title": ttt(@"title.website"),
            @"action": ^{
                [wself openSite];
            }
        },
    ]];
    
    if (self.shouldShowConnectionMode) {
        [moreItems addObject:@{
            @"icon":@"connection",
            @"title":ttt(@"title.connectionmode"),
            @"actionWithCell": ^(UITableView *tableView,UITableViewCell *cell,NSIndexPath *indexPath){
                dispatch_async(dispatch_get_main_queue(), ^{
                    [wself chooseConnectionMode:tableView cell:cell indexPath:indexPath];
                });
            }
        }];
    }
    
    [moreItems addObject:@{
        @"icon":@"app",
        @"title": [NSString stringWithFormat:@"%@ %@",ttt(@"title.appversion"), [AppUtil getAppVersion]],
        @"action": ^{
            [wself handleAppVersionTap];
        }
    }];
    
    [moreItems addObject:@{
        @"icon":@"products",
        @"title": ttt(@"title.moreapps"),
        @"action": ^{
            [wself openUrl:@"https://xnu.app"];
        }
    }];
    
    self.groups = @[
        @{
            @"title":ttt(@"title.general"),
            @"items":@[
                @{
                    @"icon":@"setup",
                    @"title":ttt(@"title.installguide"),
                    @"action": ^{
                        NSLog(@"action");
                        [wself showInstall];
                    }
                },
                @{
                    @"icon":@"auth",
                    @"title":ttt(@"title.allowfullaccess"),
                    @"action": ^{
                        NSLog(@"action");
                        [wself showEnableFullAccess];
                    }
                },
            ]
        },
        @{
            @"title":ttt(@"title.manage"),
            @"items":@[
                @{
                    @"icon":@"words",
                    @"title":ttt(@"title.quickwords"),
                    @"action": ^{
                        QuickWordsListViewController *vc = [[QuickWordsListViewController alloc] init];
                        [wself.navigationController pushViewController:vc animated:YES];
                    }
                },
                @{
                    @"icon":@"test",
                    @"title":ttt(@"title.testinput"),
                    @"action": ^{
                        TestInputViewController *vc = [[TestInputViewController alloc] init];
                        [wself.navigationController pushViewController:vc animated:YES];
                    }
                },
            ]
        },
        @{
            @"title":ttt(@"title.more"),
            @"items":moreItems
        },
    ];
    
    if (self.tableView) {
        [self.tableView reloadData];
    }
}

- (void)handleAppVersionTap {
    self.appVersionTapCount += 1;
    if (!self.shouldShowConnectionMode && self.appVersionTapCount >= 3) {
        self.shouldShowConnectionMode = YES;
        [self rebuildGroups];
    }
}

- (void)openSite {
    [self openUrl:@"https://xnu.app/remoboard"];
}

- (void)openUrl:(NSString*)url {
    NSURL *settingUrl = [NSURL URLWithString:url];
    [[UIApplication sharedApplication] openURL:settingUrl options:@{} completionHandler:^(BOOL success) {}];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        WeeklyExecutionManager *manager = [WeeklyExecutionManager sharedManager];
        [manager executeBlock:^{
            [SKStoreReviewController requestReview];
        }];
    });
    
}

- (void)showAlert:(NSString*)text {
    SCLAlertView *alert = [[SCLAlertView alloc] initWithNewWindow];
    [alert showInfo:@"Tips" subTitle:text closeButtonTitle:@"Okay" duration:0.0f]; // Error
}

- (void)openShare:(NSString*)str {
    
    UIActivityViewController *activity = [[UIActivityViewController alloc] initWithActivityItems:@[str] applicationActivities:nil];
    UIPopoverPresentationController *popover = activity.popoverPresentationController;
    if (popover) {
        popover.sourceView = self.view;
        popover.permittedArrowDirections = UIPopoverArrowDirectionUp;
    }
    [self presentViewController:activity animated:YES completion:NULL];
}

- (void)showInstall {
    SCLAlertView *alert = [[SCLAlertView alloc] initWithNewWindow];
    
    [alert showInfo:ttt(@"common.title.install") subTitle:ttt(@"common.title.install.shortguide") closeButtonTitle:ttt(@"common.ok") duration:0.0f];
}

- (void)showEnableFullAccess {
    SCLAlertView *alert = [[SCLAlertView alloc] initWithNewWindow];
    [alert addButton:ttt(@"common.gotosetting") actionBlock:^{
        [AppUtil openSetting];
    }];
    [alert showInfo:ttt(@"common.howtoallow") subTitle:ttt(@"common.howtoallow.shortguide") closeButtonTitle:ttt(@"common.later") duration:0.0f];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return self.groups.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSDictionary *group = self.groups[section];
    NSArray *items = group[@"items"];
    return items.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"cell" forIndexPath:indexPath];
    NSDictionary *group = self.groups[indexPath.section];
    NSArray *items = group[@"items"];
    NSDictionary *item = items[indexPath.row];
    
    cell.imageView.image = [UIImage imageNamed:item[@"icon"]];
    cell.textLabel.text = item[@"title"];
    
    // fix image size
    CGSize itemSize = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(itemSize, NO, UIScreen.mainScreen.scale);
    CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
    [cell.imageView.image drawInRect:imageRect];
    cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
    
    // style
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    NSDictionary *group = self.groups[section];
    return group[@"title"];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.y > 0) {
        if (self.navigationController.isNavigationBarHidden) {
            [self.navigationController setNavigationBarHidden:NO animated:NO];
        }
    } else {
        if (!self.navigationController.isNavigationBarHidden) {
            [self.navigationController setNavigationBarHidden:YES animated:NO];
        }
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *group = self.groups[indexPath.section];
    NSArray *items = group[@"items"];
    NSDictionary *item = items[indexPath.row];
    
    void (^action)(void) = item[@"action"];
    if (action) {
        action();
    }
    
    void (^actionWithCell)(UITableView *,UITableViewCell*,NSIndexPath*) = item[@"actionWithCell"];
    if (actionWithCell) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (cell) {
            actionWithCell(tableView,cell,indexPath);
        }
    }
}


- (void)chooseConnectionMode:(UITableView *)tableView cell:(UITableViewCell*)cell indexPath:(NSIndexPath*)indexPath{
    NSString *bluetoothTitle = ttt(@"common.bluetooth");
    NSString *ipTitle = ttt(@"common.ipconnectioncode");
    NSString *httpTitle = ttt(@"common.http");
    
    KBConnectMode connectionMode = [KBSetting sharedSetting].connectMode;
    if ( connectionMode == KBConnectMode_HTTP) {
        httpTitle = [NSString stringWithFormat:@"✅ %@",httpTitle];
    } else if ( connectionMode == KBConnectMode_BLE) {
        bluetoothTitle = [NSString stringWithFormat:@"✅ %@",bluetoothTitle];
    } else {
        ipTitle = [NSString stringWithFormat:@"✅ %@",ipTitle];
    }
    
    UIAlertController *actionSheet = [UIAlertController alertControllerWithTitle:ttt(@"common.chooseconnectionmode") message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    UIAlertAction *action1 = [UIAlertAction actionWithTitle:httpTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [KBSetting sharedSetting].connectMode = KBConnectMode_HTTP;
    }];
    UIAlertAction *action3 = [UIAlertAction actionWithTitle:bluetoothTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        [KBSetting sharedSetting].connectMode = KBConnectMode_BLE;
    }];
    UIAlertAction *action4 = [UIAlertAction actionWithTitle:ttt(@"common.cancel") style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
        
    }];
    [actionSheet addAction:action1];
    [actionSheet addAction:action3];
    [actionSheet addAction:action4];

    UIPopoverPresentationController * popPresenter = [actionSheet popoverPresentationController];
    popPresenter.sourceView = cell.contentView;
    popPresenter.sourceRect = [tableView rectForRowAtIndexPath:indexPath];
    
    [self presentViewController:actionSheet animated:YES completion:nil];
}

@end
