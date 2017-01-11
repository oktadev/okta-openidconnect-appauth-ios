/** Author: Jordan Melberg **/

/** Copyright © 2016, Okta, Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import UIKit
import AppAuth


class OktaAppAuth: UIViewController, OIDAuthStateChangeDelegate {
    
    // MARK: Properties
    @IBOutlet weak var tokensIcon: UIImageView!
    @IBOutlet weak var apiCallIcon: UIImageView!
    @IBOutlet weak var userInfoIcon: UIImageView!
    @IBOutlet weak var refreshTokenIcon: UIImageView!
    @IBOutlet weak var revokeTokenIcon: UIImageView!
    @IBOutlet weak var clearIcon: UIImageView!
    @IBOutlet weak var userInfoButton: UIButton!
    @IBOutlet weak var refreshTokensButton: UIButton!
    @IBOutlet weak var callApiButton: UIButton!
    @IBOutlet weak var clearButton: UIButton!
    @IBOutlet weak var revokeTokensButton: UIButton!
    
    // Okta Configuration
    var appConfig = OktaConfiguration()
    
    // AppAuth authState
    var authState:OIDAuthState?
    
    // Revoked Toggle
    var revoked = false

    override func viewDidLoad() {
        super.viewDidLoad()
        connectIcons()
        self.loadState()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    /**  Connects UI image icons to functions  */
    func connectIcons() {
        // Assign Access Icon to Retrieve Access Token
        let tokens_gesture = UITapGestureRecognizer(target:self, action: #selector(OktaAppAuth.getTokensButton(_:)))
        tokensIcon.isUserInteractionEnabled = true
        tokensIcon.addGestureRecognizer(tokens_gesture)
        
        //Assign Userinfo Icon to Retrieve User Info
        let user_gesture = UITapGestureRecognizer(target: self, action:#selector(OktaAppAuth.userinfo(_:)))
        userInfoIcon.isUserInteractionEnabled = true
        userInfoIcon.addGestureRecognizer(user_gesture)
        
        //Assign API Call Icon to Retrieve Info from Demo Endpoint
        let api_gesture = UITapGestureRecognizer(target: self, action:#selector(OktaAppAuth.apiCall))
        apiCallIcon.isUserInteractionEnabled = true
        apiCallIcon.addGestureRecognizer(api_gesture)
        
        //Assign Refresh Token Icon to Function
        let refresh_gesture = UITapGestureRecognizer(target: self, action:#selector(OktaAppAuth.refreshTokens))
        refreshTokenIcon.isUserInteractionEnabled = true
        refreshTokenIcon.addGestureRecognizer(refresh_gesture)
        
        // Assign Revoke Token Icon to Function
        let revoke_gesture = UITapGestureRecognizer(target: self, action:#selector(OktaAppAuth.revokeToken))
        revokeTokenIcon.isUserInteractionEnabled = true
        revokeTokenIcon.addGestureRecognizer(revoke_gesture)
        
        // Assign Sign out to Function
        let clear_gesture = UITapGestureRecognizer(target: self, action: #selector(OktaAppAuth.clearTokens))
        clearIcon.isUserInteractionEnabled = true
        clearIcon.addGestureRecognizer(clear_gesture)
        
    }
    
    /**
     *  Creates pop-up alert given Title and Message
     *  Dismisses on UI button click 'Cancel'
     *
     *  - parameters:
     *    - alertTitle: Title of alert
     *    - alertMessage: Output message
     */
    func createAlert(_ alertTitle: String, alertMessage: String) {
        let alert = UIAlertController(title: alertTitle, message: alertMessage, preferredStyle: .alert)
        alert.view.tintColor = UIColor.black
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.cancel, handler: nil))
        let textIndicator: UIActivityIndicatorView = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50)) as UIActivityIndicatorView
        alert.view.addSubview(textIndicator)
        
        present(alert, animated: true, completion: nil)
    }
    
    /**  Saves the current authState into NSUserDefaults  */
    func saveState() {
        if(authState != nil){
            let archivedAuthState = NSKeyedArchiver.archivedData(withRootObject: authState!)
            UserDefaults.standard.set(archivedAuthState, forKey: appConfig.kAppAuthExampleAuthStateKey)
        }
        else { UserDefaults.standard.set(nil, forKey: appConfig.kAppAuthExampleAuthStateKey) }
        
        UserDefaults.standard.synchronize()
    }
    
    /**  Loads the current authState from NSUserDefaults */
    func loadState() {
        if let archivedAuthState = UserDefaults.standard.object(forKey: appConfig.kAppAuthExampleAuthStateKey) as? Data {
            if let authState = NSKeyedUnarchiver.unarchiveObject(with: archivedAuthState) as? OIDAuthState {
                setAuthState(authState)
            } else {  return  }
        } else { return }
    }
    
    /**
     *  Setter method for authState update
     *  :param: authState The input value representing the new authorization state
     */
    fileprivate func setAuthState(_ authState:OIDAuthState?){
        self.authState = authState
        self.authState?.stateChangeDelegate = self
        self.stateChanged()
    }
    
    /**  Required method  */
    func stateChanged(){ self.saveState() }
    
    /**  Required method  */
    func didChange(_ state: OIDAuthState) { self.stateChanged() }
    
    /**  Verifies authState was performed  */
    func checkAuthState() -> Bool {
        if (authState != nil){
            return true
        } else { return false }
    }
    
    /**
     *  Starts Authorization Flow
     *  :param: sender The UI button 'Get Tokens'
     */
    @IBAction func getTokensButton(_ sender: AnyObject) { authenticate() }
    
    /**
     *  Authorization Flow Sequence
     *  
     *  This method retrieves the OpenID Connect discovery document based on the configuration specified in 'Models.swift' and creates an AppAuth authState
     *  -   Builds the authentication request with helper method OIDAuthorizationRequest
     *  -   Opens in-app iOS Safari browser to validate user credientials
     *  -   Logs: Access Token, Refresh Token, and Id Token
     *  -   Alerts: Success
     */
    func authenticate() {
        let issuer = URL(string: appConfig.kIssuer)
        let redirectURI = URL(string: appConfig.kRedirectURI)
        
        // Discovers Endpoints
        OIDAuthorizationService.discoverConfiguration(forIssuer: issuer!) {
            config, error in
            
            if ((config == nil)) {
                print("Error retrieving discovery document: \(error?.localizedDescription)")
                return
            }
            print("Retrieved configuration: \(config!)")
            
            // Build Authentication Request
            let request = OIDAuthorizationRequest(configuration: config!,
                        clientId: self.appConfig.kClientID,
                        scopes: [
                            OIDScopeOpenID,
                            OIDScopeProfile,
                            OIDScopeEmail,
                            OIDScopePhone,
                            OIDScopeAddress,
                            "groups",
                            "offline_access"
                        ],
                        redirectURL: redirectURI!,
                        responseType: OIDResponseTypeCode,
                        additionalParameters: nil)
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            
            print("Initiating Authorization Request: \(request!)")
            appDelegate.currentAuthorizationFlow =
                OIDAuthState.authState(byPresenting: request!, presenting: self){
                    authorizationResponse, error in
                    if(authorizationResponse != nil) {
                        self.setAuthState(authorizationResponse)
                        let authToken = authorizationResponse!.lastTokenResponse!.accessToken!
                        let refreshToken = authorizationResponse!.lastTokenResponse!.refreshToken!
                        let idToken = authorizationResponse!.lastTokenResponse!.idToken!
                        print("Retrieved Tokens.\n\nAccess Token: \(authToken) \n\nRefresh Token: \(refreshToken) \n\nId Token: \(idToken)")
                        self.createAlert("Tokens", alertMessage: "Check logs for token values")
                        
                    } else {
                        print("Authorization Error: \(error!.localizedDescription)")
                        self.setAuthState(nil)
                    }
            }
        }
    }
    
    /**
     *  Calls Userinfo Endpoint
     *  
     *  - parameters:
     *    - sender: The UI button 'Get User Info'
     */
    @IBAction func userinfo(_ sender: AnyObject) {
        let userinfoEndpoint = authState?.lastAuthorizationResponse
            .request.configuration.discoveryDocument?.userinfoEndpoint
        if(userinfoEndpoint  == nil ) {
            print("Userinfo endpoint not declared in discovery document")
            self.createAlert("Error", alertMessage: "User info endpoint not declared in discovery document")
            return
        }
        sendUserInfoRequest(userinfoEndpoint!)
    }
    
    /**
     *  Creates HTTP request to the User Info API endpoint
     *
     *  Verifies the accessToken wasn't revoked
     *  
     *  - parameters:
     *    - url: The url in NSURL format for the request to be made
     */
    func sendUserInfoRequest(_ url: URL){
        if checkAuthState() {
            // Check if token is revoked
            var token = authState?.lastTokenResponse?.accessToken
            
            if revoked { print("Performing request with revoked accessToken") }
            else {
                print("Performing request with fresh accessToken")
                authState?.withFreshTokensPerformAction(){
                    accessToken, idToken, error in
                    if(error != nil){
                        print("Error fetching fresh tokens: \(error!.localizedDescription)")
                        return
                    }
                    // Update accessToken
                    if(token != accessToken){
                        print("Access token refreshed automatially (\(token) to \(accessToken!))")
                        token = accessToken
                    } else { print("Access token was fresh and not updated [\(token!)]") }
                }
            }
            // Perform Request
            performRequest("User Info", currentAccessToken: (token)!, url: url)
        } else { print("Not authenticated") }
    }
    
    /**
     *  Performs HTTP Request with access token
     *
     *  - parameters:
     *      - returnTitle: Title of response alert
     *      - currentAccessToken: Current access token (may be refreshed)
     *      - url: NSURL of API endpoint
     */
    func performRequest(_ returnTitle: String, currentAccessToken: String, url: URL) {
        // Create Request to endpoint, with access_token in Authorization Header
        
        var request = URLRequest(url:url)
        let authorizationHeaderValue = "Bearer \(currentAccessToken)"
        request.addValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
            
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
            
        //Perform HTTP Request
        let postDataTask = session.dataTask(with: request, completionHandler: {
            data, response, error in
            DispatchQueue.main.async{
                if let httpResponse = response as? HTTPURLResponse {
                    do{
                        let jsonDictionaryOrArray = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers)
                        if ( httpResponse.statusCode != 200 ){
                            let responseText = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
                            if ( httpResponse.statusCode == 401 ){
                                let oauthError = OIDErrorUtilities.resourceServerAuthorizationError(withCode: 0,
                                    errorResponse: jsonDictionaryOrArray as? [AnyHashable: Any],
                                    underlyingError: error)
                                self.authState?.update(withAuthorizationError: oauthError!)
                                self.createAlert("OAuth Error", alertMessage: "\(oauthError)")
                                print("Authorization Error (\(oauthError!)). Response: \(responseText!)")
                            }
                            else { print("HTTP: \(httpResponse.statusCode). Response: \(responseText)") }
                            return
                        }
                        print("Success: \(jsonDictionaryOrArray)")
                        self.createAlert(returnTitle, alertMessage: "\(jsonDictionaryOrArray)")
                    } catch {  print("Error while serializing data to JSON")  }
                } else {
                    print("Non-HTTP response \(error)")
                    return
                }
            }
        }) 
        postDataTask.resume()
    }
    
    /**
     *  Outlet to call refreshTokens method
     *
     *  - parameters:
     *    - sender: UI button 'Refresh Token'
     */
    @IBAction func refreshTokenButton(_ sender: AnyObject) { refreshTokens() }
    
    /**  Refreshes the current tokens with existing refresh token  */
    func refreshTokens(){
        if checkAuthState() {
            print("Refreshed tokens")
            authState?.setNeedsTokenRefresh()
            authState?.withFreshTokensPerformAction(){
                accessToken, idToken, error in
                if(error != nil){
                    print("Error fetching fresh tokens: \(error!.localizedDescription)")
                    self.createAlert("Error", alertMessage: "Error fetching fresh tokens")
                    return
                }
                self.createAlert("Success", alertMessage: "Token was refreshed")
            }
        } else {
            print("Not authenticated")
            createAlert("Error", alertMessage: "Not authenticated")
        }
    }
    
    /**
     *  Outlet to call revokeTokens method
     *
     *  - parameters:
     *    - sender: UI button 'Revoke Token'
     */
    @IBAction func revokeTokensButton(_ sender: AnyObject) { revokeToken() }
    
    /**  Revokes current access token by calling OAuth revoke endpoint  */
    func revokeToken(){
        if checkAuthState() {
            print("Revoking token..")
            authState?.withFreshTokensPerformAction(){
                accessToken, idToken, error in
                
                let url = URL(string: "\(self.appConfig.kIssuer)/oauth2/v1/revoke")
                var request = URLRequest(url: url!)
                request.httpMethod = "POST"
                
                let requestData = "token=\(accessToken!)&client_id=\(self.appConfig.kClientID)"
                request.httpBody = requestData.data(using: String.Encoding.utf8)
                
                let config = URLSessionConfiguration.default
                let session = URLSession(configuration: config)
                
                //Perform HTTP Request
                let postDataTask = session.dataTask(with: request, completionHandler: {
                    data, response, error in
                    DispatchQueue.main.async{
                        if let httpResponse = response as? HTTPURLResponse {
                            do{
                                if (httpResponse.statusCode == 200 || httpResponse.statusCode == 204){
                                    self.createAlert("Token Revoked", alertMessage: "Previous access token is considered invalid")
                                    print("Previous access token is considered invalid")
                                    self.revoked = true
                                    self.authState?.setNeedsTokenRefresh()
                                    return
                                } else {
                                    // Error JSON
                                    let jsonDictionaryOrArray = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers)
                                    if ( httpResponse.statusCode != 200 || httpResponse.statusCode != 204 ){
                                        let responseText = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
                                        if ( httpResponse.statusCode == 401 ){
                                            let oauthError = OIDErrorUtilities.resourceServerAuthorizationError(withCode: 0,
                                                errorResponse: jsonDictionaryOrArray as? [AnyHashable: Any],
                                                underlyingError: error)
                                            self.authState?.update(withAuthorizationError: oauthError!)
                                            print("Authorization Error (\(oauthError)). Response: \(responseText)")
                                        }
                                        else{ print("HTTP: \(httpResponse.statusCode). Response: \(responseText)") }
                                        return
                                    }                                 }
                            } catch { print("Error while serializing data to JSON")  }
                        } else {
                            print("Non-HTTP response \(error)")
                            return
                        }
                    }
                }) 
                postDataTask.resume()
            }
        } else {
            print("Not authenticated")
            createAlert("Error", alertMessage: "Not authenticated")
        }
    }
    
    /**
     *  Outlet to call clearTokens method
     *
     *  - parameters:
     *    - sender: UI button 'Clear Tokens'
     */
    @IBAction func clearButton(_ sender: AnyObject) { clearTokens() }
    
    /**  Removes all tokens from curent authState  */
    func clearTokens(){
        if checkAuthState() {
            self.setAuthState(nil)
            let clearAll = Bundle.main.bundleIdentifier!
            UserDefaults.standard.removePersistentDomain(forName: clearAll)
            self.saveState()
            createAlert("Signed out", alertMessage: "Successfully forgot all tokens")
        } else {
            print("Not authenticated")
            createAlert("Error", alertMessage: "Not authenticated")
        }
        
    }
    
    /**  Calls external server API to return image  */
    func apiCall() {
        if checkAuthState(){
            self.performSegue(withIdentifier: "ImageViewSegue", sender: self)
        } else {
            print("Not authenticated")
            createAlert("Error", alertMessage: "Not authenticated")
        }
    }
    
    /*  Segue to next ImageView for testing Demo API Call    */
    override func prepare(for segue: UIStoryboardSegue, sender: Any?){
        if segue.identifier == "ImageViewSegue" {
            let destinationController = segue.destination as! ImageViewController
            destinationController.authState = authState
            destinationController.appConfig = appConfig
        }
    }

}


