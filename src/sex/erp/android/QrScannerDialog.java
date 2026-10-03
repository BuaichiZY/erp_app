package sex.erp.android;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.graphics.Color;
import android.graphics.Matrix;
import android.graphics.SurfaceTexture;
import android.graphics.drawable.ColorDrawable;
import android.hardware.camera2.*;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.hardware.display.DisplayManager;
import android.media.Image;
import android.media.ImageReader;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.util.Size;
import android.view.*;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;
import com.google.zxing.*;
import com.google.zxing.common.HybridBinarizer;
import java.nio.ByteBuffer;
import java.util.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/** Camera is opened only while this fullscreen native QR scanner is in the foreground. */
final class QrScannerDialog {
    private final Activity activity;
    private final Consumer<String> found,error;
    private final Runnable pickImage,requestCamera;
    private final Dialog dialog;
    private final TextureView preview;
    private final ScanOverlayView overlay;
    private final TextView enable;
    private final Handler main=new Handler(Looper.getMainLooper());
    private final DisplayManager displays;
    private final MultiFormatReader decoder=new MultiFormatReader();
    private final AtomicBoolean finished=new AtomicBoolean();
    private HandlerThread thread;
    private Handler worker;
    private CameraDevice camera;
    private CameraCaptureSession session;
    private ImageReader reader;
    private Surface displaySurface;
    private Size previewSize;
    private int sensorDegrees,cameraGeneration;
    private long lastDecode;
    private boolean cameraAllowed,opening,active=true;
    private final DisplayManager.DisplayListener displayListener=new DisplayManager.DisplayListener(){
        public void onDisplayAdded(int id){}
        public void onDisplayRemoved(int id){}
        public void onDisplayChanged(int id){configureTransform();}
    };

    QrScannerDialog(Activity activity,Consumer<String> found,Consumer<String> error,Runnable pickImage,Runnable requestCamera,boolean cameraAllowed){
        this.activity=activity;this.found=found;this.error=error;this.pickImage=pickImage;this.requestCamera=requestCamera;this.cameraAllowed=cameraAllowed;
        dialog=new Dialog(activity,android.R.style.Theme_Material_NoActionBar);
        displays=(DisplayManager)activity.getSystemService(Context.DISPLAY_SERVICE);
        Map<DecodeHintType,Object> hints=new EnumMap<>(DecodeHintType.class);
        hints.put(DecodeHintType.POSSIBLE_FORMATS,Collections.singletonList(BarcodeFormat.QR_CODE));
        hints.put(DecodeHintType.TRY_HARDER,Boolean.TRUE);decoder.setHints(hints);
        LinearLayout layout=new LinearLayout(activity);layout.setOrientation(LinearLayout.VERTICAL);layout.setBackgroundColor(Color.BLACK);
        // The reference leaves a quiet black band above the live viewfinder.
        layout.addView(new View(activity),new LinearLayout.LayoutParams(-1,0,.10f));
        FrameLayout viewfinder=new FrameLayout(activity);viewfinder.setClipChildren(true);
        viewfinder.setContentDescription(UiStrings.t("将分享名片的二维码放入取景框"));
        preview=new TextureView(activity);viewfinder.addView(preview,new FrameLayout.LayoutParams(-1,-1));
        overlay=new ScanOverlayView(activity);viewfinder.addView(overlay,new FrameLayout.LayoutParams(-1,-1));
        enable=new TextView(activity);enable.setText(UiStrings.t("开启相机扫码"));enable.setTextColor(Color.WHITE);enable.setTextSize(18);enable.setGravity(Gravity.CENTER);enable.setPadding(dp(16),dp(16),dp(16),dp(16));enable.setFocusable(true);
        enable.setVisibility(cameraAllowed?View.GONE:View.VISIBLE);viewfinder.addView(enable,new FrameLayout.LayoutParams(-1,dp(80),Gravity.CENTER));
        enable.setOnClickListener(v->requestCamera.run());
        layout.addView(viewfinder,new LinearLayout.LayoutParams(-1,0,.62f));
        FrameLayout footer=new FrameLayout(activity);footer.setBackgroundColor(Color.BLACK);
        LinearLayout controls=new LinearLayout(activity);controls.setGravity(Gravity.CENTER_VERTICAL);controls.setPadding(dp(28),0,dp(28),0);
        controls.addView(control("album",UiStrings.t("从相册选择二维码"),()->{dialog.dismiss();pickImage.run();}),new LinearLayout.LayoutParams(dp(64),dp(64)));
        controls.addView(new View(activity),new LinearLayout.LayoutParams(0,1,1));
        controls.addView(control("close",UiStrings.t("关闭扫码"),dialog::dismiss),new LinearLayout.LayoutParams(dp(64),dp(64)));
        footer.addView(controls,new FrameLayout.LayoutParams(-1,dp(80),Gravity.CENTER));
        layout.addView(footer,new LinearLayout.LayoutParams(-1,0,.28f));
        layout.setOnApplyWindowInsetsListener((view,insets)->{view.setPadding(insets.getSystemWindowInsetLeft(),insets.getSystemWindowInsetTop(),insets.getSystemWindowInsetRight(),insets.getSystemWindowInsetBottom());return insets;});
        dialog.setContentView(layout);dialog.setOnDismissListener(d->stop());
        preview.setSurfaceTextureListener(new TextureView.SurfaceTextureListener(){
            public void onSurfaceTextureAvailable(SurfaceTexture surface,int width,int height){open();}
            public void onSurfaceTextureSizeChanged(SurfaceTexture surface,int width,int height){configureTransform();}
            public boolean onSurfaceTextureDestroyed(SurfaceTexture surface){closeCamera();return true;}
            public void onSurfaceTextureUpdated(SurfaceTexture surface){}
        });
    }
    private View control(String icon,String description,Runnable action){
        FrameLayout hit=new FrameLayout(activity);hit.setContentDescription(description);hit.setFocusable(true);hit.setOnClickListener(v->action.run());
        hit.addView(new SiteIconView(activity,icon,Color.WHITE,false),new FrameLayout.LayoutParams(dp(30),dp(30),Gravity.CENTER));return hit;
    }
    private int dp(int value){return Math.round(value*activity.getResources().getDisplayMetrics().density);}
    void show(){
        thread=new HandlerThread("qr-camera");thread.start();worker=new Handler(thread.getLooper());
        Window window=dialog.getWindow();if(window!=null){
            window.setBackgroundDrawable(new ColorDrawable(Color.BLACK));window.addFlags(WindowManager.LayoutParams.FLAG_FULLSCREEN|WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
            window.setStatusBarColor(Color.BLACK);window.setNavigationBarColor(Color.BLACK);
            window.getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY|View.SYSTEM_UI_FLAG_FULLSCREEN|View.SYSTEM_UI_FLAG_HIDE_NAVIGATION|View.SYSTEM_UI_FLAG_LAYOUT_STABLE);
        }
        dialog.show();if(window!=null)window.setLayout(-1,-1);
        displays.registerDisplayListener(displayListener,main);if(preview.isAvailable())open();
    }
    void dismiss(){dialog.dismiss();}
    void startCamera(){cameraAllowed=true;enable.setVisibility(View.GONE);open();}
    void onPause(){active=false;closeCamera();}
    void onResume(){active=true;open();}
    private boolean usable(){return !finished.get()&&active&&cameraAllowed&&dialog.isShowing()&&preview.isAvailable();}
    private void open(){
        if(!usable()||worker==null||opening||camera!=null)return;opening=true;final int generation=++cameraGeneration;
        try{
            CameraManager manager=(CameraManager)activity.getSystemService(Context.CAMERA_SERVICE);String chosen=null;CameraCharacteristics characteristics=null;
            for(String id:manager.getCameraIdList()){CameraCharacteristics candidate=manager.getCameraCharacteristics(id);Integer facing=candidate.get(CameraCharacteristics.LENS_FACING);if(facing!=null&&facing==CameraCharacteristics.LENS_FACING_BACK){chosen=id;characteristics=candidate;break;}}
            if(chosen==null||characteristics==null){fail(UiStrings.t("未找到后置相机"));return;}
            Integer orientation=characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);sensorDegrees=orientation==null?0:orientation;
            StreamConfigurationMap map=characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);if(map==null)throw new IllegalStateException("Missing camera sizes");
            previewSize=choosePreview(map.getOutputSizes(SurfaceTexture.class));Size scanSize=chooseScan(map.getOutputSizes(android.graphics.ImageFormat.YUV_420_888));
            reader=ImageReader.newInstance(scanSize.getWidth(),scanSize.getHeight(),android.graphics.ImageFormat.YUV_420_888,2);reader.setOnImageAvailableListener(source->decode(source,generation),worker);
            configureTransform();final int[] afModes=characteristics.get(CameraCharacteristics.CONTROL_AF_AVAILABLE_MODES);
            manager.openCamera(chosen,new CameraDevice.StateCallback(){
                public void onOpened(CameraDevice device){if(!usable()||generation!=cameraGeneration){device.close();return;}camera=device;opening=false;startPreview(generation,afModes);}
                public void onDisconnected(CameraDevice device){device.close();if(generation==cameraGeneration&&usable())fail(UiStrings.t("相机已断开"));}
                public void onError(CameraDevice device,int code){device.close();if(generation==cameraGeneration&&usable())fail(UiStrings.t("无法打开相机"));}
            },main);
        }catch(Exception e){fail(UiStrings.t("无法打开相机"));}
    }
    private Size choosePreview(Size[] sizes){
        if(sizes==null||sizes.length==0)throw new IllegalStateException("No preview size");
        int displayDegrees=displayRotation();boolean swapped=(sensorDegrees+displayDegrees)%180!=0;
        double target=swapped?(double)preview.getHeight()/Math.max(1,preview.getWidth()):(double)preview.getWidth()/Math.max(1,preview.getHeight());
        Size best=null;double bestScore=Double.MAX_VALUE;
        for(Size size:sizes){int longer=Math.max(size.getWidth(),size.getHeight()),shorter=Math.min(size.getWidth(),size.getHeight());if(longer>1920||shorter>1080)continue;
            double aspect=(double)size.getWidth()/size.getHeight();double score=Math.abs(Math.log(aspect/target))*10+Math.abs(Math.log((double)size.getWidth()*size.getHeight()/(1280*720)));
            if(score<bestScore){best=size;bestScore=score;}
        }
        if(best==null){best=sizes[0];for(Size size:sizes)if((long)size.getWidth()*size.getHeight()<(long)best.getWidth()*best.getHeight())best=size;}return best;
    }
    private Size chooseScan(Size[] sizes){
        if(sizes==null||sizes.length==0)throw new IllegalStateException("No analysis size");Size best=null;
        for(Size size:sizes)if(size.getWidth()<=640&&size.getHeight()<=480&&(best==null||(long)size.getWidth()*size.getHeight()>(long)best.getWidth()*best.getHeight()))best=size;
        if(best==null){best=sizes[0];for(Size size:sizes)if((long)size.getWidth()*size.getHeight()<(long)best.getWidth()*best.getHeight())best=size;}return best;
    }
    private int displayRotation(){Display display=preview.getDisplay();return (display==null?activity.getWindowManager().getDefaultDisplay():display).getRotation()*90;}
    private void configureTransform(){
        if(finished.get()||previewSize==null||preview.getWidth()==0||preview.getHeight()==0)return;
        CameraPreviewGeometry geometry=CameraPreviewGeometry.centerCrop(preview.getWidth(),preview.getHeight(),previewSize.getWidth(),previewSize.getHeight(),sensorDegrees,displayRotation());
        float x=preview.getWidth()/2f,y=preview.getHeight()/2f;Matrix matrix=new Matrix();
        matrix.setScale(geometry.scaleX,geometry.scaleY,x,y);matrix.postRotate(geometry.rotation,x,y);matrix.postScale(geometry.fillScale,geometry.fillScale,x,y);preview.setTransform(matrix);
    }
    private void startPreview(int generation,int[] afModes){
        try{
            SurfaceTexture texture=preview.getSurfaceTexture();if(texture==null||camera==null||reader==null)return;
            texture.setDefaultBufferSize(previewSize.getWidth(),previewSize.getHeight());displaySurface=new Surface(texture);Surface scan=reader.getSurface();
            CaptureRequest.Builder request=camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);request.addTarget(displaySurface);request.addTarget(scan);
            if(afModes!=null)for(int mode:afModes)if(mode==CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE){request.set(CaptureRequest.CONTROL_AF_MODE,mode);break;}
            camera.createCaptureSession(Arrays.asList(displaySurface,scan),new CameraCaptureSession.StateCallback(){
                public void onConfigured(CameraCaptureSession result){if(!usable()||generation!=cameraGeneration){result.close();return;}session=result;try{result.setRepeatingRequest(request.build(),null,worker);overlay.scanning(true);}catch(CameraAccessException e){fail(UiStrings.t("相机预览失败"));}}
                public void onConfigureFailed(CameraCaptureSession result){if(generation==cameraGeneration&&usable())fail(UiStrings.t("相机预览失败"));}
            },main);
        }catch(Exception e){if(generation==cameraGeneration&&usable())fail(UiStrings.t("相机预览失败"));}
    }
    private void decode(ImageReader source,int generation){
        Image image=null;
        try{
            image=source.acquireLatestImage();if(image==null)return;long now=System.currentTimeMillis();if(finished.get()||now-lastDecode<160)return;lastDecode=now;
            Image.Plane plane=image.getPlanes()[0];ByteBuffer buffer=plane.getBuffer();int width=image.getWidth(),height=image.getHeight(),rowStride=plane.getRowStride(),pixelStride=plane.getPixelStride(),base=buffer.position();
            byte[] luminance=new byte[width*height];for(int y=0;y<height;y++)for(int x=0;x<width;x++)luminance[y*width+x]=buffer.get(base+y*rowStride+x*pixelStride);
            String value=decoder.decodeWithState(new BinaryBitmap(new HybridBinarizer(new PlanarYUVLuminanceSource(luminance,width,height,0,0,width,height,false)))).getText();
            main.post(()->{if(generation==cameraGeneration&&usable()&&finished.compareAndSet(false,true)){dialog.dismiss();found.accept(value);}});
        }catch(Exception ignored){}finally{decoder.reset();if(image!=null)image.close();}
    }
    private void fail(String message){if(finished.compareAndSet(false,true))main.post(()->{dialog.dismiss();error.accept(message);});}
    private void closeCamera(){
        cameraGeneration++;opening=false;overlay.scanning(false);
        try{if(session!=null)session.close();}catch(Exception ignored){}session=null;
        try{if(camera!=null)camera.close();}catch(Exception ignored){}camera=null;
        ImageReader previousReader=reader;reader=null;
        // Close after the worker finishes reading a frame; its ByteBuffer must remain valid.
        if(previousReader!=null){try{previousReader.setOnImageAvailableListener(null,null);}catch(Exception ignored){}if(worker==null||!worker.post(()->{try{previousReader.close();}catch(Exception ignored){}})){try{previousReader.close();}catch(Exception ignored){}}}
        if(displaySurface!=null){displaySurface.release();displaySurface=null;}
    }
    private void stop(){finished.set(true);displays.unregisterDisplayListener(displayListener);closeCamera();if(thread!=null){thread.quitSafely();thread=null;}worker=null;}
}
