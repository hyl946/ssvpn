//
//  SSVPNManager.swift
//  ssvpn
//
//  Created by Loren on 2018/4/12.
//  Copyright © 2018年 Loren. All rights reserved.
//

import UIKit
import NetworkExtension

public var SSVPNManagerLogUpdate = "SSVPNManagerLogUpdate"
public var SSVPNManagerStatusUpdate = "SSVPNManagerStatusUpdate"

public enum SSVPNManagerConnectStatus : Int {
    
    /*! @const NEVPNStatusInvalid The VPN is not configured. */
    case invalid
    
    /*! @const NEVPNStatusDisconnected The VPN is disconnected. */
    case disconnected
    
    /*! @const NEVPNStatusConnecting The VPN is connecting. */
    case connecting
    
    /*! @const NEVPNStatusConnected The VPN is connected. */
    case connected
    
    /*! @const NEVPNStatusReasserting The VPN is reconnecting following loss of underlying network connectivity. */
    case reasserting
    
    /*! @const NEVPNStatusDisconnecting The VPN is disconnecting. */
    case disconnecting
}
//不支持ssr订阅，ssr为shadowsrock内部协议，格式为ssr:// 加密为base64
public class SSVPNManager: NSObject {
    static let manager = SSVPNManager()
   
    var log = ""
    var vpnObj : SSVPNPropertyObject?
    
    var pinger : SimplePing?
    
    var sendDate : Date?
    
    var sendCount : Int?
    
    var sendTimer : Timer?
    
    
    private var config = false
    
    var isConfig: Bool {
        get {
            return config
        }
    } //是否有配置
    
    private override init() {
        super.init()
        log.append("log:----------------start-------------------")
        self.loadConfig()
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNConfigurationChange, object: nil, queue: OperationQueue.main) { (notification) in
            print(NSNotification.Name.NEVPNConfigurationChange)

        };
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NEDNSProxyConfigurationDidChange, object: nil, queue: OperationQueue.main) { (notification) in
            print(NSNotification.Name.NEDNSProxyConfigurationDidChange)

        };
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NEFilterConfigurationDidChange, object: nil, queue: OperationQueue.main) { (notification) in
            print(NSNotification.Name.NEFilterConfigurationDidChange)

        };
        NotificationCenter.default.addObserver(forName: NSNotification.Name.NEVPNStatusDidChange, object: nil, queue: OperationQueue.main) { (notification) in
            
            NotificationCenter.default.post(name: NSNotification.Name(rawValue: SSVPNManagerStatusUpdate), object: notification.object)
        };
    }
    
    //
    func loadConfig() -> Void {
        self.loadAllFromPreferences { (managers, error) in
            self.config = managers?.count != 0
            //日志-----
            let str = self.config ? "配置文件已存在" : "配置文件不存在"
            self.appendAndPostNotification(appendString: str)
        }
    }
    
    func connectVPN(completionHandler:@escaping ((Error?) -> Void)) -> Void {
        //检查有没有可用的配置
        self.checkAvailableProfile { (isAvailable) in
            if isAvailable {
                //如果有就去获取一个对象
                self.checkAndBulidProfile { (manager, error1) in
                    self.appendAndPostNotification(appendString: String.init(format: "开始链接"))
                    //连接
                    do {
                        try manager?.connection.startVPNTunnel(options: [:])
                    }
                    catch let err{
                        self.appendAndPostNotification(appendString: String.init(format: "链接出错 error=%@",(err as NSError).userInfo))
                        completionHandler(err)
                    }
                }
            }
            //没有的话 报错 配置没有连个蛋蛋啊
            else {
                let error = NSError.init(domain: "domain", code: 99999, userInfo: ["userInfo":"没有配置文件啊啊啊啊啊啊啊啊"])
                completionHandler(error);
            }
        }

    }
    func disconnectVPN(completionHandler:@escaping ((Error?) -> Void)) -> Void{
        self.checkAvailableProfile { (isAvailable) in
            if isAvailable {
                //如果有就去获取一个对象
                self.checkAndBulidProfile { (manager, error1) in
                    //断开连接
                    manager?.connection.stopVPNTunnel()
                    self.appendAndPostNotification(appendString: String.init(format: "断开链接"))
                }
            }
                //没有的话 报错 配置没有连个蛋蛋啊
            else {
                let error = NSError.init(domain: "domain", code: 99999, userInfo: ["userInfo":"没有配置文件啊啊啊啊啊啊啊啊"])
                completionHandler(error);
            }
        }
    }
    //更新配置文件
    func updateProfile(obj:SSVPNPropertyObject, completionHandler:@escaping ((Error?)->Void)) -> Void {
        self.vpnObj = obj
        self.appendAndPostNotification(appendString: String.init(format: "开始更新配置文件"))
        self.checkAndBulidProfile { (manager, error1) in
            if manager != nil {
                (manager?.protocolConfiguration as! NETunnelProviderProtocol).providerConfiguration = obj.configDic()
                manager?.saveToPreferences(completionHandler: { (error2) in
                    completionHandler(error2)
                    let isOk2 = ((error2 == nil) as Bool)
                    if isOk2 {
                        self.appendAndPostNotification(appendString: String.init(format: "更新配置文件成功"))
                    }
                    else {
                        self.appendAndPostNotification(appendString: String.init(format: "更新配置文件失败%@",(error2! as NSError).userInfo))

                    }
                })
            }
        }
    }
    //加载所有配置文件
    func loadAllFromPreferences(completionHandler:@escaping (([NETunnelProviderManager]?,Error?)->Void)) -> Void {
        NETunnelProviderManager.loadAllFromPreferences { (managers, error) in
            completionHandler(managers,error);
        }
    }
    //检查有没有可用配置
    func checkAvailableProfile(completionHandler:@escaping ((Bool)->Void)) -> Void {
        self.loadAllFromPreferences { (managers, error) in
            completionHandler(managers?.count != nil)
            self.appendAndPostNotification(appendString: String.init(format: "检查可用配置个数%ld个 error=%@",(managers?.count)!,(error == nil) ? "null" : (error! as NSError).userInfo))
            
        }
    }
    //检查有没有配置文件 没有的话 就去添加一个
    func checkAndBulidProfile(completionHandler:@escaping ((NETunnelProviderManager?,Error?) -> Void)) -> Void {
        self.loadAllFromPreferences { (managers, error1) in
            //配置文件不存在 去创建
            if managers?.count == 0 {
                //检查有没有初始化对象
                if (self.vpnObj == nil){
                    let cusError = NSError.init(domain: "domain", code: 99999, userInfo: ["userInfo":"配置文件没有"]);
                    //回掉
                    self.appendAndPostNotification(appendString: String.init(format: "保存profile文件出错,%@",cusError.userInfo))
                    completionHandler(nil,cusError as Error)
                }
                else {
                    //万事俱备 就去添加
                    self.defultManager().saveToPreferences(completionHandler: { (error2) in
                        if error2 != nil {
                            //保存出错
                            self.appendAndPostNotification(appendString: String.init(format: "采用默认manager保存profile文件出错,%@",(error2! as NSError).userInfo))
                            completionHandler(nil,error2)
                        }
                        else {
                            //保存成功 再次执行本函数
                            self.checkAndBulidProfile(completionHandler: { (manager, error) in
                                if error != nil {
                                    //已经存在了 还是 还是有错  没办法了🤷‍♀️
                                    self.appendAndPostNotification(appendString: String.init(format: "采用默认manager保存profile文件出错,%@",((error as NSError?)?.userInfo)!))
                                }
                                else {
                                    self.appendAndPostNotification(appendString: String.init(format: "采用默认manager保存profile文件成功"))
                                    completionHandler(manager,error)
                                }
                            })
                        }
                    })
                }
            }
                //已经添加了配置文件 直接回调
            else {
                completionHandler((managers?.first),error1)
            }
        }
    }
    func delAllVPNPrefile(completionHandler:@escaping ((Error?)->Void)) -> Void {
        self.loadAllFromPreferences { (managers, error1) in
            if managers != nil {
                var tempError : Error?
                
                for m in managers! {
                    m.removeFromPreferences(completionHandler: { (error2) in
                        if error2 != nil {
                            tempError = error2
                        }
                    })
                }
                completionHandler (tempError)
            }
            else if (error1 != nil){
                self.appendAndPostNotification(appendString: String.init(format: "删除profile文件出错,%@",(error1! as NSError).userInfo))
                completionHandler (error1)
            }
            else {
                self.appendAndPostNotification(appendString: String.init(format: "删除profile文件成功"))
                completionHandler (nil)
            }
        }
    }
    //添加profile
    func creatConfig(completionHandler:@escaping ((Error?)->Void)) -> Void {
        self.appendAndPostNotification(appendString: String.init(format: "开始添加配置文件"))
        self.checkAndBulidProfile { (manager, error) in
            completionHandler(error)
            self.appendAndPostNotification(appendString: String.init(format: "添加profile文件%@%@",(error != nil) ? "失败":"成功", (error != nil) ? ((error as NSError?)?.userInfo)! : ""))
        }
    }
    
    //默认NETunnelProviderManager
    func defultManager() -> NETunnelProviderManager{
        
        let v_manager = NETunnelProviderManager()
        
        v_manager.isOnDemandEnabled = false;
        v_manager.isEnabled = true
        v_manager.protocolConfiguration = defultConfigProtrol()
        v_manager.localizedDescription = "ssvpn"

        return v_manager
    }
    //默认协议
    func defultConfigProtrol() -> NETunnelProviderProtocol {
        let providerConfiguration = self.vpnObj?.configDic();
        let protocolConfig = NETunnelProviderProtocol()
        protocolConfig.serverAddress = "ssvpn"
        protocolConfig.providerConfiguration = providerConfiguration
//        protocolConfig.providerBundleIdentifier = ""
        return protocolConfig
    }

    //发送log日志
    open func appendAndPostNotification(appendString:String) {
//        self.log = logHelper(baseString: self.log, appendString: appendString)
        NotificationCenter.default.post(name: NSNotification.Name(rawValue: SSVPNManagerLogUpdate), object: appendString);
    }
}
extension SSVPNManager : SimplePingDelegate {
    //test ping
    func testping() -> Void {
        stopPing()
        if self.vpnObj?.address?.count == nil {
            //没有对象
            return
        }
        self.pinger = SimplePing.init(hostName: (self.vpnObj?.address)!)
        self.pinger?.addressStyle = .icmPv4
        self.pinger?.delegate = self
        self.pinger?.start()
    }
    func sendPingData() -> Void {
        self.appendAndPostNotification(appendString: String.init(format: "第%ld次发送", sendCount!))
        self.pinger?.send(with: nil)
    }
    func stopPing() -> Void {
        self.pinger?.stop()
        self.pinger = nil
        self.sendTimer?.invalidate()
        self.sendTimer = nil
    }
    //MARK:代理
    public func simplePing(_ pinger: SimplePing, didStartWithAddress address: Data) {
        //开始ping 执行10次
        sendCount = 1
        self.sendPingData();

        if self.sendTimer == nil {
            self.sendTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true, block: { (timer) in
                if self.sendCount! >= Int(10){
                    self.stopPing()
                    return
                }
                self.sendCount = self.sendCount! + 1
                self.sendPingData();
            })
        }
    }
    public func simplePing(_ pinger: SimplePing, didFailWithError error: Error) {
        stopPing()
    }
    
    public func simplePing(_ pinger: SimplePing, didSendPacket packet: Data, sequenceNumber: UInt16) {
        sendDate = Date.init()
    }
    
    public func simplePing(_ pinger: SimplePing, didFailToSendPacket packet: Data, sequenceNumber: UInt16, error: Error) {
        print("连接失败")
        appendAndPostNotification(appendString: "连接失败")
    }
    
    public func simplePing(_ pinger: SimplePing, didReceivePingResponsePacket packet: Data, sequenceNumber: UInt16) {
        let timeValue = Date.init().timeIntervalSince(sendDate!)
        appendAndPostNotification(appendString: String.init(format: "Delay Time Value %lfms", timeValue*1000))
    }
    
    public func simplePing(_ pinger: SimplePing, didReceiveUnexpectedPacket packet: Data) {

    }
}
