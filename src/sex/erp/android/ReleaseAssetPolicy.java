package sex.erp.android;

import java.net.URI;
import java.util.Locale;

/** Only install APK assets served by this project's release downloads. */
final class ReleaseAssetPolicy {
    static boolean valid(String name,String url){
        if(name==null||url==null||!name.toLowerCase(Locale.ROOT).endsWith(".apk"))return false;
        try{URI uri=new URI(url);return "https".equals(uri.getScheme())&&"github.com".equals(uri.getHost())&&uri.getUserInfo()==null&&(uri.getPort()==-1||uri.getPort()==443)&&uri.getPath()!=null&&uri.getPath().startsWith("/BuaichiZY/erp_app/releases/download/");}catch(Exception e){return false;}
    }
}
