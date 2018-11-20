//
//  FFTHelper.swift
//  aurioTouch
//
//  Translated by OOPer in cooperation with shlab.jp, on 2015/1/30.
//
//
/*

 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information

 Abstract:
 This class demonstrates how to use the Accelerate framework to take Fast Fourier Transforms (FFT) of the audio data. FFTs are used to perform analysis on the captured audio data

 */


import Accelerate


class DSPHelper {
    
    private var mSpectrumAnalysis: FFTSetup?
    private var mDspSplitComplex: DSPSplitComplex
    private var mFFTNormFactor: Float32
    private var mFFTLength: vDSP_Length
    private var mLog2N: vDSP_Length
    public var backgroundSigma: Float = 0.01
    
    private final var kAdjust0DB: Float32 = 1.5849e-13
    
    init(maxFramesPerSlice inMaxFramesPerSlice: Int) {
        mSpectrumAnalysis = nil
        mFFTNormFactor = 1.0/Float32(2*inMaxFramesPerSlice)
        mFFTLength = vDSP_Length(inMaxFramesPerSlice)/2
        mLog2N = vDSP_Length(log2Ceil(UInt32(inMaxFramesPerSlice)))
        mDspSplitComplex = DSPSplitComplex(
            realp: UnsafeMutablePointer.allocate(capacity: Int(mFFTLength)),
            imagp: UnsafeMutablePointer.allocate(capacity: Int(mFFTLength))
        )
        mSpectrumAnalysis = vDSP_create_fftsetup(mLog2N, FFTRadix(kFFTRadix2))
    }
    
    
    deinit {
        vDSP_destroy_fftsetup(mSpectrumAnalysis)
        mDspSplitComplex.realp.deallocate()
        mDspSplitComplex.imagp.deallocate()
    }
    
    
    func computeFFT(_ inAudioData: UnsafePointer<Float32>?, outFFTData: UnsafeMutablePointer<Float32>?) {
        guard
            let inAudioData = inAudioData,
            let outFFTData = outFFTData
        else { return }
        
        //Generate a split complex vector from the real data
        inAudioData.withMemoryRebound(to: DSPComplex.self, capacity: Int(mFFTLength)) {inAudioDataPtr in
            vDSP_ctoz(inAudioDataPtr, 2, &mDspSplitComplex, 1, mFFTLength)
        }
        
        //Take the fft and scale appropriately
        vDSP_fft_zrip(mSpectrumAnalysis!, &mDspSplitComplex, 1, mLog2N, FFTDirection(kFFTDirection_Forward))
        vDSP_vsmul(mDspSplitComplex.realp, 1, &mFFTNormFactor, mDspSplitComplex.realp, 1, mFFTLength)
        vDSP_vsmul(mDspSplitComplex.imagp, 1, &mFFTNormFactor, mDspSplitComplex.imagp, 1, mFFTLength)
        
        //Zero out the nyquist value
        mDspSplitComplex.imagp[0] = 0.0
        
        //Convert the fft data to dB
        vDSP_zvmags(&mDspSplitComplex, 1, outFFTData, 1, mFFTLength)
        
        //In order to avoid taking log10 of zero, an adjusting factor is added in to make the minimum value equal -128dB
        vDSP_vsadd(outFFTData, 1, &kAdjust0DB, outFFTData, 1, mFFTLength)
        var one: Float32 = 1
        vDSP_vdbcon(outFFTData, 1, &one, outFFTData, 1, mFFTLength, 0)
    }

    func isChangingPointStarted(_ frameBuffer: UnsafePointer<Float32>?) -> Bool {
        let outVar: UnsafeMutablePointer<Float32> = UnsafeMutablePointer.allocate(capacity: 1)
        // calculating the moving window variance to do changing point detection to segment
        vDSP_rmsqv(frameBuffer!, 1, outVar, vDSP_Length(kDefaultFrameSamples))
        let currentSoundSigma = outVar.pointee
        outVar.deallocate()

        return currentSoundSigma > 3 * backgroundSigma ? true : false
    }
    
    func isChangingPointEnded(_ frameBuffer: UnsafePointer<Float32>?) -> Bool {
        let outVar: UnsafeMutablePointer<Float32> = UnsafeMutablePointer.allocate(capacity: 1)
        // calculating the moving window variance to do changing point detection to segment
        vDSP_rmsqv(frameBuffer!, 1, outVar, vDSP_Length(kDefaultFrameSamples))
        let currentSoundSigma = outVar.pointee
        outVar.deallocate()
        
        return currentSoundSigma < 1 * backgroundSigma ? true : false
    }
    
    func generateCoughDetectionResult() {
        createMFCCFile(wavFilename: "record.wav")
        getHMMResult(wavFilename: "record.wav")
        
        // If HMM Viterbi results are successful obtained, put the recognition result. Once refreshed in View, the result will display on screen
        let result = (readFile(filename: "result.txt") ?? "no result")
        let resultManager = ResultManager.sharedInstance
        if result != "no result" {
            if result.contains("NON-COUGH") {
                resultManager.latestResultForDisplay = "NON-COUGH"
            } else {
                resultManager.latestResultForDisplay = "COUGH"
            }
            resultManager.prepareResultForDisplay()
            resultManager.uploadResultToServer()
        }
    }
}
