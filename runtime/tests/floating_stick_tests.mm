#import "KartPadFloatingStick.h"
#include <cassert>

@interface KartPadFixtureTouch : UITouch
@property(nonatomic) CGPoint fixturePoint;
@end
@implementation KartPadFixtureTouch
- (CGPoint)locationInView:(UIView *)view { (void)view; return self.fixturePoint; }
@end

int main() {
  @autoreleasepool {
    KartPadFloatingStickView *stick = [[KartPadFloatingStickView alloc]
        initWithFrame:CGRectMake(0, 0, 126, 126)];
    [stick layoutIfNeeded];
    __block float x = 99, y = 99;
    stick.valueChanged = ^(float newX, float newY) { x = newX; y = newY; };
    assert([stick pointInside:CGPointMake(-50, 70) withEvent:nil]);
    assert(![stick pointInside:CGPointMake(-200, 70) withEvent:nil]);
    KartPadFixtureTouch *first = [KartPadFixtureTouch new];
    first.fixturePoint = CGPointMake(-35, 90);
    [stick touchesBegan:[NSSet setWithObject:first] withEvent:nil];
    assert(stick.active && x == 0 && y == 0);
    KartPadFixtureTouch *second = [KartPadFixtureTouch new];
    second.fixturePoint = CGPointMake(120, 10);
    [stick touchesBegan:[NSSet setWithObject:second] withEvent:nil];
    [stick touchesEnded:[NSSet setWithObject:second] withEvent:nil];
    assert(stick.active && x == 0 && y == 0);
    first.fixturePoint = CGPointMake(28, 90);
    [stick touchesMoved:[NSSet setWithObject:first] withEvent:nil];
    assert(std::abs(x - 1) < 0.001 && y == 0);
    first.fixturePoint = CGPointMake(91, -36);
    [stick touchesMoved:[NSSet setWithObject:first] withEvent:nil];
    assert(std::abs(std::hypot(x, y) - 1) < 0.001 && x > 0 && y > 0);
    [stick touchesCancelled:[NSSet setWithObject:first] withEvent:nil];
    assert(!stick.active && x == 0 && y == 0);
    first.fixturePoint = CGPointMake(40, 40);
    [stick touchesBegan:[NSSet setWithObject:first] withEvent:nil];
    assert(stick.active && x == 0 && y == 0);
    stick.floatingEnabled = NO;
    assert(!stick.active && x == 0 && y == 0);
    assert(![stick pointInside:CGPointMake(-50, 70) withEvent:nil]);
    stick.floatingEnabled = YES;
    [stick touchesBegan:[NSSet setWithObject:first] withEvent:nil];
    stick.bounds = CGRectMake(0, 0, 172, 172);
    [stick layoutIfNeeded];
    assert(!stick.active && x == 0 && y == 0);
    puts("Floating stick pickup, ownership, axes, cancellation, editor and resize tests passed.");
  }
}
