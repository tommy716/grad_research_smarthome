//
//  MenuViewController.swift
//  gazeRemote
//
//  Created by Tommy on 2021/12/03.
//

import UIKit

class MenuViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "tv" {
            let destination = segue.destination as! ViewController
            destination.device = "tv"
        } else if segue.identifier == "apple" {
            let destination = segue.destination as! ViewController
            destination.device = "apple"
        }
    }
}
