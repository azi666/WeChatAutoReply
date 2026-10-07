//
//  WARMessageSender.h
//  发送文本消息 —— 运行时动态查找 SendTextMessage 并按实际签名调用，
//  兼容微信 8.0.x 各版本参数个数变化。
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface WARMessageSender : NSObject

/// 发送文本消息到指定会话（群 ID 或 wxid），主线程调用
+ (BOOL)sendText:(NSString *)text to:(NSString *)toUsrName;

@end

NS_ASSUME_NONNULL_END
