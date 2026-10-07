TARGET = iphone:clang:16.5:14.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = WeChatAutoReply

WeChatAutoReply_FILES = Tweak.x \
	WARRule.mm \
	WARMessageSender.mm \
	WARContactStore.mm \
	WARSettingsVC.mm \
	WARRuleEditVC.mm \
	WARPickerVC.mm

WeChatAutoReply_FRAMEWORKS = UIKit Foundation
WeChatAutoReply_CFLAGS = -fobjc-arc -Wno-unused-variable -Wno-unused-function -Wno-objc-designated-initializers

include $(THEOS_MAKE_PATH)/tweak.mk
