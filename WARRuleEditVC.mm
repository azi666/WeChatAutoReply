//
//  WARRuleEditVC.mm
//  规则编辑页：选群 → 选人 → 触发消息 / 匹配方式 / 回复消息 / 冷却 / 启用
//

#import "WARRuleEditVC.h"
#import "WARPickerVC.h"
#import "WARContactStore.h"

@interface WARTextFieldCell : UITableViewCell
@property (nonatomic, strong) UITextField *textField;
@end

@implementation WARTextFieldCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        _textField = [[UITextField alloc] init];
        _textField.font = [UIFont systemFontOfSize:16];
        _textField.textColor = [UIColor labelColor];
        _textField.textAlignment = NSTextAlignmentRight;
        _textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        _textField.autocorrectionType = UITextAutocorrectionTypeNo;
        _textField.autocapitalizationType = UITextAutocapitalizationTypeNone;
        [self.contentView addSubview:_textField];
        self.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGFloat w = CGRectGetWidth(self.contentView.bounds);
    CGFloat labelW = 100;
    _textField.frame = CGRectMake(labelW, 8, w - labelW - 16, CGRectGetHeight(self.contentView.bounds) - 16);
}

@end

static NSString *const kRowGroup   = @"group";
static NSString *const kRowMember  = @"member";
static NSString *const kRowKeyword = @"keyword";
static NSString *const kRowMatch   = @"match";
static NSString *const kRowReply   = @"reply";
static NSString *const kRowCooldown = @"cooldown";
static NSString *const kRowEnabled = @"enabled";

@interface WARRuleEditVC () <UITextFieldDelegate>
@property (nonatomic, strong) WARRule *rule;
@property (nonatomic, assign) BOOL isNew;
@property (nonatomic, strong) NSArray<NSString *> *rowKeys;
@end

@implementation WARRuleEditVC

- (instancetype)initWithRule:(WARRule *)rule isNew:(BOOL)isNew {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _rule = rule;
        _isNew = isNew;
        _rowKeys = @[kRowGroup, kRowMember, kRowKeyword, kRowMatch, kRowReply, kRowCooldown, kRowEnabled];
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.isNew ? @"添加规则" : @"编辑规则";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"保存" style:UIBarButtonItemStyleDone
                                         target:self action:@selector(save)];
}

#pragma mark - 保存

- (void)save {
    [self.view endEditing:YES];

    if (self.rule.groupWxid.length == 0) {
        [self alert:@"请选择要监控的群聊"];
        return;
    }
    if (self.rule.memberWxid.length == 0) {
        [self alert:@"请选择要监控的群成员"];
        return;
    }
    if (self.rule.keyword.length == 0) {
        [self alert:@"请填写触发消息"];
        return;
    }
    if (self.rule.reply.length == 0) {
        [self alert:@"请填写自动回复内容"];
        return;
    }

    NSMutableArray *rules = [[WARRule loadAllRules] mutableCopy];
    NSInteger existing = -1;
    for (NSInteger i = 0; i < (NSInteger)rules.count; i++) {
        if ([((WARRule *)rules[i]).ruleID isEqualToString:self.rule.ruleID]) { existing = i; break; }
    }
    if (existing >= 0) {
        rules[existing] = self.rule;
    } else {
        [rules addObject:self.rule];
    }
    [WARRule saveAllRules:rules];
    if (self.onSave) self.onSave();
}

- (void)alert:(NSString *)msg {
    UIAlertController *ac = [UIAlertController alertControllerWithTitle:nil message:msg preferredStyle:UIAlertControllerStyleAlert];
    [ac addAction:[UIAlertAction actionWithTitle:@"好" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:ac animated:YES completion:nil];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return (NSInteger)self.rowKeys.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *key = self.rowKeys[indexPath.row];
    WARRule *rule = self.rule;

    if ([key isEqualToString:kRowGroup] || [key isEqualToString:kRowMember]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"pick"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:@"pick"];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        }
        cell.textLabel.textColor = [UIColor labelColor];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        if ([key isEqualToString:kRowGroup]) {
            cell.textLabel.text = @"监控群聊";
            cell.detailTextLabel.text = rule.groupName.length ? rule.groupName : @"点击选择";
        } else {
            cell.textLabel.text = @"监控成员";
            cell.detailTextLabel.text = rule.memberName.length ? rule.memberName : @"点击选择";
        }
        return cell;
    }

    if ([key isEqualToString:kRowMatch]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"match"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"match"];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];

            UILabel *label = [[UILabel alloc] init];
            label.tag = 100;
            label.text = @"匹配方式";
            label.font = [UIFont systemFontOfSize:16];
            label.textColor = [UIColor labelColor];
            [cell.contentView addSubview:label];

            UISegmentedControl *seg = [[UISegmentedControl alloc] initWithItems:@[@"完全", @"模糊", @"开头"]];
            seg.tag = 101;
            [seg addTarget:self action:@selector(matchChanged:) forControlEvents:UIControlEventValueChanged];
            [cell.contentView addSubview:seg];
        }
        UILabel *label = (UILabel *)[cell.contentView viewWithTag:100];
        UISegmentedControl *seg = (UISegmentedControl *)[cell.contentView viewWithTag:101];
        seg.selectedSegmentIndex = rule.matchType;
        CGFloat tvW = CGRectGetWidth(self.tableView.bounds);
        label.frame = CGRectMake(16, 0, 70, 44);
        CGFloat segW = 150;
        seg.frame = CGRectMake(tvW - segW - 16, 7, segW, 30);
        return cell;
    }

    if ([key isEqualToString:kRowEnabled]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switch"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"switch"];
            UISwitch *sw = [[UISwitch alloc] init];
            [sw addTarget:self action:@selector(enabledChanged:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        }
        cell.textLabel.text = @"启用此规则";
        cell.textLabel.textColor = [UIColor labelColor];
        ((UISwitch *)cell.accessoryView).on = rule.enabled;
        return cell;
    }

    // 文本输入行
    WARTextFieldCell *cell = [tableView dequeueReusableCellWithIdentifier:@"input"];
    if (![cell isKindOfClass:[WARTextFieldCell class]]) {
        cell = [[WARTextFieldCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"input"];
        cell.textField.delegate = self;
    }
    cell.textField.tag = indexPath.row;
    cell.textField.keyboardType = UIKeyboardTypeDefault;

    if ([key isEqualToString:kRowKeyword]) {
        cell.textLabel.text = @"触发消息";
        cell.textField.placeholder = @"对方发送的内容";
        cell.textField.text = rule.keyword;
    } else if ([key isEqualToString:kRowReply]) {
        cell.textLabel.text = @"自动回复";
        cell.textField.placeholder = @"命中后回复的内容";
        cell.textField.text = rule.reply;
    } else {
        cell.textLabel.text = @"冷却(秒)";
        cell.textField.placeholder = @"60";
        cell.textField.text = rule.cooldown > 0 ? [NSString stringWithFormat:@"%.0f", rule.cooldown] : @"";
        cell.textField.keyboardType = UIKeyboardTypeNumberPad;
    }
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSString *key = self.rowKeys[indexPath.row];

    if ([key isEqualToString:kRowGroup]) {
        WARPickerVC *picker = [[WARPickerVC alloc] initWithMode:WARPickerModeGroup chatroomId:nil];
        __weak typeof(self) weakSelf = self;
        picker.onPick = ^(NSString *wxid, NSString *name) {
            weakSelf.rule.groupWxid = wxid;
            weakSelf.rule.groupName = name;
            // 换群后清空已选成员
            weakSelf.rule.memberWxid = @"";
            weakSelf.rule.memberName = @"";
            [weakSelf.tableView reloadData];
            [weakSelf.navigationController popViewControllerAnimated:YES];
        };
        [self.navigationController pushViewController:picker animated:YES];
    }
    else if ([key isEqualToString:kRowMember]) {
        if (self.rule.groupWxid.length == 0) {
            [self alert:@"请先选择群聊"];
            return;
        }
        WARPickerVC *picker = [[WARPickerVC alloc] initWithMode:WARPickerModeMember chatroomId:self.rule.groupWxid];
        __weak typeof(self) weakSelf = self;
        picker.onPick = ^(NSString *wxid, NSString *name) {
            weakSelf.rule.memberWxid = wxid;
            weakSelf.rule.memberName = name;
            [weakSelf.tableView reloadData];
            [weakSelf.navigationController popViewControllerAnimated:YES];
        };
        [self.navigationController pushViewController:picker animated:YES];
    }
}

#pragma mark - UITextFieldDelegate

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField {
    NSIndexPath *path = [NSIndexPath indexPathForRow:textField.tag inSection:0];
    [self.tableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionMiddle animated:YES];
}

- (void)textFieldDidEndEditing:(UITextField *)textField {
    NSString *key = self.rowKeys[textField.tag];
    NSString *text = [textField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([key isEqualToString:kRowKeyword]) {
        self.rule.keyword = text;
    } else if ([key isEqualToString:kRowReply]) {
        self.rule.reply = text;
    } else if ([key isEqualToString:kRowCooldown]) {
        self.rule.cooldown = [text doubleValue];
    }
}

#pragma mark - 控件事件

- (void)matchChanged:(UISegmentedControl *)seg {
    self.rule.matchType = (WARMatchType)seg.selectedSegmentIndex;
}

- (void)enabledChanged:(UISwitch *)sw {
    self.rule.enabled = sw.on;
}

@end
