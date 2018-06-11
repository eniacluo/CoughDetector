//
//  BufferManager.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/30.
//
//
/*

 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 This class handles buffering of audio data that is shared between the view and audio controller

 */

import AudioToolbox
import libkern
import AVFoundation
import Accelerate


let kNumDrawBuffers = 12
let kDefaultDrawSamples = 1024
let kDefaultFilterSamples = 32768
let kFilterWindowShiftLength = 16384
let kMaxCoefficients = 128
let kNumFrameBuffers = 16
let kDefaultFrameSamples = 1024
let kDelayBufferCount = 16

class BufferManager {
    
    var displayMode: AudioController.aurioTouchDisplayMode
    
    // Flag of whether time consuming process starts
    var isStartSession = false
    
    //for draw Buffer
    private(set) var drawBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Float32>?>
    var currentDrawBufferLength: Int
    private var mDrawBufferIndex: Int
    
    //for FFT Buffer
    private var mFFTInputBuffer: UnsafeMutablePointer<Float32>?
    private var mFFTInputBufferFrameIndex: Int
    private var mFFTInputBufferLen: Int
    var FFTOutputBufferLength: Int {return mFFTInputBufferLen / 2}
    private var mHasNewFFTData: Int32   //volatile
    private var mNeedsNewFFTData: Int32 //volatile
    private var mNeedsNewFilterData: Int32  //volatile
    var hasNewFFTData: Bool {return mHasNewFFTData != 0}
    var needsNewFFTData: Bool {return mNeedsNewFFTData != 0}
    var needsNewFilterData: Bool {return mNeedsNewFilterData != 0}
    
    //for Cough Filter Buffer
    private var filterBuffer: UnsafeMutablePointer<Float32>?
    private var mFilterBufferIndex: Int
    var xcorr_coeff: Float = 0.0
    private(set) var filterCoefficients: UnsafeMutablePointer<Float32>?
    
    //for sending data to database
    private var sendingBuffer: UnsafeMutablePointer<Float32>?
    var isSendingRealtimeData:Bool = false;
    var sendingCount = 0;
    
    //for HMM Buffer
    private(set) var frameBuffers: UnsafeMutablePointer<UnsafeMutablePointer<Float32>?>
    private var mFrameBufferIndex: Int
    private var mFrameSampleIndex: Int
    var backgroundSigma: Float = 0.01
    var startBufferIndex = 0
    var isStartSound = false
    private(set) var MFCCBuffers: UnsafeMutablePointer<Float32>?
    var recentResult = "SILENCE"
    var delayIndex = 0
    
    private var mDSPHelper: DSPHelper
    
    init(maxFramesPerSlice inMaxFramesPerSlice: Int) {//4096
        displayMode = .spectrum
        drawBuffers = UnsafeMutablePointer.allocate(capacity: Int(kNumDrawBuffers))
        frameBuffers = UnsafeMutablePointer.allocate(capacity: Int(kNumFrameBuffers))
        mDrawBufferIndex = 0
        mFilterBufferIndex = 0
        mFrameBufferIndex = 0
        mFrameSampleIndex = 0
        currentDrawBufferLength = kDefaultDrawSamples
        mFFTInputBuffer = nil
        mFFTInputBufferFrameIndex = 0
        mFFTInputBufferLen = inMaxFramesPerSlice
        mHasNewFFTData = 0
        mNeedsNewFFTData = 0
        mNeedsNewFilterData = 0
        for i in 0..<kNumDrawBuffers {
            drawBuffers[Int(i)] = UnsafeMutablePointer.allocate(capacity: Int(inMaxFramesPerSlice))
        }
        for i in 0..<kNumFrameBuffers {
            frameBuffers[Int(i)] = UnsafeMutablePointer.allocate(capacity: Int(kDefaultFrameSamples))
        }
        filterCoefficients = UnsafeMutablePointer.allocate(capacity: Int(kMaxCoefficients))
        bzero(filterCoefficients, Int(kMaxCoefficients) * MemoryLayout<Float32>.size)
        mFFTInputBuffer = UnsafeMutablePointer.allocate(capacity: Int(inMaxFramesPerSlice))
        filterBuffer = UnsafeMutablePointer.allocate(capacity: Int(kDefaultFilterSamples))
        
        
        mDSPHelper = DSPHelper(maxFramesPerSlice: inMaxFramesPerSlice)
        OSAtomicIncrement32Barrier(&mNeedsNewFFTData)
        OSAtomicIncrement32Barrier(&mNeedsNewFilterData)
    }
    
    
    deinit {
        for i in 0..<kNumDrawBuffers {
            drawBuffers[Int(i)]?.deallocate()
            drawBuffers[Int(i)] = nil
        }
        drawBuffers.deallocate()
        
        mFFTInputBuffer?.deallocate()
        
        filterBuffer?.deallocate()
        filterCoefficients?.deallocate()
        
        for i in 0..<kNumFrameBuffers {
            frameBuffers[Int(i)]?.deallocate()
            frameBuffers[Int(i)] = nil
        }
        frameBuffers.deallocate()

    }
    
    
    func copyAudioDataToDrawBuffer(_ inData: UnsafePointer<Float32>?, inNumFrames: Int) {
        if inData == nil { return }
        
        for i in 0..<inNumFrames {//256
            if i + mDrawBufferIndex >= currentDrawBufferLength {//1024
                cycleDrawBuffers()//always put new data into <Buffer 0> cycle: n->n+1
                mDrawBufferIndex = -i//concat buffer data with next one
            }
            drawBuffers[0]?[i + mDrawBufferIndex] = (inData?[i])!
        }
        mDrawBufferIndex += inNumFrames
    }
    
    func cycleDrawBuffers() {
        // Cycle the lines in our draw buffer so that they age and fade. The oldest line is discarded.
        for drawBuffer_i in stride(from: (kNumDrawBuffers - 2), through: 0, by: -1) {
            memmove(drawBuffers[drawBuffer_i + 1], drawBuffers[drawBuffer_i], size_t(currentDrawBufferLength))
        }
    }
    
    func copyAudioDataToFilterBuffer(_ inData: UnsafePointer<Float32>?, inNumFrames: Int) {
        if inData == nil { return }
        
        for i in 0..<inNumFrames {
            if i + mFilterBufferIndex >= kDefaultFilterSamples {
                cycleFilterBuffer()//always put new data into tail part
                mFilterBufferIndex -= kFilterWindowShiftLength//concat buffer data with next one
            }
            filterBuffer?[i + mFilterBufferIndex] = (inData?[i])!
        }
        mFilterBufferIndex += inNumFrames
    }
    
    func cycleFilterBuffer() {
        // Cycle the lines in our filter buffer to move the window of data instead of moving filter.
        memmove(&filterBuffer![0], &filterBuffer![kFilterWindowShiftLength], size_t((kDefaultFilterSamples - kFilterWindowShiftLength) * MemoryLayout<Float32>.size))
    }
    
    func getFilterOutput(_ filter: UnsafePointer<Float32>?, _ filterLength: Int) {
        if mNeedsNewFilterData != 0 {
            for i in stride(from: (kMaxCoefficients - 2), through: 0, by: -1) {
                memcpy(&filterCoefficients![i + 1], &filterCoefficients![i], MemoryLayout<Float32>.size)
            }
            mDSPHelper.xcorr(filterBuffer, inAudioLength: kDefaultFilterSamples, filter: filter, filterLength: filterLength, outCoefficient: &xcorr_coeff)
            filterCoefficients?[0] = xcorr_coeff
        }
    }
    
    func CopyAudioDataToFFTInputBuffer(_ inData: UnsafePointer<Float32>, numFrames: Int) {
        let framesToCopy = min(numFrames, mFFTInputBufferLen - mFFTInputBufferFrameIndex)
        memcpy(mFFTInputBuffer?.advanced(by: mFFTInputBufferFrameIndex), inData, size_t(framesToCopy * MemoryLayout<Float32>.size))
        mFFTInputBufferFrameIndex += framesToCopy * MemoryLayout<Float32>.size
        if mFFTInputBufferFrameIndex >= mFFTInputBufferLen {
            OSAtomicIncrement32(&mHasNewFFTData)
            OSAtomicDecrement32(&mNeedsNewFFTData)
        }
    }
    
    func GetFFTOutput(_ outFFTData: UnsafeMutablePointer<Float32>) {
        mDSPHelper.computeFFT(mFFTInputBuffer, outFFTData: outFFTData)
        mFFTInputBufferFrameIndex = 0
        OSAtomicDecrement32Barrier(&mHasNewFFTData)
        OSAtomicIncrement32Barrier(&mNeedsNewFFTData)
    }
    
    func copyAudioDataToSendingBuffer(_ inData: UnsafePointer<Float32>?, inNumFrames: Int) {
        if inData == nil { return }
        
        if isSendingRealtimeData == true {
            sendingBuffer = UnsafeMutablePointer.allocate(capacity: inNumFrames)
            memcpy(sendingBuffer, inData, size_t(inNumFrames * MemoryLayout<Float32>.size))
            sendingCount += 1
            WebService.sharedInstance.sendData(data: sendingBuffer, length: inNumFrames)
            sendingBuffer?.deallocate()
        }
        
    }
    
    func sendRealtimeData() {
        //isSendingRealtimeData = true
        //sendingCount = 0
        /*
        if sendingCount == 0 {
            //writeFile(str: "", filename: "")
            writeAudioFile(pcmBuffer: filterBuffer, frameCount: kDefaultFilterSamples, filename: "record.wav")
            sendingCount += 1
            return
        }
        if sendingCount == 1 {
            playAudioFile(filename: "record.wav")
            sendingCount = 0
        }
         */
        
    }
    
    func stopSendingRealtimeData() {
        isSendingRealtimeData = false
        //listFiles()
        
        
        
        //deleteAllFiles()
        //getFileSize(filename: "record.mfc")
    }
    
    func copyAudioDataToFrameBuffer(_ inData: UnsafePointer<Float32>?, inNumFrames: Int) {
        if inData == nil { return }
        
        for i in 0..<inNumFrames {//256
            if i + mFrameSampleIndex >= kDefaultFrameSamples {//1024
                mFrameSampleIndex = 0//concat buffer data with next one
                let outVar: UnsafeMutablePointer<Float32> = UnsafeMutablePointer.allocate(capacity: 1)
                vDSP_rmsqv(frameBuffers[mFrameBufferIndex]!, 1, outVar, vDSP_Length(kDefaultFrameSamples))
                if outVar.pointee > 3 * backgroundSigma && isStartSound == false {
                    isStartSound = true
                    startBufferIndex = mFrameBufferIndex
                } else if (outVar.pointee < backgroundSigma || (mFrameBufferIndex + 1) % kNumFrameBuffers == startBufferIndex) && isStartSound == true {
                    // satisfy one of the following two conditions:
                    // 1. the variance is less than 1*sigma_background
                    // 2. the length is greater than 16*1024/44100=370ms
                    
                    isStartSound = false
                    let copyBufferCount = ((mFrameBufferIndex - startBufferIndex + kNumFrameBuffers) % kNumFrameBuffers + 1)
                    MFCCBuffers = UnsafeMutablePointer.allocate(capacity: copyBufferCount * kDefaultFrameSamples)
                    var copyMFCCSampleIndex = 0
                    for i in startBufferIndex..<startBufferIndex + copyBufferCount {
                        memcpy(MFCCBuffers?.advanced(by: copyMFCCSampleIndex * kDefaultFrameSamples), frameBuffers[i % kNumFrameBuffers], size_t(kDefaultFrameSamples * MemoryLayout<Float32>.size))
                        copyMFCCSampleIndex += 1
                    }
                    writeAudioFile(pcmBuffer: MFCCBuffers, frameCount: copyBufferCount * kDefaultFrameSamples, filename: "record.wav")
                    
                    createMFCCFile(wavFilename: "record.wav")
                    getHMMResult(wavFilename: "record.wav")
                    
                    let result = (readFile(filename: "result.txt") ?? "no result")
                    if result.contains("COUGH") {
                        recentResult = "COUGH"
                        delayIndex = kDelayBufferCount
                    } else {
                        recentResult = "NON-COUGH"
                        delayIndex = kDelayBufferCount
                    }
                    MFCCBuffers?.deallocate()
                }
                if delayIndex > 0 {
                    delayIndex -= 1
                    if delayIndex == 0 {
                        recentResult = "SILENCE"
                    }
                }
 
                outVar.deallocate()
 
                mFrameBufferIndex = (mFrameBufferIndex + 1) % kNumFrameBuffers
            }
            frameBuffers[mFrameBufferIndex]?[i + mFrameSampleIndex] = (inData?[i])!
        }
        mFrameSampleIndex += inNumFrames
    }
    
}
