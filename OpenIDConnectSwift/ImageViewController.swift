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
        sendDemoApiRequest(appConfig.apiEndpoint! as URL, accessToken: (authState?.lastTokenResponse!.accessToken)!)
    }
    
    override func didReceiveMemoryWarning() { super.didReceiveMemoryWarning() }
    
    /**
     *  Calls endpoint on given server to decode and validate access token
     *
     *  - parameters:
     *    - url: NSURL of server endpoint
     *    - accessToken: Current token
     */
    func sendDemoApiRequest(_ url: URL, accessToken: String){
        print("Performing DEMO API request without auto-refresh")
        
        // Create Requst to Demo API endpoint, with access_token in Authorization Header
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let authorizationHeaderValue = "Bearer \(accessToken)"
        request.addValue(authorizationHeaderValue, forHTTPHeaderField: "Authorization")
              
        let config = URLSessionConfiguration.default
        let session = URLSession(configuration: config)
        
        //Perform HTTP Request
        let postDataTask = session.dataTask(with: request, completionHandler: {
            data, response, error in
            DispatchQueue.main.async{
                    
                if let httpResponse = response as? HTTPURLResponse {
                    do{
                        let jsonDictionaryOrArray = try JSONSerialization.jsonObject(with: data!, options: []) as! [String:Any]
                        if ( httpResponse.statusCode != 200 ){
                            let responseText = NSString(data: data!, encoding: String.Encoding.utf8.rawValue)
                            if ( httpResponse.statusCode == 401 ){
                                let oauthError = OIDErrorUtilities.resourceServerAuthorizationError(withCode: 0,
                                    errorResponse: jsonDictionaryOrArray,
                                    underlyingError: error)
                                self.authState?.update(withAuthorizationError: oauthError!)
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
                            print(jsonDictionaryOrArray["Error"]!)
                            print("\(jsonDictionaryOrArray)")
                        }
                    } catch {
                        print("Error while serializing data to JSON")
                        self.dismiss(animated: true, completion: nil)
                    }
                } else {
                    print("Non-HTTP response \(error)")
                    return
                }
            }
        }) 
        postDataTask.resume()
    }

    /**
     *  Loads ImageView and ImageText from response object
     * 
     *  - parameters:
     *    - url: Url of image path
     *    - name: Name of user
     */
    func loadImageFromURL(_ url: String, name: String){
        print("url: \(url)")
        if let userImageURL = URL(string: url){
            let data = try? Data(contentsOf: userImageURL)
            if (data != nil){
                self.image.image = UIImage(data: data!)
                self.imageText.text = name
                self.activityLoad.stopAnimating()
            } else { return }
            
        }
    }
    
    /**  Dismisses ImageViewController  */
    @IBAction func backButton(_ sender: AnyObject) {
        self.dismiss(animated: true, completion: nil)
    }
}
