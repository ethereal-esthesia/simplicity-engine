#include <simplicity/menu.hpp>
#include "native_check.hpp"
#import <AppKit/AppKit.h>

@interface SimplicityMenuTarget : NSObject
@property(nonatomic, copy) NSString* selected;
- (void)selectItem:(NSMenuItem*)sender;
@end
@implementation SimplicityMenuTarget
- (void)selectItem:(NSMenuItem*)sender { self.selected = sender.representedObject; }
@end

namespace simplicity {
namespace {
NSMenu* build(const std::vector<MenuItem>& entries, SimplicityMenuTarget* target) {
    NSMenu* menu = [[NSMenu alloc] initWithTitle:@""];
    menu.autoenablesItems = NO;
    for (const auto& entry : entries) {
        if (entry.kind == MenuKind::separator) { [menu addItem:NSMenuItem.separatorItem]; continue; }
        NSMenuItem* item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithUTF8String:entry.label.c_str()]
                                                   action:@selector(selectItem:) keyEquivalent:@""];
        item.target = target;
        item.representedObject = [NSString stringWithUTF8String:entry.id.c_str()];
        item.enabled = entry.enabled;
        item.state = entry.checked ? NSControlStateValueOn : NSControlStateValueOff;
        if (entry.kind == MenuKind::submenu) item.submenu = build(entry.children, target);
        [menu addItem:item];
    }
    return menu;
}
}
std::optional<std::string> showMenu(Menu& model, SDL_Window*) {
    @autoreleasepool {
        SimplicityMenuTarget* target = [SimplicityMenuTarget new];
        NSMenu* menu = build(model.items(), target);
        [menu popUpMenuPositioningItem:nil atLocation:NSEvent.mouseLocation inView:nil];
        if (target.selected) {
            std::string id(target.selected.UTF8String);
            if (model.activate(id)) return id;
        }
        return std::nullopt;
    }
}
bool detail::nativeMenuSelfTest() {
    @autoreleasepool {
        [NSApplication sharedApplication];
        auto model = nativeCheckModel();
        SimplicityMenuTarget* target = [SimplicityMenuTarget new];
        NSMenu* menu = build(model.items(), target);
        bool ok = menu.numberOfItems == 4 && [menu itemAtIndex:1].state == NSControlStateValueOn &&
            ![menu itemAtIndex:2].enabled && [menu itemAtIndex:3].submenu.numberOfItems == 2 &&
            [[menu itemAtIndex:3].submenu itemAtIndex:0].state == NSControlStateValueOn;
        [target selectItem:[menu itemAtIndex:0]];
        return ok && [target.selected isEqualToString:@"run"];
    }
}
bool nativeMenusAvailable() { return true; }
const char* menuBackend() { return "AppKit native"; }
}
