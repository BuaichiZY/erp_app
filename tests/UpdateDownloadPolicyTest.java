package sex.erp.android;

import java.util.Map;

public final class UpdateDownloadPolicyTest {
    private static void check(boolean result){if(!result)throw new AssertionError("Download source policy failed");}
    public static void main(String[] args){
        check(UpdateDownloadPolicy.useMirror("CN"));check(UpdateDownloadPolicy.useMirror("cn"));
        for(String country:new String[]{"JP","US","HK","TW","",null})check(!UpdateDownloadPolicy.useMirror(country));
        check(UpdateDownloadPolicy.matches("ERP-Native-1.3.0_beta.apk","v1.3.0_beta"));
        check(UpdateDownloadPolicy.matches("ERP-1.3.0_beta.apk","1.3.0_beta"));
        for(String name:new String[]{"ERP-Native-1.2.0_beta.apk","ERP-Native-1.3.0.apk","ERP-Native-1.30.0_beta.apk","ad-1.3.0_beta.apk","ERP-Native-1.3.0_beta.apk.exe"})check(!UpdateDownloadPolicy.matches(name,"1.3.0_beta"));
        check(UpdateDownloadPolicy.trusted("https://developer4.lanrar.com/file/abc"));
        for(String url:new String[]{"http://wwbpx.lanzouc.com/a","https://wwbpx.lanzouc.com.evil.test/a","https://evil@wwbpx.lanzouc.com/a","https://wwbpx.lanzouc.com:444/a","https://127.0.0.1/a"})check(!UpdateDownloadPolicy.trusted(url));
        String folder="var random_t='token';var random_k='key';data : {'lx':2,'fid':123,'pg':pgs,'t':random_t,'k':random_k,'up':1,'password':''}";
        Map<String,String> form=UpdateDownloadPolicy.form(folder);
        check(form.get("pg").equals("1")&&form.get("t").equals("token")&&form.get("k").equals("key")&&form.get("password").equals(""));
        String frame="var ajaxdata='a';var wp_sign='b';var kdns=1;var kdns=0;data:{'action':'downprocess','sign':wp_sign,'websignkey':ajaxdata,'kd':kdns,'ves':\n1}";
        check(UpdateDownloadPolicy.form(frame).get("kd").equals("1"));
        check(UpdateDownloadPolicy.form(frame).get("sign").equals("b"));
        Map<String,String> argsMap=new java.util.HashMap<>();argsMap.put("el","2");
        check(UpdateDownloadPolicy.form("data:{'file':'token','el':el,'sign':'key'}",argsMap).get("el").equals("2"));
        try{UpdateDownloadPolicy.form("data:{'t':unknown}");throw new AssertionError("Unknown script evaluated");}catch(IllegalArgumentException expected){}
        System.out.println("Update routing, version matching and public mirror parser checks passed");
    }
}
