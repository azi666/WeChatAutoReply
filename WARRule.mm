//
//  WARRule.mm
//  规则模型 / 持久化 / 消息匹配引擎 / 冷却控制
//

#import "WARRule.h"
#import "WARMessageSender.h"
#import "WARContactStore.h"

static NSString *const WARDefaultsKey = @"WARRules";
static NSString *const WARGlobalKey = @"WAREnabled";

// 每条规则最近一次触发时间（仅内存，重启微信后冷却重置）
static NSMutableDictionary<NSString *, NSDate *> *g_lastFire = nil;
// 最近的去重 key（CMessageMgr 与 MessageService 双 hook 时防止重复处理）
static NSMutableArray<NSString *> *g_recentKeys = nil;

@implementation WARRule

- (BOOL)matchesContent:(NSString *)content {
    if (self.keyword.length == 0 || content.length == 0) {
        return NO;
    }
    switch (self.matchType) {
        case WARMatchExact:
            return [content isEqualToString:self.keyword];
        case WARMatchContains:
            return [content rangeOfString:self.keyword].location != NSNotFound;
        case WARMatchPrefix:
            return [content hasPrefix:self.keyword];
    }
    return NO;
}

#pragma mark - 持久化

+ (NSArray<WARRule *> *)loadAllRules {
    NSArray *arr = [[NSUserDefaults standardUserDefaults] arrayForKey:WARDefaultsKey];
    if (![arr isKindOfClass:[NSArray class]]) {
        return @[];
    }
    NSMutableArray *rules = [NSMutableArray array];
    for (NSDictionary *d in arr) {
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        WARRule *r = [[WARRule alloc] init];
        r.ruleID = d[@"id"] ?: [[NSUUID UUID] UUIDString];
        r.groupWxid = d[@"groupWxid"] ?: @"";
        r.groupName = d[@"groupName"] ?: @"";
        r.memberWxid = d[@"memberWxid"] ?: @"";
        r.memberName = d[@"memberName"] ?: @"";
        r.keyword = d[@"keyword"] ?: @"";
        r.matchType = (WARMatchType)[d[@"matchType"] integerValue];
        r.reply = d[@"reply"] ?: @"";
        r.cooldown = [d[@"cooldown"] doubleValue];
        if (r.cooldown < 0) r.cooldown = 0;
        r.enabled = [d[@"enabled"] boolValue];
        [rules addObject:r];
    }
    return rules;
}

+ (void)saveAllRules:(NSArray<WARRule *> *)rules {
    NSMutableArray *arr = [NSMutableArray array];
    for (WARRule *r in rules) {
        [arr addObject:@{
            @"id": r.ruleID ?: @"",
            @"groupWxid": r.groupWxid ?: @"",
            @"groupName": r.groupName ?: @"",
            @"memberWxid": r.memberWxid ?: @"",
            @"memberName": r.memberName ?: @"",
            @"keyword": r.keyword ?: @"",
            @"matchType": @(r.matchType),
            @"reply": r.reply ?: @"",
            @"cooldown": @(r.cooldown),
            @"enabled": @(r.enabled),
        }];
    }
    [[NSUserDefaults standardUserDefaults] setObject:arr forKey:WARDefaultsKey];
}

+ (BOOL)globalEnabled {
    // 未设置过默认开启（规则为空时无副作用）
    if (![[NSUserDefaults standardUserDefaults] objectForKey:WARGlobalKey]) {
        return YES;
    }
    return [[NSUserDefaults standardUserDefaults] boolForKey:WARGlobalKey];
}

+ (void)setGlobalEnabled:(BOOL)on {
    [[NSUserDefaults standardUserDefaults] setBool:on forKey:WARGlobalKey];
}

#pragma mark - 消息处理

+ (void)handleIncomingMessage:(CMessageWrap *)msg {
    if (msg == nil) return;
    if (![WARRule globalEnabled]) return;

    @try {
        // 只处理文本消息（m_uiMessageType == 1）
        unsigned int msgType = 0;
        if ([msg respondsToSelector:@selector(m_uiMessageType)]) {
            msgType = [msg m_uiMessageType];
        }
        if (msgType != 1) return;

        NSString *fromUsr = [msg respondsToSelector:@selector(m_nsFromUsr)] ? [msg m_nsFromUsr] : nil;
        if (fromUsr.length == 0) return;
        // 只处理群消息
        if (![fromUsr hasSuffix:@"@chatroom"]) return;

        NSString *sender = [msg respondsToSelector:@selector(m_nsRealUsr)] ? [msg m_nsRealUsr] : nil;
        NSString *content = [msg respondsToSelector:@selector(m_nsMsgContent)] ? [msg m_nsMsgContent] : nil;
        if (content.length == 0) return;

        // 兼容老版本群消息内容格式 "wxid:\n内容"
        NSRange nl = [content rangeOfString:@"\n"];
        if (nl.location != NSNotFound && nl.location > 0) {
            NSString *maybeWxid = [content substringToIndex:nl.location];
            if ([maybeWxid rangeOfString:@" "].location == NSNotFound &&
                ([maybeWxid hasPrefix:@"wxid_"] || [maybeWxid containsString:@":"])) {
                if (sender.length == 0 || [sender isEqualToString:maybeWxid]) {
                    content = [content substringFromIndex:nl.location + 1];
                }
            }
        }
        if (sender.length == 0 || content.length == 0) return;

        // 过滤自己发出的消息（防止回复自己 / 死循环）
        NSString *selfWxid = [WARContactStore selfWxid];
        if (selfWxid.length > 0 && [sender isEqualToString:selfWxid]) return;

        // 去重（双 hook 场景）
        long long svrId = 0;
        if ([msg respondsToSelector:@selector(m_n64MesSvrID)]) {
            svrId = [msg m_n64MesSvrID];
        }
        NSString *dedupKey = [NSString stringWithFormat:@"%@|%@|%@|%lld", fromUsr, sender, content, svrId];
        @synchronized ([WARRule class]) {
            static BOOL inited = NO;
            if (!inited) {
                g_recentKeys = [NSMutableArray array];
                g_lastFire = [NSMutableDictionary dictionary];
                inited = YES;
            }
            if ([g_recentKeys containsObject:dedupKey]) return;
            [g_recentKeys addObject:dedupKey];
            if (g_recentKeys.count > 100) {
                [g_recentKeys removeObjectsInRange:NSMakeRange(0, g_recentKeys.count - 100)];
            }
        }

        // 规则匹配
        NSArray<WARRule *> *rules = [WARRule loadAllRules];
        if (rules.count == 0) return;

        NSDate *now = [NSDate date];
        for (WARRule *rule in rules) {
            if (!rule.enabled) continue;
            if (![rule.groupWxid isEqualToString:fromUsr]) continue;
            if (rule.memberWxid.length > 0 && ![rule.memberWxid isEqualToString:sender]) continue;
            if (![rule matchesContent:content]) continue;

            // 冷却检查
            BOOL fire = YES;
            @synchronized ([WARRule class]) {
                NSDate *last = g_lastFire[rule.ruleID];
                if (last && [now timeIntervalSinceDate:last] < rule.cooldown) {
                    fire = NO;
                } else {
                    g_lastFire[rule.ruleID] = now;
                }
            }
            if (!fire) continue;

            NSLog(@"[WAR] rule hit: group=%@ sender=%@ keyword=%@ -> reply=%@",
                  rule.groupName, rule.memberName, rule.keyword, rule.reply);

            dispatch_async(dispatch_get_main_queue(), ^{
                [WARMessageSender sendText:rule.reply to:rule.groupWxid];
            });
        }
    }
    @catch (NSException *e) {
        NSLog(@"[WAR] handleIncomingMessage exception: %@ - %@", e.name, e.reason);
    }
}

@end
