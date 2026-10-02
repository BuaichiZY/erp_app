package sex.erp.android;

import android.content.Context;
import android.graphics.*;
import android.os.SystemClock;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;

/** Moving, softly blended light around a stationary gold star. */
final class SuperLikeButton extends FrameLayout {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Matrix rotation=new Matrix();
    private final Path clip=new Path();
    private SweepGradient gradient;
    private ThemePalette palette;
    private boolean visible;
    SuperLikeButton(Context context,ThemePalette palette,Runnable action){
        super(context);this.palette=palette;setWillNotDraw(false);setContentDescription(UiStrings.t("超级喜欢"));setFocusable(true);setOnClickListener(v->action.run());
        int size=Math.round(24*getResources().getDisplayMetrics().density);
        addView(new SiteIconView(context,"star",palette.pop?0xff141414:0xfff5b82e,true),new LayoutParams(size,size,Gravity.CENTER));
    }
    void palette(ThemePalette value){palette=value;((SiteIconView)getChildAt(0)).tint(value.pop?0xff141414:0xfff5b82e);invalidate();}
    @Override protected void onSizeChanged(int w,int h,int oldW,int oldH){
        gradient=new SweepGradient(w/2f,h/2f,new int[]{0xffef70a9,0xff8f80df,0xff65b9e3,0xff66c796,0xffeab757,0xffef70a9},null);
    }
    @Override protected void onDraw(Canvas canvas){
        float cx=getWidth()/2f,cy=getHeight()/2f,r=Math.min(cx,cy)-1;
        float phase=(SystemClock.uptimeMillis()%9000)/9000f;
        if(palette.pop){float line=2.5f*getResources().getDisplayMetrics().density;paint.setShader(null);paint.setStyle(Paint.Style.FILL);paint.setColor(palette.border);canvas.drawCircle(cx+1,cy+1,r,paint);paint.setColor(0xff7ce0ff);canvas.drawCircle(cx-1,cy-1,r-line/2,paint);paint.setStyle(Paint.Style.STROKE);paint.setColor(palette.border);paint.setStrokeWidth(line);canvas.drawCircle(cx-1,cy-1,r-line/2,paint);paint.setStyle(Paint.Style.FILL);return;}
        paint.setShader(null);paint.setStyle(Paint.Style.FILL);paint.setColor(palette.surface);canvas.drawCircle(cx,cy,r,paint);
        if(gradient!=null){
            rotation.setRotate(phase*360,cx,cy);gradient.setLocalMatrix(rotation);
            clip.reset();clip.addCircle(cx,cy,r,Path.Direction.CW);canvas.save();canvas.clipPath(clip);
            paint.setShader(gradient);paint.setAlpha(palette.dark?80:64);canvas.drawCircle(cx,cy,r,paint);
            float angle=phase*(float)Math.PI*2,glowX=cx+(float)Math.cos(angle)*r*.55f,glowY=cy+(float)Math.sin(angle)*r*.55f;
            paint.setShader(new RadialGradient(glowX,glowY,r*1.05f,new int[]{palette.dark?0x00404040:0xb3ffffff,0x00ffffff},null,Shader.TileMode.CLAMP));paint.setAlpha(255);canvas.drawCircle(cx,cy,r,paint);canvas.restore();
            paint.setShader(gradient);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(getResources().getDisplayMetrics().density);paint.setAlpha(palette.dark?170:110);canvas.drawCircle(cx,cy,r,paint);
        }
        paint.setShader(null);paint.setAlpha(255);paint.setStyle(Paint.Style.FILL);
        if(visible&&isEnabled()&&isAttachedToWindow())postInvalidateDelayed(33);
    }
    @Override public void onVisibilityAggregated(boolean isVisible){super.onVisibilityAggregated(isVisible);visible=isVisible;if(isVisible)invalidate();}
    @Override public void setEnabled(boolean enabled){super.setEnabled(enabled);invalidate();}
    @Override protected void onDetachedFromWindow(){visible=false;super.onDetachedFromWindow();}
}
