//
//  WARPickerVC.mm
//

#import "WARPickerVC.h"
#import "WARContactStore.h"

@interface WARPickerVC () <UISearchBarDelegate>
@property (nonatomic, assign) WARPickerMode mode;
@property (nonatomic, copy) NSString *chatroomId;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *> *allItems;
@property (nonatomic, strong) NSArray<NSDictionary<NSString *, NSString *> *> *filteredItems;
@property (nonatomic, strong) UISearchBar *searchBar;
@end

@implementation WARPickerVC

- (instancetype)initWithMode:(WARPickerMode)mode chatroomId:(NSString *)chatroomId {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        _mode = mode;
        _chatroomId = chatroomId;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.mode == WARPickerModeGroup ? @"选择群聊" : @"选择群成员";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    _searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 56)];
    _searchBar.placeholder = @"搜索";
    _searchBar.delegate = self;
    _searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    self.tableView.tableHeaderView = _searchBar;

    // 数据加载（群成员可能较多，放到下一帧避免卡顿）
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.mode == WARPickerModeGroup) {
            self.allItems = [WARContactStore allChatrooms];
        } else {
            self.allItems = [WARContactStore membersOfGroup:self.chatroomId];
        }
        self.filteredItems = self.allItems;
        [self.tableView reloadData];
        if (self.allItems.count == 0) {
            if (self.mode == WARPickerModeGroup) {
                [self hint:@"未读取到群聊列表，请确认已登录并加载通讯录"];
            } else {
                [self hint:@"未读取到群成员，请先进入该群聊一次"];
            }
        }
    });
}

- (void)hint:(NSString *)msg {
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.bounds), 60)];
    l.text = msg;
    l.textColor = [UIColor tertiaryLabelColor];
    l.font = [UIFont systemFontOfSize:14];
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    self.tableView.tableFooterView = l;
}

#pragma mark - 搜索

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    NSString *q = [searchText stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (q.length == 0) {
        self.filteredItems = self.allItems;
    } else {
        NSPredicate *pred = [NSPredicate predicateWithFormat:@"name CONTAINS[cd] %@ OR wxid CONTAINS[cd] %@", q, q];
        self.filteredItems = [self.allItems filteredArrayUsingPredicate:pred];
    }
    [self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.filteredItems.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"item"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"item"];
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    NSDictionary *item = self.filteredItems[indexPath.row];
    cell.textLabel.text = item[@"name"];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.text = item[@"wxid"];
    cell.detailTextLabel.textColor = [UIColor tertiaryLabelColor];
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary *item = self.filteredItems[indexPath.row];
    if (self.onPick) {
        self.onPick(item[@"wxid"] ?: @"", item[@"name"] ?: @"");
    }
}

@end
