//
//  WeChatHeaders.h
//  微信内部类/方法的编译期声明（仅用于类型检查，运行时由微信进程提供真实实现）
//  兼容微信 8.0.x 系列；所有访问处均做了运行时防御。
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - 消息对象

@interface CMessageWrap : NSObject
// 消息类型：1 = 文本
@property (nonatomic, assign) unsigned int m_uiMessageType;
// 群消息时为群 ID（xxx@chatroom）；私聊时为对方 wxid
@property (nonatomic, copy) NSString *m_nsFromUsr;
@property (nonatomic, copy) NSString *m_nsToUsr;
// 群消息时为群内实际发送者 wxid
@property (nonatomic, copy) NSString *m_nsRealUsr;
@property (nonatomic, copy) NSString *m_nsMsgContent;
@property (nonatomic, assign) long long m_n64MesSvrID;
@property (nonatomic, assign) unsigned int m_uiStatus;
@end

#pragma mark - 联系人

@interface CContact : NSObject
@property (nonatomic, copy) NSString *m_nsUsrName;
@property (nonatomic, copy) NSString *m_nsNickName;
// 老版本：";" 分隔的群成员 wxid 字符串
@property (nonatomic, copy) NSString *m_nsChatRoomMem;
// 新版本：群成员 wxid 数组
@property (nonatomic, strong) NSArray<NSString *> *m_nsChatRoomMemList;
@end

@interface CContactMgr : NSObject
- (nullable CContact *)GetContact:(NSString *)usrName;
- (nullable CContact *)selfContact;
@property (nonatomic, strong) NSDictionary<NSString *, CContact *> *m_dicContact;
@end

#pragma mark - 服务中心

@interface MMServiceCenter : NSObject
+ (instancetype)defaultCenter;
- (nullable id)getService:(Class)serviceClass;
@end

NS_ASSUME_NONNULL_END
