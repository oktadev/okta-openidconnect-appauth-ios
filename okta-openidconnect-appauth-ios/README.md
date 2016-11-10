# iOS Native Application with AppAuth
Sample application for communicating with OAuth 2.0 and OpenID Connect providers. Demonstrates single-sign-on (SSO) with [AppAuth for iOS](https://github.com/openid/AppAuth-iOS) implemented in Swift.

## Running the Sample with your Okta Organization

###Pre-requisites
This sample application was tested with an Okta org. If you do not have an Okta org, you can easily [sign up for a free Developer Okta org](https://www.okta.com/developer/signup/).

1. Verify OpenID Connect is enabled for your Okta organization. `Admin -> Applications -> Add Application -> Create New App -> OpenID Connect`
  - If you do not see this option, email [developers@okta.com](mailto:developers@okta.com) to enable it.
2. In the **Create A New Application Integration** screen, click the **Platform** dropdown and select **Native app only**
3. Press **Create**. When the page appears, enter an **Application Name**. Press **Next**.
4. Add the reverse DNS notation of your organization to the *Redirect URIs*, followed by a custom route. *(Ex: "com.oktapreview.example:/oauth")*
5. Click **Finish** to redirect back to the *General Settings* of your application.
6. Select the **Edit** button in the *General Settings* section to configure the **Allowed Grant Types**
  - Ensure *Authorization Code* and *Refresh Token* are selected in **Allowed Grant Types**
  - **Save** the application
7. In the *Client Credentials* section verify *Proof Key for Code Exchange (PKCE)* is the default **Client Authentication**
8. Copy the **Client ID**, as it will be needed for the `Models.swift` configuration file.
9. Finally, select the **People** tab and **Assign to People** in your organization.

### Configure the Sample Application
Once the project is cloned, install [AppAuth](https://github.com/openid/AppAuth-iOS) with [CocoaPods](https://guides.cocoapods.org/using/getting-started.html) by running the following from the project root.

    pod install
    

**Important:** Open `OpenIDConnectSwift.xcworkspace`. This file should be used to run/test your application.

Update the **kIssuer**, **kClientID**, and **kRedirectURI** in your `Models.swift` file:
```swift

class OktaConfiguration {
    ...
    init(){
        kIssuer = "https://example.oktapreview.com"       // Base url of Okta Developer domain
        kClientID = "CLIENT_ID"                           // Client ID of Application
        kRedirectURI = "com.oktapreview.example:/oauth"   // Reverse DNS notation of base url with oauth route
        kAppAuthExampleAuthStateKey = "com.okta.oauth.authState"
        apiEndpoint = NSURL(string: "https://example.server.com")
    }
}
```

Modify the `Info.plist` file by including a custom URI scheme **without** the route
  - `URL types -> Item 0 -> URL Schemes -> Item 0 ->  <kRedirectURI>` (*Ex: com.oktapreview.example*)

## Running the Sample Application


| Get Tokens      | Get User Info  | Refresh Token  | Revoke Token   | Call API       | Clear Tokens   |
| :-------------: |:-------------: |:-------------: |:-------------: |:-------------: |:-------------: |
| ![Get Tokens](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/key_circle.imageset/key.png)| ![Get User Info](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/Reporting.imageset/Reporting.png)| ![Refresh Token](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/refresh.imageset/api_call.png)| ![Revoke Token](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/revoke.imageset/revoke.png) | ![Call API](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/refresh.imageset/api_call.png) | ![Clear Tokens](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/ic_key.imageset/MFA_for_Your_Apps.png)|

###Get Tokens
Interacts with the Okta Authorization Server by using the discovered values from the organization's `https://example.oktapreview.com/.well-known/openid-configuration` endpoint. If the endpoint is found, AppAuth's `OIDAuthorizationRequest` method generates the request by passing in the required scopes and opening up an in-app Safari browser using `SFSafariViewController` to authenicate the user with Okta.

If you want to customize the scopes requested by the mobile app, change the `scopes` parameter below.

```swift
// OktaAppAuth.swift

func authenticate() {
  ...
  // Discovers Endpoints
  OIDAuthorizationService.discoverServiceConfigurationForIssuer(issuer!) {
    config, error in
    ...
    // Build Authentication Request
    let request = OIDAuthorizationRequest(
      configuration: config!,
      clientId: self.appConfig.kClientID,
      scopes: [
        OIDScopeOpenID,
        OIDScopeProfile,
        OIDScopeEmail,
        OIDScopePhone
        OIDScopeAddress,
        "groups",
        "offline_access"
      ],
      redirectURL: redirectURI!,
      responseType: OIDResponseTypeCode,
      additionalParameters: nil)
    ...
  }
}
```
If authenticated, the mobile app receives an `idToken`, `accessToken`, and `refreshToken` which are available in the Debug area. 

``` swift
// OktaAppAuth.swift

// Capture Authentication Response
appDelegate.currentAuthorizationFlow =
  OIDAuthState.authStateByPresentingAuthorizationRequest(request!,presentingViewController: self){
    authorizationResponse, error in
    
    if(authorizationResponse != nil){
      self.setAuthState(authorizationResponse)
      // authorizationResponse!.lastTokenResponse!.accessToken!
      // authorizationResponse!.lastTokenResponse!.refreshToken!
      // authorizationResponse!.lastTokenResponse!.idToken!
    } else {
      // Error
    }
}

```

###Get User Info
If the user is authenticated, calling the [`/userinfo`](http://developer.okta.com/docs/api/resources/oidc#get-user-information) endpoint will retrieve user data. If received, the output is printed to the Debug area and a UIAlert.

**NOTE:** Before calling the `/userinfo` endpoint, the `accessToken` is refreshed by AppAuth's `withFreshTokensPerformAction()` method. However, if the `accessToken` was previously **revoked**, the token will **not** be refreshed.

```swift
//OktaAppAuth.swift

func sendUserInfoRequest(url: NSURL){
  if checkAuthState() {
    var token = authState?.lastTokenResponse?.accessToken
    if revoked { print("Performing request with revoked accessToken")}
    else {
      print("Performing request with fresh accessToken")
      authState?.withFreshTokensPerformAction(){
        accessToken, idToken, error in
        
        if(error != nil){
          // Error
        }
        // Update accessToken
        if(token != accessToken){
          token = accessToken
        } else {
          print("Access token was fresh and not updated [\(token!)]")
        }
      }
    }
    // Perform Request
    performRequest("User Info", currentAccessToken: (token)!, url: url)
  }
}
    
```

###Refresh Tokens
The AppAuth method `withFreshTokensPerformAction()` is used to refresh the current **access token** if the user is authenticated and the `setNeedsTokenRefresh` flag is set to `true`.
```swift
// OktaAppAuth.swift

func refreshTokens(){
  // Refreshes token
  if checkAuthState() {
    authState?.setNeedsTokenRefresh()
    authState?.withFreshTokensPerformAction(){
      accessToken, idToken, error in
      
      if(error != nil){
        // Error
        return
      }
      // accessToken
      // idToken
    }
  }
  else {
    // Not authenticated
  }
}
```

###Revoke Tokens
If authenticated, the current `accessToken` is passed to the `/revoke` endpoint to be revoked.

```swift
// OktaAppAuth.swift

func revokeToken(){
  if checkAuthState() {
    // Call revoke endpoint to terminate accessToken
    authState?.withFreshTokensPerformAction(){
      accessToken, idToken, error in
      
      let url = NSURL(string: "\(self.appConfig.kIssuer)/oauth2/v1/revoke")
      let request = NSMutableURLRequest(URL: url!)
      request.HTTPMethod = "POST"
      
      let requestData = "token=\(accessToken!)&client_id=\(self.appConfig.kClientID)"
      request.HTTPBody = requestData.dataUsingEncoding(NSUTF8StringEncoding);
      
      let config = NSURLSessionConfiguration.defaultSessionConfiguration()
      let session = NSURLSession(configuration: config)
      
      //Perform HTTP Request
      ...
      self.revoked = true // Revoke toggle for calling User Info
    }
  }
}
```

###Call API
Passes the current access token *(fresh or revoked)* to a resource server for validation. Returns an api-specific details about the authenticated user.

Currently, the [resource server](https://github.com/jmelberg/oauth-resource-server) is implemented with [node.js](https://nodejs.org/en/) and returns an image from [Gravatar API](https://en.gravatar.com/site/implement/). Please review the [setup information in the Resource Server README](https://github.com/jmelberg/oauth-resource-server/blob/master/README.md) for proper configuration.

> Example Response

```swift
// ImageViewController.swift
{
    image = "//www.gravatar.com/avatar/<hash>?s=200&r=x&d=retro";
    name = "example@okta.com";
}
```

###Clear Tokens
Sets the current `authState` to `nil` - clearing all tokens from AppAuth's cache.
