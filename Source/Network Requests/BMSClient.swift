/*
*     Copyright 2015 IBM Corp.
*     Licensed under the Apache License, Version 2.0 (the "License");
*     you may not use this file except in compliance with the License.
*     You may obtain a copy of the License at
*     http://www.apache.org/licenses/LICENSE-2.0
*     Unless required by applicable law or agreed to in writing, software
*     distributed under the License is distributed on an "AS IS" BASIS,
*     WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
*     See the License for the specific language governing permissions and
*     limitations under the License.
*/


/**
    A singleton that serves as an entry point to Bluemix client-server communication.
*/
public class BMSClient: MFPClient {
    
    public static let REGION_US_SOUTH = "ng.bluemix.net"
    public static let REGION_UK = "eu-gb.bluemix.net"
    public static let REGION_SYDNEY = "au-syd.bluemix.net"
    
    public static let HTTP_SCHEME = "http"
    public static let HTTPS_SCHEME = "https"
    
    static let QUERY_PARAM_SUBZONE = "subzone"
    
    private var registeredAuthorizationManager: AuthorizationManager?
    // MARK: Properties (public)
    
    /// This singleton should be used for all `BMSClient` activity
    public static let sharedInstance = BMSClient()
    
    /// Specifies the base backend URL
    public private(set) var bluemixAppRoute: String?
    
    // Specifies the bluemix region suffix
    public private(set) var bluemixRegionSuffix: String?
    
    /// Specifies the backend application id.
    public private(set) var bluemixAppGUID: String?
        
    /// Specifies the default timeout (in seconds) for all BMS network requests.
    public var defaultRequestTimeout: Double = 20.0
    
    // Specifies the default protocol
    public static var defaultProtocol: String  = BMSClient.HTTPS_SCHEME
    
    public var sharedAuthorizationManager: AuthorizationManager {
        get {
            if registeredAuthorizationManager == nil {
                return DefaultAuthorizationManager()
            }
            
            return registeredAuthorizationManager!
        }
        
        set(newAuthorizationManager) {
            registeredAuthorizationManager = newAuthorizationManager
        }
    }
    
    // MARK: Initializers
    
    private init() {} // Prevent users from using BMSClient() initializer - They must use BMSClient.sharedInstance
    
    
    /**
        The required intializer for the `BMSClient` class.
    
        Sets the base URL for the authorization server.

        - parameter backendRoute: Specifies the base URL for the authorization server
        - parameter backendGUID:  Specifies the GUID of the Bluemix application
     */
    public func initializeWithBluemixAppRoute(bluemixAppRoute: String, bluemixAppGUID: String, bluemixRegionSuffix: String) {
        self.bluemixAppRoute = bluemixAppRoute
        self.bluemixAppGUID = bluemixAppGUID
        self.bluemixRegionSuffix = bluemixRegionSuffix
    }
    
}


// For unit testing only
internal extension BMSClient {
    
    internal func uninitializeBluemixAppRoute() {
        self.bluemixAppRoute = nil
    }
    
    internal func uninitalizeBluemixAppGUID(){
        self.bluemixAppGUID = nil
    }
}
