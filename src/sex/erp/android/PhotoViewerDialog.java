package sex.erp.android;

import android.app.*;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.view.*;
import android.widget.*;
import org.json.*;
import java.util.*;

/** The official lightbox's close and previous/next controls, rendered natively. */
final class PhotoViewerDialog extends Dialog {
    private final Activity activity;
    private final NativeApi api;
    private final AnimatedPhotoView image;
    private final List<JSONObject> photos=new ArrayList<>();
    private final TextView position;
    private int index;
    PhotoViewerDialog(Activity activity,NativeApi api,ThemePalette palette,JSONArray candidates,JSONObject selected){
        super(activity);this.activity=activity;this.api=api;requestWindowFeature(Window.FEATURE_NO_TITLE);
        for(int i=0;i<candidates.length();i++){JSONObject item=candidates.optJSONObject(i);if(item!=null&&"show".equals(item.optString("view","show"))){if(item==selected||(!selected.optString("id").isEmpty()&&selected.optString("id").equals(item.optString("id"))))index=photos.size();photos.add(item);}}
        if(photos.isEmpty())photos.add(selected);
        FrameLayout root=new FrameLayout(activity);root.setBackgroundColor(0xf0000000);image=new AnimatedPhotoView(activity);image.palette(palette);image.setScaleType(ImageView.ScaleType.FIT_CENTER);image.setPadding(dp(12),dp(12),dp(12),dp(12));root.addView(image,new FrameLayout.LayoutParams(-1,-1));image.setOnClickListener(v->dismiss());
        FrameLayout close=control("close","关闭",this::dismiss);FrameLayout.LayoutParams lp=new FrameLayout.LayoutParams(dp(44),dp(44),Gravity.TOP|Gravity.RIGHT);lp.topMargin=dp(12);lp.rightMargin=dp(12);root.addView(close,lp);
        position=new TextView(activity);position.setTextColor(Color.WHITE);position.setTextSize(13);position.setGravity(Gravity.CENTER);position.setPadding(dp(12),dp(6),dp(12),dp(6));position.setBackground(background());FrameLayout.LayoutParams counter=new FrameLayout.LayoutParams(-2,-2,Gravity.BOTTOM|Gravity.CENTER_HORIZONTAL);counter.bottomMargin=dp(16);root.addView(position,counter);
        if(photos.size()>1){FrameLayout prev=control("back","上一张",()->{index=(index+photos.size()-1)%photos.size();display();}),next=control("back","下一张",()->{index=(index+1)%photos.size();display();});next.getChildAt(0).setRotation(180);FrameLayout.LayoutParams left=new FrameLayout.LayoutParams(dp(44),dp(44),Gravity.CENTER_VERTICAL|Gravity.LEFT);left.leftMargin=dp(10);root.addView(prev,left);FrameLayout.LayoutParams right=new FrameLayout.LayoutParams(dp(44),dp(44),Gravity.CENTER_VERTICAL|Gravity.RIGHT);right.rightMargin=dp(10);root.addView(next,right);}
        setContentView(root);display();
    }
    private void display(){image.setImageDrawable(null);api.imageCached(image,photos.get(index),false);position.setText((index+1)+" / "+photos.size());position.setVisibility(photos.size()>1?View.VISIBLE:View.GONE);}
    @Override public void show(){super.show();Window w=getWindow();if(w!=null){w.setBackgroundDrawableResource(android.R.color.transparent);w.setLayout(-1,-1);w.setStatusBarColor(Color.BLACK);w.setNavigationBarColor(Color.BLACK);}}
    private FrameLayout control(String icon,String label,Runnable click){FrameLayout result=new FrameLayout(activity);result.setBackground(background());result.setContentDescription(UiStrings.t(label));result.setFocusable(true);result.addView(new SiteIconView(activity,icon,Color.WHITE,false),new FrameLayout.LayoutParams(dp(22),dp(22),Gravity.CENTER));result.setOnClickListener(v->click.run());return result;}
    private GradientDrawable background(){GradientDrawable result=new GradientDrawable();result.setColor(0x44ffffff);result.setCornerRadius(dp(30));return result;}
    private int dp(int value){return Math.round(value*activity.getResources().getDisplayMetrics().density);}
}
