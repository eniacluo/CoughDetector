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
    // Flag of whether time consuming process starts
    public var isStartRecording = false
    
    init() {
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration)
        user = "User"
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
    
    public func initMySQLConnection()
    {
        let globalQueue = DispatchQueue.global()
            
        //use the global queue , run in asynchronous
        globalQueue.async {
            let user = OHMySQLUser(userName: "root", password: "sensorweb", serverName: "35.196.184.211", dbName: "cough_detection", port: 3306, socket: "/Applications/MAMP/tmp/mysql/mysql.sock")
            let coordinator = OHMySQLStoreCoordinator(user: user!)
            coordinator.encoding = .UTF8MB4
            coordinator.connect()
            self.globalCoordinator = coordinator
            let context = OHMySQLQueryContext()
            context.storeCoordinator = coordinator
            self.queryContext = context
        }
    }
    
    public func closeMySQLConnection()
    {
        let globalQueue = DispatchQueue.global()
        
        //use the global queue , run in asynchronous
        globalQueue.async {
            self.globalCoordinator?.disconnect()
        }
    }
    
    public func uploadCoughEvent()
    {
        let device_id = UIDevice.current.identifierForVendor?.uuidString
        let username = self.user
        let time = getCurrentTimeString()
        let label = "COUGH"
        let sound_name = MD5(string: username + device_id! + time).base64EncodedString() + ".wav"
        let SQLRequest = "INSERT INTO record (name, device_id, time, label, sound_name) VALUES ('\(username)', '\(device_id!)', curTime(), '\(label)', '\(sound_name)');"
        
        let globalQueue = DispatchQueue.global()
        
        //use the global queue , run in asynchronous
        globalQueue.async {
            let coughEventInsertionQuery = OHMySQLQueryRequest(queryString: SQLRequest)
            try? self.queryContext?.execute(coughEventInsertionQuery)
        }
        
    }
    
    public func uploadRawSound()
    {
        // upload file to FTP Server
//        var configuration = SessionConfiguration()
//        configuration.host = "35.196.184.211:21"
//        configuration.username = "ftpuser"
//        configuration.password = "sensorweb"
//        configuration.encoding = String.Encoding.utf8
//        let _session = Session(configuration: configuration)
//        _session.list("/") {
//            (resources, error) -> Void in
//            print("List directory with result:\n\(resources), error: \(error)\n\n")
//        }
    }
}
