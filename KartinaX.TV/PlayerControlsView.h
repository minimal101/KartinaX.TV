//
//  PlayerControlsView.h
//  JKSMoviePlayer
//
//  Created by Johan Sørensen on 8/22/12.
//  Copyright (c) 2012 Johan Sørensen. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface PlayerControlsView : NSView
@property (strong) NSButton *playPauseButton;
@property (strong) NSSlider *timeSlider;
@property (strong) NSTextField *timeLabel;
@property (strong) NSButton *epgButton;

- (void)setPlaying:(BOOL)flag;
@end