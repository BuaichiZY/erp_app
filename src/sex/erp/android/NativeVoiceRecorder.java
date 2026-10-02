package sex.erp.android;

import android.Manifest;
import android.app.*;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.media.MediaRecorder;
import android.os.*;
import android.view.Gravity;
import android.widget.*;
import java.io.File;
import java.util.function.Consumer;

/** Foreground-only recording, with a permission request on the Record action. */
final class NativeVoiceRecorder {
    static final int PERMISSION=701;
    private final Activity activity;
    private final Consumer<File> done;
    private final Handler handler=new Handler(Looper.getMainLooper());
    private AlertDialog dialog;
    private MediaRecorder recorder;
    private File file;
    private TextView timer,status;
    private Button record,send;
    private long started;
    private int duration;
    private boolean closed,handedOff;
    private final Runnable tick=new Runnable(){public void run(){if(recorder==null||closed)return;int seconds=(int)((SystemClock.elapsedRealtime()-started)/1000);timer.setText(EnergyTime.countdown(seconds)+" / 2:00");if(seconds>=120){stop();return;}handler.postDelayed(this,200);}};
    NativeVoiceRecorder(Activity activity,ThemePalette palette,Consumer<File> done,Runnable chooseFile){
        this.activity=activity;this.done=done;
        LinearLayout content=new LinearLayout(activity);content.setOrientation(LinearLayout.VERTICAL);content.setPadding(dp(20),dp(16),dp(20),dp(12));content.setBackgroundColor(palette.surface);
        timer=new TextView(activity);timer.setText("0:00 / 2:00");timer.setTextSize(22);timer.setTextColor(palette.text);timer.setGravity(Gravity.CENTER);content.addView(timer);
        status=new TextView(activity);status.setText("语音长度为 1 秒至 2 分钟");status.setTextColor(palette.muted);status.setPadding(0,dp(12),0,dp(12));content.addView(status);
        record=new Button(activity);record.setAllCaps(false);record.setText("开始录音");record.setOnClickListener(v->{if(recorder!=null)stop();else requestStart();});content.addView(record);
        dialog=new AlertDialog.Builder(activity).setTitle("发送语音").setView(content).setPositiveButton("下一步",null).setNegativeButton("取消",null).setNeutralButton("选择语音文件",(d,w)->chooseFile.run()).create();
        dialog.setOnDismissListener(d->cleanup());dialog.show();send=dialog.getButton(AlertDialog.BUTTON_POSITIVE);send.setEnabled(false);send.setOnClickListener(v->{if(file==null||duration<1)return;handedOff=true;File result=file;dialog.dismiss();done.accept(result);});
    }
    private int dp(int n){return Math.round(n*activity.getResources().getDisplayMetrics().density);}
    private void requestStart(){
        if(activity.checkSelfPermission(Manifest.permission.RECORD_AUDIO)!=PackageManager.PERMISSION_GRANTED){activity.requestPermissions(new String[]{Manifest.permission.RECORD_AUDIO},PERMISSION);return;}
        start();
    }
    void permissionResult(boolean granted){if(closed||!dialog.isShowing())return;if(granted)start();else status.setText("未获得麦克风权限，可重试或选择已有语音文件");}
    private void start(){
        if(closed||recorder!=null)return;
        if(file!=null){file.delete();file=null;}
        send.setEnabled(false);duration=0;
        try{
            file=File.createTempFile("voice-",".m4a",activity.getCacheDir());
            recorder=new MediaRecorder();recorder.setAudioSource(MediaRecorder.AudioSource.MIC);recorder.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4);recorder.setAudioEncoder(MediaRecorder.AudioEncoder.AAC);recorder.setAudioSamplingRate(44100);recorder.setAudioEncodingBitRate(96000);recorder.setMaxDuration(120000);recorder.setOutputFile(file.getAbsolutePath());recorder.setOnInfoListener((r,what,extra)->{if(what==MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED)stop();});recorder.setOnErrorListener((r,what,extra)->{release();send.setEnabled(false);record.setText("重新录音");status.setText("录音中断，请重新录制");});recorder.prepare();recorder.start();started=SystemClock.elapsedRealtime();record.setText("停止录音");status.setText("正在录音，离开应用会取消录音");handler.post(tick);
        }catch(Exception error){release();if(file!=null){file.delete();file=null;}record.setText("重新录音");status.setText("无法开始录音，请检查麦克风是否被其他应用占用");}
    }
    private void stop(){
        if(recorder==null)return;duration=(int)((SystemClock.elapsedRealtime()-started)/1000);
        try{recorder.stop();}catch(RuntimeException error){duration=0;}
        release();record.setText("重新录音");send.setEnabled(duration>=1);timer.setText(EnergyTime.countdown(Math.min(duration,120))+" / 2:00");status.setText(duration>=1?"录音完成，点击下一步选择内容分级":"录音不足 1 秒，请重新录制");
    }
    private void release(){handler.removeCallbacks(tick);if(recorder!=null){try{recorder.reset();recorder.release();}catch(Exception ignored){}recorder=null;}}
    private void cleanup(){closed=true;release();if(!handedOff&&file!=null)file.delete();}
    void onPause(){if(recorder!=null)close();}
    void close(){if(dialog!=null&&dialog.isShowing())dialog.dismiss();else cleanup();}
}
