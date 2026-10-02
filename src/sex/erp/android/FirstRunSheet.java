package sex.erp.android;

import android.app.Activity;
import android.app.Dialog;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.ColorDrawable;
import android.graphics.drawable.GradientDrawable;
import android.view.Gravity;
import android.view.View;
import android.view.Window;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

/** Informational first-open sheet; it grants no permissions and performs no requests. */
final class FirstRunSheet extends Dialog {
    private final LinearLayout shell;
    private final TextView title,body,acknowledge;
    private final SiteIconView close;
    private final float density;
    FirstRunSheet(Activity activity,ThemePalette palette,String heading,String description){
        super(activity);requestWindowFeature(Window.FEATURE_NO_TITLE);density=activity.getResources().getDisplayMetrics().density;
        shell=new LinearLayout(activity);shell.setOrientation(LinearLayout.VERTICAL);shell.setPadding(dp(20),dp(12),dp(20),dp(24));
        FrameLayout bar=new FrameLayout(activity),closeHit=new FrameLayout(activity);close=new SiteIconView(activity,"close",palette.muted,false);
        closeHit.addView(close,new FrameLayout.LayoutParams(dp(20),dp(20),Gravity.CENTER));closeHit.setContentDescription(UiStrings.t("关闭说明"));closeHit.setFocusable(true);closeHit.setOnClickListener(v->dismiss());
        bar.addView(closeHit,new FrameLayout.LayoutParams(dp(40),dp(40),Gravity.END));shell.addView(bar,new LinearLayout.LayoutParams(-1,dp(40)));
        title=new TextView(activity);title.setText(heading);title.setTextSize(24);title.setTypeface(null,Typeface.BOLD);title.setGravity(Gravity.CENTER);title.setPadding(0,0,0,dp(18));shell.addView(title);
        body=new TextView(activity);body.setText(description);body.setTextSize(15);body.setLineSpacing(dp(4),1);body.setPadding(0,0,0,dp(24));shell.addView(body);
        acknowledge=new TextView(activity);acknowledge.setText(UiStrings.t("我知道啦"));acknowledge.setTextSize(16);acknowledge.setTextColor(Color.WHITE);acknowledge.setTypeface(null,Typeface.BOLD);acknowledge.setGravity(Gravity.CENTER);
        GradientDrawable gradient=new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,new int[]{0xffff5a4e,0xffff586d});gradient.setCornerRadius(dp(28));acknowledge.setBackground(gradient);acknowledge.setFocusable(true);acknowledge.setOnClickListener(v->dismiss());shell.addView(acknowledge,new LinearLayout.LayoutParams(-1,dp(48)));
        ScrollView scroll=new ScrollView(activity);scroll.addView(shell);setContentView(scroll);palette(palette);
        setOnShowListener(d->{Window window=getWindow();if(window==null)return;window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));window.setGravity(Gravity.BOTTOM);
            shell.measure(View.MeasureSpec.makeMeasureSpec(activity.getResources().getDisplayMetrics().widthPixels,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(0,View.MeasureSpec.UNSPECIFIED));
            window.setLayout(-1,Math.min(shell.getMeasuredHeight(),Math.max(dp(160),activity.getWindow().getDecorView().getHeight()-dp(24))));
            shell.setTranslationY(dp(48));shell.setAlpha(.75f);shell.animate().translationY(0).alpha(1).setDuration(240).start();});
    }
    void language(String heading,String description){title.setText(heading);body.setText(description);acknowledge.setText(UiStrings.t("我知道啦"));}
    void palette(ThemePalette palette){GradientDrawable background=new GradientDrawable();background.setColor(palette.surface);background.setCornerRadius(dp(22));shell.setBackground(background);shell.setClipToOutline(true);title.setTextColor(palette.text);body.setTextColor(palette.muted);close.tint(palette.muted);}
    private int dp(float value){return Math.round(value*density);}
}
