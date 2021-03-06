//
//  PreviewViewController.swift
//  CrissCross
//
//  Created by Kyle Lee on 9/4/20.
//  Copyright © 2020 Kilo Loco. All rights reserved.
//

import Amplify
import Combine
import UIKit

final class PreviewViewController: UIViewController {

    private var uploadVideoToken: AnyCancellable?
    
    private var actionToken: AnyCancellable?
    
    private let ui = PreviewView()
    
    private let videoUrl: URL
    
    init(videoUrl: URL) {
        self.videoUrl = videoUrl
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError()
    }
    
    override func loadView() {
        view = ui
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configure()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ui.playVideo(at: videoUrl)
    }

    private func configure() {
        
        actionToken = ui.actionPublisher.sink { [weak self] action in
            switch action {
            case .back: self?.dismiss(animated: true)
            case .next: self?.showPostAlert()
            }
        }
    }
    
    private func showPostAlert() {
        let alert = UIAlertController(title: "New Post", message: nil, preferredStyle: .alert)
        alert.addTextField {
            $0.placeholder = "Username"
        }
        alert.addTextField {
            $0.placeholder = "Caption"
        }
        let postAction = UIAlertAction(title: "Post", style: .default) { [weak self, weak alert] _ in
            let user = alert?.textFields?.first?.text ?? ""
            let caption = alert?.textFields?.last?.text ?? ""
            self?.postClip(from: user, with: caption)
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(postAction)
        alert.addAction(cancelAction)
        present(alert, animated: true)
    }
    
    private func postClip(from user: String, with caption: String) {
        print(user)
        print(caption)
        
        let key = UUID().uuidString + ".mov"
        
        
        uploadVideoToken = Amplify.Storage.uploadFile(key: key, local: videoUrl)
            .resultPublisher
            .mapError { _ in UploadError.storage }
            .flatMap { _ -> AnyPublisher<Clip, UploadError> in
                let now = Temporal.DateTime(Date())
                let clip = Clip(username: user, caption: caption, creationDate: now, videoKey: key)
                return Amplify.DataStore.save(clip)
                    .mapError { _ in UploadError.dataStore }
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .sink(
                receiveCompletion: { print($0) },
                receiveValue: { [weak self] in
                    print("saved clip:", $0)
                    self?.presentingViewController?.dismiss(animated: true)
                }
            )
    }
}

enum UploadError: Error {
    case storage
    case dataStore
}
