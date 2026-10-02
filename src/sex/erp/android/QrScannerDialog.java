package sex.erp.android;

import android.app.Activity;
import android.app.Dialog;
import android.content.Context;
import android.graphics.Color;
import android.graphics.SurfaceTexture;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.media.Image;
import android.media.ImageReader;
import android.os.Handler;
import android.os.HandlerThread;
import android.view.Gravity;
import android.view.Surface;
import android.view.TextureView;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;
import com.google.zxing.BinaryBitmap;
import com.google.zxing.MultiFormatReader;
import com.google.zxing.NotFoundException;
import com.google.zxing.common.HybridBinarizer;
import com.google.zxing.PlanarYUVLuminanceSource;
import java.nio.ByteBuffer;
import java.util.Arrays;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.function.Consumer;

/** Camera is opened only while this native QR dialog is visible. */
final class QrScannerDialog {
    private final Activity activity;
    private final Consumer<String> found;
    private final Consumer<String> error;
    private final Runnable pickImage;
    private final Runnable requestCamera;
    private final Dialog dialog;
    private final TextureView preview;
    private final AtomicBoolean finished=new AtomicBoolean();
    private HandlerThread thread;
    private Handler worker;
    private CameraDevice camera;
    private CameraCaptureSession session;
    private ImageReader reader;
    private long lastDecode;
    private boolean cameraAllowed;
    private boolean opening;

    QrScannerDialog(Activity activity,Consumer<String> found,Consumer<String> error,Runnable pickImage,Runnable requestCamera,boolean cameraAllowed){
        this.activity=activity;this.found=found;this.error=error;this.pickImage=pickImage;this.requestCamera=requestCamera;this.cameraAllowed=cameraAllowed;dialog=new Dialog(activity);
        FrameLayout layout=new FrameLayout(activity);layout.setBackgroundColor(Color.BLACK);
        preview=new TextureView(activity);layout.addView(preview,new FrameLayout.LayoutParams(-1,-1));
        TextView hint=new TextView(activity);hint.setText(UiStrings.t("将分享名片的二维码放入取景框"));hint.setTextColor(Color.WHITE);hint.setTextSize(16);hint.setGravity(Gravity.CENTER);hint.setPadding(20,15,20,15);FrameLayout.LayoutParams hintLp=new FrameLayout.LayoutParams(-1,-2,Gravity.BOTTOM);hintLp.bottomMargin=105;layout.addView(hint,hintLp);
        TextView album=new TextView(activity);album.setText(UiStrings.t("▣ 从相册选择"));album.setTextColor(Color.WHITE);album.setTextSize(16);album.setGravity(Gravity.CENTER);album.setPadding(20,16,20,16);FrameLayout.LayoutParams albumLp=new FrameLayout.LayoutParams(-2,-2,Gravity.BOTTOM|Gravity.CENTER_HORIZONTAL);albumLp.bottomMargin=40;layout.addView(album,albumLp);album.setOnClickListener(v->{dialog.dismiss();pickImage.run();});
        if(!cameraAllowed){TextView enable=new TextView(activity);enable.setText(UiStrings.t("开启相机扫码"));enable.setTextColor(Color.WHITE);enable.setTextSize(18);enable.setGravity(Gravity.CENTER);FrameLayout.LayoutParams enableLp=new FrameLayout.LayoutParams(-1,90,Gravity.CENTER);layout.addView(enable,enableLp);enable.setOnClickListener(v->{layout.removeView(enable);requestCamera.run();});}
        TextView close=new TextView(activity);close.setText("✕");close.setTextColor(Color.WHITE);close.setTextSize(25);close.setGravity(Gravity.CENTER);FrameLayout.LayoutParams closeLp=new FrameLayout.LayoutParams(58,58,Gravity.TOP|Gravity.RIGHT);layout.addView(close,closeLp);close.setOnClickListener(v->dialog.dismiss());
        dialog.setContentView(layout);dialog.setOnDismissListener(d->stop());
        preview.setSurfaceTextureListener(new TextureView.SurfaceTextureListener(){public void onSurfaceTextureAvailable(SurfaceTexture surface,int width,int height){if(QrScannerDialog.this.cameraAllowed)open();}public void onSurfaceTextureSizeChanged(SurfaceTexture surface,int width,int height){}public boolean onSurfaceTextureDestroyed(SurfaceTexture surface){stop();return true;}public void onSurfaceTextureUpdated(SurfaceTexture surface){} });
    }
    void show(){dialog.show();if(dialog.getWindow()!=null)dialog.getWindow().setLayout(-1,-1);thread=new HandlerThread("qr-camera");thread.start();worker=new Handler(thread.getLooper());if(cameraAllowed&&preview.isAvailable())open();}
    void dismiss(){dialog.dismiss();}
    void startCamera(){cameraAllowed=true;if(dialog.isShowing()&&preview.isAvailable())open();}
    private void open(){if(finished.get()||worker==null||opening)return;opening=true;try{
        CameraManager manager=(CameraManager)activity.getSystemService(Context.CAMERA_SERVICE);String chosen=null;for(String id:manager.getCameraIdList()){Integer facing=manager.getCameraCharacteristics(id).get(CameraCharacteristics.LENS_FACING);if(facing!=null&&facing==CameraCharacteristics.LENS_FACING_BACK){chosen=id;break;}}if(chosen==null){fail(UiStrings.t("未找到后置相机"));return;}
        reader=ImageReader.newInstance(640,480,android.graphics.ImageFormat.YUV_420_888,2);reader.setOnImageAvailableListener(this::decode,worker);
        manager.openCamera(chosen,new CameraDevice.StateCallback(){public void onOpened(CameraDevice device){if(finished.get()){device.close();return;}camera=device;startPreview();}public void onDisconnected(CameraDevice device){device.close();fail(UiStrings.t("相机已断开"));}public void onError(CameraDevice device,int code){device.close();fail(UiStrings.t("无法打开相机"));}},worker);
    }catch(Exception e){fail(UiStrings.t("无法打开相机"));}}
    private void startPreview(){try{SurfaceTexture texture=preview.getSurfaceTexture();if(texture==null||camera==null)return;texture.setDefaultBufferSize(640,480);Surface display=new Surface(texture);Surface scan=reader.getSurface();CaptureRequest.Builder request=camera.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);request.addTarget(display);request.addTarget(scan);request.set(CaptureRequest.CONTROL_AF_MODE,CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_PICTURE);camera.createCaptureSession(Arrays.asList(display,scan),new CameraCaptureSession.StateCallback(){public void onConfigured(CameraCaptureSession result){if(finished.get()){result.close();return;}session=result;try{result.setRepeatingRequest(request.build(),null,worker);}catch(CameraAccessException e){fail(UiStrings.t("相机预览失败"));}}public void onConfigureFailed(CameraCaptureSession result){fail(UiStrings.t("相机预览失败"));}},worker);}catch(Exception e){fail(UiStrings.t("相机预览失败"));}}
    private void decode(ImageReader source){Image image=source.acquireLatestImage();if(image==null)return;try{long now=System.currentTimeMillis();if(finished.get()||now-lastDecode<160)return;lastDecode=now;Image.Plane plane=image.getPlanes()[0];ByteBuffer buffer=plane.getBuffer();int width=image.getWidth(),height=image.getHeight(),stride=plane.getRowStride();byte[] all=new byte[buffer.remaining()];buffer.get(all);byte[] luminance=new byte[width*height];for(int y=0;y<height;y++)System.arraycopy(all,y*stride,luminance,y*width,width);String value=new MultiFormatReader().decode(new BinaryBitmap(new HybridBinarizer(new PlanarYUVLuminanceSource(luminance,width,height,0,0,width,height,false)))).getText();if(finished.compareAndSet(false,true))activity.runOnUiThread(()->{dialog.dismiss();found.accept(value);});}catch(Exception ignored){}finally{image.close();}}
    private void fail(String message){if(finished.compareAndSet(false,true))activity.runOnUiThread(()->{dialog.dismiss();error.accept(message);});}
    private void stop(){finished.set(true);try{if(session!=null)session.close();}catch(Exception ignored){}try{if(camera!=null)camera.close();}catch(Exception ignored){}try{if(reader!=null)reader.close();}catch(Exception ignored){}if(thread!=null){thread.quitSafely();thread=null;}}
}
