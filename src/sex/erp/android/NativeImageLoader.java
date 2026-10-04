package sex.erp.android;

import android.graphics.*;
import android.net.Uri;
import android.os.*;
import android.util.LruCache;
import android.view.*;
import android.widget.ImageView;
import java.io.*;
import java.lang.ref.WeakReference;
import java.net.URL;
import java.security.MessageDigest;
import java.util.*;
import java.util.concurrent.*;
import javax.net.ssl.HttpsURLConnection;

/** Visible images first, shared downloads, sized bitmaps and bounded browser-like media cache. */
final class NativeImageLoader {
    interface Trace {void record(String event,long started);}
    private final ExecutorService workers=Executors.newFixedThreadPool(4);
    private final Handler ui=new Handler(Looper.getMainLooper());
    private final LruCache<String,Bitmap> memory;
    private final Map<String,Job> jobs=new HashMap<>();
    private final ConcurrentHashMap<String,CompletableFuture<byte[]>> downloads=new ConcurrentHashMap<>();
    private final File directory;
    private final String userAgent;
    private final Trace trace;
    private final Object diskLock=new Object();
    private volatile boolean closed;
    NativeImageLoader(File directory,String userAgent,Trace trace){
        this.directory=directory;this.userAgent=userAgent;this.trace=trace;directory.mkdirs();
        int budget=(int)Math.max(8*1024*1024,Math.min(48*1024*1024,Runtime.getRuntime().maxMemory()/8));
        memory=new LruCache<String,Bitmap>(budget){protected int sizeOf(String key,Bitmap value){return value.getByteCount();}};
    }
    void load(ImageView view,String url){load(view,url,"",false);}
    void loadPreview(ImageView view,String preview,String original){load(view,preview,preview.equals(original)?"":original,false);}
    private void load(ImageView view,String url,String next,boolean keepPreview){
        Object previous=view.getTag();if(previous instanceof Request)((Request)previous).dispose();
        Uri uri=Uri.parse(url);String host=uri.getHost();
        if(closed||!"https".equals(uri.getScheme())||host==null||!(host.equals("erp.sex")||host.endsWith(".erp.sex")))return;
        Request request=new Request(view,url,next,keepPreview);view.setTag(request);view.addOnAttachStateChangeListener(request);
        if(!keepPreview&&view instanceof AnimatedPhotoView)((AnimatedPhotoView)view).loading();
        if(view.isAttachedToWindow())request.attach();
    }
    private final class Request implements View.OnAttachStateChangeListener,ViewTreeObserver.OnPreDrawListener {
        final WeakReference<ImageView> target;final String url,next;final boolean keepPreview;final long started=SystemClock.elapsedRealtime();
        volatile boolean disposed;boolean startedWork;ViewTreeObserver observer;
        Request(ImageView view,String url,String next,boolean keepPreview){target=new WeakReference<>(view);this.url=url;this.next=next;this.keepPreview=keepPreview;}
        void attach(){ImageView view=target.get();if(view==null||disposed||startedWork)return;observer=view.getViewTreeObserver();observer.addOnPreDrawListener(this);}
        public void onViewAttachedToWindow(View view){attach();}
        public void onViewDetachedFromWindow(View view){if(startedWork)dispose();else unwatch();}
        private void unwatch(){if(observer!=null&&observer.isAlive())observer.removeOnPreDrawListener(this);observer=null;}
        void dispose(){disposed=true;unwatch();ImageView view=target.get();if(view!=null)view.removeOnAttachStateChangeListener(this);}
        boolean current(){ImageView view=target.get();return !disposed&&view!=null&&view.getTag()==this&&view.isAttachedToWindow();}
        public boolean onPreDraw(){
            ImageView view=target.get();if(view==null||disposed||closed){dispose();return true;}
            if(!view.isShown()||view.getWidth()==0||view.getHeight()==0)return true;
            int[] location=new int[2];view.getLocationOnScreen(location);int screenHeight=view.getResources().getDisplayMetrics().heightPixels;
            // One half viewport of look-ahead; distant/offscreen lists do not occupy download slots.
            if(location[1]+view.getHeight()<(keepPreview?0:-screenHeight/2)||location[1]>(keepPreview?screenHeight:screenHeight*3/2)||location[0]+view.getWidth()<0||location[0]>view.getResources().getDisplayMetrics().widthPixels)return true;
            startedWork=true;unwatch();int size=ImageSizing.bucket(view.getWidth(),view.getHeight());String key=url+"#"+size;
            Bitmap bitmap=memory.get(key);if(bitmap!=null){trace.record("image memory bitmap="+bitmap.getByteCount(),started);deliver(bitmap,true);return true;}
            if(!keepPreview&&view instanceof AnimatedPhotoView)((AnimatedPhotoView)view).animateLoading();
            Job job=jobs.get(key);if(job!=null){job.waiters.add(this);return true;}
            job=new Job(url,key,size);job.waiters.add(this);jobs.put(key,job);Job task=job;workers.execute(()->task.run());return true;
        }
        void deliver(Bitmap bitmap,boolean cached){ImageView view=target.get();if(current()){
            if(view instanceof AnimatedPhotoView){AnimatedPhotoView photo=(AnimatedPhotoView)view;if(bitmap==null){if(!keepPreview)photo.failed();}else if(cached||keepPreview)photo.readyCached(bitmap);else photo.ready(bitmap);}
            else if(bitmap!=null)view.setImageBitmap(bitmap);
        }boolean upgrade=current()&&!next.isEmpty()&&(bitmap==null||Math.max(bitmap.getWidth(),bitmap.getHeight())<ImageSizing.bucket(view.getWidth(),view.getHeight()));dispose();if(upgrade)load(view,next,"",bitmap!=null);}
    }
    private final class Job {
        final String url,key;final int size;final CopyOnWriteArrayList<Request> waiters=new CopyOnWriteArrayList<>();
        Job(String url,String key,int size){this.url=url;this.key=key;this.size=size;}
        boolean hasTarget(){for(Request request:waiters)if(!request.disposed)return true;return false;}
        void run(){if(closed)return;if(!hasTarget()){ui.post(()->{if(closed)return;if(hasTarget())workers.execute(this::run);else if(jobs.get(key)==this)jobs.remove(key);});return;}Bitmap bitmap=null;boolean saved=false;int bytes=0;
            try{File file=imageFile(url);saved=file.isFile()&&System.currentTimeMillis()-file.lastModified()<7L*24*60*60*1000;
                byte[] data=bytes(url);bytes=data.length;BitmapFactory.Options options=new BitmapFactory.Options();options.inJustDecodeBounds=true;BitmapFactory.decodeByteArray(data,0,data.length,options);
                options.inSampleSize=ImageSizing.sample(options.outWidth,options.outHeight,size);options.inJustDecodeBounds=false;bitmap=BitmapFactory.decodeByteArray(data,0,data.length,options);
                if(bitmap==null){file.delete();throw new IOException("Invalid image");}memory.put(key,bitmap);
            }catch(Exception|OutOfMemoryError ignored){}
            Bitmap result=bitmap;boolean cached=saved;int count=bytes;ui.post(()->{jobs.remove(key);if(closed)return;for(Request request:waiters){trace.record("image "+(cached?"disk":"network")+" bytes="+count+" bitmap="+(result==null?0:result.getByteCount()),request.started);request.deliver(result,cached);}});
        }
    }
    private byte[] bytes(String url)throws Exception{
        CompletableFuture<byte[]> own=new CompletableFuture<>(),other=downloads.putIfAbsent(url,own);if(other!=null)return other.get();
        try{File file=imageFile(url);byte[] data=null;if(file.isFile()&&System.currentTimeMillis()-file.lastModified()<7L*24*60*60*1000)try(InputStream in=new FileInputStream(file)){data=read(in);}catch(IOException ignored){}
            if(data==null){HttpsURLConnection connection=(HttpsURLConnection)new URL(url).openConnection();try{
                connection.setConnectTimeout(15000);connection.setReadTimeout(20000);connection.setInstanceFollowRedirects(false);connection.setRequestProperty("User-Agent",userAgent);
                if(connection.getResponseCode()!=200)throw new IOException("Image unavailable");try(InputStream in=connection.getInputStream()){data=read(in);}
                String policy=connection.getHeaderField("Cache-Control");if(policy==null||!policy.toLowerCase(Locale.ROOT).contains("no-store"))save(file,data);
            }finally{connection.disconnect();}}
            own.complete(data);return data;
        }catch(Exception|OutOfMemoryError error){own.completeExceptionally(error);throw error;}finally{downloads.remove(url,own);}
    }
    private static byte[] read(InputStream input)throws IOException{try(ByteArrayOutputStream output=new ByteArrayOutputStream()){byte[] buffer=new byte[8192];int n;while((n=input.read(buffer))!=-1){if(output.size()+n>12*1024*1024)throw new IOException("Image too large");output.write(buffer,0,n);}return output.toByteArray();}}
    private File imageFile(String url)throws Exception{byte[] digest=MessageDigest.getInstance("SHA-256").digest(url.getBytes("UTF-8"));StringBuilder name=new StringBuilder();for(byte part:digest)name.append(String.format(Locale.ROOT,"%02x",part&255));return new File(directory,name+".img");}
    private void save(File file,byte[] data){synchronized(diskLock){try{directory.mkdirs();File temp=new File(directory,file.getName()+".tmp");try(FileOutputStream out=new FileOutputStream(temp)){out.write(data);}if(!temp.renameTo(file))temp.delete();File[] files=directory.listFiles((dir,name)->name.endsWith(".img"));if(files==null)return;Arrays.sort(files,Comparator.comparingLong(File::lastModified));long bytes=0;int count=files.length;for(File entry:files)bytes+=entry.length();for(File entry:files){if(bytes<=64L*1024*1024&&count<=256)break;long length=entry.length();if(entry.delete()){bytes-=length;count--;}}}catch(IOException ignored){}}}
    void trim(){memory.trimToSize(memory.maxSize()/2);}
    void close(){closed=true;for(Job job:jobs.values())for(Request request:job.waiters)request.dispose();jobs.clear();workers.shutdownNow();memory.evictAll();}
}
