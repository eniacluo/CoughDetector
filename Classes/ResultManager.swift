//
//  ResultManager.swift
//  CoughDetector
//
//  Created by Zhiwei Luo on 10/25/18.
//

import Foundation
import UIKit

class ResultManager: NSObject {
    
    public var latestResultForDisplay = "SILENCE"

    public var delayIndex = 0
    public var eventCount = 0;
    public var eventString: String!
    public var eventTime = [String]()
    public var events = [[String: Any]]()
    var timerUpload: Timer!
    let uploadTimeInterval: TimeInterval = 5 * 60.0
    //var reachability: Reachability!
    
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
    
    public func addNewCoughEvent(isCough: Bool) {
        let time = getCurrentTimeString()
        let compactTime = getCurrentTimeCompactString()
        let latitude = LocationService.sharedInstance.getLatitude()
        let longitude = LocationService.sharedInstance.getLongitude()
        let username = UserDefaults.standard.string(forKey: "Username") ?? "User"
        let sound_name = username + compactTime + ".wav"
        
        renameFile(fileFrom: "record.wav", fileTo: sound_name)
        
        let newEvent = ["time": time,
                     "latitude": latitude,
                     "longitude": longitude,
                     "filename": sound_name,
                     "isCough": isCough] as [String : Any]
        events.append(newEvent)
        
        // The first Time when new Cough Event happens, start to upload per hour in Wifi
        if timerUpload == nil {
            
            if #available(iOS 10.0, *) {
                DispatchQueue.main.async {
                    self.timerUpload = Timer.scheduledTimer(withTimeInterval: self.uploadTimeInterval, repeats: true){_ in
                        self.uploadResultToServer()
                    }
                }
            } else {
                DispatchQueue.main.async {
                    self.timerUpload = Timer.scheduledTimer(timeInterval: self.uploadTimeInterval, target: self, selector: #selector(self.uploadResultToServer), userInfo: nil, repeats: true)
                }
            }
        }
    }
    
    @objc public func uploadResultToServer()
    {
        if(Reachability.isConnectedToWifi()) {
            WebService.sharedInstance.uploadAllCoughEvent()
        } else {
            print("Not in Wifi")
        }
        //if WebService.sharedInstance.isStartRecording {
            //WebService.sharedInstance.uploadCoughEvent()
            //WebService.sharedInstance.uploadRawSound()
        //}
    }

}
