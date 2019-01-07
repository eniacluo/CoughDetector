//
//  WebService.swift
//  aurioTouch
//
//  Created by Zhiwei Luo on 5/29/18.
//

import Foundation
import UIKit
import OHMySQL

public class WebService{
    var session = URLSession()
    var user: String
    var queryContext: OHMySQLQueryContext?
    var globalCoordinator: OHMySQLStoreCoordinator?
    var nextUploadSoundName: String
    // Flag of whether time consuming process starts
    public var isStartRecording = false
    
    init() {
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration)
        user = UserDefaults.standard.string(forKey: "Username") ?? "User"
        nextUploadSoundName = "record.wav"
    }
    
    public class var sharedInstance: WebService {
        struct Singleton {
            static let instance = WebService()
        }
        return Singleton.instance
    }
    
    public func sendRealtimeData(data: UnsafeMutablePointer<Float32>?, length: Int) {
        
        var Baseurl = "http://172.22.114.74:8086/write?db=cough"
        Baseurl = Baseurl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
        let requestUrl = URL(string: Baseurl)
        let request = NSMutableURLRequest(url: requestUrl!)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        let username = "zhiwei"
        let password = "950403"
        let loginString = "\(username):\(password)"
        let authString = "Basic \(loginString.data(using: .utf8)?.base64EncodedString() ?? "")"
        
        var postString: String = ""
        let beginTime = CFAbsoluteTimeGetCurrent() + kCFAbsoluteTimeIntervalSince1970
        let interval: CFTimeInterval = 1.0 / 44100
        
        for i in 0..<length {
            let curTime = Int64((beginTime + Double(i) * interval) * 1000000000)
            postString += "realtime,location=UGA value=\(data?[i] ?? 0.0) \(curTime)\n"
        }
        request.httpBody = postString.data(using: .utf8)
        
        request.addValue(authString, forHTTPHeaderField: "Authorization")
        request.addValue(String(postString.count), forHTTPHeaderField: "Content-Length")
        
        let task = session.dataTask(with: request as URLRequest) { (data, response, error) in
            
            guard error == nil && data != nil else {
                print("Sending Error")
                return
            }
            if let httpStatus = response as? HTTPURLResponse{
                if httpStatus.statusCode != 204 {
                    print("Failed Status code = \(httpStatus.statusCode)")
                }
            }
            
        }
        task.resume()
        
    }
    
    public func setUsername(name: String?)
    {
        if let name = name {
            user = name
        }
    }
    
    public func uploadCoughEvent()
    {
        let device_id = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let username = self.user
        let time = getCurrentTimeString()
        let compactTime = getCurrentTimeCompactString()
        let latitude = LocationService.sharedInstance.getLatitude()
        let longitude = LocationService.sharedInstance.getLongitude()
        let sound_name = username + compactTime + ".wav"
        
        let globalQueue = DispatchQueue.global()
        
        //use the global queue , run in asynchronous
        globalQueue.async {
            var Baseurl = "https://redcap.ovpr.uga.edu/api/"
            Baseurl = Baseurl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let requestUrl = URL(string: Baseurl)
            var request = URLRequest(url: requestUrl!)
            request.httpMethod = "POST"
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            if let record_id = UserDefaults.standard.string(forKey: "record_id") {
                var nextEventId =  UserDefaults.standard.integer(forKey: "nextEventId")
                nextEventId += 1 // Even the first time: 0->1
                print("record_id: \(record_id), event_id: \(nextEventId)")
                let postDictRecord = [["record_id": record_id,
                     "redcap_repeat_instrument": "cough_event",
                     "redcap_repeat_instance": nextEventId,
                     "username": username,
                     "device_id": device_id,
                     "time": time,
                     "longitude": longitude,
                     "latitude": latitude,
                     "filename": sound_name,
                     "cough_event_complete": 2]]
                let jsonDataRecord = try? JSONSerialization.data(withJSONObject: postDictRecord, options: [])
                let jsonStringRecord = String(data: jsonDataRecord!, encoding: .utf8)!
                let postDictParam = ["token": "E4A94D7B2ADEEFA84A30B836DFC91354",
                                     "content": "record",
                                     "format": "json",
                                     "type": "flat",
                                     "overwriteBehavior": "normal",
                                     "forceAutoNumber": "false",
                                     "data": jsonStringRecord,
                                     "returnContent": "count",
                                     "returnFormat": "json"]
                var postString = ""
                for (key, value) in postDictParam {
                    postString += key + "=" + value + "&"
                }
                postString.removeLast()
                let postData = postString.data(using: .utf8)
                
                let task = URLSession.shared.uploadTask(with: request, from: postData) { (data, response, error) in
                    guard error == nil && data != nil else {
                        print("Sending Error")
                        return
                    }
                    if let httpStatus = response as? HTTPURLResponse
                    {
                        if httpStatus.statusCode != 200 {
                            print("1_Failed Status code = \(httpStatus.statusCode)")
                        } else {
                            print("Event uploaded.")
                            var Baseurl = "https://redcap.ovpr.uga.edu/api/"
                            Baseurl = Baseurl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                            let requestUrl = URL(string: Baseurl)
                            var request = URLRequest(url: requestUrl!)
                            request.httpMethod = "POST"
                            let boundary = "---------------------------14737809831466499882746641449"
                            request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                            request.addValue("application/json", forHTTPHeaderField: "Accept")
                            var postbody = Data()
                            let postDict = ["token": "E4A94D7B2ADEEFA84A30B836DFC91354",
                                            "content": "file",
                                            "action": "import",
                                            "record": record_id,
                                            "field": "filename",
                                            "returnFormat": "json",
                                            "repeat_instance": nextEventId] as [String : Any]
                            let postBoundary = "\r\n--\(boundary)\r\n".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                            for (key, value) in postDict {
                                postbody.append(postBoundary!)
                                if let anEncoding = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                                    postbody.append(anEncoding)
                                }
                            }
                            postbody.append(postBoundary!)
                            if let anEncoding = "Content-Disposition: form-data; name=\"file\"; filename=\"\(sound_name)\" \r\n".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                                postbody.append(anEncoding)
                            }
                            if let anEncoding = "Content-Type: audio/wav\r\n\r\n".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                                postbody.append(anEncoding)
                            }
                            if let wavData = readFileData(filename: "record.wav") {
                                postbody.append(wavData)
                            }
                            if let anEncoding = "\r\n--\(boundary)--\r\n".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                                postbody.append(anEncoding)
                            }
                            UserDefaults.standard.set(nextEventId, forKey: "nextEventId")
                            
                            let task = URLSession.shared.uploadTask(with: request, from: postbody) { (data, response, error) in
                                guard error == nil && data != nil else {
                                    print("Sending Error")
                                    return
                                }
                                if let httpStatus = response as? HTTPURLResponse
                                {
                                    if httpStatus.statusCode != 200 {
                                        print("2_Failed Status code = \(httpStatus.statusCode)")
                                    } else {
                                        print("File uploaded.")
                                    }
                                }
                            }
                            task.resume()
                        }
                    }
                }
                task.resume()
            }
        }
    }
    
    public func uploadAllCoughEvent()
    {
        let device_id = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let username = UserDefaults.standard.string(forKey: "Username") ?? "User"
        
        let globalQueue = DispatchQueue.global()
        
        //use the global queue , run in asynchronous
        globalQueue.async {
            var Baseurl = "https://redcap.ovpr.uga.edu/api/"
            Baseurl = Baseurl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let requestUrl = URL(string: Baseurl)
            var request = URLRequest(url: requestUrl!)
            request.httpMethod = "POST"
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            if let record_id = UserDefaults.standard.string(forKey: "record_id") {
                let nextEventId =  UserDefaults.standard.integer(forKey: "nextEventId")
                // record_id is person-dependent
                // nextEventId is a counter to upload cough event
                let eventsToUpload = ResultManager.sharedInstance.events
                let eventUploadCount = eventsToUpload.count
                // eventUploadCount is #events needed to be uploaded this time
                var postDictRecord = [[String: Any]]()
                for i in 0..<eventUploadCount {
                    let eventId = i + nextEventId + 1
                    print("record_id: \(record_id), event_id: \(eventId)")
                    postDictRecord.append(["record_id": record_id,
                                           "redcap_repeat_instrument": "cough_event",
                                           "redcap_repeat_instance": eventId,
                                           "username": username,
                                           "device_id": device_id,
                                           "time": eventsToUpload[i]["time"]!,
                                           "longitude": eventsToUpload[i]["longitude"]!,
                                           "latitude": eventsToUpload[i]["latitude"]!,
                                           "filename": eventsToUpload[i]["filename"]!,
                                           "iscough": eventsToUpload[i]["isCough"]! as! Bool ? 1 : 0,
                                           "cough_event_complete": 2])
                }
                let jsonDataRecord = try? JSONSerialization.data(withJSONObject: postDictRecord, options: [])
                let jsonStringRecord = String(data: jsonDataRecord!, encoding: .utf8)!
                let postDictParam = ["token": "E4A94D7B2ADEEFA84A30B836DFC91354",
                                     "content": "record",
                                     "format": "json",
                                     "type": "flat",
                                     "overwriteBehavior": "normal",
                                     "forceAutoNumber": "false",
                                     "data": jsonStringRecord,
                                     "returnContent": "count",
                                     "returnFormat": "json"]
                var postString = ""
                for (key, value) in postDictParam {
                    postString += key + "=" + value + "&"
                }
                postString.removeLast() // remove last '&'
                let postData = postString.data(using: .utf8)
                
                let task = URLSession.shared.uploadTask(with: request, from: postData) { (data, response, error) in
                    guard error == nil && data != nil else {
                        print("Sending Error")
                        return
                    }
                    if let httpStatus = response as? HTTPURLResponse
                    {
                        if httpStatus.statusCode != 200 {
                            print("1_Failed Status code = \(httpStatus.statusCode)")
                        } else {
                            print("Event uploaded.")
                            let semaphore = DispatchSemaphore(value: 0)
                            for i in 0..<eventUploadCount {
                                let eventId = i + nextEventId + 1
                                var Baseurl = "https://redcap.ovpr.uga.edu/api/"
                                Baseurl = Baseurl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
                                let requestUrl = URL(string: Baseurl)
                                var request = URLRequest(url: requestUrl!)
                                request.httpMethod = "POST"
                                let boundary = "---------------------------14737809831466499882746641449"
                                request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
                                request.addValue("application/json", forHTTPHeaderField: "Accept")
                                var postbody = Data()
                                let postDict = ["token": "E4A94D7B2ADEEFA84A30B836DFC91354",
                                                "content": "file",
                                                "action": "import",
                                                "record": record_id,
                                                "field": "filename",
                                                "returnFormat": "json",
                                                "repeat_instance": eventId] as [String : Any]
                                let postBoundary = "\r\n--\(boundary)\r\n".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
                                for (key, value) in postDict {
                                    postbody.append(postBoundary!)
                                    if let anEncoding = "Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                                        postbody.append(anEncoding)
                                    }
                                }
                                postbody.append(postBoundary!)
                                let sound_name = eventsToUpload[i]["filename"]! as! String
                                if let anEncoding = "Content-Disposition: form-data; name=\"file\"; filename=\"\(sound_name)\" \r\n".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                                    postbody.append(anEncoding)
                                }
                                if let anEncoding = "Content-Type: audio/wav\r\n\r\n".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                                    postbody.append(anEncoding)
                                }
                                if let wavData = readFileData(filename: sound_name) {
                                    postbody.append(wavData)
                                }
                                if let anEncoding = "\r\n--\(boundary)--\r\n".data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue)) {
                                    postbody.append(anEncoding)
                                }
                                
                                let task = URLSession.shared.uploadTask(with: request, from: postbody) { (data, response, error) in
                                    guard error == nil && data != nil else {
                                        print("Sending Error")
                                        return
                                    }
                                    if let httpStatus = response as? HTTPURLResponse
                                    {
                                        if httpStatus.statusCode != 200 {
                                            print("2_Failed Status code = \(httpStatus.statusCode)")
                                        } else {
                                            print("File \(eventId) uploaded.")
                                            semaphore.signal() // increment semaphore
                                        }
                                    }
                                }
                                task.resume()
                                _ = semaphore.wait(timeout: DispatchTime(uptimeNanoseconds: 2000000000))
                                // decrement semaphore
                            }
                            ResultManager.sharedInstance.events.removeAll()
                            UserDefaults.standard.set(nextEventId + eventUploadCount, forKey: "nextEventId")
                        }
                    }
                }
                task.resume()
            }
        }
    }
    
    
    public func validateRecordId(RecordId: String, completionHandler: @escaping (_ recordInfo: [[String: Any]]) -> ())
    {
        let globalQueue = DispatchQueue.global()
        
        //use the global queue , run in asynchronous
        globalQueue.async {
            var Baseurl = "https://redcap.ovpr.uga.edu/api/"
            Baseurl = Baseurl.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            let requestUrl = URL(string: Baseurl)
            var request = URLRequest(url: requestUrl!)
            request.httpMethod = "POST"
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.addValue("application/json", forHTTPHeaderField: "Accept")
            
            let queryString = "token=E4A94D7B2ADEEFA84A30B836DFC91354&content=record&format=json&type=flat&records[0]=\(RecordId)&fields[0]=name&fields[1]=email&rawOrLabel=raw&rawOrLabelHeaders=raw&exportCheckboxLabel=false&exportSurveyFields=false&exportDataAccessGroups=false&returnFormat=json"
            // return [{"name":"username","email":"xxx@yyy.com"}]
            
            let queryData = queryString.data(using: .utf8)
            
            let task = URLSession.shared.uploadTask(with: request, from: queryData) { (data, response, error) in
                guard error == nil && data != nil else {
                    print("Sending Error")
                    return
                }
                if let httpStatus = response as? HTTPURLResponse, let data = data
                {
                    if httpStatus.statusCode != 200 {
                        print("Failed Status code = \(httpStatus.statusCode)")
                    } else {
                        do {
                            if let recordInfoDict = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                                completionHandler(recordInfoDict)
                            }
                        } catch {
                            print(error.localizedDescription)
                        }
                    }
                }
            }
            task.resume()
        }
    }
    
    public func uploadRawSound()
    {
        //upload file to FTP Server
        var configuration = SessionConfiguration()
        configuration.host = "35.196.184.211:21"
        configuration.username = "ftpuser"
        configuration.password = "sensorweb"
        configuration.encoding = String.Encoding.utf8
        configuration.passive = false
        let _session = Session(configuration: configuration)
        let URL = getFileURL(filename: "record.wav")
        let path = "/var/ftp/cough/" + nextUploadSoundName
        _session.upload(URL, path: path) {
            (result, error) -> Void in
                print("Upload file with result:\n\(result), error: \(error)\n\n")
        }
    }
}
