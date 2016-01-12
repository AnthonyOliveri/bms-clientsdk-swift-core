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


import Foundation

public enum PersistensePolicy: Int {
    case Never, Always
}


internal class DefaultAuthorizationManager : AuthorizationManager {
    
    internal init() {
        
    }
    
    func isOAuthError(response: Response?) -> Bool {
        return false;
    }
    
    func isAuthorizationRequired(statusCode: Int, responseAuthorizationHeader: String) -> Bool {
        return false;
    }
    
    func isAuthorizationRequired(httpResponse: NSHTTPURLResponse) -> Bool {
        return false;
    }
    
    func clearAuthorizationData() {
        
    }
    
    func addCachedAuthorizationHeader(request: NSMutableURLRequest) {
        
    }
    
    func getCachedAuthorizationHeader() -> String? {
        return nil;
    }
    
    func obtainAuthorizationHeader(completionHandler: MfpCompletionHandler?) {
//        completionHandler(nil, nil)
    }
    
    func getUserIdentity() -> AnyObject? {
        return nil;
    }
    
    func getDeviceIdentity() -> AnyObject? {
        return nil;
    }
    
    func getAppIdentity() -> AnyObject? {
        return nil;
    }
    
    func getAuthorizationPersistencePolicy() -> PersistencePolicy {
        return PersistencePolicy.NEVER
    }
    
    func setAuthorizationPersistensePolicy(policy: PersistencePolicy) {
        
    }
}