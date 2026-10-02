package sex.erp.android;

import android.content.Context;
import android.graphics.Color;
import android.graphics.Rect;
import android.graphics.drawable.GradientDrawable;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.view.*;
import android.view.animation.LinearInterpolator;
import android.widget.*;
import org.json.*;

/** Two repeating lanes of public guestbook notes, with lifecycle-aware cleanup. */
final class DanmakuView extends FrameLayout {
    private final Handler handler=new Handler(Looper.getMainLooper());
    private final NativeApi api;
    private final ThemePalette palette;
    private final boolean small;
    private JSONArray entries=new JSONArray();
    private Runnable open;
    private boolean active=true,visible;
    private int index,lastLane=-1;
    private long rest;
    private final long[] laneReady={0,0};
    private final Rect viewport=new Rect();
    private final Runnable launch=new Runnable(){@Override public void run(){
        if(!active||!visible||!isAttachedToWindow()||entries.length()==0)return;
        if(getWidth()==0){handler.postDelayed(this,100);return;}
        if(!getGlobalVisibleRect(viewport)){for(int i=0;i<getChildCount();i++)getChildAt(i).animate().cancel();removeAllViews();laneReady[0]=laneReady[1]=0;handler.postDelayed(this,800);return;}
        long now=SystemClock.uptimeMillis();
        if(index>=Math.min(50,entries.length())){
            if(getChildCount()>0){handler.postDelayed(this,400);return;}
            if(rest==0)rest=now;
            if(now-rest<6000){handler.postDelayed(this,400);return;}
            index=0;rest=0;
        }
        int lane=lastLane==0?1:0;
        if(laneReady[lane]>now){handler.postDelayed(this,400);return;}
        JSONObject note=entries.optJSONObject(index++);
        if(note==null||note.optString("body").isEmpty()){handler.post(this);return;}
        lastLane=lane;showNote(note,lane);handler.postDelayed(this,small?3000:3500);
    }};
    DanmakuView(Context context,NativeApi api,ThemePalette palette,boolean small){super(context);this.api=api;this.palette=palette;this.small=small;setClipChildren(true);setClickable(false);}
    private int dp(int n){return Math.round(n*getResources().getDisplayMetrics().density);}
    void entries(JSONArray value,Runnable open){entries=value;this.open=open;restart();}
    void active(boolean enabled){active=enabled;setVisibility(enabled?VISIBLE:GONE);restart();}
    private void stop(){handler.removeCallbacksAndMessages(null);for(int i=0;i<getChildCount();i++)getChildAt(i).animate().cancel();removeAllViews();}
    private void restart(){stop();index=0;lastLane=-1;rest=0;laneReady[0]=laneReady[1]=0;if(active&&visible&&isAttachedToWindow())handler.post(launch);}
    private void showNote(JSONObject note,int lane){
        LinearLayout chip=new LinearLayout(getContext());chip.setGravity(Gravity.CENTER_VERTICAL);chip.setPadding(dp(2),dp(2),dp(8),dp(2));
        GradientDrawable background=new GradientDrawable();background.setColor(0x90000000);background.setCornerRadius(dp(24));chip.setBackground(background);
        JSONObject author=note.optJSONObject("author");int avatarSize=dp(small?16:22);
        if(author!=null&&author.optJSONObject("avatar")!=null){AnimatedPhotoView avatar=new AnimatedPhotoView(getContext());avatar.palette(palette);avatar.setScaleType(ImageView.ScaleType.CENTER_CROP);GradientDrawable mask=new GradientDrawable();mask.setColor(0xff333333);mask.setCornerRadius(avatarSize);avatar.setBackground(mask);avatar.setClipToOutline(true);chip.addView(avatar,new LinearLayout.LayoutParams(avatarSize,avatarSize));api.image(avatar,author.optJSONObject("avatar"),true);}
        TextView text=new TextView(getContext());text.setText(note.optString("body"));text.setTextSize(small?11:13);text.setTextColor(Color.WHITE);text.setSingleLine();text.setEllipsize(android.text.TextUtils.TruncateAt.END);text.setMaxWidth(Math.max(dp(60),(int)(getWidth()*.78f)-avatarSize-dp(14)));LinearLayout.LayoutParams copy=new LinearLayout.LayoutParams(-2,-2);copy.leftMargin=dp(4);chip.addView(text,copy);
        LayoutParams lp=new LayoutParams(-2,dp(small?24:30),Gravity.TOP|Gravity.LEFT);lp.topMargin=Math.round(getHeight()*.25f)+lane*dp(small?26:34);addView(chip,lp);chip.setTranslationX(getWidth());chip.setContentDescription((author==null?"":author.optString("displayName")+"：")+note.optString("body"));if(open!=null)chip.setOnClickListener(v->open.run());
        chip.post(()->{if(!active||!visible||chip.getParent()!=this)return;float density=getResources().getDisplayMetrics().density,speed=Math.min(80,Math.max(40,getWidth()/density/6f))*density;long duration=(long)((getWidth()+chip.getWidth())/speed*1000);laneReady[lane]=SystemClock.uptimeMillis()+(long)((chip.getWidth()+Math.max(dp(60),getWidth()*.45f))/speed*1000);chip.animate().translationX(-chip.getWidth()).setDuration(duration).setInterpolator(new LinearInterpolator()).withEndAction(()->removeView(chip)).start();});
    }
    @Override public void onVisibilityAggregated(boolean isVisible){super.onVisibilityAggregated(isVisible);visible=isVisible;restart();}
    @Override protected void onAttachedToWindow(){super.onAttachedToWindow();visible=isShown();restart();}
    @Override protected void onDetachedFromWindow(){visible=false;stop();super.onDetachedFromWindow();}
}
