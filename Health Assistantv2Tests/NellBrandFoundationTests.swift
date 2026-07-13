import Testing
@testable import Health_Assistantv2

struct NellBrandFoundationTests {
    @Test func publicBrandNameAndDescriptorAreStable() {
        #expect(NellBrand.productName == "Nell")
        #expect(NellBrand.descriptor == "Your personal health companion")
    }

    @Test func assetNamesAreUnique() {
        let names = NellAsset.allCases.map(\.rawValue)
        #expect(Set(names).count == names.count)
    }

    @Test func everyMascotPoseResolvesToAMascotAsset() {
        for pose in NellMascotPose.allCases {
            #expect(pose.asset.isMascot)
        }
    }

    @Test func coachMarkHasItsOwnStableAssetName() {
        #expect(NellAsset.coachMark.rawValue == "NellCoachMark")
        #expect(!NellAsset.coachMark.isMascot)
    }
}
