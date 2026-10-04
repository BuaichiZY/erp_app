package sex.erp.android;

import org.json.JSONArray;
import org.json.JSONObject;
import javax.net.ssl.HttpsURLConnection;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.CookieManager;
import java.net.CookiePolicy;
import java.net.URI;
import java.net.URL;
import java.net.URLEncoder;
import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/** Resolves ordinary public mirror links without executing scripts or bypassing verification. */
final class UpdateDownloadResolver {
    static final String FOLDER="https://wwbpx.lanzouc.com/b0188o68if";
    private static final String ROOT="https://wwbpx.lanzouc.com";
    private static final String UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/131.0.0.0 Safari/537.36";
    private final CookieManager cookies=new CookieManager(null,CookiePolicy.ACCEPT_ORIGINAL_SERVER);
    static final class Result {
        final String url;final Map<String,String> headers;
        Result(String url,Map<String,String> headers){this.url=url;this.headers=headers;}
    }
    static final class MirrorException extends Exception {
        final String filePage;final boolean missing;
        MirrorException(String page,boolean missing){super(missing?"Mirror version missing":"Mirror requires browser verification");filePage=page;this.missing=missing;}
    }
    static String country(){
        try{String trace=publicGet("https://www.cloudflare.com/cdn-cgi/trace");Matcher m=Pattern.compile("(?m)^loc=([A-Z]{2})\\s*$").matcher(trace);if(m.find())return m.group(1);}catch(Exception ignored){}
        try{return new JSONObject(publicGet("https://api.country.is")).optString("country");}catch(Exception ignored){return "";}
    }
    private static String publicGet(String url)throws Exception{
        HttpsURLConnection conn=(HttpsURLConnection)new URL(url).openConnection();
        try{conn.setConnectTimeout(4000);conn.setReadTimeout(4000);conn.setRequestProperty("User-Agent","ERP-Android");if(conn.getResponseCode()!=200)throw new IllegalStateException("Country lookup failed");return read(conn,32768);}finally{conn.disconnect();}
    }
    Result resolve(String tag,String github)throws Exception{
        if(!UpdateDownloadPolicy.useMirror(country()))return new Result(github,new LinkedHashMap<>());
        return mirror(tag);
    }
    Result mirror(String tag)throws Exception{
        String page=FOLDER;
        try{
            String folder=request(FOLDER,null,ROOT);Map<String,String> form=UpdateDownloadPolicy.form(folder);
            String endpoint=ROOT+UpdateDownloadPolicy.capture(folder,"\\burl\\s*:\\s*['\"](/filemoreajax\\.php[^'\"]*)['\"]");
            String id=null;
            for(int n=1;n<=10;n++){
                form.put("pg",String.valueOf(n));JSONObject response=new JSONObject(request(endpoint,form,FOLDER));
                if(response.optInt("zt")==2)break;
                if(response.optInt("zt")!=1)throw new MirrorException(FOLDER,false);
                JSONArray files=response.optJSONArray("text");if(files==null)throw new MirrorException(FOLDER,false);
                for(int i=0;i<files.length();i++){JSONObject item=files.optJSONObject(i);if(item!=null&&item.optInt("t",-1)==0&&UpdateDownloadPolicy.matches(item.optString("name_all"),tag)){id=item.optString("id");break;}}
                if(id!=null)break;if(files.length()<50)break;
            }
            if(id==null)throw new MirrorException(FOLDER,true);
            if(!id.matches("[A-Za-z0-9]+"))throw new MirrorException(FOLDER,false);
            page=ROOT+"/"+id;
            String file=request(page,null,FOLDER);
            String iframe=UpdateDownloadPolicy.capture(file,"<iframe\\b[^>]*\\bsrc=['\"]([^'\"]+)['\"]").replace("&amp;","&");
            String frameUrl=new URI(page).resolve(iframe).toString();String frame=request(frameUrl,null,page);
            Map<String,String> data=UpdateDownloadPolicy.form(frame);JSONObject link=null;Exception linkFailure=null;
            for(String key:new String[]{"domain1","domain2"})try{
                String api=UpdateDownloadPolicy.capture(frame,"\\bvar\\s+"+key+"\\s*=\\s*['\"]([^'\"]+)['\"]");
                JSONObject candidate=new JSONObject(request(api,data,frameUrl));if(candidate.optInt("zt")==1){link=candidate;break;}
                linkFailure=new IllegalStateException("Mirror link response: "+candidate.optInt("zt"));
            }catch(Exception failure){linkFailure=failure;}
            if(link==null){MirrorException failure=new MirrorException(page,false);if(linkFailure!=null)failure.initCause(linkFailure);throw failure;}
            String url=link.optString("dom")+"/file/"+link.optString("url");
            if(!UpdateDownloadPolicy.trusted(url)){MirrorException failure=new MirrorException(page,false);failure.initCause(new IllegalArgumentException("Unexpected mirror host: "+new URI(url).getHost()));throw failure;}
            return binaryLink(url,frameUrl,page,0);
        }catch(MirrorException e){throw e;}catch(Exception e){MirrorException failure=new MirrorException(page,false);failure.initCause(e);throw failure;}
    }
    private Result binaryLink(String url,String referer,String page,int depth)throws Exception{
        if(depth>2)throw new MirrorException(page,false);
        Map<String,String> headers=headers(url,referer);HttpsURLConnection probe=open(url,headers);String html;
        try{
            int status=probe.getResponseCode();cookies.put(new URI(url),probe.getHeaderFields());
            if(status==301||status==302||status==303||status==307||status==308){
                URI redirect=new URI(url).resolve(probe.getHeaderField("Location"));
                if(!"https".equals(redirect.getScheme())||redirect.getHost()==null||redirect.getUserInfo()!=null)throw new MirrorException(page,false);
                return new Result(url,headers(url,referer));
            }
            if(status!=200)throw new MirrorException(page,false);
            try(InputStream in=probe.getInputStream();ByteArrayOutputStream out=new ByteArrayOutputStream()){
                byte[] signature=new byte[4];int count=0,n;while(count<4&&(n=in.read(signature,count,4-count))>0)count+=n;
                if(count==4&&signature[0]==80&&signature[1]==75&&signature[2]==3&&signature[3]==4)return new Result(url,headers(url,referer));
                out.write(signature,0,count);byte[] buffer=new byte[4096];while((n=in.read(buffer))!=-1){if(out.size()+n>1024*1024)throw new MirrorException(page,false);out.write(buffer,0,n);}html=out.toString("UTF-8");
            }
        }finally{probe.disconnect();}
        // Follow the public "verify and download" button's ordinary POST. Human
        // challenges or unfamiliar pages stay in the browser; no script is evaluated.
        if(!html.contains("down_r(2)")||html.toLowerCase(java.util.Locale.ROOT).contains("captcha")||html.contains("turnstile"))throw new MirrorException(page,false);
        Map<String,String> arguments=new LinkedHashMap<>();arguments.put("el","2");
        Map<String,String> confirmation=UpdateDownloadPolicy.form(html,arguments);
        String endpoint=UpdateDownloadPolicy.capture(html,"\\burl\\s*:\\s*['\"](ajax\\.php)['\"]");
        String api=new URI(url).resolve(endpoint).toString();JSONObject response=new JSONObject(request(api,confirmation,url));
        if(response.optInt("zt")!=1)throw new MirrorException(page,false);
        String next=response.optString("url");if(!UpdateDownloadPolicy.trusted(next))throw new MirrorException(page,false);
        return binaryLink(next,url,page,depth+1);
    }
    private Map<String,String> headers(String url,String referer)throws Exception{
        Map<String,String> result=new LinkedHashMap<>();result.put("User-Agent",UA);result.put("Referer",referer);
        Map<String,List<String>> stored=cookies.get(new URI(url),new LinkedHashMap<>());
        List<String> values=stored.get("Cookie");if(values!=null&&!values.isEmpty())result.put("Cookie",String.join("; ",values));return result;
    }
    private HttpsURLConnection open(String url,Map<String,String> headers)throws Exception{
        if(!UpdateDownloadPolicy.trusted(url))throw new IllegalArgumentException("Untrusted mirror endpoint");
        HttpsURLConnection conn=(HttpsURLConnection)new URL(url).openConnection();conn.setConnectTimeout(10000);conn.setReadTimeout(12000);
        conn.setInstanceFollowRedirects(false);for(Map.Entry<String,String> header:headers.entrySet())conn.setRequestProperty(header.getKey(),header.getValue());return conn;
    }
    private String request(String url,Map<String,String> form,String referer)throws Exception{
        HttpsURLConnection conn=open(url,headers(url,referer));
        try{if(form!=null){StringBuilder body=new StringBuilder();for(Map.Entry<String,String> entry:form.entrySet()){
            if(body.length()>0)body.append('&');body.append(URLEncoder.encode(entry.getKey(),"UTF-8")).append('=').append(URLEncoder.encode(entry.getValue(),"UTF-8"));
        }byte[] bytes=body.toString().getBytes(StandardCharsets.UTF_8);conn.setRequestMethod("POST");conn.setDoOutput(true);conn.setRequestProperty("Content-Type","application/x-www-form-urlencoded");conn.setFixedLengthStreamingMode(bytes.length);try(java.io.OutputStream out=conn.getOutputStream()){out.write(bytes);}}
            int status=conn.getResponseCode();cookies.put(new URI(url),conn.getHeaderFields());
            if(status!=200)throw new IllegalStateException("Mirror HTTP "+status);return read(conn,1024*1024);
        }finally{conn.disconnect();}
    }
    private static String read(HttpsURLConnection conn,int limit)throws Exception{
        try(InputStream in=conn.getInputStream();ByteArrayOutputStream out=new ByteArrayOutputStream()){
            byte[] bytes=new byte[4096];int n;while((n=in.read(bytes))!=-1){if(out.size()+n>limit)throw new IllegalStateException("Response too large");out.write(bytes,0,n);}return out.toString("UTF-8");
        }
    }
}
