//
//  SettingBoardViewController.swift
//  CoughDetector
//
//  Created by Zhiwei Luo on 12/31/18.
//

import Foundation

import UIKit

class SettingBoardViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    @IBOutlet var eventTableView: UITableView!
    @IBOutlet var switchUpload: UISwitch!
    @IBOutlet var txtNextEventId: UITextField!
    @IBOutlet var labelRecordId: UILabel!
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return ResultManager.sharedInstance.events.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "EventCell")!
        cell.textLabel?.text = ResultManager.sharedInstance.events[indexPath.row]["filename"] as? String
        cell.textLabel?.textColor = ResultManager.sharedInstance.events[indexPath.row]["isCough"] as! Bool ? UIColor.red : UIColor.black
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        playAudioFile(filename: (tableView.cellForRow(at: indexPath)?.textLabel?.text)!)
    }
    
    @IBAction func deleteAllDocumentFiles(_ sender: Any) {
        deleteAllFiles()
    }
    
    @IBAction func switchUploadToggled(_ sender: Any) {
        if switchUpload.isOn == true {
            WebService.sharedInstance.isStartRecording = true
            
        } else {
            WebService.sharedInstance.isStartRecording = false
        }
    }
    
    @IBAction func buttonOkPressed(_ sender: Any) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func buttonUploadPressed(_ sender: Any) {
        WebService.sharedInstance.uploadAllCoughEvent()
        //ResultManager.sharedInstance.events.removeAll()
        self.eventTableView.reloadData()
    }
    
    @IBAction func buttonUpdateNextId(_ sender: Any) {
        txtNextEventId.endEditing(true)
        let defaults = UserDefaults.standard
        defaults.set(Int(txtNextEventId.text!), forKey: "nextEventId")
    }
    
    @IBAction func buttonResetRecordId(_ sender: Any) {
        let customSettingStoryboard = UIStoryboard(name: "CustomSettingStoryboard", bundle: nil)
        let validatePageViewController = customSettingStoryboard.instantiateViewController(withIdentifier: "ValidatePageViewController")
        let naviController = UIApplication.shared.keyWindow?.rootViewController as! UINavigationController
        naviController.pushViewController(validatePageViewController, animated: true)
    }
    
    override func viewDidLoad() {
        self.eventTableView.dataSource = self
        self.eventTableView.delegate = self
        txtNextEventId.text = String(UserDefaults.standard.integer(forKey: "nextEventId"))
        labelRecordId.text = "Record_id: \(UserDefaults.standard.string(forKey: "record_id")!)"
    }
}
