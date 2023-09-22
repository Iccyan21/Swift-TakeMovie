//
//  ContentView.swift
//  Original-CameraView
//
//  Created by いっちゃん on 2023/09/20.
//

import SwiftUI
import AVFoundation
import Photos

struct ContentView: View {
    var body: some View {
        VStack {
            CameraView()
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

struct CameraView: View {
    @StateObject var camera = CameraModel()
    var body: some View {
        ZStack{
            //Going to Be Camera preview...
            CameraPreview(camera: camera).ignoresSafeArea(.all,edges: .all)
            VStack{
                if camera.isToken {
                    HStack{
                        Spacer()
                        Button(action: camera.reTake, label: {
                            Image(systemName: "camera")
                                .foregroundColor(.black)
                                .padding()
                                .background(Color.white)
                                .clipShape(Circle())
                        })
                        .padding(.trailing,10)
                    }
                }
                
                Spacer()
                
                HStack {
                    // 保存してもう一度撮影ボタンを表示して撮影すると...
                    if camera.isToken{
                        Button(action: {if !camera.isSaved{camera.savePic()}}, label: {
                            Text(camera.isSaved ? "Saved" : "Save")
                                .foregroundColor(.black)
                                .fontWeight(.semibold)
                                .padding(.vertical,10)
                                .padding(.horizontal,20)
                                .background(Color.white)
                                .clipShape(Capsule())
                        })
                        .padding(.leading)
                        
                        Spacer()
                        
                    } else {
                        Button(action: camera.takePic, label:{
                            ZStack{
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 70,height: 70)
                                //周りデザイン
                                Circle()
                                    .stroke(Color.white,lineWidth: 2)
                                    .frame(width: 75,height: 75)
                            }
                        })
                    }
                }
                .frame(height: 75)
            }
            .onAppear(perform:{
                camera.Check()
            })
        }
    }
}

//カメラモデル
class CameraModel: NSObject,ObservableObject,AVCapturePhotoCaptureDelegate {
    @Published var isToken = false
    
    @Published var session = AVCaptureSession()
    
    @Published var alert = false
    
    //since were going to read pic data ...
    @Published var output = AVCapturePhotoOutput()
    
    // preview
    @Published var preview: AVCaptureVideoPreviewLayer!
    
    //Pic Data ...
    @Published var isSaved = false
    
    @Published var picData = Data(count: 0)
    
    func Check() {
        //最初にカメラをチェックする許可を得ています
        switch AVCaptureDevice.authorizationStatus(for: .video){
        case .authorized:
            secondCheck()
            return
            //Setting Up Session
        case .notDetermined:
            //retusting for permisson
            AVCaptureDevice.requestAccess(for: .video){ (status) in
                if status {
                    self.secondCheck()
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
            
        }
    }
    
    let photoAuthorizationStatus = PHPhotoLibrary.authorizationStatus()
    //写真保存チェック
    func secondCheck() {
        //最初にカメラをチェックする許可を得ています
        switch photoAuthorizationStatus{
        case .authorized:
            setUp()
            return
            //Setting Up Session
        case .notDetermined:
            //retusting for permisson
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized {
                        self.setUp()
                    }
                }
            }
        case .denied:
            self.alert.toggle()
            return
        default:
            return
            
        }
    }
    
    
    func setUp(){
        // setting up camera
        do {
            //setting configs ...
            self.session.beginConfiguration()
            // change for your own ...
            let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            
            let input = try AVCaptureDeviceInput(device: device!)
            
            //cheacking and adding session ...
            if self.session.canAddInput(input){
                self.session.addInput(input)
            }
            // same for output ...
            if self.session.canAddOutput(self.output){
                self.session.addOutput(self.output)
            }
            self.session.commitConfiguration()
            print("Good Condistion")
        }
        catch {
            print(error.localizedDescription)
        }
    }
    // 撮影処理
    func takePic() {
        print("Success")
        DispatchQueue.global(qos: .background).async {
            self.output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
            self.session.stopRunning()
            
            DispatchQueue.main.sync {
                withAnimation{self.isToken.toggle()}
                print("No plogrem")
            }
        }
    }
    func reTake() {
        print("Replay")
        DispatchQueue.global(qos:.background).async {
            self.session.startRunning()
            
            DispatchQueue.main.async {
                withAnimation{self.isToken.toggle()}
                
                self.isSaved = false
            }
        }
    }
    //画像取得処理
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            print("Error capturing photo: \(error.localizedDescription)")
            return
        }

        if error != nil {
            return
        }
        print("pic taken...")
        
        guard let imageData = photo.fileDataRepresentation() else {return}
        
        self.picData = imageData
    }
    //写真保存処理
    func savePic() {
        let image = UIImage(data: self.picData)!
        
        //写真を保存
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        
        self.isSaved = true
        
        print("saved Successfulley...")
    }
}

struct CameraPreview: UIViewRepresentable {
    
    @ObservedObject var camera : CameraModel
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        camera.preview = AVCaptureVideoPreviewLayer(session: camera.session)
        camera.preview.frame = view.frame
        
        // Your Own Properties
        camera.preview.videoGravity = .resizeAspectFill
        view.layer.addSublayer(camera.preview)
        
        //カメラ起動
        camera.session.startRunning()
        
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}
