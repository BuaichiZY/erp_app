package sex.erp.android;

import android.app.Activity;
import android.app.Dialog;
import android.content.DialogInterface;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
import java.util.*;

/** Shared native bottom sheet for the site's forms, choices and confirmations. */
final class SiteDialog extends Dialog {
    private static final Map<Activity,Set<SiteDialog>> ACTIVE=new WeakHashMap<>();
    private final Activity activity;
    private final LinearLayout shell,header,footer;
    private final ScrollView scroll;
    private final Map<Integer,Button> buttons=new HashMap<>();
    private SiteDialog(Builder b){
        super(b.activity);activity=b.activity;requestWindowFeature(Window.FEATURE_NO_TITLE);ThemePalette p=b.palette;
        shell=column();shell.setPadding(dp(20),dp(12),dp(20),dp(20));shell.setBackground(background(p.surface,p.border,24));
        header=new LinearLayout(activity);header.setGravity(Gravity.CENTER_VERTICAL);TextView heading=label(b.title,21,p.text);heading.setTypeface(null,Typeface.BOLD);header.addView(heading,new LinearLayout.LayoutParams(0,-2,1));FrameLayout close=new FrameLayout(activity);close.addView(new SiteIconView(activity,"close",p.muted,false),new FrameLayout.LayoutParams(dp(20),dp(20),Gravity.CENTER));close.setContentDescription(UiStrings.t("关闭"));close.setOnClickListener(v->dismiss());header.addView(close,new LinearLayout.LayoutParams(dp(42),dp(42)));shell.addView(header);
        scroll=new ScrollView(activity);scroll.setFillViewport(false);LinearLayout body=column();body.setPadding(0,dp(12),0,dp(12));if(b.message!=null){TextView message=label(b.message,14,p.text);message.setLineSpacing(dp(4),1);body.addView(message);}if(b.view!=null){if(b.view.getParent()!=null)((ViewGroup)b.view.getParent()).removeView(b.view);body.addView(b.view,new LinearLayout.LayoutParams(-1,-2));}if(b.items!=null)for(int i=0;i<b.items.length;i++){int choice=i;TextView item=label(b.items[i],15,p.text);item.setGravity(Gravity.CENTER_VERTICAL);item.setPadding(dp(12),dp(14),dp(12),dp(14));item.setBackground(background(p.surface,p.border,12));item.setFocusable(true);item.setOnClickListener(v->{dismiss();if(b.itemListener!=null)b.itemListener.onClick(this,choice);});LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(-1,-2);lp.bottomMargin=dp(8);body.addView(item,lp);}scroll.addView(body);shell.addView(scroll,new LinearLayout.LayoutParams(-1,0,1));
        footer=new LinearLayout(activity);footer.setGravity(Gravity.END|Gravity.CENTER_VERTICAL);for(int which:new int[]{DialogInterface.BUTTON_NEGATIVE,DialogInterface.BUTTON_NEUTRAL,DialogInterface.BUTTON_POSITIVE}){String text=b.labels.get(which);if(text==null)continue;boolean primary=which==DialogInterface.BUTTON_POSITIVE;Button action=new Button(activity);action.setText(text);action.setAllCaps(false);action.setTextSize(14);action.setTextColor(primary?Color.WHITE:p.text);action.setStateListAnimator(null);action.setBackground(background(primary?p.accent:p.surface,primary?p.accent:p.border,22));action.setPadding(dp(12),0,dp(12),0);action.setMinWidth(0);action.setMinimumWidth(0);LinearLayout.LayoutParams lp=new LinearLayout.LayoutParams(0,dp(44),1);lp.leftMargin=dp(6);footer.addView(action,lp);buttons.put(which,action);action.setOnClickListener(v->{dismiss();DialogInterface.OnClickListener listener=b.listeners.get(which);if(listener!=null)listener.onClick(this,which);});}if(footer.getChildCount()>0)shell.addView(footer,new LinearLayout.LayoutParams(-1,-2));setContentView(shell);
    }
    @Override public void show(){super.show();Window w=getWindow();if(w==null)return;w.setBackgroundDrawableResource(android.R.color.transparent);w.setGravity(Gravity.BOTTOM);w.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_RESIZE);int width=activity.getResources().getDisplayMetrics().widthPixels;int max=activity.getResources().getDisplayMetrics().heightPixels-dp(72);scroll.getChildAt(0).measure(View.MeasureSpec.makeMeasureSpec(Math.max(1,width-dp(40)),View.MeasureSpec.EXACTLY),View.MeasureSpec.makeMeasureSpec(0,View.MeasureSpec.UNSPECIFIED));int height=dp(88)+(footer.getChildCount()>0?dp(48):0)+scroll.getChildAt(0).getMeasuredHeight();w.setLayout(-1,Math.min(max,Math.max(dp(160),height)));ACTIVE.computeIfAbsent(activity,a->Collections.newSetFromMap(new WeakHashMap<SiteDialog,Boolean>())).add(this);shell.setTranslationY(dp(28));shell.setAlpha(0);shell.animate().translationY(0).alpha(1).setDuration(180).start();}
    @Override public void dismiss(){Set<SiteDialog> active=ACTIVE.get(activity);if(active!=null)active.remove(this);super.dismiss();}
    Button getButton(int which){return buttons.get(which);}
    static void closeFor(Activity activity){Set<SiteDialog> dialogs=ACTIVE.remove(activity);if(dialogs!=null)for(SiteDialog dialog:new ArrayList<>(dialogs))dialog.dismiss();}
    private LinearLayout column(){LinearLayout result=new LinearLayout(activity);result.setOrientation(1);return result;}
    private TextView label(String text,int size,int color){TextView result=new TextView(activity);result.setText(text==null?"":text);result.setTextSize(size);result.setTextColor(color);return result;}
    private GradientDrawable background(int color,int border,int radius){GradientDrawable result=new GradientDrawable();result.setColor(color);result.setCornerRadius(dp(radius));result.setStroke(dp(1),border);return result;}
    private int dp(int value){return Math.round(value*activity.getResources().getDisplayMetrics().density);}
    static final class Builder {
        final Activity activity;final ThemePalette palette;String title,message;View view;String[] items;DialogInterface.OnClickListener itemListener;final Map<Integer,String> labels=new HashMap<>();final Map<Integer,DialogInterface.OnClickListener> listeners=new HashMap<>();
        Builder(Activity activity,ThemePalette palette){this.activity=activity;this.palette=palette;}
        Builder setTitle(String value){title=value;return this;}
        Builder setMessage(String value){message=value;return this;}
        Builder setView(View value){view=value;return this;}
        Builder setItems(String[] values,DialogInterface.OnClickListener listener){items=values;itemListener=listener;return this;}
        Builder setPositiveButton(String text,DialogInterface.OnClickListener listener){return button(DialogInterface.BUTTON_POSITIVE,text,listener);}
        Builder setNegativeButton(String text,DialogInterface.OnClickListener listener){return button(DialogInterface.BUTTON_NEGATIVE,text,listener);}
        Builder setNeutralButton(String text,DialogInterface.OnClickListener listener){return button(DialogInterface.BUTTON_NEUTRAL,text,listener);}
        private Builder button(int which,String text,DialogInterface.OnClickListener listener){labels.put(which,text);listeners.put(which,listener);return this;}
        SiteDialog create(){return new SiteDialog(this);}
        SiteDialog show(){SiteDialog dialog=create();dialog.show();return dialog;}
    }
}
