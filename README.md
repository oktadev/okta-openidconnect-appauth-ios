# iOS Native Application with AppAuth
Sample application for communicating with OAuth 2.0 and OpenID Connect providers. Demonstrates single-sign-on (SSO) with [AppAuth for iOS](https://github.com/openid/AppAuth-iOS) implemented in Swift.

## Running the Sample with your Okta Organization

### Pre-requisites
These steps require an Okta account - if you do not have one, sign up for a free developer organization [here](https://www.okta.com/developer/signup/).

1. Add an OpenID Connect Application:
  - `Admin -> Applications -> Add Application -> Create New App -> Native app -> Create`
  - If you **do not** see the `OpenID Connect` option, contact us at [developers@okta.com](mailto:developers@okta.com) to enable it
2. Create an OpenID Connect application:

    | Setting             | Value                                          |
    | ------------------- | ---------------------------------------------- |
    | Application Name    | OpenID Connect Mobile App                      |
    | Redirect URIs       | `com.okta.applicationClientId://callback`      |
    | Allowed grant types | Authorization Code, Refresh Token, Implicit    |

3. Click **Finish** to redirect back to the *General Settings* of your application.
4. In the *Client Credentials* section verify *Proof Key for Code Exchange (PKCE)* is the default **Client Authentication**
5. Copy the **Client ID**, as it will be needed for the `Models.swift` configuration file.
6. Create an OpenID Connect group:
  - In the navigation bar, select **Directory** then **Groups**
  - Select the `Add Group` button
  - Enter the following information for your new group:
  
    | Setting           | Value                        | 
    | ----------------- | ---------------------------- |
    | Name              | OpenID Connect Group         |
    | Group Description | OpenID Connect Samples Group |
    
7. Add new or existing users to your `OpenID Connect Group`:

    | Name              | Username        | Password | Group                 |
    | ----------------- | --------------- | -------- | --------------------- |
    | George Washington | george@acme.com | Asdf1234 | OpenID Connect Group  |
    | John Adams        | john@acme.com   | Asdf1234 | OpenID Connect Group  |

### Configure the Sample Application
Once the project is cloned, install [AppAuth](https://github.com/openid/AppAuth-iOS) with [CocoaPods](https://guides.cocoapods.org/using/getting-started.html) by running the following from the project root.

```bash
$ pod install
```

**Important:** Open `OpenIDConnectSwift.xcworkspace`. This file should be used to run/test your application.

Update the **kIssuer** and **kClientID** in your `Models.swift` file:
```swift

class OktaConfiguration {
    ...
    init(){
        kIssuer = "https://example.oktapreview.com"
        kClientID = "applicationClientID"   
    }
}
```

#### Updating the iOS Deep Link
By default, the web browsers can open the application by visiting the unique URL `com.okta.applicationClientId://callback`. Update the URL by performing the following actions:

1. Open `Info.plist` inside of `OpenIDConnectSwift.xcworkspace`
2. Under **Information Property List**, select the arrow next to **URL types** to expand it
3. Similarly, expand **Item 0** then **URL Schemes**
4. Update `com.okta.applicationClientId` to the desired redirect URL
5. Add the new redirect URL to your application's approved **Redirect URIs**

Common practice is to use [reverse DNS notation](https://developer.apple.com/library/content/documentation/General/Conceptual/AppSearch/UniversalLinks.html) of your organization. 


## Running the Sample Application


| Get Tokens      | Get User Info  | Refresh Token  | Revoke Token   | Call API       | Clear Tokens   |
| :-------------: |:-------------: |:-------------: |:-------------: |:-------------: |:-------------: |
| ![Get Tokens](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/key_circle.imageset/key.png)| ![Get User Info](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/Reporting.imageset/Reporting.png)| ![Refresh Token](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/refresh.imageset/api_call.png)| ![Revoke Token](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/revoke.imageset/revoke.png) | ![Call API](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/refresh.imageset/api_call.png) | ![Clear Tokens](https://raw.githubusercontent.com/jmelberg/okta-openidconnect-appauth-sample-swift/master/OpenIDConnectSwift/Assets.xcassets/ic_key.imageset/MFA_for_Your_Apps.png)|

### Get Tokens
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
  OIDAuthState.authStateByPresentingAuthorizationRequest(request, presentingViewController: self){
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

### Get User Info
If the user is authenticated, calling the [`/userinfo`](http://developer.okta.com/docs/api/resources/oidc#get-user-information) endpoint will retrieve user data. If received, the output is printed to the Debug area and a UIAlert.

**NOTE:** Before calling the `/userinfo` endpoint, the `accessToken` is refreshed by AppAuth's `withFreshTokensPerformAction()` method. However, if the `accessToken` was previously **revoked**, the token will **not** be refreshed.

```swift
//OktaAppAuth.swift

func sendUserInfoRequest(_ url: URL){
  if checkAuthState() {
    // Check if token is revoked
    var token = authState?.lastTokenResponse?.accessToken
    
    if revoked { print("Performing request with revoked accessToken") }
    else {
      print("Performing request with fresh accessToken")
      authState?.performAction(freshTokens: {
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
      })
    }

    // Perform Request
    performRequest("User Info", currentAccessToken: (token)!, url: url)
  }
}
    
```

### Refresh Tokens
The AppAuth method `withFreshTokensPerformAction()` is used to refresh the current **access token** if the user is authenticated and the `setNeedsTokenRefresh` flag is set to `true`.
```swift
// OktaAppAuth.swift

func refreshTokens(){
  // Refreshes token

  if checkAuthState() {
    authState?.setNeedsTokenRefresh()
    authState?.performAction(freshTokens: {
        accessToken, idToken, error in
        if(error != nil){
            // Error
            return
        }
        // accessToken
        // idToken

    })
  }
  else {
    // Not authenticated
  }
}

```

### Revoke Tokens
If authenticated, the current `accessToken` is passed to the `/revoke` endpoint to be revoked.

```swift
// OktaAppAuth.swift

func revokeToken(){
  if checkAuthState() {
    // Call revoke endpoint to terminate accessToken
    authState?.performAction(freshTokens: {
      accessToken, idToken, error in
      
      var request = URLRequest(url: url!)
      request.httpMethod = "POST"
                
      let requestData = "token=\(accessToken!)&client_id=\(self.appConfig.kClientID)"
      request.httpBody = requestData.data(using: String.Encoding.utf8)
                
      let config = URLSessionConfiguration.default
      let session = URLSession(configuration: config)
      
      //Perform HTTP Request
      ...
      
      self.revoked = true // Revoke toggle for calling User Info
    })
  }
}

```

### Call API
Passes the current access token *(fresh or revoked)* to a resource server for validation. Returns an api-specific details about the authenticated user.

Currently, the [resource server](https://github.com/jmelberg/oauth-resource-server) is implemented with [node.js](https://nodejs.org/en/) and returns an image from [Gravatar API](https://en.gravatar.com/site/implement/). Please review the [setup information in the Resource Server README](https://github.com/jmelberg/oauth-resource-server/blob/master/README.md) for proper configuration.

#### Example Response

```swift
// ImageViewController.swift
{
    image = "//www.gravatar.com/avatar/<hash>?s=200&r=x&d=retro";
    name = "example@okta.com";
}
```

### Clear Tokens
Sets the current `authState` to `nil` - clearing all tokens from AppAuth's cache.
