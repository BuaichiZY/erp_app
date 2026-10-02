package sex.erp.android;

import android.animation.ValueAnimator;
import android.content.Context;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.Rect;
import android.os.Bundle;
import android.os.SystemClock;
import android.view.MotionEvent;
import android.view.View;
import android.view.ViewConfiguration;
import android.view.ViewGroup;
import android.view.accessibility.AccessibilityNodeInfo;
import android.webkit.WebView;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.ProgressBar;
import android.widget.TextView;
import android.widget.ScrollView;
import java.util.function.BooleanSupplier;

/** Native refresh overlay, independent of the page's child layout and scrolling. */
final class PullRefreshLayout extends FrameLayout {
    private static final int REFRESH_ACTION = 0x00ef0001;
    private final float density;
    private final PullRefreshGesture gesture;
    private final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
    private final Rect bounds = new Rect();
    private Runnable refresh;
    private BooleanSupplier available = () -> true;
    private ThemePalette palette;
    private float startX, startY, shown;
    private boolean refreshing, intercepted;
    private boolean blankOnly;
    private ValueAnimator settle;

    PullRefreshLayout(Context context, ThemePalette palette) {
        super(context);
        density = getResources().getDisplayMetrics().density;
        gesture = new PullRefreshGesture(ViewConfiguration.get(context).getScaledTouchSlop() / density);
        this.palette = palette;
        setImportantForAccessibility(IMPORTANT_FOR_ACCESSIBILITY_YES);
    }
    void palette(ThemePalette value) { palette = value; invalidate(); }
    void onRefresh(Runnable action, BooleanSupplier available) { this.refresh = action; this.available = available; }
    void blankOnly(boolean value) { blankOnly=value;gesture.cancel(); }

    @Override public boolean onInterceptTouchEvent(MotionEvent event) {
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_DOWN:
                intercepted = false;
                startX = event.getX(); startY = event.getY();
                boolean blank = canStartAt(this, event.getRawX(), event.getRawY());
                gesture.start(blank, true, refreshing || refresh == null || !available.getAsBoolean());
                break;
            case MotionEvent.ACTION_MOVE:
                if (gesture.move((event.getX()-startX)/density, (event.getY()-startY)/density, event.getPointerCount())) {
                    stopSettling(); intercepted = true; shown = gesture.progress();
                    getParent().requestDisallowInterceptTouchEvent(true);
                    invalidate(); return true;
                }
                break;
            case MotionEvent.ACTION_POINTER_DOWN:
            case MotionEvent.ACTION_CANCEL:
            case MotionEvent.ACTION_UP:
                gesture.cancel(); break;
        }
        return false;
    }
    @Override public void requestDisallowInterceptTouchEvent(boolean disallow) {
        // ScrollView must not suppress the parent's eligible downward gesture.
        // Upward/horizontal gestures and interactive children keep normal dispatch.
        if (!disallow || !gesture.eligible()) super.requestDisallowInterceptTouchEvent(disallow);
    }
    @Override public boolean onTouchEvent(MotionEvent event) {
        if (event.getActionMasked() == MotionEvent.ACTION_DOWN) {
            onInterceptTouchEvent(event);
            return gesture.eligible() || super.onTouchEvent(event);
        }
        switch (event.getActionMasked()) {
            case MotionEvent.ACTION_MOVE:
                gesture.move((event.getX()-startX)/density, (event.getY()-startY)/density, event.getPointerCount());
                shown = gesture.progress(); invalidate(); return true;
            case MotionEvent.ACTION_UP:
                boolean released = gesture.release(); intercepted = false;
                if (released && available.getAsBoolean()) beginRefresh(); else hideIndicator();
                return true;
            case MotionEvent.ACTION_POINTER_DOWN:
            case MotionEvent.ACTION_CANCEL:
                gesture.cancel(); intercepted = false; hideIndicator(); return true;
        }
        return intercepted || super.onTouchEvent(event);
    }
    private boolean canStartAt(View view, float x, float y) {
        if (view.getVisibility()!=VISIBLE || !view.getGlobalVisibleRect(bounds) || !bounds.contains((int)x,(int)y)) return true;
        if (view instanceof ScrollView && view.canScrollVertically(-1)) return false;
        boolean interactive=view!=this && (view.isClickable() || view.isLongClickable() || view instanceof TextView || view instanceof ImageView || view instanceof WebView || view instanceof SwipeCardView || view instanceof ProfileTileView || view instanceof ProgressBar);
        if (!PullRefreshGesture.allowsStart(blankOnly,interactive)) return false;
        if (view instanceof ViewGroup) {
            ViewGroup group = (ViewGroup)view;
            for (int i=group.getChildCount()-1;i>=0;i--) if (!canStartAt(group.getChildAt(i),x,y)) return false;
        }
        return true;
    }
    private void beginRefresh() {
        stopSettling(); refreshing = true; shown = 1; invalidate();
        announceForAccessibility("正在刷新");
        refresh.run();
    }
    void finishRefresh() { refreshing = false; hideIndicator(); }
    void cancelRefresh() { refreshing = intercepted = false; gesture.cancel(); stopSettling(); shown = 0; invalidate(); }
    private void stopSettling() { if (settle!=null) { settle.cancel(); settle=null; } }
    private void hideIndicator() {
        stopSettling();
        if (shown==0) return;
        settle = ValueAnimator.ofFloat(shown,0); settle.setDuration(180);
        settle.addUpdateListener(a->{shown=(float)a.getAnimatedValue();invalidate();}); settle.start();
    }
    @Override protected void dispatchDraw(Canvas canvas) {
        super.dispatchDraw(canvas);
        if (shown<=0) return;
        canvas.save(); canvas.translate(getWidth()/2f, (10+shown*22)*density);
        paint.setStyle(Paint.Style.FILL); paint.setColor(palette.surface); paint.setAlpha(Math.round(shown*255));
        canvas.drawRoundRect(-90*density,-20*density,90*density,20*density,20*density,20*density,paint);
        paint.setColor(palette.accent); paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(2*density);
        float angle = refreshing?(SystemClock.uptimeMillis()%1000)*.36f:270;
        canvas.drawArc(-73*density,-8*density,-57*density,8*density,angle,refreshing?260:Math.max(30,shown*300),false,paint);
        paint.setStyle(Paint.Style.FILL);paint.setColor(palette.text);paint.setTextSize(13*density);paint.setTextAlign(Paint.Align.CENTER);
        canvas.drawText(refreshing?"正在刷新":gesture.ready()?"松开刷新":"下拉刷新",10*density,4*density,paint);
        canvas.restore(); if (refreshing) postInvalidateOnAnimation();
    }
    @Override public void onInitializeAccessibilityNodeInfo(AccessibilityNodeInfo info) {
        super.onInitializeAccessibilityNodeInfo(info);
        info.addAction(new AccessibilityNodeInfo.AccessibilityAction(REFRESH_ACTION,"刷新当前页面"));
    }
    @Override public boolean performAccessibilityAction(int action, Bundle arguments) {
        if (action==REFRESH_ACTION && !refreshing && refresh!=null && available.getAsBoolean()) { beginRefresh(); return true; }
        return super.performAccessibilityAction(action,arguments);
    }
    @Override protected void onDetachedFromWindow() { cancelRefresh();super.onDetachedFromWindow(); }
}
