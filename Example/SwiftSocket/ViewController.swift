//
//  ViewController.swift
//  SwiftSocket
//
//  Created by zhaoxin on 10/26/2021.
//  Copyright (c) 2021 zhaoxin. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.view.backgroundColor = .white
        let btnServer = UIButton(frame: CGRect(x: 20, y: 200, width: 100, height: 50))
        view.addSubview(btnServer)
        btnServer.setTitle("Server", for: .normal)
        btnServer.backgroundColor = .red
        btnServer.addTarget(self, action: #selector(clickServerBtn), for: .touchUpInside)
        
        let btnClient = UIButton(frame: CGRect(x: 20, y: 300, width: 100, height: 50))
        view.addSubview(btnClient)
        btnClient.setTitle("Client", for: .normal)
        btnClient.backgroundColor = .red
        btnClient.addTarget(self, action: #selector(clickClientBtn), for: .touchUpInside)
    }

    @objc func clickServerBtn() {
        self.navigationController?.pushViewController(ServerVC(), animated: true)
    }
    
    @objc func clickClientBtn() {
        self.navigationController?.pushViewController(ClientVC(), animated: true)
    }
}

