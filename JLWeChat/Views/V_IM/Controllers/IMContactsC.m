//
//  IMContactsC.m
//  IMModel
//
//  Created by jimneylee on 14-5-19.
//  Copyright (c) 2014年 jimneylee. All rights reserved.
//

#import "IMContactsC.h"
#import "IMXMPPManager.h"
#import "IMLocalSearchViewModel.h"
#import "IMContactCell.h"
#import "IMStaticContactCell.h"
#import "IMChatC.h"
#import "IMSearchDisplayController.h"
#import "IMMainMessageViewModel.h"
#import "IMContactEntity.h"

@interface IMContactsC ()<NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) IMSearchDisplayController *searchController;

@end

@implementation IMContactsC

- (void)dealloc
{
    [[IMXMPPManager sharedManager].xmppRoster removeDelegate:self delegateQueue:dispatch_get_main_queue()];
}

- (instancetype)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.title = @"通讯录";
        self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"添加朋友" style:UIBarButtonItemStylePlain
                                        target:self action:@selector(showAddFriendsView)];
        
        self.viewModel = [IMContactsViewModel sharedViewModel];
                
        @weakify(self);
        [self.viewModel.updatedContentSignal subscribeNext:^(id x) {
            @strongify(self);
            dispatch_async(dispatch_get_main_queue(), ^{
            [self.tableView reloadData];
            });
        }];
        
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.rowHeight = ADDRESS_BOOK_ROW_HEIGHT;
    self.tableView.sectionIndexColor = [UIColor darkGrayColor];
    self.tableView.tableFooterView = [IMUIHelper createDefaultTableFooterView];

    if (TTOSVersionIsAtLeast7()) {
        self.tableView.sectionIndexBackgroundColor = [UIColor clearColor];
    }
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0.f, 0.f,
                                                                           self.view.width, TT_TOOLBAR_HEIGHT)];
    searchBar.tintColor = APP_MAIN_COLOR;
    self.tableView.tableHeaderView = searchBar;
    
    IMSearchDisplayController *searchDisplayController = [[IMSearchDisplayController alloc] initWithSearchBar:searchBar
                                                                                           contentsController:self];
    self.searchController = searchDisplayController;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

#pragma mark - Private

- (void)showAddFriendsView
{
    UIAlertView *av = [[UIAlertView alloc] initWithTitle:@"请输入好友jid" message:nil
                                                delegate:nil cancelButtonTitle:@"取消"
                                       otherButtonTitles:@"发送请求", nil];
    av.alertViewStyle = UIAlertViewStylePlainTextInput;
    [av show];
    [[av rac_buttonClickedSignal] subscribeNext:^(id x) {
        if ([x intValue] == 1) {
            UITextField *tf = [av textFieldAtIndex:0];
            XMPPJID *jid = [XMPPJID jidWithUser:tf.text domain:XMPP_DOMAIN resource:XMPP_RESOURCE];
            [[[IMXMPPManager sharedManager] xmppRoster] addUser:jid
                                               withNickname:tf.text];
        }
    }];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableViewDataSource
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
    return [self.viewModel sectionIndexTitles];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [self.viewModel numberOfSections];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    return [self.viewModel titleForHeaderInSection:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)sectionIndex
{
    return [self.viewModel numberOfItemsInSection:sectionIndex];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *IMContactCellIdentifier = @"IMContactCell";
    static NSString *IMStaticContactCellIdentifier = @"IMStaticContactCellIdentifier";
    
	UITableViewCell *cell = nil;
    id object = [self.viewModel objectAtIndexPath:indexPath];
    if ([object isKindOfClass:[XMPPUserCoreDataStorageObject class]]) {
        cell = [tableView dequeueReusableCellWithIdentifier:IMContactCellIdentifier];
        if (!cell) {
            cell = [[IMContactCell alloc] initWithStyle:UITableViewCellStyleDefault
                                        reuseIdentifier:IMContactCellIdentifier];
        }
        
        XMPPUserCoreDataStorageObject *user = (XMPPUserCoreDataStorageObject *)object;
        [(IMContactCell *)cell shouldUpdateCellWithObject:user];
    }
    else if ([object isKindOfClass:[NSString class]]) {
        cell = [tableView dequeueReusableCellWithIdentifier:IMStaticContactCellIdentifier];
        if (!cell) {
            cell = [[IMStaticContactCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:IMStaticContactCellIdentifier];
        }
        [(IMStaticContactCell *)cell shouldUpdateCellWithObject:object
                                           unsubscribedCountNum:self.viewModel.unsubscribedCountNum];
    }
	
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section > 0) {
        return YES;
    }
    else {
        // section 0 不可删除
        return NO;
    }
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)aTableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section > 0) {
        return UITableViewCellEditingStyleDelete;
    }
    else {
        // section 0 不可删除
        return UITableViewCellEditingStyleNone;
    }
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section > 0 && editingStyle == UITableViewCellEditingStyleDelete) {
        
        XMPPUserCoreDataStorageObject *user = [self.viewModel objectAtIndexPath:indexPath];
        
        // 1、 解除好友关系，调用删除接口
//        if (!self.rosterAddtionlViewModel) {
//            self.rosterAddtionlViewModel = [[IMRosterAddtionalViewModel alloc] init];
//        }
//        [self.rosterAddtionlViewModel deleteFriend:user.jid.user
//                                            withMe:MY_JID.user
//                                           success:^{
//                                               NSLog(@"delete friend success");
//                                           }
//                                           failure:^(NSString *errorMsg) {
//                                               NSLog(@"delete friend error:%@", errorMsg);
//                                           }];
        // 2、xmpp删除
        [[IMXMPPManager sharedManager].xmppRoster removeUser:user.jid];

        // 3、同步删除联系人
        if ([[IMMainMessageViewModel sharedViewModel] deleteRecentContactWithJid:user.jid]) {
            NSLog(@"deleteRecentContact:%@", user.jid.bare);
        };
        
        if ([self.viewModel deleteUser:user]) {
            NSLog(@"deleteUser:%@", user.jid.bare);
            
            // 删除数据库，底层fetchController会controllerDidChangeContent
            // 不用手工删除cell
        }
    }
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark UITableViewDataDelegate
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        switch (indexPath.row) {
            case 0:
            {
//                [self showNewFriendsView];
                self.viewModel.unsubscribedCountNum = @0;
                [tableView reloadRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationNone];
            }
                break;
                
            default:
                break;
        }
    }
    else {        
        XMPPUserCoreDataStorageObject *user = [self.viewModel objectAtIndexPath:indexPath];
        IMChatC *chatC = [[IMChatC alloc] initWithBuddyJID:user.jid
                                                 buddyName:user.nickname];
        [self.navigationController pushViewController:chatC animated:YES];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (0 == section) {
        return 0.f;
    }
    return 25.f;//[super tableview:tableView heightForHeaderInSection:section];
}

@end
