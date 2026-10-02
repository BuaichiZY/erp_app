package sex.erp.android;

import android.content.Context;
import android.view.*;
import android.view.animation.OvershootInterpolator;
import android.widget.*;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import java.util.function.Consumer;

/** Moves the whole native card; children still receive taps until the drag threshold. */
final class SwipeCardView extends FrameLayout {
    private final float density;
    private final int slop;
    private final Consumer<String> action;
    private final TextView like,pass,superlike;
    private float startX,startY;
    private int pointer=-1;
    private boolean dragging,busy;
    private VelocityTracker velocity;
    SwipeCardView(Context context,View content,Consumer<String> action){
        super(context);this.action=action;density=getResources().getDisplayMetrics().density;slop=ViewConfiguration.get(context).getScaledTouchSlop();
        setClipChildren(false);setClipToPadding(false);addView(content,new LayoutParams(-1,-1));
        like=stamp(UiStrings.t("喜欢"),0xff4ade80,Gravity.TOP|Gravity.LEFT,-12,24);
        pass=stamp(UiStrings.t("跳过"),0xffff5a4e,Gravity.TOP|Gravity.RIGHT,12,24);
        superlike=stamp(UiStrings.t("超喜欢"),0xffffd447,Gravity.BOTTOM|Gravity.CENTER_HORIZONTAL,0,148);
    }
    private TextView stamp(String label,int color,int gravity,float rotate,int margin){
        TextView t=new TextView(getContext());t.setText(label);t.setTextColor(color);t.setTextSize(29);t.setTypeface(null,Typeface.BOLD);t.setPadding(dp(12),dp(4),dp(12),dp(4));
        GradientDrawable bg=new GradientDrawable();bg.setColor(0xb3101115);bg.setCornerRadius(dp(5));bg.setStroke(dp(2),color);t.setBackground(bg);t.setRotation(rotate);t.setAlpha(0);t.setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_NO);
        LayoutParams lp=new LayoutParams(-2,-2,gravity);lp.leftMargin=lp.rightMargin=dp(24);lp.topMargin=dp(margin);lp.bottomMargin=dp(margin);addView(t,lp);return t;
    }
    private int dp(int n){return Math.round(n*density);}
    boolean isBusy(){return busy;}
    void hold(){busy=true;}
    private void begin(MotionEvent e){animate().cancel();setScaleX(1);setScaleY(1);pointer=e.getPointerId(0);startX=e.getRawX();startY=e.getRawY();dragging=false;recycle();velocity=VelocityTracker.obtain();velocity.addMovement(e);}
    @Override public boolean onInterceptTouchEvent(MotionEvent e){
        if(busy)return true;
        if(e.getActionMasked()==MotionEvent.ACTION_DOWN)begin(e);
        if(e.getActionMasked()==MotionEvent.ACTION_MOVE&&pointer>=0){
            if(Math.hypot(e.getRawX()-startX,e.getRawY()-startY)>slop){dragging=true;getParent().requestDisallowInterceptTouchEvent(true);return true;}
        }
        if(e.getActionMasked()==MotionEvent.ACTION_UP||e.getActionMasked()==MotionEvent.ACTION_CANCEL){pointer=-1;recycle();}
        return false;
    }
    @Override public boolean onTouchEvent(MotionEvent e){
        if(busy)return true;
        int type=e.getActionMasked();
        if(type==MotionEvent.ACTION_DOWN){begin(e);return true;}
        if(pointer<0)return true;
        if(velocity!=null)velocity.addMovement(e);
        if(type==MotionEvent.ACTION_POINTER_DOWN||type==MotionEvent.ACTION_CANCEL){pointer=-1;restore();return true;}
        if(type==MotionEvent.ACTION_MOVE){dragging=true;pose(e.getRawX()-startX,e.getRawY()-startY);return true;}
        if(type==MotionEvent.ACTION_UP){
            float x=(e.getRawX()-startX)/density,y=(e.getRawY()-startY)/density,vx=0;
            if(velocity!=null){velocity.computeCurrentVelocity(1000);vx=velocity.getXVelocity(pointer)/density;}
            pointer=-1;recycle();String selected=dragging?SwipeGesturePolicy.action(x,y,vx):null;
            if(selected==null)restore();else perform(selected);return true;
        }
        return true;
    }
    private void pose(float x,float y){setTranslationX(x);setTranslationY(y);setRotation(SwipeGesturePolicy.rotation(x/density));boolean down=y>0&&Math.abs(y)>=Math.abs(x);like.setAlpha(down?0:SwipeGesturePolicy.likeOpacity(x/density));pass.setAlpha(down?0:SwipeGesturePolicy.passOpacity(x/density));superlike.setAlpha(down?0:SwipeGesturePolicy.superOpacity(y/density));}
    void perform(String selected){
        if(busy)return;busy=true;dragging=false;recycle();
        like.setAlpha("like".equals(selected)?1:0);pass.setAlpha("pass".equals(selected)?1:0);superlike.setAlpha("superlike".equals(selected)?1:0);
        float distance=Math.max(getResources().getDisplayMetrics().widthPixels,dp(600));
        animate().translationX("superlike".equals(selected)?0:("like".equals(selected)?distance:-distance)).translationY("superlike".equals(selected)?-Math.max(dp(700),getHeight()):0).rotation("superlike".equals(selected)?0:("like".equals(selected)?20:-20)).alpha(0).setDuration(300).setInterpolator(new android.view.animation.AccelerateInterpolator(.8f)).withEndAction(()->action.accept(selected)).start();
    }
    void restore(){
        busy=true;dragging=false;recycle();like.setAlpha(0);pass.setAlpha(0);superlike.setAlpha(0);
        animate().cancel();animate().translationX(0).translationY(0).rotation(0).alpha(1).setDuration(320).setInterpolator(new OvershootInterpolator(.8f)).withEndAction(()->busy=false).start();
    }
    private void recycle(){if(velocity!=null){velocity.recycle();velocity=null;}}
    @Override protected void onDetachedFromWindow(){animate().cancel();recycle();super.onDetachedFromWindow();}
}
