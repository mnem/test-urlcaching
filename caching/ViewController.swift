//
//  ViewController.swift
//  caching
//
//  Created by David Wagner on 08/10/2017.
//  Copyright © 2017 David Wagner. All rights reserved.
//

import UIKit

final class ViewController: UIViewController {
    
    @IBOutlet weak var urlTextField: UITextField!
    @IBOutlet weak var outputTextView: UITextView!
    
    static var activeSelf:ViewController?
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ViewController.activeSelf = self
    }
    
    static var session: URLSession = {
        let config = URLSessionConfiguration.default
        
        let cacheMemorySize = 1024 * 1024 * 50;
        let cacheDiskSize = 1024 * 1024 * 500;
        config.urlCache = URLCache(memoryCapacity: cacheMemorySize, diskCapacity: cacheDiskSize, diskPath: "foobarcache")
        config.requestCachePolicy = .useProtocolCachePolicy
        
        // NOTE: The watcher won't record anything while we're using completion handlers
        let watcher = SessionWatcher(logger: { (message) in
            ViewController.log(message)
        })
        let session = URLSession(configuration: config, delegate: watcher, delegateQueue: nil)
        return session
    }()
    
    @IBAction func onFetch(_ sender: Any) {
        guard let urlString = urlTextField.text, let url = URL(string: urlString) else {
            ViewController.log("Invalid URL: \(String(describing:urlTextField.text))")
            return
        }

// This works too, but the defaults are fine when just chucking a URL at it.
//        var request = URLRequest(url: url)
//        request.cachePolicy = .useProtocolCachePolicy

        if let cache = ViewController.session.configuration.urlCache {
            ViewController.log("Cache memory use: \(cache.currentMemoryUsage), disk use: \(cache.currentDiskUsage)")
        }
        
        let task = ViewController.session.dataTask(with: url)
        { (data, response, error) in
            if let error = error {
                ViewController.log("Task finished with error: \(String(describing:error))")
                return
            }

            guard let response = response else {
                ViewController.log("Task finished without error, but response was missing")
                return
            }

            guard let data = data else {
                ViewController.log("Task finished without error, but data was missing")
                return
            }

            let dataString: String
            if let converted = String(data: data, encoding: .utf8) {
                dataString = converted
            } else {
                dataString = "<Could not convert to string>"
            }
            ViewController.log("Task finished.\ndata:\n\(dataString)\nresponse:\n\(response)")

            if let cache = ViewController.session.configuration.urlCache {
                ViewController.log("Cache memory use: \(cache.currentMemoryUsage), disk use: \(cache.currentDiskUsage)")
            }
        }
        
        ViewController.log("Starting fetch for \(urlString)")
        DispatchQueue.global(qos:.background).async {
            task.resume()
        }
    }
}

// MARK: - Logging
extension ViewController {
    static func log(_ m: String) {
        let now  = Date()
        let message = "\(now): \(m)\n"
        
        if let activeSelf = ViewController.activeSelf, let textView = activeSelf.outputTextView {
            DispatchQueue.main.async {
                textView.text = textView.text + message
                if(textView.text.count > 0 ) {
                    let bottom = NSMakeRange(textView.text.count - 1, 1)
                    textView.scrollRangeToVisible(bottom)
                }
            }
        } else {
            print(message)
        }
    }
}

// MARK: - Session watcher. This isn't really triggered while completion handlers are in use
class SessionWatcher: NSObject {
    let logger: (String) -> Void
    init(logger: @escaping (String) -> Void) {
        self.logger = logger
    }
}

extension SessionWatcher: URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, taskIsWaitingForConnectivity task: URLSessionTask) {
        logger("Task is waiting for connectivity")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        logger("Task completed with error: \(String(describing:error))")
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        logger("Task will redirect")
        completionHandler(request)
    }
}

extension SessionWatcher: URLSessionDataDelegate {
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        logger("Task received response from server:\n\(response)")
        completionHandler(.allow)
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, willCacheResponse proposedResponse: CachedURLResponse, completionHandler: @escaping (CachedURLResponse?) -> Void) {
        logger("Task will cache proposed response:\n\(proposedResponse)")
        completionHandler(proposedResponse)
    }
}

