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
    }
    
    public func getLatitude() -> String
    {
        guard let locValue: CLLocationCoordinate2D = self.locationManager.location?.coordinate else { return ""}
        return String(format:"%.3f", locValue.latitude)
    }
    
    public func getLongitude() -> String
    {
        guard let locValue: CLLocationCoordinate2D = self.locationManager.location?.coordinate else { return ""}
        return String(format:"%.3f", locValue.longitude)
    }
}

