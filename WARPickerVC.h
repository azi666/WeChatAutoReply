//
//  WARPickerVC.h
//  群聊选择器 / 群成员选择器（带搜索）
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, WARPickerMode) {
    WARPickerModeGroup = 0,  // 选择群聊
    WARPickerModeMember = 1, // 选择群成员（需传 chatroomId）
};

@interface WARPickerVC : UITableViewController

- (instancetype)initWithMode:(WARPickerMode)mode chatroomId:(nullable NSString *)chatroomId;

/// 选中回调（wxid / 群ID + 显示名）
@property (nonatomic, copy, nullable) void (^onPick)(NSString *wxid, NSString *name);

@end

NS_ASSUME_NONNULL_END
