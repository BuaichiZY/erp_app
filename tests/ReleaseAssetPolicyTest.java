package sex.erp.android;

public final class ReleaseAssetPolicyTest {
    public static void main(String[] args){
        String root="https://github.com/BuaichiZY/erp_app/releases/download/v1.3.0/ERP.apk";
        if(!ReleaseAssetPolicy.valid("ERP.APK",root))throw new AssertionError("Valid APK was rejected");
        String[] wrong={root.replace("https:","http:"),root.replace("github.com","github.com.evil.test"),root.replace("erp_app","other"),root.replace("github.com","user@github.com"),root.replace("github.com","github.com:444"),"not a URL"};
        for(String url:wrong)if(ReleaseAssetPolicy.valid("ERP.apk",url))throw new AssertionError("Untrusted asset accepted: "+url);
        if(ReleaseAssetPolicy.valid("source.zip",root))throw new AssertionError("Non-APK accepted");
        System.out.println("Release APK origin checks passed: 8");
    }
}
