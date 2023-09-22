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
                    if camera.isRecording {
                        Button(action: camera.stopRecording, label: {
                            Text("Stop")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .clipShape(Circle())
                        })
                    } else {
                        Button(action: camera.startRecording, label: {
                            Text("Record")
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.red)
                                .clipShape(Circle())
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
    
    //撮影機能定義
    var captureSession: AVCaptureSession!
    var videoOutput: AVCaptureMovieFileOutput!
    let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    let audioDevice = AVCaptureDevice.default(for: .audio)
    @Published var isRecording = false
    
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
            checkMicrophonePermission()
            return
            //Setting Up Session
        case .notDetermined:
            //retusting for permisson
            PHPhotoLibrary.requestAuthorization { newStatus in
                DispatchQueue.main.async {
                    if newStatus == .authorized {
                        self.checkMicrophonePermission()
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
    //マイクチェック
    func checkMicrophonePermission() {
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            // マイクのアクセス許可がある場合の処理
            print("Microphone access granted")
            self.setUp()
        case .denied:
            // マイクのアクセス許可がない場合の処理
            print("Microphone access denied")
        case .undetermined:
            // ユーザーがまだマイクのアクセス許可を選択していない場合、許可をリクエスト
            audioSession.requestRecordPermission { allowed in
                DispatchQueue.main.async {
                    if allowed {
                        // ユーザーがマイクのアクセス許可を与えた場合の処理
                        print("Microphone access granted")
                        self.setUp()
                    } else {
                        // ユーザーがマイクのアクセス許可を拒否した場合の処理
                        print("Microphone access denied")
                    }
                }
            }
        @unknown default:
            // 未知のケース（将来のバージョンのiOSで新しいケースが追加された場合）
            break
        }
    }
    
    
    
    func setUp(){
        // setting up camera
        do {
            //setting configs ...
            self.session.beginConfiguration()
            
            // Video Input
            if let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                if self.session.canAddInput(videoInput){
                    self.session.addInput(videoInput)
                }
            }
            
            // Audio Input
            if let audioDevice = AVCaptureDevice.default(for: .audio) {
                let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                if self.session.canAddInput(audioInput) {
                    self.session.addInput(audioInput)
                }
            }
            
            // Photo Output
            if self.session.canAddOutput(self.output){
                self.session.addOutput(self.output)
            }
            
            // Movie File Output
            videoOutput = AVCaptureMovieFileOutput()
            if self.session.canAddOutput(videoOutput) {
                self.session.addOutput(videoOutput)
            }
            
            self.session.commitConfiguration()
            
            // Start the session after configuration has been committed
            self.session.startRunning()
            
            print("Good Condition")
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
    
    //撮影処理
    func startRecording() {
        guard !isRecording else { return }
        
        let outputDirectory = FileManager.default.temporaryDirectory
        let outputFilePath = outputDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov").path
        let outputFileURL = URL(fileURLWithPath: outputFilePath)
        
        videoOutput.startRecording(to: outputFileURL, recordingDelegate: self)
        isRecording = true
    }
    
    func stopRecording() {
        guard isRecording else {return}
        videoOutput.stopRecording()
        isRecording = false
    }
    
    func saveVideo(at url: URL) {
        // Check if the video at the URL can be saved to the photo library
        if UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(url.path) {
            // Save the video to the photo library
            UISaveVideoAtPathToSavedPhotosAlbum(url.path, self, #selector(video(_:didFinishSavingWithError:contextInfo:)), nil)
        }
    }

    @objc func video(_ videoPath: String, didFinishSavingWithError error: Error?, contextInfo info: AnyObject) {
        if let error = error {
            // Handle the error
            print("Error saving video: \(error.localizedDescription)")
        } else {
            print("Video saved successfully")
        }
    }
}

extension CameraModel: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput,
                    didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection],
                    error: Error?) {
        if let error = error {
            print("Error recording movie: \(error.localizedDescription)")
        } else {
            print("Successfully recorded movie to: \(outputFileURL)")
            // Save the recorded video to the photo library
            saveVideo(at: outputFileURL)
        }
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
        
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {
        
    }
}
