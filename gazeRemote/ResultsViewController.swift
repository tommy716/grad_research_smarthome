//
//  ResultsViewController.swift
//  gazeRemote
//
//  Created by Tommy on 2021/11/29.
//

import UIKit

class ResultsViewController: UIViewController {
    
    @IBOutlet var successLabel: UILabel!
    @IBOutlet var failLabel: UILabel!
    @IBOutlet var accuracyLabel: UILabel!
    
    var results: [Int]!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if results != nil {
            successLabel.text = "Success: \(results.filter { $0 == 1 }.count)"
            failLabel.text = "Fail: \(results.filter { $0 == 0 }.count)"
            accuracyLabel.text = "Accuracy: \(Double(results.filter { $0 == 1 }.count) / Double(results.count))"
        }
    }
}
