package sex.erp.android;

public final class VrcTrustBadgeTest {
    public static void main(String[] args){
        if(VrcTrustPalette.background("user")!=0xff2bcf5c||VrcTrustPalette.foreground("user")!=0xff111827)throw new AssertionError("Player badge must be green");
        if(VrcTrustPalette.background("known_user")!=0xffff7b42||VrcTrustPalette.foreground("known_user")!=0xff111827)throw new AssertionError("Long-time player badge must be orange");
        if(VrcTrustPalette.background("trusted_user")!=0xff8143e6||VrcTrustPalette.foreground("trusted_user")!=0xffffffff)throw new AssertionError("Trusted player badge must be purple");
        System.out.println("VRChat trust badge colors and labels passed");
    }
}
