//
//  WARContactStore.h
//  微信数据桥：读取自己 wxid、群聊列表、群成员列表（全部运行时防御）
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WARContactStore : NSObject

/// 当前登录账号的 wxid（用于过滤自己发的消息）
+ (NSString *)selfWxid;

/// 所有群聊：@[@{ @"wxid": @"xxx@chatroom", @"name": @"群名" }]
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)allChatrooms;

/// 指定群的成员列表：@[@{ @"wxid": @"wxid_xxx", @"name": @"昵称或wxid" }]
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)membersOfGroup:(NSString *)chatroomId;

/// 查询单个联系人昵称（找不到返回 nil）
+ (NSString *)nicknameOf:(NSString *)wxid;

@end

NS_ASSUME_NONNULL_END
