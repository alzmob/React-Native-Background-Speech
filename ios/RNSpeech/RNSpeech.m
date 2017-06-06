//
//  RNSpeech.m
//  RNSpeech
//
//  Created by Alex on 6/5/17.
//  Copyright © 2017 Alex. All rights reserved.
//

#import "RNSpeech.h"
#import <React/RCTUtils.h>
#import <React/RCTBridge.h>
#import <React/RCTEventDispatcher.h>

@interface RNSpeech () {
    SFSpeechRecognizer *speechRecognizer;
    SFSpeechAudioBufferRecognitionRequest *recognitionRequest;
    SFSpeechRecognitionTask *recognitionTask;
    AVAudioEngine *audioEngine;
}

@property (nonatomic, weak, readwrite) RCTBridge *bridge;

@end

@implementation RNSpeech

RCT_EXPORT_MODULE()

RCT_EXPORT_METHOD(startSpeech) {
    [self callSpeech];
}

-(void)callSpeech {
    speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:[[NSLocale alloc] initWithLocaleIdentifier:@"en_US"]];
    
    speechRecognizer.delegate = self;
    
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
                NSLog(@"Authorized");
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied:
                NSLog(@"Denied");
                break;
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                NSLog(@"Not Determined");
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted:
                NSLog(@"Restricted");
                break;
            default:
                break;
        }
    }];
    
    if (audioEngine.isRunning) {
        [audioEngine stop];
        [recognitionRequest endAudio];
        [self startListening];
    } else {
        [self startListening];
    }
}

- (void)startListening {
    
    // Initialize the AVAudioEngine
    audioEngine = [[AVAudioEngine alloc] init];
    
    // Make sure there's not a recognition task already running
    if (recognitionTask) {
        [recognitionTask cancel];
        recognitionTask = nil;
    }
    
    // Starts an AVAudio Session
    NSError *error;
    AVAudioSession *audioSession = [AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryRecord error:&error];
    if (error != nil) {
        return;
    }
    [audioSession setMode:AVAudioSessionModeMeasurement error:&error];
    if (error != nil) {
        return;
    }
    [audioSession setActive:YES withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    if (error != nil) {
        return;
    }
    
    // Starts a recognition process, in the block it logs the input or stops the audio
    // process if there's an error.
    recognitionRequest = [[SFSpeechAudioBufferRecognitionRequest alloc] init];
    if (recognitionRequest == nil){
        return;
    }
    if (audioEngine == nil) {
        audioEngine = [[AVAudioEngine alloc] init];
    }
    AVAudioInputNode *inputNode = audioEngine.inputNode;
    if (inputNode == nil) {
        return;
    }
    
    recognitionRequest.shouldReportPartialResults = YES;
    recognitionTask = [speechRecognizer recognitionTaskWithRequest:recognitionRequest resultHandler:^(SFSpeechRecognitionResult * _Nullable result, NSError * _Nullable error) {
        BOOL isFinal = NO;
        
        if (error != nil) {
            return;
        }
        
        if (result) {
            // Whatever you say in the microphone after pressing the button should be being logged
            // in the console.
            NSLog(@"RESULT:%@",result.bestTranscription.formattedString);
            isFinal = !result.isFinal;
            NSString *spokenText = [result.bestTranscription.formattedString lowercaseString];
            if ([spokenText containsString:@"next"]) {
                spokenText = @"next";
                [self stopSpeech:spokenText];
            } else if ([spokenText containsString:@"back"]) {
                spokenText = @"back";
                [self stopSpeech:spokenText];
            } else if ([spokenText containsString:@"yes"]) {
                spokenText = @"yes";
                [self stopSpeech:spokenText];
            } else if ([spokenText containsString:@"no"]) {
                spokenText = @"no";
                [self stopSpeech:spokenText];
            } else if ([spokenText containsString:@"repeat"]) {
                spokenText = @"repeat";
                [self stopSpeech:spokenText];
            } else if ([spokenText containsString:@"start"]) {
                spokenText = @"start";
                [self stopSpeech:spokenText];
            } else if ([spokenText containsString:@"restart"]) {
                spokenText = @"restart";
                [self stopSpeech:spokenText];
            } else if ([spokenText containsString:@"stop"]) {
                spokenText = @"stop";
                [self stopSpeech:spokenText];
            }
            
        }
        if (error) {
            [audioEngine stop];
            [inputNode removeTapOnBus:0];
            recognitionRequest = nil;
            recognitionTask = nil;
        }
    }];
    
    // Sets the recording format
    AVAudioFormat *recordingFormat = [inputNode outputFormatForBus:0];
    [inputNode installTapOnBus:0 bufferSize:1024 format:recordingFormat block:^(AVAudioPCMBuffer * _Nonnull buffer, AVAudioTime * _Nonnull when) {
        if (recognitionRequest != nil) {
            [recognitionRequest appendAudioPCMBuffer:buffer];
        }
    }];
    
    // Starts the audio engine, i.e. it starts listening.
    [audioEngine prepare];
    [audioEngine startAndReturnError:&error];
    
    if (error != nil) {
        return;
    }
    
    NSLog(@"Say Something, I'm listening");
}

-(void)stopSpeech:(NSString *)txt {
    [audioEngine stop];
    [recognitionRequest endAudio];

    [self.bridge.eventDispatcher sendAppEventWithName:@"RNSpeech" body:txt];
}

#pragma mark - SFSpeechRecognizerDelegate Delegate Methods

- (void)speechRecognizer:(SFSpeechRecognizer *)speechRecognizer availabilityDidChange:(BOOL)available {
    NSLog(@"Availability:%d",available);
}

@end