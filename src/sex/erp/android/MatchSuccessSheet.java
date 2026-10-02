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
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import org.json.JSONObject;

/** Native celebration sheet; opening a conversation never sends a message. */
final class MatchSuccessSheet extends Dialog {
    private final float density;
    private final LinearLayout shell;
    private final TextView subtitle;
    private final Button continueButton;
    private final SiteIconView close;

    MatchSuccessSheet(Activity activity, NativeApi api, ThemePalette palette,
                      JSONObject self, JSONObject peer, Runnable greet, Runnable keepBrowsing) {
        super(activity);
        requestWindowFeature(Window.FEATURE_NO_TITLE);
        density=activity.getResources().getDisplayMetrics().density;
        shell=new LinearLayout(activity);shell.setOrientation(LinearLayout.VERTICAL);
        shell.setPadding(dp(20),dp(14),dp(20),dp(24));
        FrameLayout bar=new FrameLayout(activity);
        FrameLayout closeHit=new FrameLayout(activity);
        close=new SiteIconView(activity,"close",palette.muted,false);
        closeHit.addView(close,new FrameLayout.LayoutParams(dp(20),dp(20),Gravity.CENTER));
        closeHit.setContentDescription(UiStrings.t("关闭配对成功提示"));closeHit.setFocusable(true);
        closeHit.setOnClickListener(v->dismiss());
        bar.addView(closeHit,new FrameLayout.LayoutParams(dp(40),dp(40),Gravity.END));
        shell.addView(bar,new LinearLayout.LayoutParams(-1,dp(40)));

        FrameLayout artwork=new FrameLayout(activity){
            @Override protected void onSizeChanged(int w,int h,int oldW,int oldH){
                super.onSizeChanged(w,h,oldW,oldH);
                int size=Math.min(dp(104),Math.round(w*.30f));
                for(int i=0;i<2;i++){
                    FrameLayout.LayoutParams card=(FrameLayout.LayoutParams)getChildAt(i).getLayoutParams();
                    card.width=Math.round(w*.32f);card.height=Math.round(h*.75f);
                    card.leftMargin=Math.round(w*(i==0?.09f:.59f));card.topMargin=Math.round(h*.08f);
                    getChildAt(i).setLayoutParams(card);
                    FrameLayout.LayoutParams avatar=(FrameLayout.LayoutParams)getChildAt(i+2).getLayoutParams();
                    avatar.width=size;avatar.height=size;
                    avatar.leftMargin=Math.round(w*(i==0?.40f:.60f)-size/2f);
                    avatar.topMargin=Math.round(h*.60f-size/2f);getChildAt(i+2).setLayoutParams(avatar);
                }
            }
        };
        for(int i=0;i<2;i++){View card=new View(activity);card.setBackground(round(0xffff5a4e,22));artwork.addView(card,new FrameLayout.LayoutParams(1,1));}
        artwork.addView(avatar(activity,api,palette,self),new FrameLayout.LayoutParams(1,1));
        artwork.addView(avatar(activity,api,palette,peer),new FrameLayout.LayoutParams(1,1));
        artwork.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO_HIDE_DESCENDANTS);
        shell.addView(artwork,new LinearLayout.LayoutParams(-1,dp(156)));
        TextView title=copy(activity,UiStrings.t("配对成功！"),29,0xffff8b43);
        title.setTypeface(null,Typeface.BOLD);title.setPadding(0,dp(10),0,dp(8));shell.addView(title);
        subtitle=copy(activity,UiStrings.t("你和 ")+peer.optString("displayName",UiStrings.t("对方"))+UiStrings.t(" 互相喜欢。"),14,palette.muted);
        subtitle.setPadding(0,0,0,dp(24));shell.addView(subtitle);
        LinearLayout greeting=new LinearLayout(activity);greeting.setGravity(Gravity.CENTER);
        GradientDrawable gradient=new GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,new int[]{0xffff5a4e,0xffff586d});
        gradient.setCornerRadius(dp(28));greeting.setBackground(gradient);
        SiteIconView chat=new SiteIconView(activity,"chat",Color.WHITE,false);
        greeting.addView(chat,new LinearLayout.LayoutParams(dp(20),dp(20)));
        TextView label=copy(activity,UiStrings.t("打声招呼"),16,Color.WHITE);label.setTypeface(null,Typeface.BOLD);
        LinearLayout.LayoutParams labelLp=new LinearLayout.LayoutParams(-2,-2);labelLp.leftMargin=dp(8);greeting.addView(label,labelLp);
        greeting.setContentDescription(UiStrings.t("打声招呼，打开配对聊天"));greeting.setFocusable(true);
        greeting.setOnClickListener(v->{dismiss();greet.run();});shell.addView(greeting,new LinearLayout.LayoutParams(-1,dp(48)));
        continueButton=new Button(activity);continueButton.setAllCaps(false);continueButton.setText(UiStrings.t("继续滑卡"));
        continueButton.setTextSize(16);continueButton.setStateListAnimator(null);
        continueButton.setBackgroundColor(Color.TRANSPARENT);continueButton.setOnClickListener(v->{dismiss();keepBrowsing.run();});
        LinearLayout.LayoutParams keepLp=new LinearLayout.LayoutParams(-1,dp(48));keepLp.topMargin=dp(10);shell.addView(continueButton,keepLp);
        ScrollView scroll=new ScrollView(activity);scroll.setFillViewport(false);scroll.addView(shell);
        setContentView(scroll);palette(palette);
        setOnShowListener(d->{Window window=getWindow();if(window==null)return;
            window.setBackgroundDrawable(new ColorDrawable(Color.TRANSPARENT));window.setGravity(Gravity.BOTTOM);
            window.addFlags(WindowManager.LayoutParams.FLAG_DIM_BEHIND);
            WindowManager.LayoutParams attributes=window.getAttributes();attributes.dimAmount=.5f;window.setAttributes(attributes);
            int maximum=activity.getWindow().getDecorView().getHeight()-dp(24);
            shell.measure(View.MeasureSpec.makeMeasureSpec(activity.getResources().getDisplayMetrics().widthPixels,View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(0,View.MeasureSpec.UNSPECIFIED));
            window.setLayout(-1,Math.min(Math.max(dp(320),maximum),shell.getMeasuredHeight()));
            shell.setTranslationY(dp(48));shell.setAlpha(.75f);shell.animate().translationY(0).alpha(1).setDuration(240).start();
        });
    }

    void palette(ThemePalette palette){shell.setBackground(round(palette.surface,22));shell.setClipToOutline(true);subtitle.setTextColor(palette.muted);continueButton.setTextColor(palette.text);close.tint(palette.muted);}
    private View avatar(Activity activity,NativeApi api,ThemePalette palette,JSONObject user){
        FrameLayout ring=new FrameLayout(activity);ring.setPadding(dp(3),dp(3),dp(3),dp(3));ring.setBackground(round(Color.WHITE,80));ring.setClipToOutline(true);
        FrameLayout inner=new FrameLayout(activity);inner.setBackground(round(palette.surface2,80));inner.setClipToOutline(true);
        String name=user.optString("displayName","");TextView fallback=copy(activity,name.isEmpty()?"?":name.substring(0,name.offsetByCodePoints(0,1)),24,palette.muted);
        inner.addView(fallback,new FrameLayout.LayoutParams(-1,-1));
        AnimatedPhotoView photo=new AnimatedPhotoView(activity);photo.palette(palette);photo.setScaleType(ImageView.ScaleType.CENTER_CROP);
        inner.addView(photo,new FrameLayout.LayoutParams(-1,-1));api.image(photo,user.optJSONObject("avatar"),true);
        ring.addView(inner,new FrameLayout.LayoutParams(-1,-1));return ring;
    }
    private TextView copy(Activity activity,String text,int size,int color){TextView view=new TextView(activity);view.setText(text);view.setTextSize(size);view.setTextColor(color);view.setGravity(Gravity.CENTER);view.setIncludeFontPadding(false);return view;}
    private GradientDrawable round(int color,int radius){GradientDrawable drawable=new GradientDrawable();drawable.setColor(color);drawable.setCornerRadius(dp(radius));return drawable;}
    private int dp(float value){return Math.round(value*density);}
}
