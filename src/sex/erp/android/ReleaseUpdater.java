package sex.erp.android;

import android.app.Activity;
import android.app.Dialog;
import android.app.DownloadManager;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.os.Handler;
import android.os.Looper;
import android.provider.Settings;
import android.view.Gravity;
import android.view.Window;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.InputStream;
import java.net.URL;
import javax.net.ssl.HttpsURLConnection;
import java.util.function.Consumer;
import java.io.File;
import java.io.FileInputStream;
import java.security.MessageDigest;
import java.util.Map;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;

/** Checks the public project's latest GitHub release and delegates downloads to Android. */
final class ReleaseUpdater {
    private static final String ENDPOINT="https://api.github.com/repos/BuaichiZY/erp_app/releases?per_page=20";
    private final Activity activity;
    private final SharedPreferences prefs;
    private final Consumer<String> notice;
    private final Handler handler=new Handler(Looper.getMainLooper());
    private ThemePalette palette;
    private boolean visible,awaitingInstallAccess,checking,manualRequested,updateAvailable,preparing,validating;
    private long verifiedId=-1;
    private Runnable availabilityChanged=()->{};
    void onAvailabilityChanged(Runnable listener){availabilityChanged=listener;}
    boolean updateAvailable(){return updateAvailable;}
    void checkSilently(){check(false);}
    private final Runnable poll=new Runnable(){public void run(){checkDownload();}};
    ReleaseUpdater(Activity activity,SharedPreferences prefs,ThemePalette palette,Consumer<String> notice){this.activity=activity;this.prefs=prefs;this.palette=palette;this.notice=notice;}
    void palette(ThemePalette value){palette=value;}
    void check(){check(true);}
    private void check(boolean manual){manualRequested|=manual;if(checking)return;checking=true;if(manual)notice.accept(UiStrings.t("正在检查更新…"));new Thread(()->{
        JSONObject release=null;String problem=null;
        try{HttpsURLConnection conn=(HttpsURLConnection)new URL(ENDPOINT).openConnection();try{conn.setConnectTimeout(12000);conn.setReadTimeout(15000);conn.setRequestProperty("Accept","application/vnd.github+json");conn.setRequestProperty("User-Agent","ERP-Android/1.0");int status=conn.getResponseCode();if(status!=200)throw new IllegalStateException("GitHub HTTP "+status);try(InputStream in=conn.getInputStream();ByteArrayOutputStream out=new ByteArrayOutputStream()){byte[] chunk=new byte[8192];int n;while((n=in.read(chunk))>=0){if(out.size()+n>2*1024*1024)throw new IllegalStateException("Response too large");out.write(chunk,0,n);}JSONArray releases=new JSONArray(out.toString("UTF-8"));for(int i=0;i<releases.length();i++){JSONObject candidate=releases.optJSONObject(i);if(candidate!=null&&!candidate.optBoolean("draft")&&!apkUrl(candidate).isEmpty()&&(release==null||candidate.optString("published_at").compareTo(release.optString("published_at"))>0))release=candidate;}}}finally{conn.disconnect();}}catch(Exception e){problem=e.getMessage();}
        JSONObject found=release;String failure=problem;activity.runOnUiThread(()->{checking=false;boolean show=manualRequested;manualRequested=false;if(activity.isFinishing()||activity.isDestroyed())return;if(failure!=null){if(show)notice.accept(UiStrings.t("无法检查更新：")+failure);return;}String current;try{current=activity.getPackageManager().getPackageInfo(activity.getPackageName(),0).versionName;}catch(Exception e){return;}updateAvailable=found!=null&&ReleaseVersion.newer(found.optString("tag_name"),current);availabilityChanged.run();if(!show)return;if(found==null){notice.accept(UiStrings.t("仓库尚无发布版本"));return;}showRelease(found);});
    },"release-check").start();}
    private static String apkUrl(JSONObject release){JSONArray assets=release.optJSONArray("assets");if(assets!=null)for(int i=0;i<assets.length();i++){JSONObject asset=assets.optJSONObject(i);if(asset!=null&&ReleaseAssetPolicy.valid(asset.optString("name"),asset.optString("browser_download_url")))return asset.optString("browser_download_url");}return "";}

    private void showRelease(JSONObject release){String tag=release.optString("tag_name");String current;try{current=activity.getPackageManager().getPackageInfo(activity.getPackageName(),0).versionName;}catch(Exception e){notice.accept(UiStrings.t("无法检查更新：")+e.getMessage());return;}if(!ReleaseVersion.newer(tag,current)){notice.accept(UiStrings.t("当前已是最新版本"));return;}
        String apk=apkUrl(release);if(apk.isEmpty()){notice.accept(UiStrings.t("最新发布尚无可安装的 APK"));return;}
        Dialog dialog=new Dialog(activity);LinearLayout layout=new LinearLayout(activity);layout.setOrientation(1);layout.setPadding(dp(22),dp(26),dp(22),dp(24));GradientDrawable background=new GradientDrawable();background.setColor(palette.surface);background.setCornerRadius(dp(24));layout.setBackground(background);
        TextView title=label(UiStrings.t("当前有新版本发布"),23,palette.accent);title.setGravity(Gravity.CENTER);title.setTypeface(null,1);layout.addView(title);TextView version=label(tag,14,palette.muted);version.setGravity(Gravity.CENTER);LinearLayout.LayoutParams versionLp=new LinearLayout.LayoutParams(-1,-2);versionLp.topMargin=dp(8);layout.addView(version,versionLp);
        ScrollView notes=new ScrollView(activity);TextView body=label(release.optString("body",UiStrings.t("本次发布暂无更新日志。")),14,palette.text);body.setPadding(0,dp(20),0,dp(20));notes.addView(body);LinearLayout.LayoutParams notesLp=new LinearLayout.LayoutParams(-1,0,1);notesLp.topMargin=dp(12);layout.addView(notes,notesLp);
        LinearLayout actions=new LinearLayout(activity);Button update=button(UiStrings.t("立即更新"),true);Button later=button(UiStrings.t("稍后再说"),false);LinearLayout.LayoutParams choice=new LinearLayout.LayoutParams(0,dp(48),1);choice.rightMargin=dp(6);actions.addView(update,choice);actions.addView(later,new LinearLayout.LayoutParams(0,dp(48),1));layout.addView(actions);later.setOnClickListener(v->dialog.dismiss());update.setOnClickListener(v->{dialog.dismiss();prepareDownload(release);});dialog.setContentView(layout);dialog.show();Window window=dialog.getWindow();if(window!=null){window.setBackgroundDrawableResource(android.R.color.transparent);window.setGravity(Gravity.BOTTOM);window.setLayout(-1,Math.min(dp(550),activity.getResources().getDisplayMetrics().heightPixels-dp(70)));}
    }
    private void prepareDownload(JSONObject release){
        if(preparing||prefs.getLong("update_download_id",-1)>=0){notice.accept(UiStrings.t("正在下载更新"));return;}
        preparing=true;notice.accept(UiStrings.t("正在准备下载…"));
        new Thread(()->{
            UpdateDownloadResolver.Result result=null;UpdateDownloadResolver.MirrorException mirrorError=null;boolean failed=false;
            try{result=new UpdateDownloadResolver().resolve(release.optString("tag_name"),apkUrl(release));}
            catch(UpdateDownloadResolver.MirrorException e){mirrorError=e;}catch(Exception e){failed=true;}
            UpdateDownloadResolver.Result resolved=result;UpdateDownloadResolver.MirrorException problem=mirrorError;boolean error=failed;
            activity.runOnUiThread(()->{preparing=false;if(activity.isFinishing()||activity.isDestroyed())return;
                if(problem!=null){
                    if(problem.missing){notice.accept(UiStrings.t("国内下载源尚未同步此版本"));return;}
                    notice.accept(UiStrings.t("国内下载源需要网页验证，请在浏览器中完成下载"));
                    try{activity.startActivity(new Intent(Intent.ACTION_VIEW,Uri.parse(problem.filePage)));}catch(Exception e){notice.accept(UiStrings.t("下载更新失败"));}return;
                }
                if(error||resolved==null){notice.accept(UiStrings.t("下载更新失败"));return;}
                download(resolved,release);
            });
        },"update-download-source").start();
    }
    private void download(UpdateDownloadResolver.Result source,JSONObject release){try{
        String tag=release.optString("tag_name"),digest="";
        JSONArray assets=release.optJSONArray("assets");if(assets!=null)for(int i=0;i<assets.length();i++){
            JSONObject asset=assets.optJSONObject(i);if(asset!=null&&apkUrl(release).equals(asset.optString("browser_download_url"))){digest=asset.optString("digest");break;}
        }
        String filename="ERP-"+tag.replaceAll("[^A-Za-z0-9._-]","")+"-"+System.currentTimeMillis()+".apk";
        DownloadManager manager=(DownloadManager)activity.getSystemService(Context.DOWNLOAD_SERVICE);
        DownloadManager.Request request=new DownloadManager.Request(Uri.parse(source.url));
        for(Map.Entry<String,String> header:source.headers.entrySet())request.addRequestHeader(header.getKey(),header.getValue());
        request.setTitle("ERP "+tag);request.setDescription(UiStrings.t("正在下载更新"));request.setMimeType("application/vnd.android.package-archive");request.setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE_NOTIFY_COMPLETED);
        request.setDestinationInExternalFilesDir(activity,Environment.DIRECTORY_DOWNLOADS,filename);
        long id=manager.enqueue(request);verifiedId=-1;awaitingInstallAccess=false;
        prefs.edit().putLong("update_download_id",id).putString("update_download_file",filename).putString("update_download_version",tag).putString("update_download_digest",digest).apply();
        notice.accept(UiStrings.t("已开始下载更新"));resume();
    }catch(Exception e){notice.accept(UiStrings.t("下载更新失败"));}}
    private boolean validDownloadedApk(){try{
        String filename=prefs.getString("update_download_file","");if(!filename.matches("ERP-[A-Za-z0-9._-]+\\.apk"))return false;
        File apk=new File(activity.getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS),filename);
        PackageManager pm=activity.getPackageManager();
        PackageInfo candidate=pm.getPackageArchiveInfo(apk.getAbsolutePath(),PackageManager.GET_SIGNATURES);
        PackageInfo installed=pm.getPackageInfo(activity.getPackageName(),PackageManager.GET_SIGNATURES);
        if(candidate==null||!activity.getPackageName().equals(candidate.packageName)||ReleaseVersion.compare(candidate.versionName,prefs.getString("update_download_version",""))!=0||!ReleaseVersion.newer(candidate.versionName,installed.versionName))return false;
        if(candidate.signatures==null||installed.signatures==null||candidate.signatures.length!=installed.signatures.length)return false;
        java.util.Set<String> expected=new java.util.HashSet<>(),actual=new java.util.HashSet<>();
        for(android.content.pm.Signature signature:installed.signatures)expected.add(signature.toCharsString());
        for(android.content.pm.Signature signature:candidate.signatures)actual.add(signature.toCharsString());
        if(!expected.equals(actual))return false;
        String digest=prefs.getString("update_download_digest","");
        if(digest.startsWith("sha256:")){
            MessageDigest sha=MessageDigest.getInstance("SHA-256");try(InputStream in=new FileInputStream(apk)){byte[] buffer=new byte[16384];int n;while((n=in.read(buffer))!=-1)sha.update(buffer,0,n);}
            StringBuilder hex=new StringBuilder();for(byte b:sha.digest())hex.append(String.format(java.util.Locale.ROOT,"%02x",b&255));
            if(!hex.toString().equalsIgnoreCase(digest.substring(7)))return false;
        }
        return true;
    }catch(Exception e){return false;}}
    void resume(){visible=true;handler.removeCallbacks(poll);if(prefs.getLong("update_download_id",-1)>=0)handler.postDelayed(poll,1200);}
    void pause(){visible=false;handler.removeCallbacks(poll);}
    void close(){pause();}
    private void checkDownload(){if(!visible)return;long id=prefs.getLong("update_download_id",-1);if(id<0)return;DownloadManager manager=(DownloadManager)activity.getSystemService(Context.DOWNLOAD_SERVICE);try{DownloadManager.Query query=new DownloadManager.Query().setFilterById(id);try(android.database.Cursor rows=manager.query(query)){if(rows==null||!rows.moveToFirst()){prefs.edit().remove("update_download_id").apply();return;}int status=rows.getInt(rows.getColumnIndexOrThrow(DownloadManager.COLUMN_STATUS));if(status==DownloadManager.STATUS_SUCCESSFUL){if(verifiedId!=id){if(!validating){validating=true;new Thread(()->{boolean valid=validDownloadedApk();activity.runOnUiThread(()->{validating=false;if(prefs.getLong("update_download_id",-1)!=id)return;if(valid){verifiedId=id;if(visible)handler.post(poll);}else{prefs.edit().remove("update_download_id").apply();manager.remove(id);if(!activity.isFinishing()&&!activity.isDestroyed())notice.accept(UiStrings.t("下载文件校验失败，请重新检查更新"));}});},"update-apk-validation").start();}return;}if(Build.VERSION.SDK_INT>=26&&!activity.getPackageManager().canRequestPackageInstalls()){if(!awaitingInstallAccess){awaitingInstallAccess=true;notice.accept(UiStrings.t("请允许安装此来源的应用"));Intent setting=new Intent(Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,Uri.parse("package:"+activity.getPackageName()));activity.startActivity(setting);}return;}Uri uri=manager.getUriForDownloadedFile(id);prefs.edit().remove("update_download_id").apply();if(uri==null){notice.accept(UiStrings.t("无法打开下载的 APK"));return;}Intent install=new Intent(Intent.ACTION_INSTALL_PACKAGE);install.setDataAndType(uri,"application/vnd.android.package-archive");install.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);activity.startActivity(install);return;}if(status==DownloadManager.STATUS_FAILED){prefs.edit().remove("update_download_id").apply();notice.accept(UiStrings.t("下载更新失败"));return;}}}catch(Exception e){notice.accept(UiStrings.t("无法打开下载的 APK"));prefs.edit().remove("update_download_id").apply();return;}handler.postDelayed(poll,1500);}
    private int dp(int value){return Math.round(value*activity.getResources().getDisplayMetrics().density);}
    private TextView label(String value,int size,int color){TextView view=new TextView(activity);view.setText(value);view.setTextSize(size);view.setTextColor(color);return view;}
    private Button button(String value,boolean primary){Button view=new Button(activity);view.setText(value);view.setAllCaps(false);view.setTextSize(14);view.setTextColor(primary?Color.WHITE:palette.text);GradientDrawable drawable=new GradientDrawable();drawable.setColor(primary?palette.accent:palette.surface2);drawable.setCornerRadius(dp(15));view.setBackground(drawable);return view;}
}
