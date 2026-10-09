package sex.erp.android;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Paint;
import android.view.View;
import android.view.animation.PathInterpolator;

/** Likes use four 3:4 cards; visitors use five short rows, as on the site. */
final class LikesSkeletonView extends View {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final boolean visitors;
    private int color,columns;
    private float cardWidth,cardHeight,opacity=1;
    private ValueAnimator pulse;
    LikesSkeletonView(Context context,ThemePalette palette,boolean visitors){
        super(context);this.visitors=visitors;color=palette.surface2;
        setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
    }
    void palette(ThemePalette palette){color=palette.surface2;invalidate();}
    private int dp(int value){return Math.round(value*getResources().getDisplayMetrics().density);}
    @Override protected void onMeasure(int widthSpec,int heightSpec){
        int width=MeasureSpec.getSize(widthSpec),screenWidth=getResources().getConfiguration().screenWidthDp;
        columns=visitors?1:screenWidth>=1024?4:screenWidth>=640?3:2;
        int gap=dp(visitors?8:12),count=visitors?5:4,rows=(count+columns-1)/columns;
        cardWidth=Math.max(0,(width-(columns-1)*gap)/(float)columns);cardHeight=visitors?dp(56):cardWidth*4/3;
        setMeasuredDimension(resolveSize(width,widthSpec),resolveSize(Math.round(rows*cardHeight+(rows-1)*gap),heightSpec));
    }
    @Override protected void onDraw(Canvas canvas){
        paint.setColor(color);paint.setAlpha(Math.round(Color.alpha(color)*opacity));
        int gap=dp(visitors?8:12),count=visitors?5:4;
        for(int i=0;i<count;i++){float left=(i%columns)*(cardWidth+gap),top=(i/columns)*(cardHeight+gap);canvas.drawRoundRect(left,top,left+cardWidth,top+cardHeight,dp(16),dp(16),paint);}
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
