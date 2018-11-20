//
//  ResultManager.swift
//  CoughDetector
//
//  Created by Zhiwei Luo on 10/25/18.
//

import Foundation

class ResultManager: NSObject {
    
    public var latestResultForDisplay = "SILENCE"

    public var delayIndex = 0
    public var eventCount = 0;
    public var eventString: String!
    public var eventTime = [String]()
    
    public class var sharedInstance: ResultManager {
        struct Singleton {
            static let instance = ResultManager()
        }
        return Singleton.instance
    }

    public func prepareResultForDisplay() {
        delayIndex = kDelayBufferCount
        if latestResultForDisplay == "COUGH" {
            eventString = "Cough Event:"
            let currentTime = getCurrentTimeString()
            eventTime.append(currentTime)
            for i in 0...eventCount
            {
                if i > eventCount - 5 {
                    eventString = "\(eventString!)\n #\(i+1): \(eventTime[i])"
                }
            }
            eventCount += 1
        }
    }

    public func freezeResult() {
        if delayIndex > 0 {
            delayIndex -= 1
            if delayIndex == 0 {
                latestResultForDisplay = "SILENCE"
            }
        }
    }
    
    public func uploadResultToServer()
    {
        if WebService.sharedInstance.isStartRecording {
            WebService.sharedInstance.uploadCoughEvent()
            //WebService.sharedInstance.uploadRawSound()
        }
    }

}
