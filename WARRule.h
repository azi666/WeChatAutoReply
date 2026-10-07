//
//  WARRule.h
//  规则模型 / 持久化 / 消息匹配引擎 / 冷却控制
//

#import <Foundation/Foundation.h>
#import "WeChatHeaders.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WARMatchType) {
    WARMatchExact    = 0, // 完全匹配
    WARMatchContains = 1, // 模糊匹配（包含）
    WARMatchPrefix   = 2, // 开头匹配
};

@interface WARRule : NSObject

@property (nonatomic, copy) NSString *ruleID;
@property (nonatomic, copy) NSString *groupWxid;   // 群 ID（xxx@chatroom）
@property (nonatomic, copy) NSString *groupName;   // 群名（展示用）
@property (nonatomic, copy) NSString *memberWxid;  // 监控的群成员 wxid
@property (nonatomic, copy) NSString *memberName;  // 成员昵称（展示用）
@property (nonatomic, copy) NSString *keyword;     // 触发消息
@property (nonatomic, assign) WARMatchType matchType;
@property (nonatomic, copy) NSString *reply;       // 自动回复内容
@property (nonatomic, assign) NSTimeInterval cooldown; // 冷却秒数
@property (nonatomic, assign) BOOL enabled;

- (BOOL)matchesContent:(NSString *)content;

#pragma mark - 持久化

+ (NSArray<WARRule *> *)loadAllRules;
+ (void)saveAllRules:(NSArray<WARRule *> *)rules;
+ (BOOL)globalEnabled;
+ (void)setGlobalEnabled:(BOOL)on;

#pragma mark - 消息处理（由 Tweak.x 调用）

+ (void)handleIncomingMessage:(CMessageWrap *)msg;

@end

NS_ASSUME_NONNULL_END
