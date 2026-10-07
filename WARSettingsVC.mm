//
//  WARSettingsVC.mm
//  规则列表设置页：总开关 + 规则增删改查
//

#import "WARSettingsVC.h"
#import "WARRule.h"
#import "WARRuleEditVC.h"

@interface WARSettingsVC ()
@property (nonatomic, strong) NSArray<WARRule *> *rules;
@end

@implementation WARSettingsVC

- (instancetype)init {
    self = [super initWithStyle:UITableViewStyleGrouped];
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = @"群消息自动回复";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                      target:self
                                                      action:@selector(addRule)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.rules = [WARRule loadAllRules];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)addRule {
    WARRule *rule = [[WARRule alloc] init];
    rule.ruleID = [[NSUUID UUID] UUIDString];
    rule.matchType = WARMatchExact;
    rule.cooldown = 60;
    rule.enabled = YES;
    WARRuleEditVC *edit = [[WARRuleEditVC alloc] initWithRule:rule isNew:YES];
    __weak typeof(self) weakSelf = self;
    edit.onSave = ^{ [weakSelf.navigationController popViewControllerAnimated:YES]; };
    [self.navigationController pushViewController:edit animated:YES];
}

- (void)toggleGlobal:(UISwitch *)sender {
    [WARRule setGlobalEnabled:sender.on];
}

- (void)toggleRule:(UISwitch *)sender {
    NSInteger idx = sender.tag;
    if (idx < 0 || idx >= (NSInteger)self.rules.count) return;
    WARRule *rule = self.rules[idx];
    rule.enabled = sender.on;
    NSMutableArray *rules = [self.rules mutableCopy];
    rules[idx] = rule;
    [WARRule saveAllRules:rules];
    self.rules = rules;
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) return 1;
    return self.rules.count > 0 ? self.rules.count : 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 1) return self.rules.count > 0 ? @"规则" : nil;
    return nil;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"switch"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"switch"];
            UISwitch *sw = [[UISwitch alloc] init];
            [sw addTarget:self action:@selector(toggleGlobal:) forControlEvents:UIControlEventValueChanged];
            cell.accessoryView = sw;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
        cell.textLabel.text = @"自动回复总开关";
        cell.textLabel.textColor = [UIColor labelColor];
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        UISwitch *sw = (UISwitch *)cell.accessoryView;
        sw.on = [WARRule globalEnabled];
        return cell;
    }

    if (self.rules.count == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"empty"];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"empty"];
            cell.textLabel.text = @"暂无规则，点右上角 + 添加";
            cell.textLabel.textColor = [UIColor tertiaryLabelColor];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
        }
        return cell;
    }

    WARRule *rule = self.rules[indexPath.row];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rule"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"rule"];
        UISwitch *sw = [[UISwitch alloc] init];
        [sw addTarget:self action:@selector(toggleRule:) forControlEvents:UIControlEventValueChanged];
        cell.accessoryView = sw;
        cell.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    }
    cell.textLabel.text = [NSString stringWithFormat:@"%@ · %@", rule.groupName, rule.memberName];
    NSString *matchDesc = @[@"完全匹配", @"模糊匹配", @"开头匹配"][rule.matchType];
    cell.detailTextLabel.text = [NSString stringWithFormat:@"[%@]「%@」→「%@」",
                                 matchDesc, rule.keyword, rule.reply];
    cell.textLabel.textColor = [UIColor labelColor];
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    UISwitch *sw = (UISwitch *)cell.accessoryView;
    sw.tag = indexPath.row;
    sw.on = rule.enabled;
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return indexPath.section == 1 && self.rules.count > 0;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle != UITableViewCellEditingStyleDelete) return;
    NSMutableArray *rules = [self.rules mutableCopy];
    [rules removeObjectAtIndex:indexPath.row];
    [WARRule saveAllRules:rules];
    self.rules = rules;
    [tableView reloadData];
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == 0 || self.rules.count == 0) return;

    WARRule *rule = self.rules[indexPath.row];
    WARRuleEditVC *edit = [[WARRuleEditVC alloc] initWithRule:rule isNew:NO];
    __weak typeof(self) weakSelf = self;
    edit.onSave = ^{ [weakSelf.navigationController popViewControllerAnimated:YES]; };
    [self.navigationController pushViewController:edit animated:YES];
}

@end
