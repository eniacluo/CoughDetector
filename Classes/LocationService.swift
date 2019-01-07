//
//  LocationService.swift
//  CoughDetector
//
//  Created by Zhiwei Luo on 10/10/18.
//

import Foundation
import CoreLocation
import UIKit

class LocationService: NSObject, CLLocationManagerDelegate {
    
    var isConfigured: Bool = false
    let locationManager = CLLocationManager()
    var timerUpdateLocation: Timer!
    var isLocationLocked: Bool = false
    var lastLocation: CLLocationCoordinate2D?
    let updateLocationTimeInterval: TimeInterval = 60 * 10.0
    
    public class var sharedInstance: LocationService {
        struct Singleton {
            static let instance = LocationService()
        }
        return Singleton.instance
    }
    
    public func configureLocationManager()
    {
        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()
        
        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            self.locationManager.delegate = self
            self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            self.locationManager.startUpdatingLocation()
        }
        self.isConfigured = true
        self.updateLocation()
        
        if #available(iOS 10.0, *) {
            DispatchQueue.main.async {
                self.timerUpdateLocation = Timer.scheduledTimer(withTimeInterval: self.updateLocationTimeInterval, repeats: true){_ in
                    self.updateLocation()
                }
            }
        } else {
            DispatchQueue.main.async {
                self.timerUpdateLocation = Timer.scheduledTimer(timeInterval: self.updateLocationTimeInterval, target: self, selector: #selector(self.updateLocation), userInfo: nil, repeats: true)
            }
        }
        
    }
    
    @objc private func updateLocation()
    {
        guard let locValue: CLLocationCoordinate2D = self.locationManager.location?.coordinate else { return }
        self.lastLocation = locValue
        print("cur loc: \(locValue.latitude) \(locValue.longitude)")
    }
    
    public func getLatitude() -> String
    {
        if let location = lastLocation {
            return String(format:"%.3f", location.latitude)
        } else {
            return ""
        }
    }
    
    public func getLongitude() -> String
    {
        if let location = lastLocation {
            return String(format:"%.3f", location.longitude)
        } else {
            return ""
        }
    }
}

