package sex.erp.android;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.view.View;
import android.view.animation.PathInterpolator;

/** Four rounded placeholders with the site's two-second opacity pulse. */
final class MatchGroupSkeletonView extends View {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final int rowHeight,inset;
    private int color;
    private float opacity=1;
    private ValueAnimator pulse;
    MatchGroupSkeletonView(Context context,ThemePalette palette,boolean headers){
        super(context);color=palette.surface2;rowHeight=dp(headers?56:64);inset=dp(headers?0:4);
        setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
    }
    void palette(ThemePalette palette){color=palette.surface2;invalidate();}
    private int dp(int value){return Math.round(value*getResources().getDisplayMetrics().density);}
    @Override protected void onMeasure(int width,int height){setMeasuredDimension(MeasureSpec.getSize(width),resolveSize(4*rowHeight+dp(24)+2*inset,height));}
    @Override protected void onDraw(Canvas canvas){
        paint.setColor(color);paint.setAlpha(Math.round(android.graphics.Color.alpha(color)*opacity));
        for(int i=0;i<4;i++){float top=inset+i*(rowHeight+dp(8));canvas.drawRoundRect(inset,top,getWidth()-inset,top+rowHeight,dp(16),dp(16),paint);}
    }
    private void updateAnimation(){
        if(isAttachedToWindow()&&isShown()&&getWindowVisibility()==VISIBLE){
            if(pulse!=null)return;
            pulse=ValueAnimator.ofFloat(1,.5f);pulse.setDuration(1000);pulse.setRepeatCount(ValueAnimator.INFINITE);pulse.setRepeatMode(ValueAnimator.REVERSE);
            pulse.setInterpolator(new PathInterpolator(.4f,0,.6f,1));pulse.addUpdateListener(a->{opacity=(float)a.getAnimatedValue();invalidate();});pulse.start();
        }else stop();
    }
    private void stop(){if(pulse!=null){pulse.cancel();pulse=null;}opacity=1;}
    @Override protected void onAttachedToWindow(){super.onAttachedToWindow();updateAnimation();}
    @Override protected void onVisibilityChanged(View view,int visibility){super.onVisibilityChanged(view,visibility);updateAnimation();}
    @Override protected void onWindowVisibilityChanged(int visibility){super.onWindowVisibilityChanged(visibility);updateAnimation();}
    @Override protected void onDetachedFromWindow(){stop();super.onDetachedFromWindow();}
}
