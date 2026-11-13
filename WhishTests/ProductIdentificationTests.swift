import Foundation
import ImageIO
import Testing
import UIKit
@testable import Whish

// MARK: - Edge Function responses

struct IdentifyResponseDecoderTests {

    private let periodEnd = ISO8601DateFormatter().date(from: "2026-12-01T00:00:00Z")!

    private func decode(_ status: Int, _ json: String) throws -> ProductIdentificationResponse {
        try IdentifyResponseDecoder.decode(status: status, data: Data(json.utf8))
    }

    @Test func decodesASuccessfulIdentification() throws {
        let response = try decode(200, """
        {"result":{"status":"identified","title":"Nike Air Max 90","brand":"Nike","model":"Air Max 90",
         "color":"White/Infrared","category":"Sneakers","description":"Classic low-top sneaker.",
         "estimatedPrice":{"low":120,"high":140,"currency":"USD"},"searchQuery":"nike air max 90","confidence":0.91},
         "usage":{"used":2,"limit":5,"remaining":3,"periodEnd":"2026-12-01T00:00:00.000Z"}}
        """)
        #expect(response.result.status == .identified)
        #expect(response.result.title == "Nike Air Max 90")
        #expect(response.result.estimatedPrice == .init(low: 120, high: 140, currency: "USD"))
        #expect(response.result.foundProduct)
        #expect(response.usage == IdentifyUsage(used: 2, limit: 5, remaining: 3, periodEnd: periodEnd))
    }

    @Test func unknownStatusFallsBackToUnclear() throws {
        let response = try decode(200, """
        {"result":{"status":"something_new","title":"","brand":null,"model":null,"color":null,"category":"",
         "description":"","estimatedPrice":null,"searchQuery":"","confidence":0}}
        """)
        #expect(response.result.status == .unclear)
        #expect(!response.result.foundProduct)
        #expect(response.usage == nil)
    }

    @Test func mapsQuotaExceededWithUsage() {
        #expect(throws: ProductIdentificationError.quotaExceeded(
            IdentifyUsage(used: 5, limit: 5, remaining: 0, periodEnd: periodEnd)
        )) {
            try decode(429, #"{"code":"quota_exceeded","error":"x","usage":{"used":5,"limit":5,"remaining":0,"periodEnd":"2026-12-01T00:00:00.000Z"}}"#)
        }
    }

    @Test func mapsKnownErrorCodes() {
        #expect(throws: ProductIdentificationError.notSignedIn) { try decode(401, #"{"code":"unauthorized","error":"x"}"#) }
        #expect(throws: ProductIdentificationError.notConfigured) { try decode(503, #"{"code":"not_configured","error":"x"}"#) }
        #expect(throws: ProductIdentificationError.busy) { try decode(503, #"{"code":"busy","error":"x"}"#) }
        #expect(throws: ProductIdentificationError.imageTooLarge) { try decode(413, #"{"code":"image_too_large","error":"x"}"#) }
        #expect(throws: ProductIdentificationError.invalidImage) { try decode(400, #"{"code":"bad_request","error":"x"}"#) }
        #expect(throws: ProductIdentificationError.refused) { try decode(422, #"{"code":"refused","error":"x"}"#) }
    }

    @Test func otherFailuresCarryTheServerMessage() {
        #expect(throws: ProductIdentificationError.server("Couldn't reach the identification service. Try again.")) {
            try decode(502, #"{"code":"upstream_error","error":"Couldn't reach the identification service. Try again."}"#)
        }
        #expect(throws: ProductIdentificationError.server("Something went wrong (500). Try again.")) {
            try decode(500, "<html>gateway</html>")
        }
        // A bare 401 from the gateway still means "sign in".
        #expect(throws: ProductIdentificationError.notSignedIn) { try decode(401, "") }
    }

    @Test func malformedSuccessBodyIsAServerError() {
        #expect(throws: ProductIdentificationError.server("Couldn't read the result. Try again.")) {
            try decode(200, #"{"result":42}"#)
        }
    }

    @Test func onlyTransientErrorsOfferRetry() {
        #expect(ProductIdentificationError.network.isRetryable)
        #expect(ProductIdentificationError.busy.isRetryable)
        #expect(!ProductIdentificationError.quotaExceeded(nil).isRetryable)
        #expect(!ProductIdentificationError.notSignedIn.isRetryable)
    }
}

// MARK: - Form pre-fill and display

struct IdentifyPrefillTests {

    private let sneakers = MockProductIdentificationService.sneakers

    @Test func fillsEmptyFields() {
        let prefill = IdentifyPrefill.make(from: sneakers, currentTitle: "  ", currentNotes: "")
        #expect(prefill == IdentifyPrefill(
            title: "Nike Air Max 90",
            notes: "Classic low-top running sneaker with a visible Air unit in the heel.",
            brand: "Nike",
            color: "White/Infrared"
        ))
    }

    @Test func neverOverwritesWhatTheUserTyped() {
        let prefill = IdentifyPrefill.make(from: sneakers, currentTitle: "My shoes", currentNotes: "Size 42")
        #expect(prefill.title == nil)
        #expect(prefill.notes == nil)
        #expect(prefill.brand == "Nike")
    }

    @Test func noProductMeansNoChanges() {
        let nothing = ProductIdentification(
            status: .notAProduct, title: "", brand: nil, model: nil, color: nil, category: "",
            description: "A sunset.", estimatedPrice: nil, searchQuery: "", confidence: 0.9
        )
        #expect(IdentifyPrefill.make(from: nothing, currentTitle: "", currentNotes: "") == IdentifyPrefill())
    }

    @Test func estimateMidpointRoundsToWholeAmounts() {
        #expect(ProductIdentification.PriceEstimate(low: 120, high: 141, currency: "USD").midpoint == 131)
        #expect(ProductIdentification.PriceEstimate(low: 25, high: 25, currency: "GBP").midpoint == 25)
    }

    @Test func estimateRangeText() {
        let us = Locale(identifier: "en_US")
        #expect(ProductIdentification.PriceEstimate(low: 120, high: 140, currency: "USD").rangeText(locale: us) == "$120–$140")
        #expect(ProductIdentification.PriceEstimate(low: 99, high: 99, currency: "USD").rangeText(locale: us) == "$99")
        #expect(ProductIdentification.PriceEstimate(low: 80, high: 95, currency: "GBP").rangeText(locale: Locale(identifier: "en_GB")) == "£80–£95")
    }

    @Test func shoppingSearchURLEncodesTheQuery() throws {
        let url = try #require(sneakers.shoppingSearchURL)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.host == "www.google.com")
        #expect(components.queryItems?.first { $0.name == "tbm" }?.value == "shop")
        #expect(components.queryItems?.first { $0.name == "q" }?.value == "Nike Air Max 90 white infrared")
    }
}

// MARK: - Identify flow shared by both add-item forms

private final class FakeIdentifyService: ProductIdentificationService, @unchecked Sendable {
    let requiresSignIn: Bool
    let outcome: Result<ProductIdentificationResponse, ProductIdentificationError>
    private(set) var calls = 0

    init(requiresSignIn: Bool = true,
         outcome: Result<ProductIdentificationResponse, ProductIdentificationError>) {
        self.requiresSignIn = requiresSignIn
        self.outcome = outcome
    }

    func identify(imageData: Data, currency: String) async throws -> ProductIdentificationResponse {
        calls += 1
        return try outcome.get()
    }
}

@MainActor
@Suite(.serialized)
struct IdentifyControllerTests {

    private let usage = IdentifyUsage(used: 2, limit: 5, remaining: 3, periodEnd: .distantFuture)
    private let photo = Data([0xFF, 0xD8, 0xFF])

    private func freshDefaults(consent: Bool = false) -> UserDefaults {
        let defaults = UserDefaults(suiteName: "IdentifyControllerTests.\(UUID().uuidString)")!
        if consent { defaults.set(true, forKey: IdentifyController.consentKey) }
        return defaults
    }

    private func success() -> Result<ProductIdentificationResponse, ProductIdentificationError> {
        .success(ProductIdentificationResponse(result: MockProductIdentificationService.sneakers, usage: usage))
    }

    /// The request runs in a Task; give it a moment to land.
    private func settle(_ controller: IdentifyController) async {
        for _ in 0..<200 where controller.phase == .running {
            try? await Task.sleep(for: .milliseconds(5))
        }
        try? await Task.sleep(for: .milliseconds(20))
    }

    @Test func signedOutUsersAreAskedToSignInFirst() async {
        let service = FakeIdentifyService(outcome: success())
        let controller = IdentifyController(service: service, defaults: freshDefaults(consent: true))
        controller.start(imageData: photo, currency: "USD", isSignedIn: false) { _ in }
        await settle(controller)
        #expect(controller.phase == .failed(.notSignedIn))
        #expect(!controller.isShowingConsent)
        #expect(service.calls == 0)

        controller.signedInChanged(true)
        #expect(controller.phase == .idle)
    }

    @Test func asksForConsentThenRunsTheWaitingRequest() async {
        let service = FakeIdentifyService(outcome: success())
        let defaults = freshDefaults()
        let controller = IdentifyController(service: service, defaults: defaults)
        var applied: [ProductIdentification] = []

        controller.start(imageData: photo, currency: "USD", isSignedIn: true) { applied.append($0) }
        #expect(controller.isShowingConsent)
        #expect(controller.phase == .idle)
        #expect(service.calls == 0)

        controller.grantConsent()
        await settle(controller)
        #expect(defaults.bool(forKey: IdentifyController.consentKey))
        #expect(controller.phase == .done(MockProductIdentificationService.sneakers))
        #expect(applied == [MockProductIdentificationService.sneakers])
        #expect(controller.usage == usage)
        #expect(service.calls == 1)
    }

    @Test func quotaErrorsKeepTheReportedAllowance() async {
        let exhausted = IdentifyUsage(used: 5, limit: 5, remaining: 0, periodEnd: .distantFuture)
        let service = FakeIdentifyService(outcome: .failure(.quotaExceeded(exhausted)))
        let controller = IdentifyController(service: service, defaults: freshDefaults(consent: true))
        var appliedCount = 0
        controller.start(imageData: photo, currency: "USD", isSignedIn: true) { _ in appliedCount += 1 }
        await settle(controller)
        #expect(controller.phase == .failed(.quotaExceeded(exhausted)))
        #expect(controller.usage == exhausted)
        #expect(appliedCount == 0)
    }

    @Test func aResultForAReplacedPhotoIsDropped() async {
        let service = FakeIdentifyService(outcome: success())
        let controller = IdentifyController(service: service, defaults: freshDefaults(consent: true))
        var appliedCount = 0
        controller.start(imageData: photo, currency: "USD", isSignedIn: true) { _ in appliedCount += 1 }
        controller.reset()   // the photo changed before the response arrived
        await settle(controller)
        #expect(controller.phase == .idle)
        #expect(appliedCount == 0)
    }

    @Test func servicesThatDontNeedSignInSkipTheGate() async {
        let service = FakeIdentifyService(requiresSignIn: false, outcome: success())
        let controller = IdentifyController(service: service, defaults: freshDefaults(consent: true))
        controller.start(imageData: photo, currency: "USD", isSignedIn: false) { _ in }
        await settle(controller)
        #expect(controller.phase == .done(MockProductIdentificationService.sneakers))
    }
}

// MARK: - Share Extension photo hand-off

@Suite(.serialized)
struct SharedImageInboxTests {

    private func sandbox() -> (UserDefaults, URL) {
        let suite = "SharedImageInboxTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("\(suite).jpg")
        return (defaults, file)
    }

    @Test func storedPhotoIsHandedOverOnce() throws {
        let (defaults, file) = sandbox()
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0x01, 0x02])
        try SharedImageInbox.store(jpeg, defaults: defaults, fileURL: file)

        #expect(SharedImageInbox.consume(defaults: defaults, fileURL: file) == jpeg)
        #expect(SharedImageInbox.consume(defaults: defaults, fileURL: file) == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func aPhotoReplacesAPendingLink() throws {
        let (defaults, file) = sandbox()
        defaults.set("https://example.com/item", forKey: SharedImageInbox.pendingURLKey)
        try SharedImageInbox.store(Data([1]), defaults: defaults, fileURL: file)
        #expect(defaults.string(forKey: SharedImageInbox.pendingURLKey) == nil)
        SharedImageInbox.clear(defaults: defaults, fileURL: file)
        #expect(SharedImageInbox.consume(defaults: defaults, fileURL: file) == nil)
    }

    @Test func staleSharesAreDropped() throws {
        let (defaults, file) = sandbox()
        let sharedAt = Date(timeIntervalSince1970: 1_000_000)
        try SharedImageInbox.store(Data([1, 2, 3]), now: sharedAt, defaults: defaults, fileURL: file)
        let later = sharedAt.addingTimeInterval(SharedImageInbox.maxAge + 1)
        #expect(SharedImageInbox.consume(now: later, defaults: defaults, fileURL: file) == nil)
        #expect(!FileManager.default.fileExists(atPath: file.path))
    }

    @Test func downscalesLargePhotosToTheStoredSize() throws {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let big = UIGraphicsImageRenderer(size: CGSize(width: 3000, height: 2000), format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 3000, height: 2000))
        }
        let png = try #require(big.pngData())
        let source = try #require(CGImageSourceCreateWithData(png as CFData, nil))

        let jpeg = try #require(SharedImageInbox.downscaledJPEG(from: source))
        let output = try #require(CGImageSourceCreateWithData(jpeg as CFData, nil))
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(output, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyPixelWidth] as? Int == 1200)
        #expect(properties[kCGImagePropertyPixelHeight] as? Int == 800)
        #expect(CGImageSourceGetType(output) as String? == "public.jpeg")
    }
}
