//
//  ViewController.swift
//  gazeRemote
//
//  Created by Tommy on 2021/10/15.
//

import UIKit
import AVFoundation
import Vision
import Alamofire

class ViewController: UIViewController {
//    @IBOutlet var inputButton: UIButton!
    
    @IBOutlet var powerButton: UIButton!
    @IBOutlet var tvInputButton: UIButton!
    
    var avCaptureSession = AVCaptureSession()
    
    var results: [Int] = []
    
    let baseUrl = "https://api.nature.global/1/"
    var token: String = ""
    let tvButtonIds: [String:String] = [
        "power": "d9558865-591e-43b1-bf88-72a908f8cb98",
        "input": "2c2bf0ff-f5dc-476e-85c7-0e72f9699f2c",
        "top": "db3ff1f5-b2c9-4798-bfe2-2f5d5494131a",
        "bottom": "f9f8ba0d-215d-4686-86e8-af2a126317cc",
        "left": "0987fc8b-7182-4bb6-aa69-4415cadbe4b5",
        "right": "b26e0096-95a2-453a-bcb6-a21d1121c1e5",
        "enter": "6b45a920-711d-4f3a-8735-d103a473d953",
        "back": "4a85da2f-95af-4404-8238-e160a0ba3da0",
        "mute": "2889f781-bb93-49e2-9291-ac3758af3082",
        "minus": "f41ca104-00da-4151-9edd-bd18e29e887a",
        "plus": "3dd34695-e0bd-4069-98cf-c33b0fc27ee3",
    ]
    
    let appleTvButtonIds: [String:String] = [
        "menu": "531afe4f-6b2e-46ea-a814-1f1deb8ebcc6",
        "playPause": "f65a8628-eb53-42b1-a11a-839cfb709f14",
    ]
    
    var lastClosingEye: Date?
    
    var eyeYaw: Double?
    
    var device: String!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        setupCamera()
//        buildInputButton()
        self.powerButton.layer.borderWidth = 10
        self.tvInputButton.layer.borderWidth = 10
        self.powerButton.layer.borderColor = UIColor.clear.cgColor
        self.tvInputButton.layer.borderColor = UIColor.clear.cgColor
        
        var property: Dictionary<String, Any> = [:]
        let path = Bundle.main.path(forResource: "Token", ofType: "plist")
        let configurations = NSDictionary(contentsOfFile: path!)
        if let _: [String : Any]  = configurations as? [String : Any] {
            property = configurations as! Dictionary<String, Any>
        }
        token = property["token"] as! String
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        avCaptureSession.stopRunning()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toDone" {
            let destination = segue.destination as! ResultsViewController
            destination.results = self.results
        }
    }
    
//    func buildInputButton() {
//        let deviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
//        let devices = deviceDiscoverySession.devices
//
//        var actions: [UIAction] = []
//
//        for device in devices {
//            let action = UIAction(title: device.localizedName, handler: { _ in
//                self.avCaptureSession.stopRunning()
//                self.avCaptureSession = AVCaptureSession()
//                self.setupCamera(device)
//            })
//            actions.append(action)
//        }
//
//        self.inputButton.menu = UIMenu(title: "Camera Input", image: UIImage(systemName: "camera.fill"), identifier: nil, options: .displayInline, children: actions)
//        self.inputButton.showsMenuAsPrimaryAction = true
//    }
    
    func setupCamera(_ selectedDevice: AVCaptureDevice? = nil) {
        avCaptureSession.sessionPreset = .photo
        
        var device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        
        if selectedDevice != nil {
            device = selectedDevice
        }
        
        let input = try! AVCaptureDeviceInput(device: device!)
        avCaptureSession.addInput(input)
        
        let videoDataOutput = AVCaptureVideoDataOutput()
        videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String : Int(kCVPixelFormatType_32BGRA)]
        videoDataOutput.alwaysDiscardsLateVideoFrames = true
        videoDataOutput.setSampleBufferDelegate(self, queue: .global())
        
        avCaptureSession.addOutput(videoDataOutput)
        avCaptureSession.startRunning()
    }
    
    func getFaceObservations(pixelBuffer: CVPixelBuffer) {
        let landmarkRequest = VNDetectFaceLandmarksRequest { [self] (request, error) in
            guard let faces = request.results as? [VNFaceObservation] else { return }
            
            if let landmarks = faces.first?.landmarks {
                if let rightEye = relativeCoordinate(eye: landmarks.rightEye?.normalizedPoints ?? [], pupil: landmarks.rightPupil?.normalizedPoints.first), let leftEye = relativeCoordinate(eye: landmarks.leftEye?.normalizedPoints ?? [], pupil: landmarks.leftEye?.normalizedPoints.first) {
                    
                    if let rX = rightEye.first, let lX = leftEye.first, let yaw = self.eyeYaw {
                        DispatchQueue.main.async {
                            let faceAngle = yaw > 0 ? 0.0 : 1.0
                            if ((((rX + lX) / 2) + faceAngle) / 2) < 0 {
                                self.powerButton.layer.borderColor = UIColor.red.cgColor
                                self.tvInputButton.layer.borderColor = UIColor.clear.cgColor
                                
                                if self.detectBlinking(bottom: landmarks.leftEye?.normalizedPoints[6], top: landmarks.leftEye?.normalizedPoints[2]) && self.detectBlinking(bottom: landmarks.rightEye?.normalizedPoints[6], top: landmarks.rightEye?.normalizedPoints[2]) {
                                    if self.lastClosingEye != nil {
                                        if Date().timeIntervalSince(self.lastClosingEye!) > 3 {
                                            if self.device == "tv" {
                                                self.pressButton(id: tvButtonIds["power"] ?? "")
                                            } else if self.device == "apple" {
                                                self.pressButton(id: appleTvButtonIds["menu"] ?? "")
                                            }
                                            self.lastClosingEye = nil
                                        }
                                    } else {
                                        self.lastClosingEye = Date()
                                    }
                                } else {
                                    self.lastClosingEye = nil
                                }
                            } else {
                                self.powerButton.layer.borderColor = UIColor.clear.cgColor
                                self.tvInputButton.layer.borderColor = UIColor.red.cgColor
                                
                                if self.detectBlinking(bottom: landmarks.leftEye?.normalizedPoints[6], top: landmarks.leftEye?.normalizedPoints[2]) && self.detectBlinking(bottom: landmarks.rightEye?.normalizedPoints[6], top: landmarks.rightEye?.normalizedPoints[2]) {
                                    if self.lastClosingEye != nil {
                                        if Date().timeIntervalSince(self.lastClosingEye!) > 3 {
                                            if self.device == "tv" {
                                                self.pressButton(id: tvButtonIds["input"] ?? "")
                                            } else if self.device == "apple" {
                                                self.pressButton(id: appleTvButtonIds["playPause"] ?? "")
                                            }
                                            self.lastClosingEye = nil
                                        }
                                    } else {
                                        self.lastClosingEye = Date()
                                    }
                                } else {
                                    self.lastClosingEye = nil
                                }
                            }
                        }
                    } else {
                        self.results.append(0)
                    }
                } else {
                    self.results.append(0)
                }
            }
        }
        
        if #available(iOS 12.0, *) {
            landmarkRequest.revision = 2
        }
        
        let rectangleRequest = VNDetectFaceRectanglesRequest { [self] (request, error) in
            guard let faces = request.results as? [VNFaceObservation] else {
                return
            }
            
            if let face = faces.first {
                if let yaw = face.yaw?.doubleValue {
                    self.eyeYaw = rad2deg(yaw)
                }
            }
        }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([landmarkRequest, rectangleRequest])
    }
    
    func rad2deg(_ number: Double) -> Double {
        return number * 180 / .pi
    }
    
    func relativeCoordinate(eye: [CGPoint], pupil: CGPoint?) -> [Double]? {
        guard let pupil = pupil else { return nil }
        
        if eye.count == 8 {
            let centerX = (eye[0].x + eye[4].x) / 2
            let multiplierX = 1 / (eye[4].x - centerX)
            let rX = (pupil.x - centerX) * multiplierX
            
            let centerY = (eye[1].y + eye[5].y) / 2
            let multiplierY = 1 / (eye[5].y - centerY)
            let rY = -((centerY - pupil.y) * multiplierY)
            
            return [rX, rY]
        } else {
            self.results.append(0)
            return nil
        }
    }
    
    func detectBlinking(bottom: CGPoint?, top: CGPoint?) -> Bool {
        guard let bottom = bottom, let top = top else {
            return false
        }
        return (bottom.y - top.y).magnitude < 0.03 ? true : false
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        getFaceObservations(pixelBuffer: pixelBuffer)
    }
}

extension ViewController {
    func pressButton(id: String) {
        let requestUrl  = baseUrl + "signals/" + id + "/send"
        let Auth_header: HTTPHeaders = [
            "Authorization" : "Bearer " + token
        ]
        AF.request(requestUrl, method: .post, parameters: nil, headers: Auth_header).responseJSON{ response in
            if let error = response.error {
                print("Error: \(error)")
                self.results.append(0)
            } else {
                print("Success")
                self.results.append(1)
            }
        }
    }
}
