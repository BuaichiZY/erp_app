package sex.erp.android;

import android.content.Context;
import android.graphics.*;
import android.os.SystemClock;
import android.view.Gravity;
import android.widget.*;

/** Compact profile pills; the superlike keeps its outlined star above moving gold light. */
final class ProfileActionButton extends LinearLayout {
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG);
    private final String action;
    private ThemePalette palette;
    private boolean visible;
    ProfileActionButton(Context context,ThemePalette palette,String action,Runnable click){
        super(context);this.action=action;this.palette=palette;setWillNotDraw(false);setGravity(Gravity.CENTER);setFocusable(true);setClickable(true);setOnClickListener(v->click.run());
        boolean superlike=action.equals("superlike"),like=action.equals("like");int color=like?Color.WHITE:palette.text;float density=getResources().getDisplayMetrics().density;
        String title=superlike?UiStrings.t("超级喜欢"):like?UiStrings.t("喜欢"):UiStrings.t("跳过");setContentDescription(title);int iconSize=Math.round(16*density);
        addView(new SiteIconView(context,superlike?"star":like?"heart":"close",color,false),new LayoutParams(iconSize,iconSize));
        TextView label=new TextView(context);label.setText(title);label.setTextColor(color);label.setTextSize(14);label.setTypeface(null,Typeface.BOLD);label.setSingleLine();LayoutParams lp=new LayoutParams(-2,-2);lp.leftMargin=Math.round(6*density);addView(label,lp);
        if(superlike){((SiteIconView)getChildAt(0)).tint(0xff24251d);label.setTextColor(0xff24251d);}
    }
    void palette(ThemePalette value){palette=value;invalidate();}
    @Override protected void onDraw(Canvas c){
        float w=getWidth(),h=getHeight(),r=h/2,phase=(SystemClock.uptimeMillis()%7000)/7000f;paint.setStyle(Paint.Style.FILL);paint.setShader(null);
        if(action.equals("superlike")){float wave=(float)Math.sin(phase*Math.PI*2);paint.setShader(new LinearGradient(w*(.1f+.2f*wave),0,w*(.8f+.2f*wave),h,new int[]{0xffa1c344,0xffffba28,0xffe6c91e,0xff8fbc58},null,Shader.TileMode.CLAMP));c.drawRoundRect(0,0,w,h,r,r,paint);paint.setShader(null);paint.setColor(0x66749b42);paint.setStyle(Paint.Style.STROKE);paint.setStrokeWidth(getResources().getDisplayMetrics().density);c.drawRoundRect(.5f,.5f,w-.5f,h-.5f,r,r,paint);if(visible&&isEnabled()&&isAttachedToWindow())postInvalidateDelayed(33);}
        else if(action.equals("like")){paint.setColor(palette.accent);c.drawRoundRect(0,0,w,h,r,r,paint);}
        paint.setShader(null);paint.setStyle(Paint.Style.FILL);
    }
    @Override public void onVisibilityAggregated(boolean isVisible){super.onVisibilityAggregated(isVisible);visible=isVisible;if(isVisible)invalidate();}
    @Override public void setEnabled(boolean enabled){super.setEnabled(enabled);setAlpha(enabled?1:.5f);invalidate();}
    @Override protected void onDetachedFromWindow(){visible=false;super.onDetachedFromWindow();}
}
