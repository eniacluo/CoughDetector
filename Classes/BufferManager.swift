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


let kNumDrawBuffers = 12
let kDefaultDrawSamples = 1024
let kDefaultFilterSamples = 32768
let kFilterWindowLength = 16384
let kMaxCoefficients = 128

class BufferManager {
    
    var displayMode: AudioController.aurioTouchDisplayMode
    
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
    
    private var mDSPHelper: DSPHelper
    
    init(maxFramesPerSlice inMaxFramesPerSlice: Int) {//4096
        displayMode = .spectrum
        drawBuffers = UnsafeMutablePointer.allocate(capacity: Int(kNumDrawBuffers))
        mDrawBufferIndex = 0
        mFilterBufferIndex = 0
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
        filterCoefficients = UnsafeMutablePointer.allocate(capacity: Int(kMaxCoefficients))
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
                mFilterBufferIndex -= kFilterWindowLength//concat buffer data with next one
            }
            filterBuffer?[i + mFilterBufferIndex] = (inData?[i])!
        }
        mFilterBufferIndex += inNumFrames
    }
    
    func saveAudioDataToFile() {

        let url = URL(fileURLWithPath: String("Documents/record.wav"))
        let SAMPLE_RATE =  Float64(44100.0)
        
        let outputFormatSettings = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            //  AVLinearPCMIsBigEndianKey: false,
            AVSampleRateKey: SAMPLE_RATE,
            AVNumberOfChannelsKey: 1
            ] as [String : Any]
        
        let audioFile = try? AVAudioFile(forWriting: url, settings: outputFormatSettings, commonFormat: AVAudioCommonFormat.pcmFormatFloat32, interleaved: true)
        
        let bufferFormat = AVAudioFormat(settings: outputFormatSettings)
        
        let outputBuffer = AVAudioPCMBuffer(pcmFormat: bufferFormat!, frameCapacity: AVAudioFrameCount(kDefaultFilterSamples))
        
        // i had my samples in doubles, so convert then write
        
        for i in 0..<kDefaultFilterSamples {
            outputBuffer?.floatChannelData!.pointee[i] = Float( filterBuffer![i] )
        }
        outputBuffer?.frameLength = AVAudioFrameCount(kDefaultFilterSamples)
        
        do{
            try audioFile?.write(from: outputBuffer!)
            
        } catch let error as NSError {
            print("error:", error.localizedDescription)
        }
    }
    
    func cycleFilterBuffer() {
        // Cycle the lines in our filter buffer to move the window of data instead of moving filter.
        memmove(&filterBuffer![0], &filterBuffer![kFilterWindowLength], size_t((kDefaultFilterSamples - kFilterWindowLength) * MemoryLayout<Float32>.size))
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
}
