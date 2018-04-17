//
//  ConfigViewController.swift
//  ssvpn
//
//  Created by Loren on 2018/4/13.
//  Copyright © 2018年 Loren. All rights reserved.
//

import UIKit
import NetworkExtension

protocol SSVPNConfigDelegate {
    func SSVPNConfigFinish(obj:SSVPNPropertyObject?) -> Void
}
public func stringIsEmty(str:String?) -> Bool {
    return (str?.count == 0)
}
class ConfigViewController: UIViewController , SSVPNConfigDelegate , UITextFieldDelegate{
    func SSVPNConfigFinish(obj: SSVPNPropertyObject?) {
    }

    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var portLabel: UILabel!
    @IBOutlet weak var methodLabel: UILabel!
    @IBOutlet weak var passwdLabel: UILabel!
    @IBOutlet weak var dnsLabel: UILabel!
    @IBOutlet weak var addressTextfiled: UITextField!
    @IBOutlet weak var portTextFiled: UITextField!
    @IBOutlet weak var methodTextFiled: UITextField!
    @IBOutlet weak var passwdTextFiled: UITextField!
    @IBOutlet weak var dnsTextFiled: UITextField!
    @IBOutlet weak var saveButton: UIButton!
    
    open var delegate : SSVPNConfigDelegate?
    
    var sapceHeight = 30.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.layoutUI()
        self.layoutConfig()
    }
    @objc func close(sender: Any) {
        self.view.window?.resignFirstResponder()
        self.dismiss(animated: true) {
            
        }
    }
    @IBAction func saveAction(_ sender: Any) {
        let address = addressTextfiled.text
        let port = portTextFiled.text
        let method = methodTextFiled.text
        let passwd = passwdTextFiled.text
//        let dns = dnsTextFiled.text
        
        if stringIsEmty(str: address) {
            self.showAlertMsd(message: "地址为空"); return
        }
        if stringIsEmty(str: port) {
            self.showAlertMsd(message: "端口为空"); return
        }
        if stringIsEmty(str: method) {
            self.showAlertMsd(message: "加密方式为空"); return
        }
        if stringIsEmty(str: passwd) {
            self.showAlertMsd(message: "密码为空"); return
        }
//        if stringIsEmty(str: dns) {
//            self.showAlertMsd(message: "dns为空"); return
//        }
        var type : SSVPNEncryptionType?
        switch method {
            case "AES128CFB"? :
            type = .AES128CFB
            break
        case "AES192CFB"? :
            type = .AES192CFB
            break
        case "AES256CFB"?:
            type = .AES256CFB
            break
        case "CHACHA20"?:
            type = .CHACHA20
            break
        case "SALSA20"?:
            type = .SALSA20
            break
        case "RC4MD5"?:
            type = .RC4MD5
            break
        default:
            type = .AES256CFB
        }
        let object = SSVPNPropertyObject.init(address: address!, port: port!, method: type!, passwd: passwd!, config: nil)
        
        if (delegate != nil){
            delegate?.SSVPNConfigFinish(obj: object)
        }
        self.dismiss(animated: true, completion: {
            //nothing
        })
    }
    func layoutConfig() -> Void {
        SSVPNManager.manager.loadAllFromPreferences { (managers, error) in
            if managers?.first != nil {
                let protocolConfiguration = managers?.first?.protocolConfiguration as! NETunnelProviderProtocol
                let config = protocolConfiguration.providerConfiguration
                let address = config?["address"] as? String
                let port    = config?["port"] as? String
                let method  = config?["method"] as? String
                let passwd  = config?["passwd"] as? String
                
                self.addressTextfiled.text = address
                self.portTextFiled.text = port
                self.methodTextFiled.text = method ?? "AES256CFB"
                self.passwdTextFiled.text = passwd
                self.dnsTextFiled.text = "8.8.8.8"
            }
        }
    }
    func layoutUI(){
        self.title = "配置页面"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "保存", style: UIBarButtonItemStyle.done, target: self, action: #selector(saveAction(_:)))
        self.navigationItem.leftBarButtonItem = UIBarButtonItem.init(title: "关闭", style: UIBarButtonItemStyle.done, target: self, action: #selector(close(sender:)))

        self.addressLabel.ss_origin_y = 120
        self.portLabel.ss_origin_y = self.addressLabel.ss_bottom_y + CGFloat(self.sapceHeight)
        self.methodLabel.ss_origin_y = self.portLabel.ss_bottom_y + CGFloat(self.sapceHeight)
        self.passwdLabel.ss_origin_y = self.methodLabel.ss_bottom_y + CGFloat(self.sapceHeight)
        self.dnsLabel.ss_origin_y = self.passwdLabel.ss_bottom_y + CGFloat(self.sapceHeight)
        
        self.addressTextfiled.ss_center_y   = self.addressLabel.ss_center_y
        self.portTextFiled.ss_center_y      = self.portLabel.ss_center_y
        self.methodTextFiled.ss_center_y    = self.methodLabel.ss_center_y
        self.passwdTextFiled.ss_center_y    = self.passwdLabel.ss_center_y
        self.dnsTextFiled.ss_center_y       = self.dnsLabel.ss_center_y
        
        let leftSpace = self.methodLabel.ss_bottom_x + CGFloat(10.0)
        self.addressTextfiled.ss_origin_x   = leftSpace
        self.portTextFiled.ss_origin_x      = leftSpace
        self.methodTextFiled.ss_origin_x    = leftSpace
        self.passwdTextFiled.ss_origin_x    = leftSpace
        self.dnsTextFiled.ss_origin_x       = leftSpace
        
        let width     = self.view.ss_size_w - leftSpace - 10
        self.addressTextfiled.ss_size_w   = width
        self.portTextFiled.ss_size_w      = width
        self.methodTextFiled.ss_size_w    = width
        self.passwdTextFiled.ss_size_w    = width
        self.dnsTextFiled.ss_size_w       = width
        
        self.addressTextfiled.delegate = self
        self.portTextFiled.delegate = self
        self.methodTextFiled.delegate = self
        self.passwdTextFiled.delegate = self
        self.dnsTextFiled.delegate = self
        
        self.dnsTextFiled.isHidden = true
        self.dnsLabel.isHidden = true
        self.saveButton.isHidden = true
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    func showAlertMsd(message:String) -> Void {
        var v  = UIAlertView.init(title: "SSVPN", message: message, delegate: nil, cancelButtonTitle: "确定")
        v.show()
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
extension UIView {
    var ss_origin_y : CGFloat {
        set {
            var rect = self.frame
            rect.origin.y = CGFloat(newValue)
            self.frame = rect
        }
        get {
            return CGFloat(self.frame.origin.y)
        }
    }
    var ss_origin_x : CGFloat {
        set {
            var rect = self.frame
            rect.origin.x = CGFloat(newValue)
            self.frame = rect
        }
        get {
            return CGFloat(self.frame.origin.x)
        }
    }
    var ss_size_w : CGFloat {
        set {
            var rect = self.frame
            rect.size.width = CGFloat(newValue)
            self.frame = rect
        }
        get {
            return CGFloat(self.frame.size.width)
        }
    }
    var ss_size_h : CGFloat {
        set {
            var rect = self.frame
            rect.size.height = CGFloat(newValue)
            self.frame = rect
        }
        get {
            return CGFloat(self.frame.size.height)
        }
    }
    
    var ss_bottom_y : CGFloat {
        set {
            var rect = self.frame
            rect.origin.y = CGFloat(newValue - self.ss_size_h)
            self.frame = rect
        }
        get {
            return CGFloat(self.frame.origin.y + self.ss_size_h)
        }
    }
    var ss_bottom_x : CGFloat {
        set {
            var rect = self.frame
            rect.origin.x = CGFloat(newValue - self.ss_size_w)
            self.frame = rect
        }
        get {
            return CGFloat(self.ss_origin_x + self.ss_size_w)
        }
    }
    var ss_center_x : CGFloat {
        set {
            var center = self.center
            center.x = CGFloat(newValue)
            self.center = center
        }
        get {
            return CGFloat(self.center.x)
        }
    }
    var ss_center_y : CGFloat {
        set {
            var center = self.center
            center.y = CGFloat(newValue)
            self.center = center
        }
        get {
            return CGFloat(self.center.y)
        }
    }
}
