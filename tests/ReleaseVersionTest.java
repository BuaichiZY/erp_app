package sex.erp.android;

public final class ReleaseVersionTest {
    private static void check(boolean actual,boolean expected){if(actual!=expected)throw new AssertionError("Unexpected release comparison");}
    public static void main(String[] args){
        check(ReleaseVersion.newer("1.0.0_beta","1.0.0-beta"),false);
        check(ReleaseVersion.newer("v1.0.1_beta","1.0.0-beta"),true);
        check(ReleaseVersion.newer("1.0.0","1.0.0-beta"),true);
        check(ReleaseVersion.newer("1.0.0-beta","1.0.0"),false);
        check(ReleaseVersion.newer("1.0.0-beta","1.0.1-beta"),false);
        check(ReleaseVersion.newer("erp_app_1.1.0_beta","1.0.0-beta"),true);
        System.out.println("Release version checks passed: 6");
    }
}
