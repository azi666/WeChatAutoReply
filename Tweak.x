//
//  Tweak.x
//  WeChatAutoReply —— 核心 Hook
//
//  1. 收消息：hook CMessageMgr / MessageService 的 onNewMsg:（双保险，内部按消息去重）
//  2. 入口：微信「我」页面 / 「设置」页面底部插入「群消息自动回复」入口
//

#import "WeChatHeaders.h"
#import "WARRule.h"
#import "WARSettingsVC.h"

#pragma mark - 入口 Footer 视图

// 仿微信 cell 样式的入口按钮，作为 tableView 的 tableFooterView 注入，
// 不触碰微信任何私有 UI 类，跨版本稳定。
@interface WAREntryFooterView : UIView
@end

@implementation WAREntryFooterView {
    UIButton *_button;
}

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _button = [UIButton buttonWithType:UIButtonTypeCustom];
        _button.frame = CGRectMake(0, 12, CGRectGetWidth(frame), 48);
        _button.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _button.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        _button.layer.cornerRadius = 0;

        [_button setTitleColor:[UIColor labelColor] forState:UIControlStateNormal];
        _button.titleLabel.font = [UIFont systemFontOfSize:17];
        [_button setTitle:@"  群消息自动回复" forState:UIControlStateNormal];
        _button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
        _button.contentEdgeInsets = UIEdgeInsetsMake(0, 16, 0, 0);
        [_button setImage:[UIImage systemImageNamed:@"arrowshape.turn.up.right.circle"]
                forState:UIControlStateNormal];
        _button.imageView.tintColor = [UIColor systemGreenColor];
        _button.imageEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 8);
        [_button addTarget:self
                    action:@selector(openSettings)
          forControlEvents:UIControlEventTouchUpInside];
        [self addSubview:_button];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    _button.frame = CGRectMake(0, 12, CGRectGetWidth(self.bounds), 48);
}

- (void)openSettings {
    // 沿响应链找到宿主 ViewController，用微信自己的导航栈 push
    UIResponder *responder = self.nextResponder;
    while (responder && ![responder isKindOfClass:[UIViewController class]]) {
        responder = responder.nextResponder;
    }
    UIViewController *host = (UIViewController *)responder;
    if (!host.navigationController) {
        return;
    }
    WARSettingsVC *vc = [[WARSettingsVC alloc] init];
    [host.navigationController pushViewController:vc animated:YES];
}

@end

#pragma mark - 工具

static UITableView *WARFindTableView(UIView *root) {
    if ([root isKindOfClass:[UITableView class]]) {
        return (UITableView *)root;
    }
    for (UIView *sub in root.subviews) {
        UITableView *tv = WARFindTableView(sub);
        if (tv) return tv;
    }
    return nil;
}

// 在宿主页面的 tableView 底部安装入口（重复调用安全）
static void WARInstallEntry(UIViewController *host) {
    if (!host.view) return;
    UITableView *tv = WARFindTableView(host.view);
    if (!tv) return;
    if ([tv.tableFooterView isKindOfClass:[WAREntryFooterView class]]) {
        return; // 已安装
    }
    CGFloat width = CGRectGetWidth(tv.bounds);
    WAREntryFooterView *footer = [[WAREntryFooterView alloc] initWithFrame:CGRectMake(0, 0, width, 72)];
    // 保留微信原有的 footer 内容（若有），把我们的入口叠在下方
    if (tv.tableFooterView && !CGRectIsEmpty(tv.tableFooterView.bounds)) {
        UIView *old = tv.tableFooterView;
        CGFloat oldH = CGRectGetHeight(old.bounds);
        UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, width, oldH + 72)];
        [container addSubview:old];
        old.frame = CGRectMake(0, 0, width, oldH);
        [container addSubview:footer];
        footer.frame = CGRectMake(0, oldH, width, 72);
        tv.tableFooterView = container;
    } else {
        tv.tableFooterView = footer;
    }
}

#pragma mark - Hook：收消息

%hook CMessageMgr

- (void)onNewMsg:(CMessageWrap *)msg {
    %orig;
    [WARRule handleIncomingMessage:msg];
}

%end

%hook MessageService

- (void)onNewMsg:(CMessageWrap *)msg {
    %orig;
    [WARRule handleIncomingMessage:msg];
}

%end

#pragma mark - Hook：配置入口

%hook WCAccountMainViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WARInstallEntry(self);
}

%end

%hook NewSettingViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    WARInstallEntry(self);
}

%end

#pragma mark - 构造

%ctor {
    @autoreleasepool {
        NSLog(@"[WAR] WeChatAutoReply loaded");
        NSLog(@"[WAR] CMessageMgr: %@, MessageService: %@, WCAccountMainViewController: %@, NewSettingViewController: %@",
              objc_getClass("CMessageMgr") ? @"OK" : @"MISSING",
              objc_getClass("MessageService") ? @"OK" : @"MISSING",
              objc_getClass("WCAccountMainViewController") ? @"OK" : @"MISSING",
              objc_getClass("NewSettingViewController") ? @"OK" : @"MISSING");
    }
}
