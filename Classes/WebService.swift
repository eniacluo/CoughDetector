//
//  WebService.swift
//  aurioTouch
//
//  Created by Zhiwei Luo on 5/29/18.
//

import Foundation

public class WebService{
    var session = URLSession()
    init() {
        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration)
    }
    public class var sharedInstance: WebService {
        struct Singleton {
            static let instance = WebService()
        }
        return Singleton.instance
    }
    
    public func sendData(data: UnsafeMutablePointer<Float32>?, length: Int) {
        
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
}
