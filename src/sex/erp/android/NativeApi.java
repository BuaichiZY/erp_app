package sex.erp.android;

import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.BitmapFactory;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;
import android.webkit.CookieManager;
import android.webkit.WebSettings;
import android.widget.ImageView;
import org.json.JSONObject;
import org.json.JSONArray;
import java.io.*;
import java.net.*;
import java.util.*;
import java.util.concurrent.*;
import javax.net.ssl.HttpsURLConnection;

/** Native HTTPS requests. No page scraping or WebView is used for application data. */
final class NativeApi {
    static final String ORIGIN = "https://erp.sex";
    interface Done { void complete(Object result, Failure error); }
    static final class Failure extends Exception {
        final int status;
        final String code;
        Failure(int status, String code, String message) { super(message); this.status=status; this.code=code; }
    }
    private final ExecutorService requests = Executors.newFixedThreadPool(4);
    private final ExecutorService images = Executors.newFixedThreadPool(3);
    private final Handler ui = new Handler(Looper.getMainLooper());
    private final CookieManager cookies = CookieManager.getInstance();
    private final NativeImageLoader imageLoader;
    private final ReadResponseCache readResponses=new ReadResponseCache();
    private final Map<String,List<Done>> readInFlight=new HashMap<>();
    private long readEpoch;
    private boolean closed;
    final String userAgent;
    volatile String mode = "sfw";
    volatile String language = "zh-CN";
    private ReadRefreshBatch readScope;
    boolean performance;
    private void trace(String event,long started){if(performance)android.util.Log.i("ERPPerf",event+" ms="+(android.os.SystemClock.elapsedRealtime()-started));}
    NativeApi(Context context) { userAgent=WebSettings.getDefaultUserAgent(context); cookies.setAcceptCookie(true);imageLoader=new NativeImageLoader(new File(context.getCacheDir(),"profile-images"),userAgent,this::trace); }

    // Scope only reads started by this action or its callbacks, not background polling.
    void readBatch(Runnable action, Runnable complete) {
        ReadRefreshBatch batch=new ReadRefreshBatch(complete), previous=readScope;
        readScope=batch;
        try { action.run(); } finally { readScope=previous;batch.release(); }
    }

    void invalidateReads(String reason){readEpoch++;readResponses.invalidate(reason);}
    private String readContext(){return mode+"|"+language;}
    private static Object parseSnapshot(String text)throws Exception{return text.startsWith("[")?new JSONArray(text):new JSONObject(text);}
    void call(String method,String path,JSONObject body,Done callback) {
        final long started=android.os.SystemClock.elapsedRealtime();
        final ReadRefreshBatch batch="GET".equals(method)?readScope:null;
        if(batch!=null)batch.retain();
        final String contentMode=mode,contentLanguage=language,context=readContext();
        final String category=method+" "+path.split("[/?]")[1];
        Done deliver=(value,problem)->{ReadRefreshBatch previous=readScope;readScope=batch;
            try{trace("read "+category,started);if(!closed)callback.complete(value,problem);}
            finally{readScope=previous;if(batch!=null)batch.release();}
        };
        if(!"GET".equals(method))invalidateReads(path);
        if("GET".equals(method)&&batch==null){String saved=readResponses.get(context,path,started);if(saved!=null)try{Object value=parseSnapshot(saved);ui.post(()->{trace("read memory "+category,started);deliver.complete(value,null);});return;}catch(Exception ignored){}}
        final long epoch=readEpoch;
        final String flight="GET".equals(method)?epoch+"|"+context+"|"+path+(batch==null?"":"|fresh"):null;
        if(flight!=null){List<Done> waiters=readInFlight.get(flight);if(waiters!=null){waiters.add(deliver);return;}waiters=new ArrayList<>();waiters.add(deliver);readInFlight.put(flight,waiters);}
        requests.execute(() -> {
            Object result=null; Failure error=null;
            try { result=request(method,path,body,contentMode,contentLanguage); }
            catch(Failure e) { error=e; }
            catch(Exception e) { error=new Failure(0,"NETWORK",UiStrings.t("网络连接失败，请检查网络后重试")); }
            Object value=result; Failure problem=error;
            // The serialized copy is immutable: callbacks may edit their own JSONObject.
            String snapshot=problem==null&&"GET".equals(method)&&ReadResponseCache.lifetime(path)>0?value.toString():null;
            ui.post(() -> {
                if(snapshot!=null&&epoch==readEpoch&&!closed)readResponses.put(context,path,snapshot,android.os.SystemClock.elapsedRealtime());
                if(!"GET".equals(method)&&problem==null)invalidateReads(path);
                List<Done> waiters=flight==null?null:readInFlight.remove(flight);
                if(waiters==null){deliver.complete(value,problem);return;}
                for(Done waiter:waiters){Object copy=value;if(waiters.size()>1&&problem==null)try{copy=parseSnapshot(value.toString());}catch(Exception ignored){}waiter.complete(copy,problem);}
            });
        });
    }
    void upload(Context context,Uri file,String purpose,String matchId,Done callback) {
        upload(context,file,purpose,matchId,json("rating","general"),callback);
    }
    void upload(Context context,Uri file,String purpose,String matchId,JSONObject options,Done callback) {
        final String contentMode=mode;
        requests.execute(() -> {
            Object result=null;Failure error=null;
            try {
                ensureCsrf();
                String mime=context.getContentResolver().getType(file);
                if(mime==null&&"file".equals(file.getScheme()))mime=android.webkit.MimeTypeMap.getSingleton().getMimeTypeFromExtension(android.webkit.MimeTypeMap.getFileExtensionFromUrl(file.toString()));
                if(mime==null || !(mime.startsWith("image/")||mime.startsWith("audio/")))throw new Failure(0,"UNSUPPORTED_MEDIA",UiStrings.t("请选择图片或语音文件"));
                boolean audio="chat_voice".equals(purpose)||"voice_card".equals(purpose);
                if(audio!=mime.startsWith("audio/"))throw new Failure(0,"UNSUPPORTED_MEDIA",UiStrings.t("文件类型与附件类型不匹配"));
                String rating=options.optString("rating");
                if(!Arrays.asList("general","suggestive","r18").contains(rating))throw new Failure(0,"VALIDATION_FAILED",UiStrings.t("请选择内容分级"));
                if(!audio&&options.optBoolean("realPerson")&&!"general".equals(rating))throw new Failure(0,"REAL_PERSON_NSFW",UiStrings.t("真人图片仅支持全年龄分级"));
                ByteArrayOutputStream bytes=new ByteArrayOutputStream();
                try(InputStream input=context.getContentResolver().openInputStream(file)) {
                    if(input==null)throw new IOException("Missing file");byte[] buffer=new byte[8192];int n;
                    while((n=input.read(buffer))!=-1){if(bytes.size()+n>20*1024*1024)throw new Failure(413,"FILE_TOO_LARGE",UiStrings.t("文件不能超过 20 MB"));bytes.write(buffer,0,n);}
                }
                if(!audio){
                    if(!Arrays.asList("image/jpeg","image/png","image/webp","image/gif").contains(mime))throw new Failure(0,"UNSUPPORTED_MEDIA",UiStrings.t("请选择 JPEG、PNG、WebP 或 GIF 图片"));
                    byte[] source=bytes.toByteArray();BitmapFactory.Options bounds=new BitmapFactory.Options();bounds.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(source,0,source.length,bounds);
                    if(bounds.outWidth<=0||bounds.outHeight<=0)throw new Failure(0,"UNSUPPORTED_MEDIA",UiStrings.t("图片无法读取"));
                    // Like the website, upload a resized JPEG and strip embedded metadata.
                    int maxEdge=options.optBoolean("original")?4096:1600;bounds.inJustDecodeBounds=false;bounds.inSampleSize=1;while(Math.max(bounds.outWidth,bounds.outHeight)/bounds.inSampleSize>maxEdge*2)bounds.inSampleSize*=2;
                    Bitmap decoded=BitmapFactory.decodeByteArray(source,0,source.length,bounds);if(decoded==null)throw new Failure(0,"UNSUPPORTED_MEDIA",UiStrings.t("图片无法读取"));
                    decoded=ImageOrientation.upright(context,file,decoded);
                    float scale=Math.min(1f,(float)maxEdge/Math.max(decoded.getWidth(),decoded.getHeight()));Bitmap resized=Bitmap.createScaledBitmap(decoded,Math.max(1,Math.round(decoded.getWidth()*scale)),Math.max(1,Math.round(decoded.getHeight()*scale)),true);
                    Bitmap flattened=Bitmap.createBitmap(resized.getWidth(),resized.getHeight(),Bitmap.Config.ARGB_8888);android.graphics.Canvas canvas=new android.graphics.Canvas(flattened);canvas.drawColor(android.graphics.Color.WHITE);canvas.drawBitmap(resized,0,0,null);bytes.reset();flattened.compress(Bitmap.CompressFormat.JPEG,options.optBoolean("original")?92:85,bytes);flattened.recycle();if(resized!=decoded)resized.recycle();decoded.recycle();mime="image/jpeg";
                }else{
                    android.media.MediaMetadataRetriever metadata=new android.media.MediaMetadataRetriever();
                    try{metadata.setDataSource(context,file);String length=metadata.extractMetadata(android.media.MediaMetadataRetriever.METADATA_KEY_DURATION);long milliseconds=length==null?0:Long.parseLong(length);if(milliseconds<1000||milliseconds>121000)throw new Failure(0,"AUDIO_DURATION_INVALID",UiStrings.t("语音长度须为 1 秒至 2 分钟"));}finally{metadata.release();}
                }
                String boundary="ERP"+UUID.randomUUID().toString().replace("-","");
                HttpsURLConnection connection=(HttpsURLConnection)new URL(ORIGIN+"/api/v1/media").openConnection();
                try {
                    connection.setConnectTimeout(20000);connection.setReadTimeout(60000);connection.setInstanceFollowRedirects(false);connection.setRequestMethod("POST");
                    connection.setRequestProperty("User-Agent",userAgent);connection.setRequestProperty("Accept","application/json");connection.setRequestProperty("Accept-Language",language);connection.setRequestProperty("X-Content-Mode",contentMode);connection.setRequestProperty("Origin",ORIGIN);connection.setRequestProperty("Referer",ORIGIN+"/");
                    String cookie=cookies.getCookie(ORIGIN+"/api/v1/");
                    if(cookie!=null){connection.setRequestProperty("Cookie",cookie);for(String part:cookie.split(";")){String v=part.trim();if(v.startsWith("erp_csrf="))connection.setRequestProperty("X-CSRF-Token",URLDecoder.decode(v.substring(9),"UTF-8"));}}
                    connection.setRequestProperty("Content-Type","multipart/form-data; boundary="+boundary);connection.setDoOutput(true);connection.setChunkedStreamingMode(8192);
                    try(OutputStream output=connection.getOutputStream()) {
                        multipartField(output,boundary,"purpose",purpose);multipartField(output,boundary,"rating",rating);
                        for(String key:new String[]{"realPerson","r18Kind","adultConfirm","original"})if(options.has(key))multipartField(output,boundary,key,options.optString(key));
                        if(matchId!=null)multipartField(output,boundary,"matchId",matchId);
                        String extension=mime.substring(mime.indexOf('/')+1).replaceAll("[^a-zA-Z0-9]","");
                        if(mime.equals("image/jpeg"))extension="jpg";if(mime.equals("audio/mpeg"))extension="mp3";if(mime.equals("audio/mp4"))extension="m4a";
                        output.write(("--"+boundary+"\r\nContent-Disposition: form-data; name=\"file\"; filename=\"attachment."+extension+"\"\r\nContent-Type: "+mime+"\r\n\r\n").getBytes("UTF-8"));
                        bytes.writeTo(output);output.write(("\r\n--"+boundary+"--\r\n").getBytes("UTF-8"));
                    }
                    int status=connection.getResponseCode();
                    for(Map.Entry<String,List<String>> entry:connection.getHeaderFields().entrySet())if("Set-Cookie".equalsIgnoreCase(entry.getKey()))for(String v:entry.getValue())cookies.setCookie(ORIGIN+"/api/v1/",v);
                    cookies.flush();InputStream stream=status>=400?connection.getErrorStream():connection.getInputStream();
                    JSONObject response=new JSONObject(stream==null?"{}":read(stream,1024*1024));
                    if(status>=300){JSONObject detail=response.optJSONObject("error");throw new Failure(status,detail==null?"UPLOAD_FAILED":detail.optString("code"),detail==null?UiStrings.t("上传失败"):detail.optString("message",UiStrings.t("上传失败")));}
                    result=response;
                }finally{connection.disconnect();}
            }catch(Failure e){error=e;}catch(OutOfMemoryError e){error=new Failure(0,"FILE_TOO_LARGE",UiStrings.t("图片过大，请选择较小的图片"));}catch(Exception e){error=new Failure(0,"NETWORK",UiStrings.t("上传失败，请检查网络或文件格式"));}
            Object value=result;Failure problem=error;ui.post(()->{if(problem==null)invalidateReads("/media");callback.complete(value,problem);});
        });
    }
    private static void multipartField(OutputStream output,String boundary,String name,String value)throws IOException {
        output.write(("--"+boundary+"\r\nContent-Disposition: form-data; name=\""+name+"\"\r\n\r\n"+value+"\r\n").getBytes("UTF-8"));
    }
    Object request(String method,String path,JSONObject body) throws Exception {return request(method,path,body,mode,language);}
    private Object request(String method,String path,JSONObject body,String contentMode,String contentLanguage) throws Exception {
        if(!method.equals("GET")&&!method.equals("HEAD"))ensureCsrf();
        HttpsURLConnection connection=(HttpsURLConnection)new URL(ORIGIN+"/api/v1"+path).openConnection();
        connection.setConnectTimeout(20000);connection.setReadTimeout(30000);
        connection.setInstanceFollowRedirects(false);
        connection.setRequestMethod(method);
        connection.setRequestProperty("User-Agent",userAgent);
        connection.setRequestProperty("Accept","application/json");
        connection.setRequestProperty("Accept-Language",contentLanguage);
        connection.setRequestProperty("X-Content-Mode",contentMode);
        connection.setRequestProperty("Origin",ORIGIN);
        connection.setRequestProperty("Referer",ORIGIN+"/");
        String cookie=cookies.getCookie(ORIGIN+"/api/v1/");
        if(cookie!=null) {
            connection.setRequestProperty("Cookie",cookie);
            if(!method.equals("GET")) for(String part:cookie.split(";")) {
                String value=part.trim();
                if(value.startsWith("erp_csrf=")) connection.setRequestProperty("X-CSRF-Token",URLDecoder.decode(value.substring(9),"UTF-8"));
            }
        }
        try {
            if(body!=null) {
                connection.setRequestProperty("Content-Type","application/json; charset=utf-8");
                connection.setDoOutput(true);
                try(OutputStream output=connection.getOutputStream()) { output.write(body.toString().getBytes("UTF-8")); }
            }
            int status=connection.getResponseCode();
            for(Map.Entry<String,List<String>> entry:connection.getHeaderFields().entrySet()) {
                if("Set-Cookie".equalsIgnoreCase(entry.getKey())) for(String value:entry.getValue()) cookies.setCookie(ORIGIN+"/api/v1/",value);
            }
            cookies.flush();
            InputStream stream=status>=400?connection.getErrorStream():connection.getInputStream();
            String text=stream==null?"":read(stream,8*1024*1024);
            Object result;
            try { result=text.startsWith("[")?new JSONArray(text):text.isEmpty()?new JSONObject():new JSONObject(text); }
            catch(Exception e) { throw new Failure(status,"NON_JSON",UiStrings.t("网站返回了验证页面，请稍后重试")); }
            if(status>=400 || status>=300) {
                JSONObject detail=result instanceof JSONObject?((JSONObject)result).optJSONObject("error"):null;
                throw new Failure(status,detail==null?"HTTP_"+status:detail.optString("code"),detail==null?UiStrings.t("网站返回 ")+status:detail.optString("message",UiStrings.t("操作失败")));
            }
            return result;
        } finally { connection.disconnect(); }
    }
    private void ensureCsrf() throws Exception {
        String present=cookies.getCookie(ORIGIN+"/api/v1/");
        if(present!=null&&present.contains("erp_csrf="))return;
        // Read the ordinary site entry to receive its anonymous session/CSRF cookies.
        // HTML is never displayed or evaluated here.
        HttpsURLConnection connection=(HttpsURLConnection)new URL(ORIGIN+"/login").openConnection();
        try{
            connection.setConnectTimeout(15000);connection.setReadTimeout(15000);connection.setInstanceFollowRedirects(false);
            connection.setRequestProperty("User-Agent",userAgent);connection.setRequestProperty("Accept","text/html");
            if(present!=null)connection.setRequestProperty("Cookie",present);
            connection.getResponseCode();
            for(Map.Entry<String,List<String>> entry:connection.getHeaderFields().entrySet())if("Set-Cookie".equalsIgnoreCase(entry.getKey()))for(String value:entry.getValue())cookies.setCookie(ORIGIN+"/",value);
            cookies.flush();
        }finally{connection.disconnect();}
    }
    private static String read(InputStream stream,int limit) throws IOException {
        try(InputStream input=stream;ByteArrayOutputStream output=new ByteArrayOutputStream()) {
            byte[] buffer=new byte[8192];int n;
            while((n=input.read(buffer))!=-1) { if(output.size()+n>limit)throw new IOException("Response too large");output.write(buffer,0,n); }
            return output.toString("UTF-8");
        }
    }
    void image(ImageView view,JSONObject media,boolean thumbnail) {
        if(media==null || !media.optString("view","show").equals("show")) return;
        String url=thumbnail?media.optString("thumbUrl",media.optString("url")):media.optString("url",media.optString("thumbUrl"));
        String preview=media.optString("thumbUrl",url);
        if(!thumbnail&&!preview.isEmpty()&&!url.isEmpty())imageLoader.loadPreview(view,preview,url);else imageUrl(view,url);
    }
    void imageCached(ImageView view,JSONObject media,boolean thumbnail){
        if(media==null||!"show".equals(media.optString("view","show")))return;
        String url=thumbnail?media.optString("thumbUrl",media.optString("url")):media.optString("url",media.optString("thumbUrl"));
        imageUrl(view,url,true);
    }
    void shareCardPhoto(String id,java.util.function.Consumer<Bitmap> done) {
        if(id==null||id.isEmpty()){ui.post(()->done.accept(null));return;}
        images.execute(()->{
            Bitmap bitmap=null;HttpsURLConnection connection=null;
            try{
                connection=(HttpsURLConnection)new URL(ORIGIN+"/api/v1/me/share-cards/photo/"+Uri.encode(id)).openConnection();
                connection.setConnectTimeout(15000);connection.setReadTimeout(25000);connection.setInstanceFollowRedirects(false);
                connection.setRequestProperty("User-Agent",userAgent);String cookie=cookies.getCookie(ORIGIN+"/api/v1/");if(cookie!=null)connection.setRequestProperty("Cookie",cookie);
                if(connection.getResponseCode()!=200)throw new IOException("Share photo unavailable");
                try(InputStream input=connection.getInputStream();ByteArrayOutputStream output=new ByteArrayOutputStream()){
                    byte[] buffer=new byte[8192];int n;while((n=input.read(buffer))!=-1){if(output.size()+n>16*1024*1024)throw new IOException("Image too large");output.write(buffer,0,n);}
                    byte[] bytes=output.toByteArray();BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);options.inSampleSize=1;while(options.outWidth/options.inSampleSize>1800||options.outHeight/options.inSampleSize>2200)options.inSampleSize*=2;options.inJustDecodeBounds=false;bitmap=BitmapFactory.decodeByteArray(bytes,0,bytes.length,options);
                }
            }catch(Exception ignored){}finally{if(connection!=null)connection.disconnect();}
            Bitmap result=bitmap;ui.post(()->done.accept(result));
        });
    }
    void imageUrl(ImageView view,String url) { imageUrl(view,url,false); }
    private void imageUrl(ImageView view,String url,boolean disk){imageLoader.load(view,url);}
    void trimMemory(){imageLoader.trim();}
    void close(){closed=true;readResponses.clear();requests.shutdownNow();images.shutdownNow();imageLoader.close();}
    static JSONObject object(Object result) { return result instanceof JSONObject?(JSONObject)result:new JSONObject(); }
    static JSONObject json(Object... pairs) {
        JSONObject o=new JSONObject();
        try { for(int i=0;i<pairs.length;i+=2)o.put(String.valueOf(pairs[i]),pairs[i+1]); }
        catch(Exception e) {throw new IllegalArgumentException(e);}
        return o;
    }
    static String encode(String value) { return Uri.encode(value); }
}
