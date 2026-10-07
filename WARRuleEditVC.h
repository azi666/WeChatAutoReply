//
//  WARRuleEditVC.h
//  规则编辑页
//

#import <UIKit/UIKit.h>
#import "WARRule.h"

NS_ASSUME_NONNULL_BEGIN

@interface WARRuleEditVC : UITableViewController

- (instancetype)initWithRule:(WARRule *)rule isNew:(BOOL)isNew;

@property (nonatomic, copy, nullable) void (^onSave)(void);

@end

NS_ASSUME_NONNULL_END
