import Foundation
import GoogleMobileAds
import UserMessagingPlatform

@MainActor
final class AdService: NSObject, ObservableObject, FullScreenContentDelegate {
    @Published private(set) var privacyOptionsRequired = false

    private var interstitial: InterstitialAd?
    private var didStartAds = false
    private var isLoading = false

    func prepare() {
        Task { await gatherConsentAndLoad() }
    }

    func showAfterSuccessfulPass() {
        guard let interstitial else { return }
        self.interstitial = nil
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            interstitial.present(from: nil)
        }
    }

    func showPrivacyOptions() {
        Task {
            try? await ConsentForm.presentPrivacyOptionsForm(from: nil)
            refreshPrivacyStatus()
        }
    }

    private func gatherConsentAndLoad() async {
        let parameters = RequestParameters()
        await withCheckedContinuation { continuation in
            ConsentInformation.shared.requestConsentInfoUpdate(with: parameters) { _ in
                continuation.resume()
            }
        }
        try? await ConsentForm.loadAndPresentIfRequired(from: nil)
        refreshPrivacyStatus()
        guard ConsentInformation.shared.canRequestAds else { return }
        startAndLoadIfNeeded()
    }

    private func refreshPrivacyStatus() {
        privacyOptionsRequired = ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private func startAndLoadIfNeeded() {
        if !didStartAds {
            didStartAds = true
            MobileAds.shared.start()
        }
        Task { await loadInterstitial() }
    }

    private func loadInterstitial() async {
        guard !isLoading, interstitial == nil else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let ad = try await InterstitialAd.load(
                with: AppConfiguration.interstitialAdUnitID,
                request: Request()
            )
            ad.fullScreenContentDelegate = self
            interstitial = ad
        } catch {
            // Ads are best-effort and must never block the core Wallet flow.
        }
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { await loadInterstitial() }
    }

    func ad(
        _ ad: FullScreenPresentingAd,
        didFailToPresentFullScreenContentWithError error: Error
    ) {
        Task { await loadInterstitial() }
    }
}
