//
//  WARContactStore.mm
//

#import "WARContactStore.h"
#import "WeChatHeaders.h"
#import <objc/runtime.h>

#pragma clang diagnostic ignored "-Warc-performSelector-leaks"

#pragma mark - 工具

static CContactMgr *WARContactMgr(void) {
    @try {
        Class centerCls = objc_getClass("MMServiceCenter");
        if (!centerCls) {
            NSLog(@"[WAR] MMServiceCenter class missing");
            return nil;
        }
        id center = [centerCls defaultCenter];
        if (!center) {
            NSLog(@"[WAR] MMServiceCenter defaultCenter nil");
            return nil;
        }
        Class mgrCls = objc_getClass("CContactMgr");
        if (!mgrCls) {
            NSLog(@"[WAR] CContactMgr class missing");
            return nil;
        }
        id svc = [center getService:mgrCls];
        if (!svc) {
            NSLog(@"[WAR] CContactMgr service not registered");
        }
        return svc;
    }
    @catch (NSException *e) {
        NSLog(@"[WAR] WARContactMgr exception: %@", e);
        return nil;
    }
}

// 安全取属性
static id WARSafeValue(id obj, NSString *key) {
    if (!obj) return nil;
    @try {
        return [obj valueForKey:key];
    }
    @catch (NSException *e) {
        return nil;
    }
}

static NSString *WARSafeString(id obj, NSString *key) {
    id v = WARSafeValue(obj, key);
    if ([v isKindOfClass:[NSString class]]) return v;
    return nil;
}

// 运行时遍历 obj 的所有 ivar，找出值是 NSDictionary 且 values 看起来像联系人的字典
static NSDictionary *WARFindContactDictionary(id obj) {
    if (!obj) return nil;
    @try {
        unsigned int count = 0;
        Ivar *ivars = class_copyIvarList([obj class], &count);
        for (unsigned int i = 0; i < count; i++) {
            const char *name = ivar_getName(ivars[i]);
            if (!name) continue;
            NSString *key = [NSString stringWithUTF8String:name];
            id val = WARSafeValue(obj, key);
            if ([val isKindOfClass:[NSDictionary class]]) {
                NSDictionary *d = (NSDictionary *)val;
                if (d.count == 0) continue;
                // 检查 values 里是否有 CContact（有 m_nsUsrName 属性且含 @chatroom 或 wxid_）
                id firstVal = d.allValues.firstObject;
                if (firstVal) {
                    NSString *usr = WARSafeString(firstVal, @"m_nsUsrName");
                    if (usr.length > 0) {
                        NSLog(@"[WAR] found contact dict via ivar '%@', count=%lu, sample usr=%@",
                              key, (unsigned long)d.count, usr);
                        free(ivars);
                        return d;
                    }
                }
            }
        }
        free(ivars);
    }
    @catch (NSException *e) {
        NSLog(@"[WAR] WARFindContactDictionary exception: %@", e);
    }
    return nil;
}

// 尝试调用返回 NSArray 的「获取所有联系人」方法
static NSArray *WARTryGetAllContacts(id mgr) {
    NSArray *selectors = @[
        @"GetAllContact",
        @"GetAllContacts",
        @"GetContactList",
        @"allContacts",
        @"GetAllFriend",
        @"GetAllFriends",
    ];
    for (NSString *selName in selectors) {
        SEL sel = NSSelectorFromString(selName);
        if ([mgr respondsToSelector:sel]) {
            @try {
                id arr = [mgr performSelector:sel];
                if ([arr isKindOfClass:[NSArray class]] && [arr count] > 0) {
                    NSLog(@"[WAR] GetAllContacts via '%@', count=%lu", selName, (unsigned long)[arr count]);
                    return arr;
                }
            }
            @catch (NSException *e) { }
        }
    }
    return nil;
}

@implementation WARContactStore

+ (NSString *)selfWxid {
    @try {
        CContactMgr *mgr = WARContactMgr();
        if (!mgr) return nil;
        id selfContact = nil;
        // 尝试多种获取自己联系人的方法
        NSArray *sels = @[@"selfContact", @"GetSelfContact", @"getSelfContact"];
        for (NSString *s in sels) {
            SEL sel = NSSelectorFromString(s);
            if ([mgr respondsToSelector:sel]) {
                selfContact = [mgr performSelector:sel];
                if (selfContact) break;
            }
        }
        NSString *wxid = WARSafeString(selfContact, @"m_nsUsrName");
        NSLog(@"[WAR] selfWxid=%@", wxid);
        return wxid;
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
        if (!mgr) {
            NSLog(@"[WAR] allChatrooms: mgr nil");
            return @[];
        }

        // 1) 先尝试已知属性名 m_dicContact
        NSDictionary *dic = nil;
        NSArray *dictKeys = @[@"m_dicContact", @"m_dicContacts", @"dicContact", @"m_dicAllContact"];
        for (NSString *k in dictKeys) {
            id v = WARSafeValue(mgr, k);
            if ([v isKindOfClass:[NSDictionary class]] && [v count] > 0) {
                dic = v;
                NSLog(@"[WAR] allChatrooms: found dict via '%@', count=%lu", k, (unsigned long)[v count]);
                break;
            }
        }

        // 2) 属性名拿不到，运行时遍历 ivar 找
        if (dic.count == 0) {
            dic = WARFindContactDictionary(mgr);
        }

        // 3) 还是没有，尝试 GetAllContact 类方法返回数组
        NSArray *allContacts = nil;
        if (dic.count == 0) {
            allContacts = WARTryGetAllContacts(mgr);
        }

        if (dic.count == 0 && allContacts.count == 0) {
            NSLog(@"[WAR] allChatrooms: no contact source found on CContactMgr");
            // 打印 CContactMgr 所有 ivar 名供调试
            unsigned int count = 0;
            Ivar *ivars = class_copyIvarList([mgr class], &count);
            NSMutableArray *names = [NSMutableArray array];
            for (unsigned int i = 0; i < count; i++) {
                const char *n = ivar_getName(ivars[i]);
                if (n) [names addObject:[NSString stringWithUTF8String:n]];
            }
            free(ivars);
            NSLog(@"[WAR] CContactMgr ivars: %@", names);
            return @[];
        }

        // 遍历联系人，筛选群聊
        NSArray *contacts = dic ? dic.allValues : allContacts;
        for (id contact in contacts) {
            NSString *wxid = WARSafeString(contact, @"m_nsUsrName");
            if (wxid.length == 0) continue;
            // 群聊 ID 以 @chatroom 结尾
            if (![wxid hasSuffix:@"@chatroom"]) continue;
            NSString *name = WARSafeString(contact, @"m_nsNickName");
            if (name.length == 0) name = wxid;
            [result addObject:@{ @"wxid": wxid, @"name": name }];
        }
        NSLog(@"[WAR] allChatrooms: found %lu chatrooms from %lu contacts",
              (unsigned long)result.count, (unsigned long)contacts.count);
    }
    @catch (NSException *e) {
        NSLog(@"[WAR] allChatrooms exception: %@", e);
        return @[];
    }

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
        if (!group) {
            NSLog(@"[WAR] membersOfGroup: GetContact returned nil for %@", chatroomId);
            return @[];
        }

        // 多种成员列表属性名
        NSArray<NSString *> *memberIds = nil;
        NSArray *listKeys = @[@"m_nsChatRoomMemList", @"m_arrChatRoomMem", @"m_chatRoomMemList", @"chatRoomMemList"];
        for (NSString *k in listKeys) {
            id list = WARSafeValue(group, k);
            if ([list isKindOfClass:[NSArray class]] && [list count] > 0) {
                memberIds = list;
                break;
            }
        }

        if (memberIds.count == 0) {
            // 回退：";" 分隔的字符串
            NSArray *memStrKeys = @[@"m_nsChatRoomMem", @"m_szChatRoomMem", @"chatRoomMem"];
            for (NSString *k in memStrKeys) {
                NSString *memStr = WARSafeString(group, k);
                if (memStr.length > 0) {
                    memberIds = [memStr componentsSeparatedByString:@";"];
                    break;
                }
            }
        }

        NSLog(@"[WAR] membersOfGroup %@: %lu members", chatroomId, (unsigned long)memberIds.count);

        NSString *selfWxid = [self selfWxid];
        for (id m in memberIds) {
            if (![m isKindOfClass:[NSString class]]) continue;
            NSString *wxid = (NSString *)m;
            if (wxid.length == 0) continue;
            if (selfWxid.length > 0 && [wxid isEqualToString:selfWxid]) continue;
            NSString *name = [self nicknameOf:wxid];
            if (name.length == 0) name = wxid;
            [result addObject:@{ @"wxid": wxid, @"name": name }];
        }
    }
    @catch (NSException *e) {
        NSLog(@"[WAR] membersOfGroup exception: %@", e);
        return @[];
    }

    [result sortUsingComparator:^NSComparisonResult(NSDictionary *a, NSDictionary *b) {
        return [a[@"name"] compare:b[@"name"] options:NSNumericSearch];
    }];
    return result;
}

@end
