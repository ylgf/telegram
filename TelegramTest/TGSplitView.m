//
//  TGSplitView.m
//  TelegramModern
//
//  Created by keepcoder on 24.06.15.
//  Copyright (c) 2015 telegram. All rights reserved.
//

#import "TGSplitView.h"

@interface TGSplitView ()
{
    NSMutableDictionary *_proportions;
    NSMutableDictionary *_startSize;
    TGView *_containerView;
    NSMutableArray *_controllers;
    BOOL _isSingleLayout;
    NSMutableDictionary *_layoutProportions;
}
@end

@implementation TGSplitView

-(instancetype)initWithFrame:(NSRect)frameRect {
    if(self = [super initWithFrame:frameRect]) {
        _proportions = [[NSMutableDictionary alloc] init];
        _controllers = [[NSMutableArray alloc] init];
        _startSize = [[NSMutableDictionary alloc] init];
        _layoutProportions = [[NSMutableDictionary alloc] init];
        
        _containerView = [[TGView alloc] initWithFrame:self.bounds];
        _containerView.autoresizingMask = self.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        self.autoresizesSubviews = YES;
        [self addSubview:_containerView];
        
        _state = TGSplitViewStateDualLayout;
        
    }
    
    return self;
}

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    
}

-(void)addController:(TGViewController *)controller proportion:(struct TGSplitProportion)proportion {
    
    assert([NSThread isMainThread] && controller.view.superview == nil);
    
    
    [_containerView addSubview:controller.view];
    
    [_controllers addObject:controller];
    
    _startSize[controller.internalId] = [NSValue valueWithSize:controller.view.frame.size];
    
    NSValue *encodeProportion = [NSValue valueWithBytes:&proportion objCType:@encode(struct TGSplitProportion)];
    
    _proportions[controller.internalId] = encodeProportion;
    
}


-(void)update {
    [self setFrameSize:self.frame.size];
}

-(void)setFrameSize:(NSSize)newSize {
    [super setFrameSize:newSize];
    
    
    struct TGSplitProportion singleLayout = {0,0};
    struct TGSplitProportion dualLayout = {0,0};
    struct TGSplitProportion tripleLayout = {0,0};
    
    [_layoutProportions[@(TGSplitViewStateSingleLayout)] getValue:&singleLayout];
    [_layoutProportions[@(TGSplitViewStateDualLayout)] getValue:&dualLayout];
    [_layoutProportions[@(TGSplitViewStateTripleLayout)] getValue:&tripleLayout];
    
    
    if(isAcceptLayout(singleLayout)) {
        if(_state != TGSplitViewStateSingleLayout && NSWidth(_containerView.frame) < singleLayout.max )
            self.state = TGSplitViewStateSingleLayout;
        
        if(isAcceptLayout(dualLayout)) {
            if(isAcceptLayout(tripleLayout)) {
                if(_state != TGSplitViewStateDualLayout && NSWidth(_containerView.frame) > dualLayout.min && NSWidth(_containerView.frame) < tripleLayout.min)
                    self.state = TGSplitViewStateDualLayout;
                else
                    self.state = TGSplitViewStateTripleLayout;
            } else
                if(_state != TGSplitViewStateDualLayout && NSWidth(_containerView.frame) > dualLayout.min)
                    self.state = TGSplitViewStateDualLayout;
        }
    }
    
    __block NSUInteger x = 0;
    
    [_controllers enumerateObjectsUsingBlock:^(TGViewController<TGSplitViewDelegate> *obj, NSUInteger idx, BOOL *stop) {
        
        struct TGSplitProportion proportion;
        
        [_proportions[obj.internalId] getValue:&proportion];
        
        NSSize startSize = [_startSize[obj.internalId] sizeValue];
        
        
        NSSize size = NSMakeSize(x, NSHeight(_containerView.frame));
        
        
        int min = startSize.width;
        
        if(startSize.width < proportion.min)
        {
            min = proportion.min;
        } else if(startSize.width > proportion.max)
        {
            min = NSWidth(_containerView.frame) - x;
            
        }
        
        if(idx == _controllers.count - 1)
            min = NSWidth(_containerView.frame) - x;
        
        size = NSMakeSize(x + min > NSWidth(_containerView.frame) ? (NSWidth(_containerView.frame) - x) : min, NSHeight(_containerView.frame));
        
        NSRect rect = NSMakeRect(x, 0, size.width, size.height);
        
        if(!NSEqualRects(rect, obj.view.frame))
            [obj splitViewDidNeedResizeController:rect];
        
        x+=size.width;
        
    }];
    
  
    
}

bool isAcceptLayout(struct TGSplitProportion prop) {
    return prop.min != 0 && prop.max != 0;
}

-(void)setState:(TGSplitViewState)state {
    
    BOOL notify = state != _state;
    
    _state = state;
    
    assert(notify);
    
    if(notify) {
        
        [_delegate splitViewDidNeedSwapToLayout:_state];
        
    }
    
}

-(void)removeController:(TGViewController *)controller {
    NSUInteger idx = [_controllers indexOfObject:controller];
    
    assert([NSThread isMainThread]);
    
    if(idx != NSNotFound) {
        [_containerView.subviews[idx] removeFromSuperview];
        [_controllers removeObjectAtIndex:idx];
        [_startSize removeObjectForKey:controller.internalId];
        [_proportions removeObjectForKey:controller.internalId];
    }
    
    [self updateConstraintsForSubtreeIfNeeded];
    
}

-(void)removeAllControllers {
    [_containerView removeAllSubviews];
    [_controllers removeAllObjects];
    [_startSize removeAllObjects];
    [_proportions removeAllObjects];
}

-(void)setProportion:(struct TGSplitProportion)proportion forState:(TGSplitViewState)state {
    _layoutProportions[@(state)] = [NSValue valueWithBytes:&proportion objCType:@encode(struct TGSplitProportion)];
}


-(BOOL)wantsDefaultClipping {
    return NO;
}


@end
