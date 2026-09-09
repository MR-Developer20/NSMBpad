#pragma once

#import <UIKit/UIKit.h>
#include <algorithm>
#include <cmath>

// Narrow interface to the immutable SunPad control. KartPad owns the new
// behavior without changing the pinned overlay used by the other ports.
@interface SunPadStickView : UIView
@property(nonatomic, copy) void (^valueChanged)(float x, float y);
@property(nonatomic, readonly) BOOL active;
- (void)applyBaseColor:(UIColor *)baseColor thumbColor:(UIColor *)thumbColor;
- (void)reset;
@end

@interface KartPadFloatingStickView : SunPadStickView
@property(nonatomic, assign) BOOL floatingEnabled;
- (void)refreshPresentation;
@end

@implementation KartPadFloatingStickView {
  NSArray<UIView *> *_fixedArtwork;
  UIView *_disc;
  UIView *_thumb;
  UIColor *_baseColor;
  UITouch *_ownedTouch;
  CGPoint _anchor;
  CGPoint _axis;
}
@synthesize floatingEnabled = _floatingEnabled;

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    _fixedArtwork = self.subviews.copy;
    _floatingEnabled = YES;
    _disc = [UIView new];
    _disc.userInteractionEnabled = NO;
    _disc.layer.borderWidth = 2.0;
    _disc.layer.borderColor = [UIColor colorWithWhite:1 alpha:0.68].CGColor;
    _thumb = [UIView new];
    [_disc addSubview:_thumb];
    [self addSubview:_disc];
    [self refreshPresentation];
  }
  return self;
}

- (void)applyBaseColor:(UIColor *)baseColor thumbColor:(UIColor *)thumbColor {
  [super applyBaseColor:baseColor thumbColor:thumbColor];
  _baseColor = baseColor;
  _disc.backgroundColor = baseColor;
  _thumb.backgroundColor = thumbColor;
  [self refreshPresentation];
}

- (void)setFloatingEnabled:(BOOL)enabled {
  if (_floatingEnabled != enabled) [self reset];
  _floatingEnabled = enabled;
  [self refreshPresentation];
}

- (BOOL)active { return _floatingEnabled ? _ownedTouch != nil : super.active; }

- (void)refreshPresentation {
  self.backgroundColor = _floatingEnabled ? UIColor.clearColor : _baseColor;
  if (_floatingEnabled) self.layer.borderWidth = 0;
  for (UIView *artwork in _fixedArtwork) artwork.hidden = _floatingEnabled;
  _disc.hidden = !_floatingEnabled || _ownedTouch == nil;
  CGFloat side = MIN(self.bounds.size.width, self.bounds.size.height);
  _disc.bounds = CGRectMake(0, 0, side, side);
  _disc.center = _anchor;
  _disc.layer.cornerRadius = side * 0.5;
  CGFloat thumb = side * 0.42;
  _thumb.bounds = CGRectMake(0, 0, thumb, thumb);
  _thumb.layer.cornerRadius = thumb * 0.5;
  CGFloat travel = MAX(0, (side - thumb) * 0.5 - 4);
  _thumb.center = CGPointMake(side * 0.5 + _axis.x * travel,
                              side * 0.5 - _axis.y * travel);
}

- (void)layoutSubviews {
  [super layoutSubviews];
  // Rotation/resizing must not carry an old steering value into a new surface.
  if (_ownedTouch != nil) [self reset];
  [self refreshPresentation];
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
  if (!_floatingEnabled) return [super pointInside:point withEvent:event];
  // A generous pickup zone around the editable resting position. Buttons
  // above this view keep normal hit-test priority; an owned touch stays owned.
  return CGRectContainsPoint(CGRectInset(self.bounds,
      -self.bounds.size.width * 0.65, -self.bounds.size.height * 0.45), point);
}

- (void)reset {
  _ownedTouch = nil;
  _axis = CGPointZero;
  [super reset];
  [self refreshPresentation];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  if (!_floatingEnabled) { [super touchesBegan:touches withEvent:event]; return; }
  if (_ownedTouch != nil) return;
  _ownedTouch = touches.anyObject;
  _anchor = [_ownedTouch locationInView:self];
  _axis = CGPointZero;
  if (self.valueChanged) self.valueChanged(0, 0);
  [self refreshPresentation];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  if (!_floatingEnabled) { [super touchesMoved:touches withEvent:event]; return; }
  if (_ownedTouch == nil || ![touches containsObject:_ownedTouch]) return;
  CGPoint point = [_ownedTouch locationInView:self];
  CGFloat radius = MAX(1, MIN(self.bounds.size.width, self.bounds.size.height) * 0.5);
  CGFloat x = (point.x - _anchor.x) / radius;
  CGFloat y = (_anchor.y - point.y) / radius;
  CGFloat length = MAX(1, hypot(x, y));
  _axis = CGPointMake(x / length, y / length);
  if (self.valueChanged) self.valueChanged(_axis.x, _axis.y);
  [self refreshPresentation];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  if (!_floatingEnabled) { [super touchesEnded:touches withEvent:event]; return; }
  if (_ownedTouch != nil && [touches containsObject:_ownedTouch]) [self reset];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  if (!_floatingEnabled) { [super touchesCancelled:touches withEvent:event]; return; }
  if (_ownedTouch != nil && [touches containsObject:_ownedTouch]) [self reset];
}
@end
