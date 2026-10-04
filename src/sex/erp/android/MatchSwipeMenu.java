package sex.erp.android;

import android.content.Context;
import android.graphics.Color;
import android.view.*;
import android.view.animation.DecelerateInterpolator;
import android.widget.*;

/** Horizontal row actions; vertical movement stays with the list and pull-to-refresh. */
final class MatchSwipeMenu extends FrameLayout {
    static final class Group {
        MatchSwipeMenu open;
        void clear(){if(open!=null)open.close();open=null;}
    }
    private final View content;
    private final LinearLayout menu;
    private final Group group;
    private final int slop,menuWidth;
    private float startX,startY,initial;
    private boolean tracking,dragging,vertical,closeOnly;
    private VelocityTracker velocity;
    MatchSwipeMenu(Context context,View content,Group group,ThemePalette palette,String pinLabel,String readLabel,Runnable pin,Runnable read){
        super(context);this.content=content;this.group=group;slop=ViewConfiguration.get(context).getScaledTouchSlop();
        int width=Math.round(104*getResources().getDisplayMetrics().density);menuWidth=width*2;
        menu=new LinearLayout(context);menu.setOrientation(LinearLayout.HORIZONTAL);
        menu.addView(action(pinLabel,palette.surface2,palette.text,pin),new LinearLayout.LayoutParams(width,-1));
        menu.addView(action(readLabel,palette.accent,palette.pop?palette.text:Color.WHITE,read),new LinearLayout.LayoutParams(width,-1));
        addView(menu,new LayoutParams(menuWidth,-1,Gravity.RIGHT));menu.setVisibility(INVISIBLE);
        addView(content,new LayoutParams(-1,-2));setClipChildren(true);setClipToPadding(true);
    }
    private TextView action(String label,int color,int foreground,Runnable callback){
        TextView text=new TextView(getContext());text.setText(label);text.setTextSize(14);text.setTextColor(foreground);
        text.setGravity(Gravity.CENTER);text.setBackgroundColor(color);text.setFocusable(true);text.setContentDescription(label);
        text.setOnClickListener(v->{close();callback.run();});return text;
    }
    private boolean begin(MotionEvent event){
        // Visible action buttons receive normal clicks, without starting a content gesture.
        if(content.getTranslationX()<0&&event.getX()>=getWidth()+content.getTranslationX())return false;
        content.animate().cancel();initial=content.getTranslationX();startX=event.getX();startY=event.getY();
        tracking=true;dragging=false;vertical=false;closeOnly=group.open!=null;
        if(group.open!=null&&group.open!=this)group.open.close();
        recycle();velocity=VelocityTracker.obtain();velocity.addMovement(event);return false;
    }
    @Override public boolean onInterceptTouchEvent(MotionEvent event){
        int type=event.getActionMasked();
        if(type==MotionEvent.ACTION_DOWN)return begin(event);
        if(!tracking)return false;
        if(type==MotionEvent.ACTION_MOVE){
            float x=event.getX()-startX,y=event.getY()-startY;
            if(!dragging&&!vertical&&Math.abs(y)>slop&&Math.abs(y)>=Math.abs(x)){vertical=true;if(group.open==this)close();}
            if(!vertical&&MatchSwipePolicy.horizontal(x,y,slop)){dragging=true;getParent().requestDisallowInterceptTouchEvent(true);move(initial+x);return true;}
        }
        if(type==MotionEvent.ACTION_UP&&closeOnly&&!vertical)return true;
        if(type==MotionEvent.ACTION_UP||type==MotionEvent.ACTION_CANCEL){tracking=false;recycle();}
        return false;
    }
    @Override public boolean onTouchEvent(MotionEvent event){
        int type=event.getActionMasked();if(type==MotionEvent.ACTION_DOWN){if(!tracking)begin(event);return true;}
        if(!tracking)return true;if(velocity!=null)velocity.addMovement(event);
        if(type==MotionEvent.ACTION_MOVE){float x=event.getX()-startX,y=event.getY()-startY;
            if(!dragging&&!vertical&&Math.abs(y)>slop&&Math.abs(y)>=Math.abs(x)){vertical=true;if(group.open==this)close();}
            if(!vertical&&(dragging||MatchSwipePolicy.horizontal(x,y,slop))){dragging=true;getParent().requestDisallowInterceptTouchEvent(true);move(initial+x);}return true;}
        if(type==MotionEvent.ACTION_UP){float speed=0;if(velocity!=null){velocity.computeCurrentVelocity(1000);speed=velocity.getXVelocity();}
            boolean reveal=dragging&&MatchSwipePolicy.reveal(content.getTranslationX(),menuWidth,speed);tracking=false;recycle();settle(reveal);return true;}
        if(type==MotionEvent.ACTION_CANCEL||type==MotionEvent.ACTION_POINTER_DOWN){tracking=false;recycle();settle(initial<0);return true;}return true;
    }
    private void move(float offset){menu.setVisibility(VISIBLE);content.setTranslationX(Math.max(-menuWidth,Math.min(0,offset)));}
    private void settle(boolean reveal){if(reveal){if(group.open!=null&&group.open!=this)group.open.close();group.open=this;menu.setVisibility(VISIBLE);}else if(group.open==this)group.open=null;
        content.animate().cancel();content.animate().translationX(reveal?-menuWidth:0).setDuration(180).setInterpolator(new DecelerateInterpolator()).withEndAction(()->{if(!reveal)menu.setVisibility(INVISIBLE);}).start();}
    void close(){settle(false);}
    private void recycle(){if(velocity!=null){velocity.recycle();velocity=null;}}
    @Override protected void onDetachedFromWindow(){content.animate().cancel();recycle();if(group.open==this)group.open=null;super.onDetachedFromWindow();}
}
