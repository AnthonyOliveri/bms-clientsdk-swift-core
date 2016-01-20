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


import WatchKit
 

/**
    The HTTP method to be used in the `Request` class initializer.
*/
public enum HttpMethod: String {
    case GET, POST, PUT, DELETE, TRACE, HEAD, OPTIONS, CONNECT, PATCH
}
 
 
/**
    The type of callback sent with MFP network requests
*/
public typealias MfpCompletionHandler = (Response?, NSError?) -> Void
    
    
public let MFP_PACKAGE_PREFIX = "mfpsdk."

 
/**
    Build and send HTTP network requests.

    When building a Request object, all components of the HTTP request must be provided in the initializer, except for the `requestBody`, which can be supplied as either NSData or plain text when sending the request via one of the following methods:

        sendString(requestBody: String, withCompletionHandler callback: mfpCompletionHandler?)
        sendData(requestBody: NSData, withCompletionHandler callback: mfpCompletionHandler?)
*/
public class MFPRequest: NSObject, NSURLSessionTaskDelegate {

    
    // MARK: Constants
    
    public static let CONTENT_TYPE = "Content-Type"
    public static let TEXT_PLAIN_TYPE = "text/plain"
    
    public static let MFP_CORE_ERROR_DOMAIN = "com.ibm.mobilefirstplatform.clientsdk.swift.BMSCore"
    
    internal static let MFP_REQUEST_PACKAGE = MFP_PACKAGE_PREFIX + "request"
    
    
    
    // MARK: Properties (public)
    
    /// URL that the request is being sent to
    public private(set) var resourceUrl: String
    
    /// HTTP method (GET, POST, etc.)
    public let httpMethod: HttpMethod
    
    /// Request timeout measured in seconds
    public var timeout: Double
    
    /// All request headers
    public var headers: [String: String] = [:]
    
    /// Query parameters to append to the `resourceURL`
    public var queryParameters: [String: String]?
    
    /// The request body can be set when sending the request via the `sendString` or `sendData` methods.
    public private(set) var requestBody: NSData?
    
    // TODO: How is this actually used?
    public var allowRedirects : Bool = true
    
    // Public access required by BMSAnalytics framework
    public internal(set) var startTime: NSTimeInterval = 0.0
    
    // Public access required by BMSAnalytics framework
    public internal(set) var trackingId: String = ""
    
    
    
    // MARK: Properties (internal/private)
    
    var networkRequest: NSMutableURLRequest
    
    private static let logger = Logger.getLoggerForName(MFP_REQUEST_PACKAGE)
    
    private static var networkSession: NSURLSession!
    
    // Create a UUID for the current device and save it to the keychain
    // Currently only used for Apple Watch devices
    internal static var uniqueDeviceId: String {
        // First, check if a UUID was already created
        let mfpUserDefaults = NSUserDefaults(suiteName: "com.ibm.mobilefirstplatform.clientsdk.swift.Analytics")
        guard mfpUserDefaults != nil else {
            MFPRequest.logger.error("Failed to get an ID for this device.")
            return ""
        }
        
        var deviceId = mfpUserDefaults!.stringForKey("deviceId")
        if deviceId == nil {
            deviceId = NSUUID().UUIDString
            mfpUserDefaults!.setValue(deviceId, forKey: "deviceId")
        }
        return deviceId!
    }
    
    
    
    // MARK: Initializer
    
    /**
        Constructs a new request with the specified URL, using the specified HTTP method.
        Additionally this constructor sets a custom timeout.

        - parameter url:             The resource URL
        - parameter method:          The HTTP method to use
        - parameter headers:         Optional headers to add to the request.
        - parameter queryParameters: Optional query parameters to add to the request.
        - parameter timeout:         Timeout in seconds for this request
    */
    public init(url: String,
               headers: [String: String]?,
               queryParameters: [String: String]?,
               method: HttpMethod = HttpMethod.GET,
               timeout: Double = BMSClient.sharedInstance.defaultRequestTimeout) {
        
        self.resourceUrl = url
        self.httpMethod = method
        if headers != nil {
            self.headers = headers!
        }
        self.timeout = timeout
        self.queryParameters = queryParameters
                
        // Set timeout and initialize network session and request
        let configuration = NSURLSessionConfiguration.defaultSessionConfiguration()
        configuration.timeoutIntervalForRequest = timeout
//        networkSession = NSURLSession(configuration: configuration)
        networkRequest = NSMutableURLRequest()
        super.init()
        MFPRequest.networkSession = NSURLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }
    
    public func getNetworkSession() -> NSURLSession {
        return MFPRequest.networkSession
    }
    
    
    
    // MARK: Methods (public)
    
    /**
        Add a request body and send the request asynchronously.
    
        If the Content-Type header is not already set, it will be set to "text/plain".
    
        The response received from the server is packaged into a `Response` object which is passed back via the completion handler parameter.
    
        If the `resourceUrl` string is a malformed url or if the `queryParameters` cannot be appended to it, the completion handler will be called back with an error and a nil `Response`.
    
        - parameter requestBody: HTTP request body
        - parameter withCompletionHandler: The closure that will be called when this request finishes
    */
    public func sendString(requestBody: String, withCompletionHandler callback: MfpCompletionHandler?) {
        self.requestBody = requestBody.dataUsingEncoding(NSUTF8StringEncoding)
        
        // Don't want to overwrite content type if it has already been specified as something else
        if headers[MFPRequest.CONTENT_TYPE] == nil {
            headers[MFPRequest.CONTENT_TYPE] = MFPRequest.TEXT_PLAIN_TYPE
        }
        
        self.sendWithCompletionHandler(callback)
    }
    
    /**
        Add a request body and send the request asynchronously.
        
        The response received from the server is packaged into a `Response` object which is passed back via the completion handler parameter.
    
        If the `resourceUrl` string is a malformed url or if the `queryParameters` cannot be appended to it, the completion handler will be called back with an error and a nil `Response`.
    
        - parameter requestBody: HTTP request body
        - parameter withCompletionHandler: The closure that will be called when this request finishes
    */
    func sendData(requestBody: NSData, withCompletionHandler callback: MfpCompletionHandler?) {
        
        self.requestBody = requestBody
        self.sendWithCompletionHandler(callback)
    }
    
    // TODO: Refactor sendWithCompletionHandler - slit into more methods
    
    /**
        Send the request asynchronously.
    
        The response received from the server is packaged into a `Response` object which is passed back via the completion handler parameter.
    
        If the `resourceUrl` string is a malformed url or if the `queryParameters` cannot be appended to it, the completion handler will be called back with an error and a nil `Response`.

        - parameter completionHandler: The closure that will be called when this request finishes
    */
    public func sendWithCompletionHandler(callback: MfpCompletionHandler?) {
        // Build the Response object and pass it to the user
//        let originalUrl = self.resourceUrl // Copy the url before query parameters get added to it
        let buildAndSendResponse = {
            (data: NSData?, response: NSURLResponse?, error: NSError?) -> Void in
            
            let networkResponse = Response(responseData: data, httpResponse: response as? NSHTTPURLResponse, isRedirect: self.allowRedirects)
            
            // TODO: Add back in when the Analytics server supports this functionality (estimated for May 2016)
//            let responseMetadata = Analytics.generateInboundResponseMetadata(self, response: networkResponse, url: originalUrl)
//            Request.logger.analytics(responseMetadata)
            
            callback?(networkResponse as Response, error)
        }
        
        // Add metadata to the request header so that analytics data can be obtained for ALL mfp network requests
        // Must be called before query parameters are added to self.resourceUrl
        
        MFPRequest.logger.debug("Network request outbound")
        
        // TODO: Conditional check for Analytics framework
        
        // The analytics server needs this ID to match each request with its corresponding response
//        self.trackingId = NSUUID().UUIDString
//        headers["x-wl-analytics-tracking-id"] = self.trackingId
        
//        if let requestMetadata = Analytics.generateOutboundRequestMetadata() {
//            self.headers["x-mfp-analytics-metadata"] = requestMetadata
//        }
        
        self.startTime = NSDate.timeIntervalSinceReferenceDate()
        
        if var url = NSURL(string: self.resourceUrl) {
            
            if queryParameters != nil {
                guard let urlWithQueryParameters = MFPRequest.appendQueryParameters(queryParameters!, toURL: url) else {
                    // This scenario does not seem possible due to the robustness of appendQueryParameters(), but it will stay just in case
                    let urlErrorMessage = "Failed to append the query parameters to the resource url."
                    MFPRequest.logger.error(urlErrorMessage)
                    let malformedUrlError = NSError(domain: MFPRequest.MFP_CORE_ERROR_DOMAIN, code: MFPErrorCode.MalformedUrl.rawValue, userInfo: [NSLocalizedDescriptionKey: urlErrorMessage])
                    callback?(nil, malformedUrlError)
                    return
                }
                url = urlWithQueryParameters
            }
            
            // Build request
            resourceUrl = String(url)
            networkRequest.URL = url
            networkRequest.HTTPMethod = httpMethod.rawValue
            networkRequest.allHTTPHeaderFields = headers
            networkRequest.HTTPBody = requestBody
            
            MFPRequest.logger.info("Sending Request to " + resourceUrl)
            
            // Send request            
            getNetworkSession().dataTaskWithRequest(networkRequest as NSURLRequest, completionHandler: buildAndSendResponse).resume()
           
        }
        else {
            let urlErrorMessage = "The supplied resource url is not a valid url."
            MFPRequest.logger.error(urlErrorMessage)
            let malformedUrlError = NSError(domain: MFPRequest.MFP_CORE_ERROR_DOMAIN, code: MFPErrorCode.MalformedUrl.rawValue, userInfo: [NSLocalizedDescriptionKey: urlErrorMessage])
            callback?(nil, malformedUrlError)
        }
    }
    
    
    
    // MARK: NSURLSessionTaskDelegate
    
    // Handle HTTP redirection
    public func URLSession(session: NSURLSession,
        task: NSURLSessionTask,
        willPerformHTTPRedirection response: NSHTTPURLResponse,
        newRequest request: NSURLRequest,
        completionHandler: ((NSURLRequest?) -> Void))
    {
        var redirectRequest: NSURLRequest?
        if allowRedirects {
            MFPRequest.logger.info("Redirecting: " + String(session))
            redirectRequest = request
        }
        
        completionHandler(redirectRequest)
    }
    
    
    
    // MARK: Methods (internal/private)
    
    /**
        Returns the supplied URL with query parameters appended to it; the original URL is not modified.
        Characters in the query parameters that are not URL safe are automatically converted to percent-encoding.
    
        - parameter parameters:  The query parameters to be appended to the end of the url
        - parameter originalURL: The url that the parameters will be appeneded to
    
        - returns: The original URL with the query parameters appended to it
    */
    static func appendQueryParameters(parameters: [String: String], toURL originalUrl: NSURL) -> NSURL? {
        
        if parameters.isEmpty {
            return originalUrl
        }
        
        var parametersInURLFormat = [NSURLQueryItem]()
        for (key, value) in parameters {
            parametersInURLFormat += [NSURLQueryItem(name: key, value: value)]
        }
        
        if let newUrlComponents = NSURLComponents(URL: originalUrl, resolvingAgainstBaseURL: false) {
            if newUrlComponents.queryItems != nil {
                newUrlComponents.queryItems!.appendContentsOf(parametersInURLFormat)
            }
            else {
                newUrlComponents.queryItems = parametersInURLFormat
            }
            return newUrlComponents.URL
        }
        else {
            return nil
        }
    }
    
}
