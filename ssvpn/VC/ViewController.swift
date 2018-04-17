//
//  ViewController.swift
//  ssvpn
//
//  Created by Loren on 2018/4/12.
//  Copyright © 2018年 Loren. All rights reserved.
//

import UIKit
import NetworkExtension

public func logHelper(baseString:String, appendString:String?) -> String {
    if appendString?.count == 0 {
        return baseString
    }
    return baseString + String.init(format: "%@-log:", Date() as CVarArg) + appendString! + "\n"
}

class ViewController: UIViewController{
    

    @IBOutlet weak var connect_b: UIButton!
    @IBOutlet weak var log_textv: UITextView!
    
    var log = "SSVPN log --------------------\n"
    
    var object : SSVPNPropertyObject?
    
    var connectStatus : NEVPNStatus?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.log_textv.text = log
        //添加监听
        self.addObserver()
        //获取状态
        SSVPNManager.manager.checkAndBulidProfile { (manager, error) in
            self.connectStatus = manager?.connection.status
        }
        
        self.title = "SSVPN"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem.init(title: "配置", style: UIBarButtonItemStyle.done, target: self, action: #selector(configAction(_:)))
        
    }
    
    @objc func configAction(_ sender: Any) {
        let storyboard = UIStoryboard.init(name: "Main", bundle: Bundle.main)
        let v = storyboard.instantiateViewController(withIdentifier: "ConfigViewController") as! ConfigViewController
        v.delegate = self
        self.present(UINavigationController.init(rootViewController: v), animated: true) {
            
        }
    }
    @IBAction func buttonAction(_ sender: Any) {
        if self.connectStatus == .connected {
            self.disconnect()
        }
        else if self.connectStatus == .disconnected {
            self.connect()
        }
        else if self.connectStatus == nil {
            self.creatVPNPrefile()
        }
    }
    
    func disconnect() -> Void {
        SSVPNManager.manager.disconnectVPN { (error) in
            if error != nil {
                NSLog("%@", (error! as NSError).userInfo)
            }
            else {
                NSLog("%@", "断开成功")
            }
        }
    }
    func connect() -> Void {
//        SSVPNManager.manager.vpnObj = SSVPNPropertyObject.init(address: "8.9.8.78", port: "8888", method:SSVPNEncryptionType.AES256CFB, passwd: "hyl946", config: SSVPNPropertyObject.defaultRule())
//
        SSVPNManager.manager.checkAvailableProfile { (isOk) in
            if isOk {
                SSVPNManager.manager.connectVPN { (error) in
                    if error != nil {
                        let errorInfo = (error! as NSError).userInfo
                        NSLog("哎呀 出错了 errorInfo---->%@", errorInfo )
                    }
                }
            }
            else {
                NSLog("%@", "出错喽")
            }
        }
    }

    func creatVPNPrefile() {
        SSVPNManager.manager.vpnObj = SSVPNPropertyObject.init(address: "8.9.8.78", port: "8888", method:SSVPNEncryptionType.AES256CFB, passwd: "hyl946", config: SSVPNPropertyObject.defaultRule())
        SSVPNManager.manager.checkAndBulidProfile { (manager, error) in
            if error != nil {
                NSLog("%@", "出错了")
            }
            else {
                NSLog("%@", "YES")
            }
        }
    }
    func addObserver() {
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: SSVPNManagerStatusUpdate), object: nil, queue: OperationQueue.main) { (notification) in
            let session = notification.object as! NETunnelProviderSession
            self.connectStatus = session.status
            self.connect_b.isEnabled = true
            switch session.status {
            case .invalid :
                self.connect_b.setTitle("invalid", for: UIControlState.normal)
                self.connect_b.isEnabled = false
                self.showLog(appendString: "invalid")
                break
            case .connected:
                self.connect_b.setTitle("connected", for: UIControlState.normal)
                self.showLog(appendString: "connected")
                break
            case .connecting:
                self.connect_b.setTitle("connecting", for: UIControlState.normal)
                self.connect_b.isEnabled = false
                self.showLog(appendString: "connecting")
                break
            case .disconnected:
                self.connect_b.setTitle("disconnected", for: UIControlState.normal)
                self.showLog(appendString: "disconnected")
                break
            case .disconnecting:
                self.connect_b.setTitle("disconnecting", for: UIControlState.normal)
                self.connect_b.isEnabled = false
                self.showLog(appendString: "disconnecting")
                break
            case .reasserting:
                self.connect_b.setTitle("reasserting", for: UIControlState.normal)
                self.connect_b.isEnabled = false
                self.showLog(appendString: "reasserting")
                break
            }
        }
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: SSVPNManagerLogUpdate), object: nil, queue: OperationQueue.main) { (notification) in
            let logString = notification.object as? String
            self.showLog(appendString: logString)
        }
    }
    func showLog(appendString:String?) -> Void {
        self.log = logHelper(baseString: self.log, appendString: appendString)
        self.log_textv.text = self.log
        self.log_textv.scrollRangeToVisible(NSMakeRange(self.log.count, 1))
    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

}

extension ViewController :SSVPNConfigDelegate{
    func SSVPNConfigFinish(obj: SSVPNPropertyObject?) {
        if obj != nil {
            self.object = obj
            SSVPNManager.manager.updateProfile(obj: self.object!, completionHandler: { (error2) in
                if error2 == nil {
                    //yes
                    self.showLog(appendString: "配置文件更新完毕")
                    SSVPNManager.manager.testping()
                }
                //else NO
            })
//            //先删掉旧的
//            SSVPNManager.manager.delAllVPNPrefile(completionHandler: { (error1) in
//                if error1 == nil {
//                    //再添加新的
//                    SSVPNManager.manager.updateProfile(obj: self.object!, completionHandler: { (error2) in
//                        if error2 == nil {
//                            //yes
//                            self.showLog(appendString: "配置文件添加完毕")
//                            SSVPNManager.manager.testping()
//                        }
//                        //else NO
//                    })
//                }
//                //else NO
//            })
        }
    }
}
