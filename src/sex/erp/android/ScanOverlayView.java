package sex.erp.android;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.LinearGradient;
import android.graphics.Paint;
import android.graphics.Shader;
import android.view.View;
import android.view.animation.LinearInterpolator;

/** A subtle moving scan beam, drawn above the undimmed live camera image. */
final class ScanOverlayView extends View {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private ValueAnimator animator;
    private boolean scanning;
    private float progress;
    ScanOverlayView(Context context){super(context);setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);}
    void scanning(boolean enabled){scanning=enabled;if(enabled&&isAttachedToWindow())start();else stop();invalidate();}
    private void start(){if(animator!=null)return;animator=ValueAnimator.ofFloat(0,1);animator.setDuration(2800);animator.setRepeatCount(ValueAnimator.INFINITE);animator.setRepeatMode(ValueAnimator.REVERSE);animator.setInterpolator(new LinearInterpolator());animator.addUpdateListener(a->{progress=(float)a.getAnimatedValue();invalidate();});animator.start();}
    private void stop(){if(animator!=null){animator.cancel();animator=null;}}
    @Override protected void onDraw(Canvas canvas){
        if(!scanning)return;float density=getResources().getDisplayMetrics().density;
        float left=12*density,right=getWidth()-left,y=getHeight()*(.10f+.80f*progress),trail=22*density;
        paint.setShader(new LinearGradient(0,y-trail,0,y,new int[]{0x0000cbd0,0x1800cbd0},null,Shader.TileMode.CLAMP));
        canvas.drawRect(left,y-trail,right,y,paint);
        paint.setShader(new LinearGradient(left,y,right,y,new int[]{0xff40d4d9,0xff90afe3,0xffb084b9},null,Shader.TileMode.CLAMP));
        canvas.drawRect(left,y,right,y+1.2f*density,paint);paint.setShader(null);
    }
    @Override protected void onAttachedToWindow(){super.onAttachedToWindow();if(scanning)start();}
    @Override protected void onDetachedFromWindow(){stop();super.onDetachedFromWindow();}
}
