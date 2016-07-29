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

class ImageViewController: UIViewController {
    
    // MARK: Properties
    @IBOutlet weak var image: UIImageView!
    @IBOutlet weak var activityLoad: UIActivityIndicatorView!
    @IBOutlet weak var imageText: UILabel!
    
    // Retrieve from segue needed request values
    var authState:OIDAuthState?
    var appConfig = OktaConfiguration()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        activityLoad.startAnimating()
        sendDemoApiRequest(appConfig.apiEndpoint!, accessToken: (authState?.lastTokenResponse!.accessToken)!)
    }
    
    override func didReceiveMemoryWarning() { super.didReceiveMemoryWarning() }
    
    /**
     *  Calls endpoint on given server to decode and validate access token
     *
     *  - parameters:
     *    - url: NSURL of server endpoint
     *    - accessToken: Current token
     */
    func sendDemoApiRequest(url: NSURL, accessToken: String){
        print("Performing DEMO API request without auto-refresh")
        
        // Create Requst to Demo API endpoint, with access_token in Authorization Header
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "GET"
        let authorizationHeaderValue = "Bearer \(accessToken)"
        request.addValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
              
        let config = NSURLSessionConfiguration.defaultSessionConfiguration()
        let session = NSURLSession(configuration: config)
        
        //Perform HTTP Request
        let postDataTask = session.dataTaskWithRequest(request) {
            data, response, error in
            dispatch_async( dispatch_get_main_queue() ){
                    
                if let httpResponse = response as? NSHTTPURLResponse {
                    do{
                        let jsonDictionaryOrArray = try NSJSONSerialization.JSONObjectWithData(data!, options: .MutableContainers)
                        if ( httpResponse.statusCode != 200 ){
                            let responseText = NSString(data: data!, encoding: NSUTF8StringEncoding)
                            if ( httpResponse.statusCode == 401 ){
                                let oauthError = OIDErrorUtilities.resourceServerAuthorizationErrorWithCode(0,
                                    errorResponse: jsonDictionaryOrArray as? [NSObject : AnyObject],
                                    underlyingError: error)
                                self.authState?.updateWithAuthorizationError(oauthError!)
                                print("Authorization Error (\(oauthError)). Response: \(responseText)")
                            }
                            else{ print("HTTP: \(httpResponse.statusCode). Response: \(responseText)") }
                            return
                        }
                        if let imageURL = jsonDictionaryOrArray["image"] as? String{
                            if let name = jsonDictionaryOrArray["name"] as? NSString{
                                self.loadImageFromURL(imageURL, name: name as String)
                                print("\(jsonDictionaryOrArray)")
                            }
                        }
                        else if jsonDictionaryOrArray["Error"] != nil{
                            self.imageText.text = jsonDictionaryOrArray["Error"] as? String
                            self.activityLoad.stopAnimating()
                            print(jsonDictionaryOrArray["Error"])
                            print("\(jsonDictionaryOrArray)")
                        }
                    } catch {
                        print("Error while serializing data to JSON")
                        self.dismissViewControllerAnimated(true, completion: nil)
                    }
                } else {
                    print("Non-HTTP response \(error)")
                    return
                }
            }
        }
        postDataTask.resume()
    }

    /**
     *  Loads ImageView and ImageText from response object
     * 
     *  - parameters:
     *    - url: Url of image path
     *    - name: Name of user
     */
    func loadImageFromURL(url: String, name: String){
        print("url: \(url)")
        if let userImageURL = NSURL(string: url){
            let data = NSData(contentsOfURL: userImageURL)
            if (data != nil){
                self.image.image = UIImage(data: data!)
                self.imageText.text = name
                self.activityLoad.stopAnimating()
            } else { return }
            
        }
    }
    
    /**  Dismisses ImageViewController  */
    @IBAction func backButton(sender: AnyObject) {
        self.dismissViewControllerAnimated(true, completion: nil)
    }
}