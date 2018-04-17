//
//  SSVPNPropertyObject.swift
//  ssvpn
//
//  Created by Loren on 2018/4/12.
//  Copyright © 2018年 Loren. All rights reserved.
//

import UIKit

public enum SSVPNEncryptionType : String {
    
    case AES128CFB
    
    case AES192CFB
    
    case AES256CFB
    
    case CHACHA20
    
    case SALSA20
    
    case RC4MD5
}

class SSVPNPropertyObject: NSObject {
    var address : String?
    var port    : String?
    var method  : String?
    var passwd  : String?
    var config  : String?
    
    override init() {
        super.init()
        address = ""
        port    = ""
        method  = "AES256CFB"
        passwd  = ""
        config = SSVPNPropertyObject.defaultRule()
    }
    convenience init(address:String, port:String, method:SSVPNEncryptionType, passwd:String, config:String?) {
        self.init()
        self.address = address
        self.port = port
        self.method = method.rawValue
        self.passwd = passwd
        self.config = config ?? SSVPNPropertyObject.defaultRule()
    }
    
    public func configDic() -> Dictionary<String, Any> {
        return ["address":self.address ?? "","port":self.port ?? "","method":self.method ?? "","passwd":self.passwd ?? "","config":self.config ?? ""]
    }
    class func defaultRule() -> String {
        let filePath = Bundle.main.path(forResource: "NEKitRule", ofType: "conf")
        let fileData = try? Data.init(contentsOf: URL.init(fileURLWithPath: filePath!))
        let rule = String.init(data: fileData!, encoding: String.Encoding.utf8)
        return rule!
    }
}
