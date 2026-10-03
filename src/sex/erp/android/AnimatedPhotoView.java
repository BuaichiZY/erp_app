package sex.erp.android;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.*;
import android.view.animation.DecelerateInterpolator;

/** Native shimmer and rotating dot indicator, followed by a short photo fade-in. */
final class AnimatedPhotoView extends FocusedPhotoView {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private ValueAnimator pulse,fade;
    private boolean loading,failed;
    private float phase,reveal=1;
    private int muted=0xff9ba0ad;
    AnimatedPhotoView(Context context){super(context);}
    void palette(ThemePalette p){muted=p.muted;invalidate();}
    void loading(){stop();loading=true;failed=false;reveal=0;setImageDrawable(null);setContentDescription(UiStrings.t("图片加载中"));if(isAttachedToWindow())startPulse();invalidate();}
    void ready(Bitmap bitmap){stop();loading=false;failed=false;setImageBitmap(bitmap);setContentDescription(UiStrings.t("名片图片"));if(!isAttachedToWindow()){reveal=1;return;}reveal=0;fade=ValueAnimator.ofFloat(0,1);fade.setDuration(280);fade.setInterpolator(new DecelerateInterpolator());fade.addUpdateListener(a->{reveal=(float)a.getAnimatedValue();invalidate();});fade.start();}
    void readyCached(Bitmap bitmap){stop();loading=false;failed=false;reveal=1;setImageBitmap(bitmap);setContentDescription(UiStrings.t("名片图片"));invalidate();}
    void failed(){stop();loading=false;failed=true;reveal=1;setContentDescription(UiStrings.t("图片加载失败"));invalidate();}
    private void startPulse(){pulse=ValueAnimator.ofFloat(0,1);pulse.setDuration(1100);pulse.setRepeatCount(ValueAnimator.INFINITE);pulse.addUpdateListener(a->{phase=(float)a.getAnimatedValue();invalidate();});pulse.start();}
    private void stop(){if(pulse!=null){pulse.cancel();pulse=null;}if(fade!=null){fade.cancel();fade=null;}}
    @Override protected void onDraw(Canvas canvas){
        if(!loading&&!failed){int saved=canvas.saveLayerAlpha(0,0,getWidth(),getHeight(),Math.round(reveal*255));super.onDraw(canvas);canvas.restoreToCount(saved);return;}
        float density=getResources().getDisplayMetrics().density,w=getWidth(),h=getHeight();
        if(loading){float center=(phase*2-0.5f)*w;paint.setShader(new LinearGradient(center-w*.4f,0,center+w*.4f,h,new int[]{0x009ba0ad,0x129ba0ad,0x009ba0ad},null,Shader.TileMode.CLAMP));canvas.drawRect(0,0,w,h,paint);paint.setShader(null);float radius=12*density;for(int i=0;i<12;i++){double angle=(i/12.0)*Math.PI*2;float relative=(i/12f-phase+1)%1;paint.setColor(muted);paint.setAlpha(Math.round(35+(1-relative)*170));canvas.drawCircle(w/2+(float)Math.cos(angle)*radius,h/2+(float)Math.sin(angle)*radius,1.5f*density,paint);}paint.setAlpha(255);
        }else{paint.setColor(muted);paint.setTextSize(12*density);paint.setTextAlign(Paint.Align.CENTER);canvas.drawText(UiStrings.t("图片加载失败"),w/2,h/2,paint);}
    }
    @Override protected void onAttachedToWindow(){super.onAttachedToWindow();if(loading)startPulse();}
    @Override protected void onDetachedFromWindow(){stop();if(!loading)reveal=1;super.onDetachedFromWindow();}
}
