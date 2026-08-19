import Photos
import SwiftUI

enum PhotoAuthState: Equatable {
    case unknown
    case authorized
    case limited
    case denied
}

@Observable
final class PhotoLibraryService {
    private(set) var authState: PhotoAuthState

    init() {
        authState = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authState = Self.map(status)
    }

    func refreshAuthState() {
        authState = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    private static func map(_ status: PHAuthorizationStatus) -> PhotoAuthState {
        switch status {
        case .notDetermined: return .unknown
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied, .restricted: return .denied
        @unknown default: return .denied
        }
    }
}
