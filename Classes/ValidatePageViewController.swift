//
//  ValidatePageViewController.swift
//  CoughDetector
//
//  Created by Zhiwei Luo on 11/20/18.
//

import Foundation
import UIKit

class ValidatePageViewController: UIViewController{
    
    @IBOutlet var txtRecordId: UITextField!
    @IBOutlet var txtName: UITextField!
    @IBOutlet var txtEmail: UITextField!
    @IBOutlet var labelName: UILabel!
    @IBOutlet var labelEmail: UILabel!
    @IBOutlet var labelInforming: UILabel!
    @IBOutlet var buttonOk: UIButton!
    @IBOutlet var buttonCancel: UIButton!
    
    @IBAction func buttonCancelClick(_ sender: Any) {
        clearView()
    }
    
    @IBAction func buttonOkClick(_ sender: UIButton) {
        self.navigationController?.popViewController(animated: true)
        UserDefaults.standard.set(true, forKey: "isNotFirstRun")
        UserDefaults.standard.set(txtRecordId.text, forKey: "record_id")
    }
    
    @IBAction func buttonValidateClick(_ sender: UIButton) {
        txtRecordId.endEditing(true)
        let alert = UIAlertController(title: nil, message: "Please Wait...", preferredStyle: .alert)
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
        loadingIndicator.startAnimating();
        
        alert.view.addSubview(loadingIndicator)
        present(alert, animated: true, completion: nil)
        WebService.sharedInstance.validateRecordId(RecordId: self.txtRecordId.text!) {
            recordInfo in // Async way: when get the result
            guard recordInfo.count > 0 else {
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                    self.clearView()
                }
                return
            }
            DispatchQueue.main.async {
                // Update UI from background thread
                self.labelName.isHidden = false
                self.labelEmail.isHidden = false
                self.txtName.isHidden = false
                self.txtEmail.isHidden = false
                self.labelInforming.isHidden = false
                self.buttonOk.isHidden = false
                self.buttonCancel.isHidden = false
                self.txtName.text = recordInfo[0]["name"]! as? String
                self.txtEmail.text = recordInfo[0]["email"]! as? String
                self.dismiss(animated: true, completion: nil)
            }
        }
        
    }
    
    func clearView()
    {
        txtRecordId.text = ""
        txtRecordId.endEditing(true)
        labelName.isHidden = true
        labelEmail.isHidden = true
        txtName.isHidden = true
        txtEmail.isHidden = true
        labelInforming.isHidden = true
        buttonOk.isHidden = true
        buttonCancel.isHidden = true
        txtName.text = ""
        txtEmail.text = ""
    }
    
    @IBAction func buttonClearClick(_ sender: UIButton) {
        clearView()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }
}
