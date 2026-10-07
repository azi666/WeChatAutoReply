//
//  WARMessageSender.mm
//

#import "WARMessageSender.h"
#import "WeChatHeaders.h"
#import <objc/runtime.h>

#pragma mark - 运行时工具

// 沿继承链扫描以 SendTextMessage 开头的实例方法（参数个数随版本变化）
static SEL WARFindSendTextSelector(id target) {
    Class cls = [target class];
    while (cls) {
        unsigned int count = 0;
        Method *methods = class_copyMethodList(cls, &count);
        for (unsigned int i = 0; i < count; i++) {
            SEL sel = method_getName(methods[i]);
            NSString *name = NSStringFromSelector(sel);
            if ([name hasPrefix:@"SendTextMessage"]) {
                free(methods);
                return sel;
            }
        }
        free(methods);
        cls = class_getSuperclass(cls);
    }
    return NULL;
}

// 按方法实际签名构造 NSInvocation：
//   第 1 个对象参数 -> 消息文本；第 2 个对象参数 -> 目标会话；
//   其余对象参数 -> nil；指针 -> NULL；数值/结构体 -> 全零。
static BOOL WARInvoke(id target, SEL sel, NSString *text, NSString *to) {
    NSMethodSignature *sig = [target methodSignatureForSelector:sel];
    if (!sig) return NO;

    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:sig];
    [inv setTarget:target];
    [inv setSelector:sel];

    BOOL textSet = NO, toSet = NO;
    for (NSUInteger i = 2; i < sig.numberOfArguments; i++) {
        const char *type = [sig getArgumentTypeAtIndex:i];
        if (type[0] == '@') {
            id arg = nil;
            if (!textSet) {
                arg = text;
                textSet = YES;
            } else if (!toSet) {
                arg = to;
                toSet = YES;
            }
            [inv setArgument:&arg atIndex:i];
        } else {
            NSUInteger size = 0;
            NSGetSizeAndAlignment(type, &size, NULL);
            if (size > 0 && size <= 64) {
                uint8_t buf[64] = {0};
                [inv setArgument:buf atIndex:i];
            }
        }
    }

    [inv retainArguments];
    [inv invoke];
    return YES;
}

@implementation WARMessageSender

+ (BOOL)sendText:(NSString *)text to:(NSString *)toUsrName {
    if (text.length == 0 || toUsrName.length == 0) return NO;

    @try {
        // 取消息服务：优先 MessageService（8.0.4x+），回退 CMessageMgr
        id service = nil;
        Class centerCls = objc_getClass("MMServiceCenter");
        if (centerCls) {
            id center = [centerCls defaultCenter];
            if (center) {
                for (NSString *svcName in @[@"MessageService", @"CMessageMgr"]) {
                    Class svcCls = NSClassFromString(svcName);
                    if (!svcCls) continue;
                    id svc = [center getService:svcCls];
                    if (svc) {
                        service = svc;
                        break;
                    }
                }
            }
        }
        if (!service) {
            NSLog(@"[WAR] message service not found");
            return NO;
        }

        // 1) 经典 2 参签名 SendTextMessage:toUsrName:
        SEL sel = NSSelectorFromString(@"SendTextMessage:toUsrName:");
        if ([service respondsToSelector:sel]) {
            BOOL ok = WARInvoke(service, sel, text, toUsrName);
            NSLog(@"[WAR] send via SendTextMessage:toUsrName: -> %@", ok ? @"OK" : @"FAIL");
            return ok;
        }

        // 2) 动态扫描变体签名（参数更多时其余参数填默认值）
        sel = WARFindSendTextSelector(service);
        if (sel) {
            BOOL ok = WARInvoke(service, sel, text, toUsrName);
            NSLog(@"[WAR] send via %@ -> %@", NSStringFromSelector(sel), ok ? @"OK" : @"FAIL");
            return ok;
        }

        NSLog(@"[WAR] no SendTextMessage method on service class %@", NSStringFromClass([service class]));
        return NO;
    }
    @catch (NSException *e) {
        NSLog(@"[WAR] sendText exception: %@ - %@", e.name, e.reason);
        return NO;
    }
}

@end
