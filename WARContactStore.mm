//
//  WARContactStore.mm
//

#import "WARContactStore.h"
#import "WeChatHeaders.h"
#import <objc/runtime.h>

static CContactMgr *WARContactMgr(void) {
    @try {
        Class centerCls = objc_getClass("MMServiceCenter");
        if (!centerCls) return nil;
        id center = [centerCls defaultCenter];
        if (!center) return nil;
        Class mgrCls = objc_getClass("CContactMgr");
        if (!mgrCls) return nil;
        return [center getService:mgrCls];
    }
    @catch (NSException *e) {
        return nil;
    }
}

// 安全取 CContact 属性（属性不存在时返回 nil 而不是 crash）
static NSString *WARSafeString(id obj, NSString *key) {
    if (!obj) return nil;
    @try {
        id v = [obj valueForKey:key];
        if ([v isKindOfClass:[NSString class]]) return v;
        return nil;
    }
    @catch (NSException *e) {
        return nil;
    }
}

@implementation WARContactStore

+ (NSString *)selfWxid {
    @try {
        CContactMgr *mgr = WARContactMgr();
        if (!mgr) return nil;
        id selfContact = nil;
        if ([mgr respondsToSelector:@selector(selfContact)]) {
            selfContact = [mgr performSelector:@selector(selfContact)];
        }
        return WARSafeString(selfContact, @"m_nsUsrName");
    }
    @catch (NSException *e) {
        return nil;
    }
}

+ (NSString *)nicknameOf:(NSString *)wxid {
    if (wxid.length == 0) return nil;
    @try {
        CContactMgr *mgr = WARContactMgr();
        if (!mgr) return nil;
        id contact = nil;
        if ([mgr respondsToSelector:@selector(GetContact:)]) {
            contact = [mgr performSelector:@selector(GetContact:) withObject:wxid];
        }
        return WARSafeString(contact, @"m_nsNickName");
    }
    @catch (NSException *e) {
        return nil;
    }
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)allChatrooms {
    NSMutableArray *result = [NSMutableArray array];
    @try {
        CContactMgr *mgr = WARContactMgr();
        if (!mgr) return @[];
        NSDictionary *dic = nil;
        if ([mgr respondsToSelector:@selector(m_dicContact)]) {
            dic = [mgr performSelector:@selector(m_dicContact)];
        }
        if (![dic isKindOfClass:[NSDictionary class]]) return @[];

        for (id contact in dic.allValues) {
            NSString *wxid = WARSafeString(contact, @"m_nsUsrName");
            if (wxid.length == 0 || ![wxid hasSuffix:@"@chatroom"]) continue;
            NSString *name = WARSafeString(contact, @"m_nsNickName");
            if (name.length == 0) name = wxid;
            [result addObject:@{ @"wxid": wxid, @"name": name }];
        }
    }
    @catch (NSException *e) {
        return @[];
    }

    // 按群名排序，方便查找
    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] compare:b[@"name"] options:NSNumericSearch];
    }];
    return result;
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)membersOfGroup:(NSString *)chatroomId {
    NSMutableArray *result = [NSMutableArray array];
    if (chatroomId.length == 0) return @[];

    @try {
        CContactMgr *mgr = WARContactMgr();
        if (!mgr) return @[];

        id group = nil;
        if ([mgr respondsToSelector:@selector(GetContact:)]) {
            group = [mgr performSelector:@selector(GetContact:) withObject:chatroomId];
        }
        if (!group) return @[];

        // 优先 m_nsChatRoomMemList（数组），回退 m_nsChatRoomMem（";" 分隔字符串）
        NSArray<NSString *> *memberIds = nil;
        @try {
            id list = [group valueForKey:@"m_nsChatRoomMemList"];
            if ([list isKindOfClass:[NSArray class]]) {
                memberIds = list;
            }
        }
        @catch (NSException *e) { }

        if (memberIds.count == 0) {
            NSString *memStr = WARSafeString(group, @"m_nsChatRoomMem");
            if (memStr.length > 0) {
                memberIds = [memStr componentsSeparatedByString:@";"];
            }
        }

        NSString *selfWxid = [self selfWxid];
        for (id m in memberIds) {
            if (![m isKindOfClass:[NSString class]]) continue;
            NSString *wxid = (NSString *)m;
            if (wxid.length == 0) continue;
            if (selfWxid.length > 0 && [wxid isEqualToString:selfWxid]) continue; // 排除自己
            NSString *name = [self nicknameOf:wxid];
            if (name.length == 0) name = wxid;
            [result addObject:@{ @"wxid": wxid, @"name": name }];
        }
    }
    @catch (NSException *e) {
        return @[];
    }

    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] compare:b[@"name"] options:NSNumericSearch];
    }];
    return result;
}

@end
