import Photos
import SwiftUI
import UIKit

enum PhotoAuthState: Equatable {
    case unknown
    case authorized
    case limited
    case denied
}

@Observable
final class PhotoLibraryService {
    private(set) var authState: PhotoAuthState

    @ObservationIgnored
    private let imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.totalCostLimit = 400 * 1024 * 1024
        return cache
    }()

    init() {
        authState = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func cachedImage(for identifier: String) -> UIImage? {
        imageCache.object(forKey: identifier as NSString)
    }

    func requestAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authState = Self.map(status)
    }

    func refreshAuthState() {
        authState = Self.map(PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func fetchAssetsNewestFirst() -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: false)
        ]
        options.predicate = NSPredicate(
            format: "mediaType == %d || mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        return PHAsset.fetchAssets(with: options)
    }

    func requestImage(for asset: PHAsset, targetSize: CGSize) async -> UIImage? {
        let key = asset.localIdentifier as NSString
        if let cached = imageCache.object(forKey: key) {
            return cached
        }

        let gate = ResumeGate()
        let image: UIImage? = await withCheckedContinuation { (continuation: CheckedContinuation<UIImage?, Never>) in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                if gate.take() {
                    continuation.resume(returning: image)
                }
            }
        }

        if let image {
            let cost = Int(image.size.width * image.size.height * 4)
            imageCache.setObject(image, forKey: key, cost: cost)
        }
        return image
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

private final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var taken = false

    func take() -> Bool {
        lock.lock(); defer { lock.unlock() }
        if taken { return false }
        taken = true
        return true
    }
}
