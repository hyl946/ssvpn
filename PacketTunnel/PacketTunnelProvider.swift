//
//  PacketTunnelProvider.swift
//  PacketTunnel2
//
//  Created by Loren on 2018/4/12.
//Copyright © 2018年 Loren. All rights reserved.
//

import NetworkExtension
import NEKit
import CocoaLumberjackSwift
import Yaml

class PacketTunnelProvider: NEPacketTunnelProvider {
    var connection: NWTCPConnection? = nil
    var pendingStartCompletion: ((NSError?) -> Void)?
    var enablePacketProcessing = true
    var proxyServer: ProxyServer!
    var interface: TUNInterface!
    var lastPath:NWPath?


    override func startTunnel(options: [String : NSObject]? = nil, completionHandler: @escaping (Error?) -> Void) {
        
        let config = (self.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration
        
        if config == nil {
            return
        }
        let passwd  = config!["passwd"] as! String
        let method  = config!["method"] as! String
        let port    = config!["port"] as! String
        let rule    = config!["config"] as! String
        let address = config!["address"] as! String
        
        var algorithm : CryptoAlgorithm
        
        switch method {
            case "AES128CFB":
                algorithm = .AES128CFB
            break
            case "AES192CFB":
                algorithm = .AES192CFB

            break
            case "AES256CFB":
                algorithm = .AES256CFB

            break
            case "CHACHA20":
                algorithm = .CHACHA20

            break
            case "SALSA20":
                algorithm = .SALSA20

            break
            case "RC4MD5":
                algorithm = .RC4MD5
            break
            default :
            algorithm = .AES256CFB
        }
        let obfuscater = ShadowsocksAdapter.ProtocolObfuscater.OriginProtocolObfuscater.Factory()

        let ssAdapterFactory = ShadowsocksAdapterFactory(serverHost: address, serverPort: Int(port)!, protocolObfuscaterFactory:obfuscater, cryptorFactory: ShadowsocksAdapter.CryptoStreamProcessor.Factory(password: passwd, algorithm: algorithm), streamObfuscaterFactory: ShadowsocksAdapter.StreamObfuscater.OriginStreamObfuscater.Factory())
        
        let directAdapterFactory = DirectAdapterFactory()
        
        //Get lists from conf

        let value = try! Yaml.load(rule)
        
        var UserRules:[NEKit.Rule] = []
        
        for each in (value["rule"].array! ){
            var adapter:NEKit.AdapterFactory
//            if each["adapter"].string! == "direct"{
//                adapter = directAdapterFactory
//            }else{
//                adapter = ssAdapterFactory
//            }
            //全部走代理
            adapter = ssAdapterFactory;
            
            let ruleType = each["type"].string!
            switch ruleType {
            case "domainlist":
                var rule_array : [NEKit.DomainListRule.MatchCriterion] = []
                for dom in each["criteria"].array!{
                    let raw_dom = dom.string!
                    let index = raw_dom.index(raw_dom.startIndex, offsetBy: 1)
                    let index2 = raw_dom.index(raw_dom.startIndex, offsetBy: 2)
                    let typeStr = raw_dom.substring(to: index)
                    let url = raw_dom.substring(from: index2)
                    
                    if typeStr == "s"{
                        rule_array.append(DomainListRule.MatchCriterion.suffix(url))
                    }else if typeStr == "k"{
                        rule_array.append(DomainListRule.MatchCriterion.keyword(url))
                    }else if typeStr == "p"{
                        rule_array.append(DomainListRule.MatchCriterion.prefix(url))
                    }else if typeStr == "r"{
                        // ToDo:
                        // shoud be complete
                    }
                }
                UserRules.append(DomainListRule(adapterFactory: adapter, criteria: rule_array))
                
                
            case "iplist":
                let ipArray = each["criteria"].array!.map{$0.string!}
                UserRules.append(try! IPRangeListRule(adapterFactory: adapter, ranges: ipArray))
            default:
                break
            }
        }
        
        
        // Rules
        
        let chinaRule = CountryRule(countryCode: "CN", match: true, adapterFactory: directAdapterFactory)
        let unKnowLoc = CountryRule(countryCode: "--", match: true, adapterFactory: directAdapterFactory)
        let dnsFailRule = DNSFailRule(adapterFactory: ssAdapterFactory)
        
        let allRule = AllRule(adapterFactory: ssAdapterFactory)
        UserRules.append(contentsOf: [chinaRule,unKnowLoc,dnsFailRule,allRule])
        
//        let configuration = Configuration()
//        try! configuration.load(fromConfigFile: rule)
//
        RuleManager.currentManager = RuleManager.init(fromRules: UserRules, appendDirect: true)
        RawSocketFactory.TunnelProvider = self
        
        let networkSetting = NEPacketTunnelNetworkSettings.init(tunnelRemoteAddress: "8.8.8.8")
        networkSetting.mtu = 1500
        
        let ipv4Setting = NEIPv4Settings.init(addresses:[address], subnetMasks: ["255.255.255.0"])
        
        if enablePacketProcessing {
//            ipv4Setting.includedRoutes = [[NEIPv4Route.default()]]
//            ipv4Setting.excludedRoutes = [
//                NEIPv4Route(destinationAddress: "10.0.0.0", subnetMask: "255.0.0.0"),
//                NEIPv4Route(destinationAddress: "100.64.0.0", subnetMask: "255.192.0.0"),
//                NEIPv4Route(destinationAddress: "127.0.0.0", subnetMask: "255.0.0.0"),
//                NEIPv4Route(destinationAddress: "169.254.0.0", subnetMask: "255.255.0.0"),
//                NEIPv4Route(destinationAddress: "172.16.0.0", subnetMask: "255.240.0.0"),
//                NEIPv4Route(destinationAddress: "192.168.0.0", subnetMask: "255.255.0.0"),
//            ]
            ipv4Setting.includedRoutes = []
            ipv4Setting.excludedRoutes = []
        }
        networkSetting.ipv4Settings = ipv4Setting
        
        let proxySettings = NEProxySettings()
        proxySettings.httpEnabled = true
        proxySettings.httpsEnabled = true
        proxySettings.httpServer = NEProxyServer(address: "127.0.0.1", port: Int(port)!)
        proxySettings.httpsServer = NEProxyServer(address: "127.0.0.1", port: Int(port)!)
        proxySettings.excludeSimpleHostnames = true
        proxySettings.matchDomains = [""];
        
        networkSetting.proxySettings = proxySettings
        
        if enablePacketProcessing {
            let DNSSettings = NEDNSSettings(servers: ["8.8.8.8"])
            DNSSettings.matchDomains = [""]
            DNSSettings.matchDomainsNoSearch = false
            networkSetting.dnsSettings = DNSSettings
        }
        
        setTunnelNetworkSettings(networkSetting) { (error) in
            if error != nil {
                completionHandler(error) //出问题了
                return
            }
            
            self.proxyServer = GCDHTTPProxyServer(address: IPAddress.init(fromString: "127.0.0.1"), port: Port(port: UInt16(port)!))
            try! self.proxyServer.start()
            completionHandler(nil)
            
            if self.enablePacketProcessing {
                self.interface = TUNInterface(packetFlow: self.packetFlow)
    
                let fakeIPPool = IPPool.init(range:try! IPRange.init(startIP: IPAddress.init(fromString: "198.18.1.1")!, endIP: IPAddress.init(fromString: "198.18.255.255")!))
                
                let dnsServer = DNSServer(address: IPAddress.init(fromString: "8.8.8.8")!, port: Port(port: 53), fakeIPPool: fakeIPPool)
                let resolver = UDPDNSResolver(address: IPAddress.init(fromString: "114.114.114.114")!, port: Port(port: 53))
                dnsServer.registerResolver(resolver)
                self.interface.register(stack: dnsServer)
                DNSServer.currentServer = dnsServer
                
                let udpStack = UDPDirectStack()
                self.interface.register(stack: udpStack)
                
                let tcpStack = TCPStack.stack
                tcpStack.proxyServer = self.proxyServer
                self.interface.register(stack: tcpStack)
                self.interface.start()
            }
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "state" {
            if let conn = object as? NWTCPConnection {
                if conn.state == NWTCPConnectionState.connected {
                    if let ra = conn.remoteAddress as? NWHostEndpoint {
                        setTunnelNetworkSettings(NEPacketTunnelNetworkSettings(tunnelRemoteAddress: ra.hostname)) {
                            error in
                            if error == nil {
                                self.addObserver(self, forKeyPath:"defaultPath", options:NSKeyValueObservingOptions.initial, context:nil)
                                self.packetFlow.readPackets {
                                    packets, protocols in
                                    // Add code here to deal with packets, and call readPacketsWithCompletionHandler again when ready for more.
                                }
                                conn.readMinimumLength(0, maximumLength: 8192) {
                                    (data, error) in
                                    // Add code here to parse packets from the data
                                    self.packetFlow.writePackets([NSData]() as [Data], withProtocols: [NSNumber]())
                                }
                            }
                            self.pendingStartCompletion?(error as NSError?)
                            self.pendingStartCompletion = nil
                        }
                    }
                } else if conn.state == NWTCPConnectionState.disconnected {
                    let error = NSError(domain:"PacketTunnelProviderDomain", code:-1, userInfo:[NSLocalizedDescriptionKey:"Failed to connect"])
                    if pendingStartCompletion != nil {
                        self.pendingStartCompletion?(error)
                        self.pendingStartCompletion = nil
                    } else {
                        cancelTunnelWithError(error)
                    }
                    conn.cancel()
                } else if conn.state == NWTCPConnectionState.cancelled {
                    conn.removeObserver(self, forKeyPath:"state")
                    self.removeObserver(self, forKeyPath:"defaultPath")
                    connection = nil
                }
            }
        } else if keyPath == "defaultPath" {
            if self.defaultPath?.status == .satisfied && self.defaultPath != lastPath{
                if(lastPath == nil){
                    lastPath = self.defaultPath
                }else{
                    NSLog("received network change notifcation")
                    let delayTime = DispatchTime.now() + Double(Int64(1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
                    DispatchQueue.main.asyncAfter(deadline: delayTime) {
                        self.startTunnel(options: nil){_ in}
                    }
                }
            }else{
                lastPath = defaultPath
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of:object, change:change, context:context)
        }
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        if enablePacketProcessing {
            interface.stop()
            interface = nil
            DNSServer.currentServer = nil
        }
        
        if(proxyServer != nil){
            proxyServer.stop()
            proxyServer = nil
            RawSocketFactory.TunnelProvider = nil
        }
        completionHandler()
        
        exit(EXIT_SUCCESS)
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)? = nil) {
        // Add code here to handle the message
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep
        completionHandler()
        
    }
    
    override func wake() {
        // Add code here to wake up
    }
}

